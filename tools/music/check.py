"""Checks every module under art/generated/music/ with an independent player (run by `make art`,
after generate.py): libmodplug (see modplug.py) must load it as 4 channels with its patterns, and
play it row by row as its piece says: every row of every section in the order, each for `speed`
ticks (see `tick_frames`), the short sections broken off after their last row, and then stop.
Where libmodplug is not installed it says so and checks nothing.

With --against DIR it compares the game's renders, DIR/<piece>.wav (mono 16 bit at 44.1 kHz, the
order list once through, written by render.gd; `make music-check` runs both), with libmodplug's:
- the length: as many samples as the piece's rows take;
- the time: no offset between the two (the best match within MAX_SEARCH samples is at most 2 off);
  a render too short to look for it (3 s and the search) is a problem of its own;
- the events: their loudness tick by tick correlates (at least MIN_LOUDNESS_CORRELATION);
- the pitch: in each row the strongest frequency is the same within MAX_PITCH_CENTS in nearly every
  row, and the spectra are alike (cosine similarity at least MIN_ROW_SIMILARITY in every row); a row
  silent in both counts as alike, a row silent in only one as unlike.
Both interpolate linearly between samples and ramp volumes against clicks, ModPlug's ramps a little
different (see game/audio/module_renderer.gd).
"""

import argparse
import sys
import wave
from pathlib import Path

import numpy as np

import modplug
from generate import MUSIC, PATTERN_ROWS, PIECES, parse_piece

RATE = 44100
MAX_OFFSET = 2
# The offset between the render and libmodplug's is looked for this far, in samples, each way.
MAX_SEARCH = 200
MIN_LOUDNESS_CORRELATION = 0.9
MIN_ROW_SIMILARITY = 0.95
MAX_PITCH_CENTS = 50
MIN_PITCH_ROWS = 0.95
# A row's spectrum below this (a sum over the row's FFT, samples -1..1) is silence.
SILENCE = 1e-3


def tick_frames(tempo):
    """The samples of a tick at RATE: 2.5 / tempo seconds, cut to a whole number, as libmodplug plays
    it. At tempo 125 it is exact."""
    return RATE * 5 // (2 * tempo)


def expected_rows(piece):
    """The (order, row) of every row the piece plays, in order."""
    rows, order = [], 0
    for name in piece["order"]:
        section_rows = piece["sections"][name]["rows"]
        for start in range(0, section_rows, PATTERN_ROWS):
            rows += [(order, row) for row in range(min(PATTERN_ROWS, section_rows - start))]
            order += 1
    return rows


def problems(module, piece):
    _, positions, info = modplug.play(module, RATE, tick_frames(piece["tempo"]))
    patterns = sum(-(-piece["sections"][name]["rows"] // PATTERN_ROWS) for name in set(piece["order"]))
    found = []
    if info["channels"] != 4:
        found.append(f"{info['channels']} channels, not 4")
    if info["patterns"] != patterns:
        found.append(f"{info['patterns']} patterns, the piece has {patterns}")
    # ModPlug reports the position after each tick: the row each tick belongs to.
    played = positions[:: piece["speed"]]
    rows = expected_rows(piece)
    if played[: len(rows)] != rows:
        first = next(i for i, (a, b) in enumerate(zip(played, rows + [None] * len(played))) if a != b)
        found.append(f"row {first} played as {played[first]}, the piece has {rows[first] if first < len(rows) else 'ended'}")
    if len(positions) > (len(rows) + 2) * piece["speed"]:
        found.append(f"plays {len(positions) / piece['speed']:.0f} rows, the piece has {len(rows)}")
    return found


def render_problems(module, piece, rendered):
    """What differs between `rendered` (samples -1..1) and libmodplug's play of the module; prints
    the measures."""
    tick = tick_frames(piece["tempo"])
    row_frames = tick * piece["speed"]
    reference, _, _ = modplug.play(module, RATE, tick)
    rows = len(expected_rows(piece))
    found = []
    if len(rendered) != rows * row_frames:
        found.append(f"the render has {len(rendered)} samples, the piece's {rows} rows take {rows * row_frames}")
    length = min(len(rendered), len(reference), rows * row_frames) // row_frames * row_frames
    rendered, reference = rendered[:length], reference[:length]
    window = RATE * 3
    if length < window + 2 * MAX_SEARCH:
        found.append(f"too short to compare: {length} samples, at least {window + 2 * MAX_SEARCH} needed")
        return found

    search = range(-MAX_SEARCH, MAX_SEARCH + 1)
    start = MAX_SEARCH
    matches = [np.dot(rendered[start : start + window], reference[start + offset : start + offset + window]) for offset in search]
    offset = search[int(np.argmax(matches))]
    loudness = [np.sqrt((signal.reshape(-1, tick) ** 2).mean(axis=1)) for signal in (rendered, reference)]
    with np.errstate(invalid="ignore"):
        # Not a number where a side is silent throughout: found below.
        correlation = np.corrcoef(*loudness)[0, 1]
    taper = np.hanning(row_frames)
    frequencies = np.fft.rfftfreq(row_frames, 1 / RATE)
    audible = frequencies > 30
    similarities, pitch_cents = [], []
    for start in range(0, length, row_frames):
        spectra = [np.abs(np.fft.rfft(signal[start : start + row_frames] * taper))[audible] for signal in (rendered, reference)]
        norms = [np.linalg.norm(spectrum) for spectrum in spectra]
        sounding = [norm > SILENCE for norm in norms]
        if not any(sounding):
            similarities.append(1.0)
            continue
        if not all(sounding):
            similarities.append(0.0)
            pitch_cents.append(np.inf)
            continue
        similarities.append(np.dot(*spectra) / (norms[0] * norms[1]))
        strongest = [frequencies[audible][np.argmax(spectrum)] for spectrum in spectra]
        pitch_cents.append(abs(1200 * np.log2(strongest[0] / strongest[1])))
    pitch_rows = np.mean(np.array(pitch_cents) <= MAX_PITCH_CENTS) if pitch_cents else 1.0
    print(
        f"  against libmodplug: offset {offset} samples, loudness correlation {correlation:.3f}, "
        f"row spectra similarity min {min(similarities):.3f} median {np.median(similarities):.3f}, "
        f"strongest frequency within {MAX_PITCH_CENTS} cents in {pitch_rows:.1%} of {len(pitch_cents)} rows"
    )
    if abs(offset) > MAX_OFFSET:
        found.append(f"the render is {offset} samples off libmodplug's")
    if not np.isfinite(correlation) or correlation < MIN_LOUDNESS_CORRELATION:
        found.append(f"the loudness tick by tick correlates {correlation:.3f}, under {MIN_LOUDNESS_CORRELATION}")
    if min(similarities) < MIN_ROW_SIMILARITY:
        found.append(f"row {int(np.argmin(similarities))} sounds unlike libmodplug's (similarity {min(similarities):.3f})")
    if pitch_rows < MIN_PITCH_ROWS:
        found.append(f"the strongest frequency differs in {1 - pitch_rows:.1%} of the rows")
    return found


def read_wav(path):
    """The samples (-1..1) of a mono 16-bit WAV file at RATE."""
    with wave.open(str(path)) as file:
        if (file.getnchannels(), file.getsampwidth(), file.getframerate()) != (1, 2, RATE):
            sys.exit(f"{path}: not mono 16 bit at {RATE} Hz")
        return np.frombuffer(file.readframes(file.getnframes()), dtype="<i2") / 32768


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--against", type=Path, help="compare the game's renders in this folder with libmodplug's")
    arguments = parser.parse_args()
    if modplug.LIBRARY is None:
        print("tools/music/check.py: skipped, libmodplug is not installed (Gentoo: media-libs/libmodplug)")
        return
    failed = False
    for path in sorted(PIECES.glob("*.txt")):
        module = (MUSIC / f"{path.stem}.mod").read_bytes()
        piece = parse_piece(path.read_text())
        found = problems(module, piece)
        if arguments.against:
            print(f"{path.stem}.mod:")
            found += render_problems(module, piece, read_wav(arguments.against / f"{path.stem}.wav"))
        for problem in found:
            print(f"{path.stem}.mod: {problem}")
            failed = True
    if failed:
        sys.exit("tools/music/check.py: a module does not play as its piece says")


if __name__ == "__main__":
    main()
