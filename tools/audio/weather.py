"""Weather sounds: the rain and wind loops, wind gusts and thunder (see design/presentation/sound.md).

The loops are built as circles (see generate.py), so every part of them uses loop=True.
"""

from functools import partial

import numpy as np

from dsp import bandpass, drift, envelope, fade_out, lowpass, noise, noise_band, normalized
from dsp import RATE, place, ring, rms, samples, swell, swept_band, times

RAIN_LENGTH = 4.0
WIND_LENGTH = 6.0


def rain_loop(rng):
    """A steady hiss with drops ticking all over it."""
    out = 0.35 * bandpass(noise(rng, RAIN_LENGTH), 500, 7000, loop=True)
    for _ in range(round(105 * RAIN_LENGTH)):
        drop = ring(rng.uniform(2500, 6000), 333, 0.015)
        place(out, drop, rng.uniform(0, RAIN_LENGTH), rng.uniform(0.1, 0.5), loop=True)
    return out


def wind_loop(rng):
    """Broad low noise that slowly swells and fades once per loop, its body rising in pitch
    as it gets stronger, with a faint whistle wandering above it."""

    def movement():
        return drift(rng, WIND_LENGTH, 0.5, loop=True)

    # A random curve alone may hardly move in six seconds, so one swell is certain.
    swell_phase = rng.uniform(0, 2 * np.pi)
    once = 0.5 - 0.5 * np.cos(2 * np.pi * times(WIND_LENGTH) / WIND_LENGTH + swell_phase)
    strength = 0.7 * once + 0.3 * movement()
    low = noise_band(rng, WIND_LENGTH, 80, 400, loop=True) * (0.4 + 0.6 * movement())
    body = swept_band(noise(rng, WIND_LENGTH), 250 * 3**strength, 0.5, loop=True)
    air = noise_band(rng, WIND_LENGTH, 1000, 3000, loop=True)
    whistle = swept_band(noise(rng, WIND_LENGTH), 600 * 1.6 ** movement(), 0.08, loop=True)
    high = 0.08 * air + 0.12 * whistle / rms(whistle)
    wind = 0.6 * low + 0.8 * body / rms(body) + high * strength
    return lowpass(wind, 2000, loop=True) * (0.3 + 0.7 * strength)


def wind_gust(rng):
    """A swell of wind: it rises, its body sweeps up in pitch, and it dies down."""
    pitch = rng.uniform(0.9, 1.1)
    length = rng.uniform(2.6, 3.4)
    shape = swell(length, rng.uniform(0.4, 0.55) * length)
    body = swept_band(noise(rng, length), 300 * pitch * 4**shape, 0.6)
    whistle = swept_band(noise(rng, length), 700 * pitch * 2**shape, 0.08)
    low = noise_band(rng, length, 80, 500)
    return (body / rms(body) + 0.5 * low) * shape + 0.2 * whistle / rms(whistle) * shape**2


# The variants of each kind differ in length, pitch (the rumble's cutoff), attack and rolls:
# every roll is (start in s, gain, length in s) and each gets its own rumble, so a single roll,
# a double roll and a long rolling series are all there.
FAR = [
    dict(length=9.5, cutoff=75, attack=1.4, rate=0.4, rolls=[(0, 1, 9.5)]),
    dict(length=8.0, cutoff=95, attack=0.9, rate=0.5, rolls=[(0, 1, 4.5), (3.2, 0.7, 4.8)]),
    dict(length=5.5, cutoff=110, attack=0.5, rate=0.7, rolls=[(0, 1, 5.5)]),
    dict(length=12.0, cutoff=85, attack=1.0, rate=0.55,
         rolls=[(0, 1, 4.5), (2.8, 0.8, 4.5), (6.0, 0.75, 3.5), (8.0, 0.55, 4.0)]),
    dict(length=7.0, cutoff=65, attack=1.8, rate=0.45, rolls=[(0, 1, 7.0)]),
    dict(length=10.0, cutoff=100, attack=0.7, rate=0.5, rolls=[(0, 0.8, 4.0), (4.5, 1, 5.5)]),
]
MID = [
    dict(length=6.0, cutoff=175, attack=0.28, rate=0.7, rolls=[(0, 1, 6.0)]),
    dict(length=4.0, cutoff=210, attack=0.12, rate=1.1, rolls=[(0, 1, 4.0)]),
    dict(length=7.5, cutoff=150, attack=0.5, rate=0.65, rolls=[(0, 1, 4.0), (2.6, 0.75, 4.9)]),
    dict(length=9.5, cutoff=165, attack=0.3, rate=0.6,
         rolls=[(0, 1, 4.0), (2.2, 0.8, 3.5), (4.5, 0.7, 3.5), (6.2, 0.5, 3.3)]),
    dict(length=5.0, cutoff=135, attack=0.6, rate=0.8, rolls=[(0, 1, 5.0)]),
    dict(length=6.5, cutoff=195, attack=0.2, rate=0.75, rolls=[(0, 0.9, 3.0), (2.4, 1, 4.1)]),
]
CLOSE = [
    dict(length=5.4, cutoff=290, attack=0.04, rate=0.9, snap=1.0, rolls=[(0, 1, 5.4)]),
    dict(length=3.6, cutoff=330, attack=0.03, rate=1.3, snap=1.2, rolls=[(0, 1, 3.6)]),
    dict(length=7.5, cutoff=260, attack=0.05, rate=0.75, snap=1.0, rolls=[(0, 1, 4.5), (3.2, 0.6, 4.3)]),
    dict(length=9.0, cutoff=240, attack=0.06, rate=0.7, snap=0.9,
         rolls=[(0, 1, 4.0), (2.5, 0.7, 3.5), (5.0, 0.6, 4.0)]),
    dict(length=4.6, cutoff=210, attack=0.12, rate=1.0, snap=0.7, rolls=[(0, 1, 4.6)]),
    dict(length=6.2, cutoff=310, attack=0.02, rate=0.95, snap=1.3, rolls=[(0, 1, 2.5), (1.8, 0.8, 4.4)]),
]


def thunder_variants(profiles):
    """The variant functions of a thunder kind: far off, a rumble that rises slowly and rolls
    on for many seconds; a middle distance, one with body and a dull thud at its start; close
    (profiles with a snap), a sharp crack at once and a heavy rumble after it."""
    return [partial(_series, profile=profile) for profile in profiles]


def _series(rng, profile):
    out = np.zeros(samples(profile["length"] + 0.1))
    for start, gain, duration in profile["rolls"]:
        cutoff = profile["cutoff"] * rng.uniform(0.9, 1.1)
        part = _thunder(rng, duration, cutoff, profile["attack"] * rng.uniform(0.9, 1.15),
                        profile["rate"] * rng.uniform(0.9, 1.1), crack=0)
        place(out, part, start, gain)
    out = normalized(out)
    if "snap" in profile:
        return _close_crack(rng, out, profile["snap"])
    if profile["cutoff"] > 120:
        thud = lowpass(noise(rng, len(out) / RATE), 700) * envelope(len(out) / RATE, 0.03, 7)
        out = normalized(out + 0.1 * rms(out) * thud / rms(thud))
    return normalized(fade_out(out, 0.5))


def _close_crack(rng, rumble, snap_gain):
    """A sharp crack at once (a snap, then the tearing of the bolt) over the rumble."""
    length = len(rumble) / RATE
    snap = bandpass(noise(rng, length), 800, 7000) * envelope(length, 0.001, 70)
    tear = bandpass(noise(rng, length), 250, 3500) * envelope(length, 0.004, 9)
    tear *= 1 + 0.6 * np.sin(2 * np.pi * rng.uniform(25, 45) * times(length))
    out = 0.9 * rumble / rms(rumble) * 0.25 + snap_gain * 1.2 * snap / rms(snap) * 0.05
    out += 0.45 * tear / rms(tear) * 0.1
    return normalized(fade_out(out, 0.5))


def _thunder(rng, length, rumble_cutoff, attack, rate, crack):
    # The draft's brown noise was a leaky integrator, y = 0.995 * y + 0.05 * x: the same as
    # a one-pole low-pass at 35 Hz with a gain of 10.
    brown = 10 * lowpass(noise(rng, length), 35)
    rumble = lowpass(brown, rumble_cutoff)
    t = times(length)
    roll_speed = rng.uniform(1.4, 2.0)
    wander = 1.3 * np.sin(2 * np.pi * rng.uniform(0.4, 0.8) * t + rng.uniform(0, 2 * np.pi))
    roll = 1 + 0.5 * np.sin(2 * np.pi * roll_speed * t + wander)
    out = rumble * envelope(length, attack, rate) * roll
    if crack:
        out += crack * bandpass(noise(rng, length), 300, 3000) * envelope(length, 0.005, 9)
    return normalized(fade_out(out, 0.5))


CRAWL = [
    dict(length=7.0, cutoff=170, build=0.55, rumbles=4.5, crackles=32, tear=(120, 3200)),
    dict(length=8.4, cutoff=140, build=0.45, rumbles=3.5, crackles=26, tear=(90, 2600)),
    dict(length=6.2, cutoff=200, build=0.6, rumbles=5.5, crackles=44, tear=(160, 3800)),
    dict(length=8.0, cutoff=185, build=0.4, rumbles=4.0, crackles=36, tear=(100, 3000)),
]


def thunder_crawl(profile):
    return partial(_crawl, profile=profile)


def _poisson_times(rng, start, end, rate, density=None):
    """Event times of a Poisson process with gaps of tens of ms to about a second. With a
    density (0..1 over the length) the events thin out where it is low."""
    found = []
    at = start
    while True:
        at += min(rng.exponential(1 / rate), 1.0)
        if at >= end:
            return found
        if density is None or rng.uniform() < density(at):
            found.append(at)


def _crawl(rng, profile):
    """Lightning running across the sky: a long rolling rumble of many overlapping, decaying
    bursts at random gaps (no steady rate anywhere, or it would sound like rotor blades),
    sharp tearing crackles scattered through it, thickest in the middle, a slow swell and a
    long fade."""
    length = profile["length"]
    peak = profile["build"] * length
    shape = swell(length, peak)
    out = np.zeros(samples(length + 1.6))
    for at in _poisson_times(rng, 0, length, profile["rumbles"] * 4):
        size = rng.uniform(0.3, 1.5)
        cutoff = rng.uniform(40, profile["cutoff"])
        burst = lowpass(10 * lowpass(noise(rng, size), 40), cutoff)
        burst = burst / rms(burst) * envelope(size, rng.uniform(0.01, 0.12), rng.uniform(2.5, 9))
        place(out, burst, at, rng.lognormal(0, 0.5) * (0.15 + shape[min(len(shape) - 1, samples(at))]))
    out *= 0.9 / np.abs(out).max()
    low, high = profile["tear"]

    def middle(at):
        return 0.1 + 0.9 * np.exp(-0.5 * ((at - peak) / (0.22 * length)) ** 2)

    rate = profile["crackles"] / length * 2
    for at in _poisson_times(rng, 0.05, length - 0.3, rate, middle):
        size = rng.uniform(0.008, 0.07)
        crackle = bandpass(noise(rng, size), rng.uniform(300, 1800), rng.uniform(3000, 8000))
        crackle = crackle / (rms(crackle) + 1e-9) * envelope(size, 0.0004, 5 / size)
        place(out, crackle, at, 0.09 * rng.lognormal(0, 0.6) * (0.3 + shape[samples(at)]))
    # Longer tearing: a few brief rips of mid-high noise that die away.
    for at in _poisson_times(rng, 0.2, length - 0.5, 0.6, middle):
        size = rng.uniform(0.1, 0.4)
        rip = bandpass(noise(rng, size), low * rng.uniform(1, 3), high * rng.uniform(0.4, 1))
        rip = rip / rms(rip) * envelope(size, rng.uniform(0.003, 0.03), rng.uniform(6, 18))
        place(out, rip, at, 0.06 * rng.lognormal(0, 0.4) * (0.3 + shape[samples(at)]))
    return normalized(fade_out(out[: samples(length + 0.5)], 1.0))
