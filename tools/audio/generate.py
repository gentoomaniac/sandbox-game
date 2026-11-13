"""Generates every sound under art/generated/sounds/ (run it with `make art`).

Each sound event (see EVENTS; the names are also the keys of data/sounds.cfg) is written as
a few variants, art/generated/sounds/<event>_<n>.wav with n from 1: mono, 16 bit, 44.1 kHz.

- The sounds are made in footsteps.py, work.py, ui.py, weather.py, fire.py, bell.py and
  animals.py, from the building blocks in dsp.py. Each variant is a function that takes a random
  generator and returns samples. An event lists its variant functions, so most repeat one
  function (the generator makes each a little different in pitch, timing and noise) and some
  mix kinds.
- Every variant draws from its own generator, seeded by its event name and number, so
  changing one sound leaves all the others byte for byte the same.
- An event's level is the peak of its loudest variant, in dBFS; the variants keep their
  differences (a quiet variant stays quieter than a loud one). The levels balance the events
  against each other; data/sounds.cfg adjusts the volume in the game.
- Every sound is high-passed at 20 Hz (no DC offset) and gets a short fade at both ends.
- The loops (events ending in _loop) are built as circles: noise is filtered circularly,
  slow movements end where they start, events near the end wrap around to the start, and
  tones hold a whole number of cycles. The seam is then like any other point, which beats
  crossfading the tail into the head (a crossfade dips or doubles the level of tones and
  thins out noise for its length). Their files carry a forward loop over the whole file
  in a "smpl" chunk, which Godot's importer reads (edit/loop_mode "Detect From WAV", its
  default), so they loop with no setting on the Godot side. Godot then loops from the
  first to the last sample, as it does when loop_mode is set to Forward by hand.

To tune one sound, change its function and run `make art`; `tools/audio/check.py`
reports lengths and levels, `tools/audio/preview.py` writes all events into one file to
listen to. To replace a sound with a recording, point its event in data/sounds.cfg to the
new file (or drop the event from EVENTS and write the recording under its name).
"""

import struct
import zlib
from pathlib import Path

import numpy as np

import animals
import bell
import fire
import footsteps
import ui
import weather
import work
from dsp import RATE, highpass, samples

SOUNDS = Path(__file__).resolve().parents[2] / "art" / "generated" / "sounds"

# event: (peak level in dBFS, the function of each variant)
EVENTS = {
    "step_grass": (-20, [footsteps.step_grass] * 4),
    "step_soil": (-18, [footsteps.step_soil] * 4),
    "step_sand": (-20, [footsteps.step_sand] * 4),
    "step_wetland": (-17, [footsteps.step_wetland] * 4),
    "step_ice": (-20, [footsteps.step_ice] * 4),
    "step_snow": (-19, [footsteps.step_snow] * 4),
    "step_wood": (-17, [footsteps.step_wood] * 4),
    "axe_chop": (-6, [work.axe_chop] * 3),
    "tree_fall": (-4, [work.tree_fall] * 2),
    "pickaxe_hit": (-8, [work.pickaxe_hit] * 3),
    "stone_break": (-5, [work.stone_break] * 3),
    "scythe_swish": (-11, [work.scythe_swish] * 3),
    "shovel_dig": (-9, [work.shovel_dig] * 3),
    "hoe_till": (-10, [work.hoe_till] * 3),
    "water_pour": (-11, [work.water_pour] * 2),
    "plant": (-13, [work.plant] * 3),
    "pick_bush": (-12, [work.pick_bush] * 3),
    "item_pickup": (-12, [work.item_pickup] * 3),
    "build_place": (-6, [work.build_place] * 2),
    "denied": (-12, [work.denied] * 2),
    "ui_click": (-16, [ui.ui_click] * 3),
    "ui_open": (-15, [ui.ui_open] * 2),
    "ui_close": (-15, [ui.ui_close] * 2),
    "hotbar_select": (-18, [ui.hotbar_select] * 3),
    "chest_open": (-9, [ui.chest_open] * 2),
    "chest_close": (-10, [ui.chest_close] * 2),
    "rain_loop": (-10, [weather.rain_loop] * 2),
    "wind_loop": (-12, [weather.wind_loop] * 2),
    "wind_gust": (-8, [weather.wind_gust] * 3),
    # By distance (task 214): the game also lowers and dulls them the farther the strike was.
    "thunder_far": (-16, weather.thunder_variants(weather.FAR)),
    "thunder_mid": (-9, weather.thunder_variants(weather.MID)),
    "thunder_close": (-2, weather.thunder_variants(weather.CLOSE)),
    # Lightning running across the sky (task 222): a long tearing rumble, mono; the game pans it.
    "thunder_crawl": (-9, [weather.thunder_crawl(profile) for profile in weather.CRAWL]),
    # The main sound of a room with a fire: crackle only, the pops no louder than a log's.
    "fire_crackle_loop": (-8, [fire.fire_crackle_loop] * 2),
    # Heard across the marsh, so loud, and long: the low partials hum for ten seconds.
    "bell_ring": (-9, [bell.bell_strike] * 2),
    "bird_chirp": (-12, [animals.bird_rising, animals.bird_trill, animals.bird_whistle]),
    "frog_croak": (-10, [animals.frog_common, animals.frog_bull, animals.frog_tree]),
    # Under the single croaks, and quiet: it plays on and on through spring and summer evenings.
    "frog_chorus_loop": (-22, [animals.frog_chorus_loop] * 2),
    "deer_snort": (-11, [animals.deer_snort] * 2 + [animals.deer_double_snort]),
    "deer_hooves": (-12, [animals.deer_hooves] * 3),
    "rabbit_rustle": (-14, [animals.rabbit_rustle] * 3),
    "squirrel_chatter": (-13, [animals.squirrel_chatter] * 3),
    "bee_buzz_loop": (-16, [animals.bee_buzz_loop] * 2),
    # The storks and geese are rare and far off, so quieter still than the farm animals.
    "stork_clatter": (-25, [animals.stork_clatter] * 3),
    "goose_honk": (-24, [animals.goose_honk] * 3),
    # The farm animals are kept quiet: they are heard often, wherever the player keeps them.
    "cow_moo": (-20, [animals.cow_moo] * 3),
    "sheep_baa": (-21, [animals.sheep_baa] * 3),
    "chicken_cluck": (-22, [animals.chicken_cluck] * 3),
    # The rooster carries across the farm, so it is a little louder than a cluck.
    "rooster_crow": (-17, [animals.rooster_crow] * 3),
    "dog_bark": (-20, [animals.dog_bark] * 3),
    "cat_meow": (-23, [animals.cat_meow] * 3),
    # Horses whinny, and as often snort.
    "horse_whinny": (-21, [animals.horse_whinny, animals.horse_whinny, animals.horse_snort, animals.horse_snort]),
}

FADE_IN = 0.002
FADE_OUT = 0.01


def is_loop(event):
    return event.endswith("_loop")


def cleaned(sound, loop):
    """Without DC and, unless it loops, with a short fade at both ends against clicks."""
    sound = highpass(sound, 20, loop)
    if not loop:
        fade_in = samples(FADE_IN)
        fade_out = samples(FADE_OUT)
        sound[:fade_in] *= np.sin(0.5 * np.pi * np.arange(fade_in) / fade_in) ** 2
        sound[-fade_out:] *= np.cos(0.5 * np.pi * np.arange(1, fade_out + 1) / fade_out) ** 2
    return sound


def wav_bytes(pcm, loop):
    """A 16-bit mono WAV file; a loop gets a "smpl" chunk looping the whole file."""
    data = pcm.astype("<i2").tobytes()
    chunks = struct.pack("<4sIHHIIHH", b"fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16)
    chunks += struct.pack("<4sI", b"data", len(data)) + data
    if loop:
        sample_period = round(1e9 / RATE)
        # Header (no MIDI or SMPTE data, one loop), then the loop: forward, over every
        # sample (the end is inclusive), played forever.
        smpl = struct.pack("<9I", 0, 0, sample_period, 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(pcm) - 1, 0, 0)
        chunks += struct.pack("<4sI", b"smpl", len(smpl)) + smpl
    return b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks


def main():
    SOUNDS.mkdir(parents=True, exist_ok=True)
    for event, (level, variants) in EVENTS.items():
        loop = is_loop(event)
        sounds = []
        for number, variant in enumerate(variants, start=1):
            rng = np.random.default_rng([zlib.crc32(event.encode()), number])
            sounds.append(cleaned(variant(rng), loop))
        gain = 10 ** (level / 20) / max(np.abs(sound).max() for sound in sounds)
        for number, sound in enumerate(sounds, start=1):
            pcm = np.round(sound * gain * 32767)
            (SOUNDS / f"{event}_{number}.wav").write_bytes(wav_bytes(pcm, loop))


if __name__ == "__main__":
    main()
