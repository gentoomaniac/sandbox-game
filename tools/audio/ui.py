"""UI sounds: short, soft blips for menus, the inventory and the hotbar."""

from dsp import TRIANGLE, constant, envelope, place, silence, tone


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
