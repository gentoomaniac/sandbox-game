"""Art for the beech (Buche, bøg), the tree of the woods of the east: a tall, smooth, silver-grey
bole that forks high up into a few steep limbs, under a broad, dense dome of a crown whose leaves
lie in flat sprays. It turns copper in autumn; in winter its fine grey twigs fan out upwards.

Each picture is an object cell (96x160 at 32 px per tile, see trees.py) with its foot at the
bottom centre, in palette colour names. generate.py calls `beech_row` and draws the winter looks
with `bare_beech`.
"""

import math
import random

from trees import CENTRE, LEAVES, crown_limb, cell, foliage, ground_shadow, limb, shade_under_crown, tree_trunk

BEECH_SEEDS = (331, 332, 333)
# Smooth grey bark, lit to dark; the darkest also outlines it.
BARK = ("stone_light", "stone", "stone", "stone_dark")
# Where the bole forks into its limbs.
FORK_Y = 100
TRUNK_WIDTH = 12


def _bole(canvas, rng):
    """The smooth grey trunk with the dark eyes beech bark has where branches fell off."""
    ground_shadow(canvas, 28, rows=7)
    tree_trunk(canvas, rng, FORK_Y, TRUNK_WIDTH, BARK)
    left = CENTRE - TRUNK_WIDTH // 2
    for _ in range(3):
        x, y = left + rng.randint(2, TRUNK_WIDTH - 5), rng.randint(FORK_Y + 10, 140)
        for dx, dy, colour in ((0, 0, "stone_dark"), (1, 0, "stone_dark"), (2, 0, "stone_dark"), (1, 1, "stone_dark"), (0, -1, "stone_light"), (1, -1, "stone_light")):
            canvas[y + dy][x + dx] = colour


def bare_beech(seed):
    """The beech in winter: the same bole, its limbs fanning out steeply into a dome of fine grey
    twigs."""
    rng = random.Random(seed)
    canvas = cell()
    _bole(canvas, rng)
    limbs = (-0.75, -0.3, 0.15, 0.6) if seed % 2 else (-0.6, -0.1, 0.4, 0.8)
    for angle in limbs:
        # The steep middle limbs reach highest, so the twigs round off into a dome.
        length = round(46 - 16 * abs(angle))
        crown_limb(canvas, rng, (CENTRE + angle * 5, FORK_Y + 3), angle + rng.uniform(-0.1, 0.1), length, BARK, forks=4, spread=0.34)
    return canvas


def beech(seed):
    """The beech in leaf: the bole and the first of its limbs, under a broad, round dome of a
    crown, its rim of sprays of uneven size."""
    rng = random.Random(seed)
    canvas = cell()
    _bole(canvas, rng)
    for direction in (-1, 1):
        limb(canvas, (CENTRE + direction * 2, FORK_Y + 6), (CENTRE + direction * 12, FORK_Y - 14), 3, BARK)
    # The dome: a broad, round body reaching low, with sprays of uneven size bulging from its rim
    # over the top and the sides (below, they would light a ring inside it).
    centre_y = 74 + rng.uniform(-2, 2)
    blobs = [(CENTRE + rng.uniform(-2, 2), centre_y, 28 + rng.uniform(0, 2))]
    for index in range(10):
        angle = math.pi * (0.9 + 1.2 * index / 9) + rng.uniform(-0.15, 0.15)
        radius = rng.uniform(9, 16)
        blobs.append((CENTRE + math.cos(angle) * 30, centre_y + math.sin(angle) * 24, radius))
    foliage(canvas, rng, blobs, LEAVES[:4], "green_deep", leaf_size=3.6, holes=3)
    shade_under_crown(canvas, BARK)
    return canvas


def beech_row():
    """The atlas row of the beech: three trees."""
    return [beech(seed) for seed in BEECH_SEEDS]
