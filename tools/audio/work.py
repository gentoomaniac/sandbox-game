"""Work sounds: tools, harvesting, building, and the "denied" blip (see design/presentation/sound.md)."""

import numpy as np

from dsp import RATE, SOFT_SQUARE, bandpass, bubble, burst, drift, envelope, grains, highpass
from dsp import knock, lowpass, noise, noise_band, place, resonance, ring, rms, silence, swell
from dsp import swept_band, sweep, times


def axe_chop(rng):
    """A falling thud, the crack of the blade going in, and a short wooden tone."""
    pitch = rng.uniform(0.93, 1.07)
    thud = sweep(190 * pitch, 70 * pitch, 0.35, 0.5) * envelope(0.35, 0.002, 18)
    crack = bandpass(noise(rng, 0.35), 600 * pitch, 3500 * pitch) * envelope(0.35, 0.001, 45)
    wood = sweep(520 * pitch, 430 * pitch, 0.35) * envelope(0.35, 0.001, 30)
    return 0.9 * thud + 0.8 * crack + 0.25 * wood


def tree_fall(rng):
    """The trunk cracks faster and louder until it gives, creaks as it leans, the crown
    rushes through the air, and it lands with a deep thud and a smaller bounce."""
    pitch = rng.uniform(0.92, 1.08)
    out = silence(3.6)
    cracks = 12
    for number in range(cracks):
        at = 0.6 * (number / cracks) ** 0.6 + rng.uniform(0, 0.02)
        gain = 0.12 + 0.25 * number / cracks
        place(out, burst(rng, 0.06, 500, 5000, 0.0005, 120), at, gain)
        place(out, ring(rng.uniform(400, 900), 120, 0.05), at, 2 * gain)
    give = 0.68 + rng.uniform(0, 0.04)
    place(out, burst(rng, 0.2, 300, 4000, 0.0008, 30), give, 0.55)
    place(out, sweep(140 * pitch, 70 * pitch, 0.25, 0.5) * envelope(0.25, 0.002, 20), give, 0.6)

    # The creak is wood slipping in tiny jerks: a train of clicks through two wooden
    # resonances. Its rate is the pitch, rising as the tree leans further.
    creak_length = 1.3
    progress = times(creak_length) / creak_length
    rate = (90 + 70 * progress) * pitch * (1 + 0.08 * (drift(rng, creak_length, 6) - 0.5))
    clicks = np.diff(np.floor(np.cumsum(rate) / RATE), prepend=0)
    clicks *= rng.uniform(0.5, 1, len(clicks))
    creak = resonance(clicks, 650 * pitch, 0.35) + 0.6 * resonance(clicks, 1500 * pitch, 0.25)
    creak *= swell(creak_length, 0.8 * creak_length)
    place(out, creak / rms(creak), give + 0.1, 0.13)

    fall = give + 1.0
    rush_length = 1.0
    rush_shape = swell(rush_length, 0.85 * rush_length)
    rush = swept_band(noise(rng, rush_length), 400 * 3**rush_shape, 0.5) * rush_shape
    place(out, rush / rms(rush), fall, 0.25)
    leaves = bandpass(grains(rng, rush_length, 3000), 2000, 7000)
    place(out, leaves / rms(leaves) * rush_shape, fall, 0.15)

    impact = fall + rush_length * 0.9 + rng.uniform(-0.05, 0.05)
    place(out, sweep(95 * pitch, 38 * pitch, 0.8, 0.5) * envelope(0.8, 0.004, 7), impact, 1.0)
    place(out, burst(rng, 0.7, 40, 500, 0.004, 9), impact, 0.4)
    place(out, burst(rng, 0.6, 1000, 6000, 0.006, 10, per_second=4000), impact, 0.18)
    place(out, burst(rng, 0.5, 400, 3000, 0.004, 12, per_second=600), impact + 0.02, 0.22)
    bounce = impact + rng.uniform(0.26, 0.32)
    place(out, sweep(80 * pitch, 45 * pitch, 0.4, 0.5) * envelope(0.4, 0.004, 14), bounce, 0.35)
    place(out, burst(rng, 0.3, 40, 400, 0.004, 18), bounce, 0.18)
    return out


def pickaxe_hit(rng):
    """Steel on stone: a short inharmonic clink over a spray of grit."""
    pitch = rng.uniform(0.96, 1.04)
    clink = silence(0.5)
    partials = ((1870, 1.0, 14), (2950, 0.6, 18), (4310, 0.4, 24), (6120, 0.2, 30))
    for frequency, gain, rate in partials:
        partial = sweep(frequency * pitch, frequency * pitch * 0.995, 0.5)
        clink += gain * partial * envelope(0.5, 0.0005, rate)
    grit = highpass(noise(rng, 0.5), 2000) * envelope(0.5, 0.0005, 60)
    return 0.6 * clink + 0.7 * grit


def stone_break(rng):
    """A crack and a low boom, then rubble and pebbles settling."""
    pitch = rng.uniform(0.92, 1.08)
    out = silence(1.0)
    place(out, burst(rng, 0.15, 200, 5000, 0.0008, 50), 0, 0.6)
    place(out, sweep(120 * pitch, 50 * pitch, 0.4, 0.5) * envelope(0.4, 0.002, 14), 0, 0.9)
    place(out, burst(rng, 0.8, 150, 1800, 0.01, 6, per_second=1500), 0.02, 0.35)
    for _ in range(rng.integers(12, 19)):
        at = 0.04 + 0.7 * rng.random() ** 1.6
        pebble = ring(rng.uniform(1500, 4200) * pitch, rng.uniform(250, 500), 0.03)
        place(out, pebble, at, rng.uniform(0.05, 0.25) * (1 - at))
    return out


def scythe_swish(rng):
    """A whoosh rising and falling through the air, and the snip of cut grass."""
    pitch = rng.uniform(0.9, 1.1)
    length = rng.uniform(0.38, 0.44)
    shape = swell(length, 0.55 * length)
    whoosh = swept_band(noise(rng, length), 600 * pitch * 3.5**shape, 0.5) * shape**1.5
    out = silence(length + 0.05)
    place(out, whoosh / rms(whoosh), 0, 0.5)
    snip = burst(rng, 0.08, 2500, 8000, 0.002, 70, per_second=6000)
    place(out, snip, 0.55 * length, 0.5)
    return out


def shovel_dig(rng):
    """The blade scrapes into the soil, earth crunches, and a shovelful lands beside."""
    pitch = rng.uniform(0.92, 1.08)
    out = silence(0.65)
    place(out, burst(rng, 0.12, 900 * pitch, 4500, 0.002, 45, per_second=5000), 0, 0.5)
    place(out, ring(850 * pitch, 60, 0.1), 0, 0.25)
    place(out, burst(rng, 0.2, 40, 300, 0.003, 35), 0, 0.7)
    place(out, burst(rng, 0.25, 150, 1500, 0.01, 20, per_second=2500), 0.01, 0.5)
    toss = rng.uniform(0.3, 0.36)
    place(out, burst(rng, 0.28, 200, 2500, 0.015, 18, per_second=1800), toss, 0.4)
    place(out, burst(rng, 0.15, 40, 300, 0.004, 35), toss + 0.02, 0.3)
    return out


def hoe_till(rng):
    """A dull strike into the ground, the blade dragging back, and a few clods."""
    pitch = rng.uniform(0.92, 1.08)
    out = silence(0.5)
    place(out, burst(rng, 0.15, 50, 450 * pitch, 0.002, 35), 0, 0.9)
    place(out, ring(420 * pitch, 50, 0.1), 0, 0.25)
    place(out, burst(rng, 0.32, 700 * pitch, 3500, 0.04, 16, per_second=3500), 0.03, 0.45)
    for _ in range(3):
        place(out, burst(rng, 0.08, 40, 400, 0.003, 60), rng.uniform(0.1, 0.35), 0.2)
    return out


def water_pour(rng):
    """Water from a can: a wobbling splash of noise full of droplets, then two drips."""
    pitch = rng.uniform(0.92, 1.08)
    stream_length = rng.uniform(0.85, 1.0)
    out = silence(stream_length + 0.3)
    wobble = 0.75 + 0.25 * drift(rng, stream_length, 12)
    shape = envelope(stream_length, 0.08, 15, hold=stream_length - 0.38)
    stream = noise_band(rng, stream_length, 500 * pitch, 2500 * pitch) * wobble * shape
    place(out, stream, 0, 0.5)
    for _ in range(round(stream_length * 45)):
        at = rng.uniform(0.03, stream_length - 0.1)
        place(out, bubble(rng.uniform(600, 2000) * pitch), at, rng.uniform(0.1, 0.35))
    for at in (stream_length + 0.05, stream_length + rng.uniform(0.15, 0.22)):
        place(out, bubble(rng.uniform(900, 1500) * pitch, 0.04), at, 0.2)
    return out


def plant(rng):
    """Two soft pats of soil over the seed."""
    pitch = rng.uniform(0.9, 1.1)
    out = silence(0.4)
    for at, gain in ((0, 0.8), (rng.uniform(0.11, 0.14), 0.55)):
        place(out, burst(rng, 0.12, 40, 350 * pitch, 0.003, 45), at, gain)
        place(out, burst(rng, 0.1, 600, 3000, 0.005, 50, per_second=2000), at, 0.2 * gain)
    return out


def pick_bush(rng):
    """A few quick rustles of leaves and the snap of a twig."""
    pitch = rng.uniform(0.9, 1.1)
    out = silence(0.45)
    at = 0.0
    for gain in (0.7, 0.5, 0.6, 0.35)[: rng.integers(3, 5)]:
        place(out, lowpass(burst(rng, 0.1, 1800 * pitch, 4500, 0.01, 45), 5000), at, gain)
        at += rng.uniform(0.05, 0.09)
    snap = rng.uniform(0.1, 0.18)
    place(out, burst(rng, 0.03, 1500, 5000, 0.0005, 300), snap, 0.5)
    place(out, ring(rng.uniform(1800, 2600), 150, 0.04), snap, 0.35)
    return out


def item_pickup(rng):
    """A soft rising pop."""
    pitch = rng.uniform(0.94, 1.06)
    return sweep(620 * pitch, 1250 * pitch, 0.18, 0.6) * envelope(0.18, 0.003, 30)


def build_place(rng):
    """A building set down: a solid thud with a wooden knock, a smaller knock as it
    settles, and a little dust."""
    pitch = rng.uniform(0.94, 1.06)
    out = silence(0.75)
    place(out, sweep(110 * pitch, 60 * pitch, 0.3, 0.5) * envelope(0.3, 0.003, 18), 0, 0.8)
    place(out, burst(rng, 0.2, 40, 500, 0.003, 30), 0, 0.6)
    place(out, knock(210 * pitch, 0.25), 0, 0.75)
    settle = rng.uniform(0.13, 0.17)
    place(out, knock(240 * pitch, 0.2), settle, 0.45)
    place(out, burst(rng, 0.15, 40, 400, 0.003, 40), settle, 0.25)
    place(out, burst(rng, 0.45, 800, 5000, 0.03, 9, per_second=1500), 0.02, 0.12)
    return out


def denied(rng):
    """A dull, low double blip: two muffled hollow tones, the second a little lower."""
    pitch = rng.uniform(0.97, 1.03)
    out = silence(0.3)
    for at, frequency in ((0, 200 * pitch), (0.12, 180 * pitch)):
        blip = sweep(frequency, frequency * 0.97, 0.1, harmonics=SOFT_SQUARE)
        place(out, lowpass(blip * envelope(0.1, 0.004, 45), 900), at)
    return out
