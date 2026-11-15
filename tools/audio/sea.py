"""The sea: soft waves lapping a flat Wadden Sea shore (see design/presentation/sound.md).

A loop, built as a circle (see generate.py). Not surf: on the flats the water arrives low and
spent, so a wave is a slow swell of hushing wash with a little fizz of foam on its crest, and a
trickle as it runs back, one every five to eight seconds, over a faint steady hush of the sea
beyond. No wave booms or breaks hard.
"""

import numpy as np

from dsp import bandpass, drift, grains, noise, noise_band, place, rms, samples, times

SEA_LENGTH = 15.0
# Seconds from one wave's arrival to the next, on average; the loop holds a whole number.
WAVE_PERIOD = 6.0


def _wash(rng, strength):
    """One wave coming up the shore: it swells over a second or two, its foam fizzes at the
    crest, and the water runs back with a thin trickle. `strength` (0.5 to 1) is how far it
    runs up."""
    length = rng.uniform(5.0, 6.5)
    t = times(length)
    rise = rng.uniform(1.4, 2.4)
    # Up on a raised cosine, then back down slowly (the draw of the water off the mud).
    up = np.sin(0.5 * np.pi * np.clip(t / rise, 0, 1)) ** 2
    down = np.exp(-(np.maximum(t - rise, 0)) / rng.uniform(1.3, 1.9))
    swell = up * down
    body = bandpass(noise(rng, length), 180, 2200) * swell
    body = body / rms(body)
    hiss = bandpass(noise(rng, length), 1800, 7000) * swell**2
    hiss = hiss / rms(hiss)
    # Foam: tiny bubbles popping on the crest, and a patter as the water drains off.
    bubbles = bandpass(grains(rng, length, 900), 2500, 9000) * swell**3
    drain = bandpass(grains(rng, length, 350), 900, 4500) * np.clip((t - rise) / 1.5, 0, 1) * down
    out = body * 0.9 + hiss * 0.3 * swell + 0.9 * bubbles / (rms(bubbles) + 1e-9) * 0.08
    out += 0.5 * drain / (rms(drain) + 1e-9) * 0.05
    # The tail fades to nothing, so a wave placed round the seam ends cleanly.
    tail = np.cos(0.5 * np.pi * np.clip((t - (length - 0.8)) / 0.8, 0, 1)) ** 2
    return out * strength * tail


def sea_loop(rng):
    """Waves lapping at a flat shore over the hush of the sea."""
    count = round(SEA_LENGTH / WAVE_PERIOD)
    # A circle: the waves are spread round it with some jitter, and wash over the seam.
    out = 0.3 * noise_band(rng, SEA_LENGTH, 60, 900, loop=True)
    out *= 0.6 + 0.8 * drift(rng, SEA_LENGTH, 0.3, loop=True)
    wave_sum = np.zeros(samples(SEA_LENGTH))
    slot = SEA_LENGTH / count
    start = rng.uniform(0, slot)
    for index in range(count):
        at = start + (index + rng.uniform(-0.12, 0.12)) * slot
        place(wave_sum, _wash(rng, rng.uniform(0.55, 1.0)), at % SEA_LENGTH, loop=True)
    # The wash of the sea itself comes and goes in the gaps of the waves, quietly.
    return out + wave_sum / rms(wave_sum) * 0.35


# The stormy shore (#101): the same flat coast in a gale, so breakers still, not surf with a
# boom, but heavier and closer together: one every three to four seconds.
STORM_WAVE_PERIOD = 3.6


def _breaker(rng, strength):
    """One breaker on the flats in a storm: it comes up quickly, breaks into a long roar of
    foam with a hard hiss and a crackle of bubbles, and the water rushes back with a patter.
    `strength` (0.6 to 1) is how heavy it is."""
    length = rng.uniform(4.0, 5.0)
    t = times(length)
    rise = rng.uniform(0.6, 1.0)
    up = np.sin(0.5 * np.pi * np.clip(t / rise, 0, 1)) ** 1.5
    down = np.exp(-(np.maximum(t - rise, 0)) / rng.uniform(1.1, 1.6))
    swell = up * down
    roar = bandpass(noise(rng, length), 120, 1800) * swell
    roar = roar / rms(roar)
    hiss = bandpass(noise(rng, length), 1500, 8000) * swell
    hiss = hiss / rms(hiss)
    # Foam: dense bubbles bursting along the whole break, and the rush back off the mud.
    bubbles = bandpass(grains(rng, length, 2500), 2000, 9000) * swell**1.5
    rush = bandpass(grains(rng, length, 900), 700, 4500) * np.clip((t - rise) / 1.0, 0, 1) * down
    out = roar * 0.8 + hiss * 0.55
    out += bubbles / (rms(bubbles) + 1e-9) * 0.2 + rush / (rms(rush) + 1e-9) * 0.12
    tail = np.cos(0.5 * np.pi * np.clip((t - (length - 0.8)) / 0.8, 0, 1)) ** 2
    return out * strength * tail


def sea_storm_loop(rng):
    """Heavy breakers, close together, over the continuous roar of a rough sea."""
    count = round(SEA_LENGTH / STORM_WAVE_PERIOD)
    # The roar of the sea beyond never lets up, but swells and sinks with the gusts.
    out = 0.6 * noise_band(rng, SEA_LENGTH, 80, 2500, loop=True)
    out *= 0.6 + 0.8 * drift(rng, SEA_LENGTH, 0.4, loop=True)
    wave_sum = np.zeros(samples(SEA_LENGTH))
    slot = SEA_LENGTH / count
    start = rng.uniform(0, slot)
    for index in range(count):
        at = start + (index + rng.uniform(-0.2, 0.2)) * slot
        place(wave_sum, _breaker(rng, rng.uniform(0.6, 1.0)), at % SEA_LENGTH, loop=True)
    return out + wave_sum / rms(wave_sum) * 0.5
