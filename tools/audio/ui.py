"""UI sounds: short, soft blips for menus, the inventory and the hotbar, and the chest."""

import numpy as np

from dsp import RATE, TRIANGLE, burst, constant, drift, envelope, knock, place, resonance, rms
from dsp import silence, swell, sweep, times, tone


def blip(frequency, duration, rate, harmonics=TRIANGLE):
    """One soft note: a quick rise and a short decay."""
    return tone(constant(frequency, duration), harmonics) * envelope(duration, 0.002, rate)


def ui_click(rng):
    return blip(1050 * rng.uniform(0.96, 1.04), 0.07, 90)


def ui_open(rng):
    """Two notes going up a fifth."""
    pitch = rng.uniform(0.97, 1.03)
    out = silence(0.2)
    place(out, blip(660 * pitch, 0.11, 45), 0)
    place(out, blip(990 * pitch, 0.13, 40), 0.06)
    return out


def ui_close(rng):
    """Two notes going down a fifth."""
    pitch = rng.uniform(0.97, 1.03)
    out = silence(0.2)
    place(out, blip(990 * pitch, 0.11, 45), 0)
    place(out, blip(660 * pitch, 0.13, 40), 0.06)
    return out


def hotbar_select(rng):
    """A tiny, bright tick."""
    return blip(1500 * rng.uniform(0.96, 1.04), 0.05, 130, harmonics=(1.0, 0.2))


def chest_open(rng):
    """The lid of a chest creaking up on dry hinges: a latch click, then a train of tiny slips
    through two wooden resonances that rises in pitch as the lid swings, ending in a soft
    knock against the stop."""
    pitch = rng.uniform(0.93, 1.07)
    length = rng.uniform(0.42, 0.5)
    out = silence(length + 0.2)
    place(out, burst(rng, 0.03, 1200, 5000, 0.0005, 150), 0, 0.5)
    progress = times(length) / length
    rate = (70 + 110 * progress**1.5) * pitch * (1 + 0.12 * (drift(rng, length, 8) - 0.5))
    slips = np.diff(np.floor(np.cumsum(rate) / RATE), prepend=0)
    slips *= rng.uniform(0.4, 1, len(slips))
    creak = resonance(slips, 780 * pitch, 0.3) + 0.7 * resonance(slips, 1750 * pitch, 0.25)
    creak *= swell(length, 0.7 * length)
    place(out, creak / rms(creak), 0.04, 0.35)
    place(out, knock(190 * pitch, 0.15) * envelope(0.15, 0.001, 25), 0.04 + length, 0.3)
    return out


def chest_close(rng):
    """A soft wooden thump: the lid settling on the box, with a duller body knock under it."""
    pitch = rng.uniform(0.93, 1.07)
    out = silence(0.4)
    place(out, sweep(130 * pitch, 62 * pitch, 0.25, 0.5) * envelope(0.25, 0.003, 22), 0, 0.8)
    place(out, knock(210 * pitch, 0.25), 0, 0.35)
    place(out, burst(rng, 0.12, 200, 1800, 0.002, 40), 0, 0.3)
    return out
