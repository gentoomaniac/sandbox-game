"""Animal sounds: birds, crows, frogs and their chorus, deer, rabbits, squirrels and bees, the storks
and the geese, and the cows, sheep, hens, dogs, cats and horses of the livestock (see
design/presentation/sound.md)."""

import numpy as np

from dsp import RATE, SAW, bandpass, burst, envelope, fade_out, lowpass, noise, noise_band
from dsp import place, resonance, rms, silence, sweep, times, tone

BEE_LENGTH = 3.0
CHORUS_LENGTH = 8.0
# Croaks of the chorus keep this far from the loop's seam, so both sides of it are the murmur.
CHORUS_SEAM_GAP = 0.15


def _bird_note(start, end, length):
    """One chirp: a quick glide with a fast flutter, fading out at its end."""
    flutter = 0.75 + 0.25 * np.sin(2 * np.pi * 38 * times(length))
    note = sweep(start, end, length, 0.7, harmonics=(1.0, 0.1)) * flutter
    return fade_out(note * envelope(length, 0.008, 25), 0.015)


def _phrase(notes, gap):
    """Notes (start Hz, end Hz, length) one after another, gap seconds apart."""
    out = silence(sum(length + gap for _, _, length in notes) + 0.1)
    at = 0.02
    for start, end, length in notes:
        place(out, _bird_note(start, end, length), at)
        at += length + gap
    return out


def bird_rising(rng):
    """Three chirps, each a little higher."""
    pitch = rng.uniform(0.92, 1.08)
    notes = [(3200, 4800, 0.07), (4600, 3600, 0.06), (3400, 5200, 0.09)]
    stretch = rng.uniform(0.9, 1.1, len(notes))
    notes = [(start * pitch, end * pitch, length * k) for (start, end, length), k in zip(notes, stretch)]
    return _phrase(notes, rng.uniform(0.04, 0.06))


def bird_trill(rng):
    """A quick trill of short notes, falling a little."""
    pitch = rng.uniform(0.92, 1.08)
    count = rng.integers(7, 10)
    notes = [(4200 * pitch * 0.97**k, 3600 * pitch * 0.97**k, 0.035) for k in range(count)]
    return _phrase(notes, 0.02)


def bird_whistle(rng):
    """A thin high note and a lower falling one: "tsee-tew"."""
    pitch = rng.uniform(0.92, 1.08)
    return _phrase([(4800 * pitch, 5000 * pitch, 0.18), (3800 * pitch, 2900 * pitch, 0.15)], 0.06)


def _croak(start, end, length, pulse_rate, low, high, attack, rate, release):
    """A frog's croak: a buzzing tone, pulsed by its throat, through a band."""
    pulses = 0.5 + 0.5 * np.sin(2 * np.pi * pulse_rate * times(length))
    buzz = sweep(start, end, length, harmonics=SAW) * pulses
    croak = bandpass(buzz, low, high) * envelope(length, attack, rate)
    return fade_out(croak, release)


def _croaks(rng, croak, count, gap):
    """The same croak count times, about gap seconds apart."""
    length = len(croak) / RATE
    out = silence(0.02 + count * (length + 1.15 * gap) + 0.05)
    at = 0.02
    for _ in range(count):
        place(out, croak, at)
        at += length + gap * rng.uniform(0.85, 1.15)
    return out


def frog_common(rng):
    """Two or three throaty croaks."""
    pitch = rng.uniform(0.9, 1.1)
    croak = _croak(118 * pitch, 104 * pitch, 0.28, 26, 250, 1400, 0.03, 6, 0.04)
    return _croaks(rng, croak, rng.integers(2, 4), 0.35)


def frog_bull(rng):
    """One deep, long "rumm"."""
    pitch = rng.uniform(0.9, 1.1)
    croak = _croak(90 * pitch, 80 * pitch, 0.6, 18, 150, 800, 0.05, 3, 0.1)
    return _croaks(rng, croak, 1, 0)


def frog_tree(rng):
    """A small frog's quick, high "creek creek creek"."""
    pitch = rng.uniform(0.9, 1.1)
    creek = _croak(420 * pitch, 400 * pitch, 0.07, 55, 800, 3500, 0.008, 20, 0.015)
    return _croaks(rng, creek, rng.integers(3, 5), 0.07)


def frog_chorus_loop(rng):
    """Frogs croaking together on a spring evening: a murmur of far ones, a throaty buzz pulsing
    in a band, and over it a dozen near frogs, each croaking a few times in its own pitch."""
    # The pulses hold a whole number of cycles in the loop, so the murmur has no seam.
    pulses = 0.6 + 0.4 * np.sin(2 * np.pi * 22 * times(CHORUS_LENGTH))
    out = 0.08 * noise_band(rng, CHORUS_LENGTH, 300, 1100, loop=True) * pulses
    for _ in range(12):
        pitch = rng.uniform(0.85, 1.25)
        length = rng.uniform(0.18, 0.3)
        croak = _croak(118 * pitch, 104 * pitch, length, rng.uniform(22, 30), 250, 1400, 0.03, 6, 0.04)
        calls = _croaks(rng, croak, rng.integers(2, 5), rng.uniform(0.15, 0.4))
        latest = CHORUS_LENGTH - CHORUS_SEAM_GAP - len(calls) / RATE
        place(out, calls, rng.uniform(CHORUS_SEAM_GAP, latest), rng.uniform(0.15, 0.6))
    return out


def _snort(rng, length, pitch, rate):
    """A forceful breath through the nose: noise with two nasal peaks, fluttering."""
    breath = noise(rng, length)
    nasal = (
        resonance(breath, 900 * pitch, 0.45)
        + 0.6 * resonance(breath, 2200 * pitch, 0.3)
        + 0.3 * bandpass(breath, 200, 4000)
    )
    flutter = 0.75 + 0.25 * np.sin(2 * np.pi * 35 * times(length))
    nasal = lowpass(nasal, 3000)
    return nasal / rms(nasal) * flutter * envelope(length, 0.012, rate, hold=0.04)


def deer_snort(rng):
    pitch = rng.uniform(0.9, 1.1)
    out = silence(0.45)
    place(out, _snort(rng, 0.35, pitch, 14), 0)
    return out


def deer_double_snort(rng):
    """A short snort and a longer one."""
    pitch = rng.uniform(0.9, 1.1)
    out = silence(0.65)
    place(out, _snort(rng, 0.18, pitch * 1.05, 30), 0, 0.7)
    place(out, _snort(rng, 0.35, pitch, 14), rng.uniform(0.2, 0.25))
    return out


def deer_hooves(rng):
    """A deer bounding away: each bound lands as two or three quick hits, and every
    bound is quieter and duller than the one before."""
    out = silence(1.5)
    at = 0.0
    for bound in range(4):
        distance = 0.8**bound
        hit_at = at
        for _ in range(rng.integers(2, 4)):
            hit = burst(rng, 0.1, 40, 400, 0.002, 50)
            place(hit, burst(rng, 0.02, 1000, 3500, 0.0005, 400), 0, 0.3)
            place(hit, burst(rng, 0.08, 500, 3000, 0.003, 40, per_second=2000), 0, 0.2)
            place(out, lowpass(hit, 3000 * distance), hit_at, distance)
            hit_at += rng.uniform(0.02, 0.045)
        at += rng.uniform(0.28, 0.34)
    return out


def rabbit_rustle(rng):
    """A rabbit dashing off through the grass: quick rustles and light hops."""
    out = silence(0.6)
    at = 0.0
    for number in range(rng.integers(4, 7)):
        gain = 0.8 - 0.1 * number
        place(out, lowpass(burst(rng, 0.1, 1800, 4500, 0.008, rng.uniform(40, 60)), 5000), at, gain)
        if number % 2 == 0:
            place(out, burst(rng, 0.05, 40, 250, 0.002, 90), at, 0.3 * gain)
        at += rng.uniform(0.05, 0.09)
    return out


def squirrel_chatter(rng):
    """A fast run of short, sharp "chk" notes that swells and fades."""
    pitch = rng.uniform(0.92, 1.08)
    count = rng.integers(8, 15)
    out = silence(count * 0.08 + 0.1)
    at = 0.0
    for number in range(count):
        loudness = 0.4 + 0.6 * np.sin(np.pi * (number + 0.5) / count)
        start = rng.uniform(3000, 3800) * pitch
        note = sweep(start, start * 0.7, 0.04, harmonics=(1.0, 0.3, 0.15))
        note *= envelope(0.04, 0.002, 120)
        place(out, note, at, loudness)
        place(out, burst(rng, 0.01, 2000, 6000, 0.0005, 900), at, 0.15 * loudness)
        at += rng.uniform(0.06, 0.08)
    return out


def bee_buzz_loop(rng):
    """A soft buzz of wings whose pitch and loudness slowly waver, as the bee turns."""
    turns = 2 * np.pi * times(BEE_LENGTH) / BEE_LENGTH
    phases = rng.uniform(0, 2 * np.pi, 3)
    wobble = 0.03 * np.sin(2 * turns + phases[0]) + 0.012 * np.sin(5 * turns + phases[1])
    frequency = rng.uniform(200, 240) * (1 + wobble)
    # A loop has to hold a whole number of cycles, or the buzz jumps at the seam.
    cycles = frequency.sum() / RATE
    frequency *= round(cycles) / cycles
    buzz = tone(frequency, (1.0, 0.6, 0.45, 0.3, 0.25, 0.18, 0.12, 0.08, 0.05, 0.03))
    wings = noise_band(rng, BEE_LENGTH, 150, 1200, loop=True)
    loudness = 0.8 + 0.2 * np.sin(3 * turns + phases[2])
    return (buzz / rms(buzz) + 0.08 * wings) * loudness


def _voice(pitch_curve, length, formants, vibrato=0.0, vibrato_rate=6.0):
    """A voiced call: a buzzing tone along a pitch curve (start, peak, end in Hz) through the
    resonances of a mouth (centre Hz, width), swelling in and fading out."""
    start, peak, end = pitch_curve
    half = length / 2
    frequency = np.concatenate([np.linspace(start, peak, len(times(half))), np.linspace(peak, end, len(times(length - half)))])
    if vibrato:
        frequency = frequency * (1 + vibrato * np.sin(2 * np.pi * vibrato_rate * np.arange(len(frequency)) / RATE))
    buzz = tone(frequency, SAW[:20])
    mouth = sum(gain * resonance(buzz, centre, width) for centre, width, gain in formants)
    mouth = lowpass(mouth, 2500)
    shape = np.sin(np.pi * np.clip(times(len(frequency) / RATE) / length, 0, 1)) ** 0.6
    return fade_out(mouth / rms(mouth) * shape, 0.05)


def cow_moo(rng):
    """A low, closed "mmooo" that rises a little and sinks again."""
    pitch = rng.uniform(0.9, 1.1)
    length = rng.uniform(0.9, 1.3)
    out = silence(length + 0.1)
    curve = (95 * pitch, 125 * pitch, 85 * pitch)
    place(out, _voice(curve, length, [(300, 0.6, 1.0), (700, 0.4, 0.4)]), 0.02)
    return out


def sheep_baa(rng):
    """A bleat: "baa" with the quick wobble of a sheep's voice."""
    pitch = rng.uniform(0.9, 1.12)
    length = rng.uniform(0.5, 0.75)
    out = silence(length + 0.1)
    curve = (300 * pitch, 340 * pitch, 280 * pitch)
    voice = _voice(curve, length, [(800, 0.5, 1.0), (1300, 0.4, 0.6)], vibrato=0.04, vibrato_rate=9)
    tremolo = 0.7 + 0.3 * np.sin(2 * np.pi * 9 * times(len(voice) / RATE))
    place(out, voice * tremolo, 0.02)
    return out


def chicken_cluck(rng):
    """A hen going about: two to four short, throaty clucks."""
    out = silence(0.9)
    at = 0.02
    for _ in range(rng.integers(2, 5)):
        pitch = rng.uniform(0.85, 1.15)
        length = rng.uniform(0.05, 0.08)
        place(out, _voice((420 * pitch, 520 * pitch, 380 * pitch), length, [(900, 0.5, 1.0), (1800, 0.4, 0.4)]), at, rng.uniform(0.6, 1.0))
        at += length + rng.uniform(0.08, 0.16)
    return out


def dog_bark(rng):
    """A farm dog's one to three barks: short, rough "wuff"s, the first the loudest."""
    out = silence(1.0)
    at = 0.02
    pitch = rng.uniform(0.85, 1.15)
    for number in range(rng.integers(1, 4)):
        length = rng.uniform(0.09, 0.13)
        curve = (380 * pitch, 520 * pitch, 300 * pitch)
        voice = _voice(curve, length, [(700, 0.5, 1.0), (1500, 0.4, 0.6)])
        rasp = bandpass(noise(rng, length), 500, 2500) * envelope(length, 0.005, 25)
        loudness = 1.0 - 0.15 * number
        place(out, voice, at, loudness)
        place(out, rasp / rms(rasp), at, 0.4 * loudness)
        at += length + rng.uniform(0.12, 0.22)
    return out


def cat_meow(rng):
    """A cat's "miaow": rising through an opening mouth, then falling as it closes."""
    pitch = rng.uniform(0.9, 1.15)
    length = rng.uniform(0.45, 0.7)
    out = silence(length + 0.1)
    curve = (600 * pitch, 820 * pitch, 520 * pitch)
    place(out, _voice(curve, length, [(1100, 0.4, 1.0), (2600, 0.3, 0.5)], vibrato=0.01), 0.02)
    return out


def horse_whinny(rng):
    """A whinny: a high, shaking call that falls away in a long trill."""
    pitch = rng.uniform(0.9, 1.1)
    length = rng.uniform(1.0, 1.4)
    out = silence(length + 0.1)
    curve = (900 * pitch, 1100 * pitch, 450 * pitch)
    voice = _voice(curve, length, [(1000, 0.5, 1.0), (2200, 0.4, 0.5)], vibrato=0.06, vibrato_rate=14)
    shake = 0.6 + 0.4 * np.sin(2 * np.pi * 12 * times(len(voice) / RATE))
    place(out, voice * shake, 0.02)
    return out


def horse_snort(rng):
    """A horse blowing through its nose: a long, low, fluttering snort."""
    out = silence(0.7)
    place(out, _snort(rng, 0.55, rng.uniform(0.55, 0.7), 6), 0)
    return out


def stork_clatter(rng):
    """A stork clattering its bill: a dry, hollow rattle of quick knocks, the beak snapping shut
    on itself, that speeds up and slows down again and fades."""
    length = rng.uniform(1.1, 1.6)
    out = silence(length + 0.15)
    pitch = rng.uniform(0.9, 1.1)
    at = 0.02
    while at < length:
        progress = at / length
        # Fastest in the middle of the rattle, loudest a little before it.
        gap = 0.075 - 0.03 * np.sin(np.pi * progress)
        loudness = np.sin(np.pi * min(progress * 1.3, 1.0)) ** 0.7
        knock = burst(rng, 0.03, 500, 4000, 0.0005, 260)
        wood = resonance(knock, 1150 * pitch * rng.uniform(0.95, 1.05), 0.25)
        place(out, wood / rms(wood) * 0.5 + 0.2 * knock, at, loudness * rng.uniform(0.75, 1.0))
        at += gap * rng.uniform(0.85, 1.15)
    return lowpass(out, 5000)


def goose_honk(rng):
    """A greylag's call: two or three nasal "aahng" honks, the first the longest."""
    out = silence(1.0)
    at = 0.02
    pitch = rng.uniform(0.9, 1.1)
    for number in range(rng.integers(2, 4)):
        length = rng.uniform(0.16, 0.22) * (1.3 if number == 0 else 1.0)
        curve = (330 * pitch, 380 * pitch, 300 * pitch)
        voice = _voice(curve, length, [(900, 0.4, 1.0), (1900, 0.3, 0.7), (2800, 0.3, 0.3)])
        place(out, voice, at, rng.uniform(0.7, 1.0))
        at += length + rng.uniform(0.07, 0.12)
    return out


def rooster_crow(rng):
    """A rooster's "cock-a-doodle-doo": a short rising "cock", a quick "a", a high "doo" that
    breaks off into a strained "dle" and a long "doooo" that wavers, sags and gives out. Loud and
    sharp, since it has to carry across the farm."""
    pitch = rng.uniform(0.93, 1.07)
    mouth = [(1100, 0.4, 1.0), (2100, 0.3, 0.7), (3200, 0.3, 0.3)]

    def syllable(start, peak, end, length, shake=0.0):
        voice = _voice((start * pitch, peak * pitch, end * pitch), length, mouth, vibrato=shake, vibrato_rate=rng.uniform(22, 28))
        size = len(voice) / RATE
        rasp = bandpass(noise(rng, size), 1000, 3500) * envelope(size, 0.01, 8)
        return voice + 0.12 * rasp / rms(rasp) * np.sin(np.pi * times(size) / size)

    out = silence(2.3)
    at = 0.02
    for length, curve, shake, gain in [
        (0.22, (560, 720, 700), 0.0, 0.85),  # cock
        (0.09, (680, 740, 700), 0.0, 0.6),  # a
        (0.24, (700, 960, 930), 0.01, 0.95),  # doo
        (0.16, (900, 880, 760), 0.03, 0.8),  # dle
    ]:
        place(out, syllable(*curve, length, shake), at, gain)
        at += length + rng.uniform(0.02, 0.05)
    # The long last note rises, hangs at the top with a strained wobble and sinks away.
    length = rng.uniform(0.85, 1.1)
    place(out, syllable(780, 1020, 640, length, 0.035), at + 0.02)
    return out


def _caw(rng, length, pitch):
    """One hoarse "kraa" of a hooded crow or rook: a falling, buzzing note whose voice is
    chopped into a rough grate by a fast pulse and mixed with breathy noise, with a hard
    start. Higher and rawer than a raven's deep croak."""
    curve = (rng.uniform(560, 620) * pitch, rng.uniform(600, 680) * pitch, rng.uniform(380, 450) * pitch)
    voice = _voice(curve, length, [(1000, 0.5, 1.0), (1900, 0.4, 0.8), (3100, 0.4, 0.4)], vibrato=0.02, vibrato_rate=rng.uniform(40, 60))
    size = len(voice) / RATE
    # The grate: the voice breaks up into pulses about 80 times a second.
    grate = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * rng.uniform(70, 95) * times(size) + rng.uniform(0, 6)))
    grate = lowpass(grate, 400)
    rasp = bandpass(noise(rng, size), 900, 4200) * np.sin(np.pi * np.clip(times(size) / size, 0, 1)) ** 0.5
    mixed = voice * grate + 0.5 * rasp / rms(rasp) * rms(voice)
    # A sharp, short onset: the "k" of "kraa".
    onset = 1 + 1.2 * np.exp(-times(size) / 0.025)
    return mixed * onset


def _caws(rng, count):
    """Count caws in a row, each a little shorter and lower than the one before, apart by
    short pauses."""
    pitch = rng.uniform(0.88, 1.12)
    out = silence(0.2 + count * 0.5)
    at = 0.02
    for number in range(count):
        length = rng.uniform(0.2, 0.32) * (1.0 if count == 1 else 0.85) * (1 - 0.06 * number)
        place(out, _caw(rng, length, pitch * (1 - 0.04 * number)), at, 1 - 0.1 * number)
        at += length + rng.uniform(0.09, 0.2)
    return out[: int((at + 0.1) * RATE)]


def crow_caw_single(rng):
    """A single harsh "kraa"."""
    return _caws(rng, 1)


def crow_caw_double(rng):
    """A double "kraa kraa"."""
    return _caws(rng, 2)


def crow_caw_triple(rng):
    """A triple "kraa kraa kraa"."""
    return _caws(rng, 3)


def crow_flock_rise(rng):
    """A flock of crows taking off: the wing beats of many birds, a heavy, clapping flutter that
    starts at once and thins out as they climb, and caws from several throats, overlapping and
    at different pitches, loudest in the first second."""
    length = 2.6
    out = silence(length)
    # Wings: soft thumps and claps of many beats, dense at first and fewer later.
    at = 0.0
    while at < 2.2:
        progress = at / 2.2
        beat = burst(rng, 0.09, 120, 1400, 0.004, 40)
        flap = resonance(beat, rng.uniform(250, 500), 0.4)
        place(out, flap / rms(flap) * 0.25 + 0.5 * beat / rms(beat) * 0.12, at, (1 - 0.6 * progress) * rng.uniform(0.5, 1.0))
        at += (0.012 + 0.07 * progress) * rng.uniform(0.6, 1.4)
    # Voices.
    for _ in range(rng.integers(7, 10)):
        start = rng.uniform(0.0, 1.5) ** 1.2
        caw = _caw(rng, rng.uniform(0.17, 0.3), rng.uniform(0.85, 1.2))
        place(out, caw / rms(caw) * 1.3, start, rng.uniform(0.5, 1.0) * (1 - 0.4 * start / 1.5))
    return out
