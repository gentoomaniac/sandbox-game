"""The flames of the campfire and the hearth, as a short loop of frames (see generate.py,
fireplace and hearth, and game/scenes/fire.gdshader, which plays them).

A flame is a heat field: a round body over the logs and three tongues rising out of it. Each
tongue grows, licks sideways and falls back in turn, and as it is at its tallest its tip breaks
off as a lick that rises, shrinks and goes out. The tongues are a third of the loop apart, so
the flame is never the same shape twice in a loop of FRAMES frames. The hottest heat is cream,
then gold, flame and, at the cool tips, ember.
"""

import math

# As many as AmbientMotion.FIRE_FRAMES.
FRAMES = 6
# Heat over which a pixel takes each colour, from the core out.
HEAT_COLOURS = ((0.62, "cream"), (0.35, "gold"), (0.1, "flame"), (0.0, "ember"))
# The tongues: where they stand (a share of the half width, from the middle), how tall they
# are at their tallest (a share of the flame's height) and when in the loop they are tallest.
TONGUES = ((-0.4, 0.8, 0.0), (0.05, 1.05, 1 / 3), (0.45, 0.75, 2 / 3))


def flame(width, height, frame, half_width, tall):
    """Frame `frame` of the loop: rows of colour names, `width` by `height`, the flame standing
    on the bottom row in the middle, `half_width` pixels to either side at its widest and about
    `tall` pixels high (its licks rise higher)."""
    centre = width / 2
    canvas = [[None] * width for _ in range(height)]
    for y in range(height):
        rise = height - y - 0.5
        for x in range(width):
            across = x + 0.5 - centre
            # The body, a round glow over the logs.
            heat = 0.85 - math.hypot(across / (0.9 * half_width), rise / (0.5 * tall))
            for at, tallest, peak in TONGUES:
                # 0 at the tongue's tallest, 0.5 at its lowest.
                phase = (frame / FRAMES - peak) % 1.0
                grown = 0.5 + 0.5 * math.cos(2 * math.pi * phase)
                length = tall * tallest * (0.55 + 0.45 * grown)
                width_at_foot = half_width * (0.6 + 0.15 * grown)
                up = rise / length
                if up < 1.0:
                    # It licks away from the middle while it grows, back while it falls.
                    lick = math.sin(2 * math.pi * phase) * (1.0 if at >= 0 else -1.0)
                    middle = at * half_width + 1.6 * lick * up * up
                    reach = width_at_foot * (1.0 - up) ** 0.75
                    heat = max(heat, 0.95 - abs(across - middle) / reach - 0.45 * up)
                # The tip that broke off as the tongue was tallest rises and shrinks.
                if 0.0 < phase < 0.5:
                    lick_rise = tall * tallest + phase * 12.0
                    size = 1.6 * (1.0 - 1.2 * phase)
                    distance = math.hypot(across - at * half_width - 2.0 * phase, (rise - lick_rise) / 1.6)
                    heat = max(heat, 0.3 * (1.0 - distance / size))
            for threshold, colour in HEAT_COLOURS:
                if heat > threshold:
                    canvas[y][x] = colour
                    break
    return canvas


def strip(behind, front, box, half_width, tall):
    """The cells of a fire's strip (assets/fire/<type>.png), each the size of `box` (x, y,
    width, height in the picture): what is behind the flame, what is in front of it, then the
    flame's frames."""
    _, _, width, height = box
    flames = [flame(width, height, frame, half_width, tall) for frame in range(FRAMES)]
    return [_cropped(behind, box), _cropped(front, box)] + flames


def burning(behind, front, box, half_width, tall):
    """The whole picture with the first frame of its flame, for where it does not move."""
    x0, y0, width, height = box
    canvas = [row[:] for row in behind]
    first = flame(width, height, 0, half_width, tall)
    for y in range(height):
        for x in range(width):
            if first[y][x] is not None:
                canvas[y0 + y][x0 + x] = first[y][x]
    for y, row in enumerate(front):
        for x, colour in enumerate(row):
            if colour is not None:
                canvas[y][x] = colour
    return canvas


def _cropped(canvas, box):
    x0, y0, width, height = box
    return [row[x0 : x0 + width] for row in canvas[y0 : y0 + height]]
