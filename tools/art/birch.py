"""Art for the birch (Birke, birk), the light tree of the Geest and the wet woods: a slender white
trunk with black marks, rough and dark at its foot, under a narrow, airy crown of small leaves on
hanging twigs, with the sky showing through. It turns yellow in autumn; in winter its white limbs
end in a haze of fine brown twigs that hang at their tips.

Each picture is an object cell (48x80, see canvas.py) with its foot at the bottom centre, in
palette colour names. generate.py calls `birch_row` and draws the winter looks with `bare_birch`.
"""

import math
import random

from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank
from trees import ground_shadow, outline_in_bark, shaded_blob, twigs

BIRCH_SEEDS = (341, 342, 343)
# White bark, lit to shaded, and its outline.
BARK = ("lime", "stone_light", "stone", "stone_dark")
# The black marks across the bark, and the rough dark bark at the foot.
MARKS = "ink"
FOOT_BARK = ("mud", "mud_dark", "ink")
# How many rows up the dark foot reaches.
FOOT_HEIGHT = 7
# The small, light leaves, lit to dark, and the outline of the crown.
LEAVES = ("green_bright", "green_light", "green_light", "green")
LEAF_OUTLINE = "green_deep"
# The thin twigs of winter: the limbs are white, the fine twigs purple-brown.
TWIGS = ("stone_light", "soil")
TOP = 18


def _trunk(canvas, rng, seed):
    """The slender white trunk from the ground to the top of the crown, leaning a little, with its
    black marks and its dark foot. Returns the trunk's centre per row."""
    ground_shadow(canvas, 9)
    lean = (-2, 1.5, 2.5)[seed % 3]
    centres = {}
    for y in range(TOP, OBJECT_BOTTOM + 1):
        rise = (OBJECT_BOTTOM - y) / (OBJECT_BOTTOM - TOP)
        centres[y] = OBJECT_CENTRE + lean * rise
        width = 4 if rise < 0.45 else 3 if rise < 0.8 else 2
        flare = 1 if y > OBJECT_BOTTOM - 2 else 0
        left = round(centres[y] - width / 2) - flare
        shades = FOOT_BARK if y > OBJECT_BOTTOM - FOOT_HEIGHT + rng.randint(-1, 1) else BARK
        for x in range(left, left + width + 2 * flare):
            index = x - left
            canvas[y][x] = shades[0] if index == 0 else shades[2] if index == width + 2 * flare - 1 and width > 2 else shades[1]
    # The black marks: short dashes across the white bark, wider low down.
    for _ in range(9):
        y = rng.randint(TOP + 8, OBJECT_BOTTOM - FOOT_HEIGHT - 1)
        x = round(centres[y]) + rng.choice((-1, 0))
        for dx in range(rng.randint(1, 2)):
            if canvas[y][x + dx] in BARK:
                canvas[y][x + dx] = MARKS
    return centres


def _hanging_tips(canvas, rng, ends, colour, count):
    """Strands 2 to 4 px long hanging from pixels of `ends` that have nothing below them."""
    spots = [
        (x, y)
        for y in range(1, OBJECT_BOTTOM - 20)
        for x in range(OBJECT_CELL_WIDTH)
        if canvas[y][x] in ends and canvas[y + 1][x] is None
    ]
    for x, y in rng.sample(spots, min(count, len(spots))):
        for step in range(1, rng.randint(3, 5)):
            if canvas[y + step][x] is not None:
                break
            canvas[y + step][x] = colour


def bare_birch(seed):
    """The birch in winter: the white trunk and limbs, fine brown twigs at their ends, some hanging
    down."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    centres = _trunk(canvas, rng, seed)
    outline_in_bark(canvas, BARK[3])
    side = rng.choice((-1, 1))
    for index, y in enumerate(range(TOP + 6, 50, 6)):
        angle = side * rng.uniform(0.55, 0.9)
        twigs(canvas, rng, centres[y], y, angle, 8 + index, TWIGS, 2, 0.55)
        side = -side
    twigs(canvas, rng, centres[TOP], TOP, rng.uniform(-0.2, 0.2), 5, TWIGS, 2, 0.4)
    _hanging_tips(canvas, rng, {TWIGS[1]}, TWIGS[1], 14)
    return canvas


def birch(seed):
    """The birch in leaf: the white trunk through a narrow, open crown of small clumps of leaves
    along hanging twigs."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    centres = _trunk(canvas, rng, seed)
    outline_in_bark(canvas, BARK[3])
    # Small clumps over a narrow oval round the trunk; gaps between them let the sky through.
    blobs = []
    for ring, count in ((0.35, 5), (0.7, 9), (1.0, 12)):
        for index in range(count):
            angle = 2 * math.pi * (index + rng.uniform(0, 0.6)) / count
            y = 34 + math.sin(angle) * 18 * ring
            x = centres[max(TOP, round(y))] + math.cos(angle) * 11 * ring
            blobs.append((x, y, rng.uniform(2.5, 4)))
    # Leave a few holes, so the crown stays open.
    blobs = rng.sample(blobs, len(blobs) - 4)
    shaded_blob(canvas, rng, blobs, LEAVES, LEAF_OUTLINE)
    # The twigs hang: strands of leaves dangle from the clumps' undersides.
    _hanging_tips(canvas, rng, {LEAF_OUTLINE}, LEAVES[2], 22)
    return canvas


def birch_row():
    """The atlas row of the birch: three trees."""
    return [birch(seed) for seed in BIRCH_SEEDS]
