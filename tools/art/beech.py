"""Art for the beech (Buche, bøg), the tree of the woods of the east: a tall, smooth, silver-grey
bole that forks high up into a few steep limbs, under a broad, dense dome of a crown whose leaves
lie in flat sprays. It turns copper in autumn; in winter its fine grey twigs
fan out upwards.

Each picture is an object cell (48x80, see canvas.py) with its foot at the bottom centre, in
palette colour names. generate.py calls `beech_row` and draws the winter looks with `bare_beech`.
"""

import math
import random

from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank
from trees import LEAVES, ground_shadow, outline_in_bark, shade_under_crown, shaded_blob, tree_trunk, twigs

BEECH_SEEDS = (331, 332, 333)
# Smooth grey bark, lit to dark; the darkest also outlines it.
BARK = ("stone_light", "stone", "stone", "stone_dark")
# Where the bole forks into its limbs.
FORK_Y = 50
TRUNK_WIDTH = 6


def _bole(canvas, rng):
    """The smooth grey trunk with the dark eyes beech bark has where branches fell off."""
    ground_shadow(canvas, 14)
    tree_trunk(canvas, rng, FORK_Y, TRUNK_WIDTH, BARK)
    left = OBJECT_CENTRE - TRUNK_WIDTH // 2
    for _ in range(2):
        x, y = left + rng.randint(1, TRUNK_WIDTH - 3), rng.randint(FORK_Y + 6, OBJECT_BOTTOM - 8)
        canvas[y][x] = canvas[y][x + 1] = "stone_dark"
        canvas[y - 1][x] = "stone_light"


def bare_beech(seed):
    """The beech in winter: the same bole, its limbs fanning out steeply into a dome of fine
    grey twigs."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    _bole(canvas, rng)
    outline_in_bark(canvas, "stone_dark")
    limbs = (-0.75, -0.3, 0.15, 0.6) if seed % 2 else (-0.6, -0.1, 0.4, 0.8)
    for angle in limbs:
        # The steep middle limbs reach highest, so the twigs round off into a dome.
        length = round(12 - 4 * abs(angle))
        twigs(canvas, rng, OBJECT_CENTRE + round(angle * 3), FORK_Y + 1, angle + rng.uniform(-0.1, 0.1), length, ("stone", "stone_dark"), 4, 0.36)
    return canvas


def beech(seed):
    """The beech in leaf: the bole and the first of its limbs, under a broad, round dome of a
    crown, its rim of sprays of uneven size."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    _bole(canvas, rng)
    for direction in (-1, 1):
        for step in range(7):
            x, y = OBJECT_CENTRE + direction * (1 + step // 2), FORK_Y - step
            canvas[y][x] = BARK[1] if direction < 0 else BARK[3]
    # The dome: a broad, round body reaching low, with sprays of uneven size bulging from its rim
    # over the top and the sides (below, they would light a ring inside it).
    centre_y = 37 + rng.uniform(-1, 1)
    blobs = [(OBJECT_CENTRE + rng.uniform(-1, 1), centre_y, 14 + rng.uniform(0, 1))]
    for index in range(10):
        angle = math.pi * (0.9 + 1.2 * index / 9) + rng.uniform(-0.15, 0.15)
        radius = rng.uniform(4.5, 8)
        blobs.append((OBJECT_CENTRE + math.cos(angle) * 15, centre_y + math.sin(angle) * 12, radius))
    shaded_blob(canvas, rng, blobs, LEAVES[:5], "green_deep")
    shade_under_crown(canvas, BARK)
    return canvas


def beech_row():
    """The atlas row of the beech: three trees."""
    return [beech(seed) for seed in BEECH_SEEDS]
