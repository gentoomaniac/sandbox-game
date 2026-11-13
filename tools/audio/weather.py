"""Weather sounds: the rain and wind loops, wind gusts and thunder (see design/presentation/sound.md).

The loops are built as circles (see generate.py), so every part of them uses loop=True.
"""

import numpy as np

from dsp import bandpass, drift, envelope, fade_out, lowpass, noise, noise_band, normalized
from dsp import place, ring, rms, swell, swept_band, times

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


def thunder_far_roll(rng):
    """Far off: only a low, soft rumble that rises slowly and rolls on for many seconds."""
    return _thunder(rng, length=rng.uniform(7.5, 9.0), rumble_cutoff=rng.uniform(80, 100),
                    attack=rng.uniform(0.8, 1.2), rate=rng.uniform(0.38, 0.5), crack=0)


def thunder_mid_roll(rng):
    """A middle distance: a rumble with body and a dull, low-passed thud at its start."""
    length = rng.uniform(5.5, 6.5)
    out = _thunder(rng, length, rumble_cutoff=rng.uniform(160, 190), attack=rng.uniform(0.2, 0.35),
                   rate=rng.uniform(0.6, 0.8), crack=0)
    thud = lowpass(noise(rng, length), 700) * envelope(length, 0.03, 7)
    return normalized(out + 0.1 * rms(out) * thud / rms(thud))


def thunder_close(rng):
    """A close strike: a sharp crack at once (a snap, then the tearing of the bolt), and a
    heavy rumble under and after it."""
    length = rng.uniform(5.0, 5.8)
    rumble = _thunder(rng, length, rumble_cutoff=rng.uniform(260, 320), attack=0.04,
                      rate=rng.uniform(0.8, 0.95), crack=0)
    snap = bandpass(noise(rng, length), 800, 7000) * envelope(length, 0.001, 70)
    tear = bandpass(noise(rng, length), 250, 3500) * envelope(length, 0.004, 9)
    tear *= 1 + 0.6 * np.sin(2 * np.pi * rng.uniform(25, 45) * times(length))
    out = 0.9 * rumble / rms(rumble) * 0.25 + 1.2 * snap / rms(snap) * 0.05
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
