"""Footsteps: one step per file, its sound chosen by the ground (see SPEC.md "Sound")."""

from dsp import bandpass, bubble, burst, envelope, grains, knock, lowpass, noise, place, ring
from dsp import rms, silence, swept_band, sweep, times


def step_grass(rng):
    """A soft brush of blades, then the toe, over a faint thump of the foot."""
    pitch = rng.uniform(0.9, 1.1)
    out = silence(0.2)
    brush = bandpass(noise(rng, 0.12), 1200 * pitch, 6000 * pitch) * envelope(0.12, 0.01, 40)
    place(out, brush, 0)
    toe = bandpass(noise(rng, 0.1), 1500 * pitch, 6500 * pitch) * envelope(0.1, 0.008, 55)
    place(out, toe, rng.uniform(0.035, 0.055), 0.5)
    place(out, burst(rng, 0.1, 40, 250, 0.004, 60), 0, 0.03)
    return out


def step_soil(rng):
    """A dull thump with a little grit of crumbs."""
    pitch = rng.uniform(0.9, 1.1)
    out = silence(0.18)
    place(out, burst(rng, 0.15, 40, 500 * pitch, 0.004, 45), 0)
    place(out, burst(rng, 0.12, 900 * pitch, 3500, 0.006, 40, per_second=1500), 0.005, 0.25)
    return out


def step_sand(rng):
    """A soft granular shuffle that slides a little."""
    pitch = rng.uniform(0.9, 1.1)
    out = silence(0.24)
    place(out, burst(rng, 0.2, 1500 * pitch, 5000, 0.015, 25, per_second=6000), 0, 0.6)
    place(out, burst(rng, 0.15, 1800 * pitch, 5000, 0.01, 35, per_second=4000), 0.05, 0.35)
    place(out, burst(rng, 0.1, 40, 250, 0.004, 60), 0, 0.4)
    return out


def step_wetland(rng):
    """A squelch: the foot sinks in (a thump), then mud lets go of it (a band of noise
    sweeping up, and a couple of bubbles)."""
    pitch = rng.uniform(0.9, 1.1)
    out = silence(0.32)
    place(out, burst(rng, 0.15, 40, 350, 0.006, 35), 0, 0.9)
    suck_length = 0.2
    rise = (times(suck_length) / suck_length) ** 0.7
    centre = 350 * pitch * 4**rise
    suck = swept_band(noise(rng, suck_length), centre, 0.25) * envelope(suck_length, 0.03, 25)
    place(out, suck / rms(suck), rng.uniform(0.02, 0.04), 0.5)
    for _ in range(rng.integers(2, 4)):
        place(out, bubble(rng.uniform(350, 800) * pitch, 0.035), rng.uniform(0.05, 0.2), 0.4)
    return out


def step_ice(rng):
    """A hard tick: a glassy click and ring, over a short knock of the heel."""
    pitch = rng.uniform(0.92, 1.08)
    out = silence(0.12)
    place(out, burst(rng, 0.02, 2500, 9000, 0.0005, 600), 0, 0.4)
    place(out, ring(2900 * pitch, 90, 0.08), 0, 0.5)
    place(out, ring(4650 * pitch, 140, 0.05), 0, 0.25)
    place(out, ring(260 * pitch, 50, 0.1), 0, 0.5)
    return out


def step_snow(rng):
    """A crunch of tiny grains, muffled, as the snow packs under the foot."""
    pitch = rng.uniform(0.9, 1.1)
    out = silence(0.26)
    crunch = lowpass(bandpass(grains(rng, 0.18, 11000), 300 * pitch, 4000 * pitch), 3000)
    place(out, crunch * envelope(0.18, 0.015, 25), 0)
    settle = lowpass(bandpass(grains(rng, 0.12, 6000), 300 * pitch, 3500 * pitch), 2500)
    place(out, settle * envelope(0.12, 0.01, 40), rng.uniform(0.04, 0.06), 0.5)
    return out


def step_wood(rng):
    """A hollow knock on floorboards: a few wooden modes and the click of the heel."""
    pitch = rng.uniform(0.92, 1.08)
    out = silence(0.2)
    place(out, knock(180 * pitch, 0.2), 0)
    place(out, burst(rng, 0.02, 800, 4000, 0.0005, 400), 0, 0.15)
    place(out, sweep(110 * pitch, 70 * pitch, 0.12) * envelope(0.12, 0.002, 40), 0, 0.5)
    return out
