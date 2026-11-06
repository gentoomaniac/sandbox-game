"""Art for the pollard willow of the marsh ditches (Kopfweide): a short, thick, furrowed trunk cut
back to a knobbly head at about the height of a man, from which a crown of straight rods springs
every year. In summer the rods carry narrow silver-green leaves; in winter they stand bare, golden
and orange-brown, which is the willow's look of the marsh in winter.

Each picture is an object cell (48x80, see canvas.py) with its foot at the bottom centre, in
palette colour names. generate.py calls `willow_row` and draws the winter looks with
`bare_willow`.
"""

import math
import random

from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank
from trees import ground_shadow, outline_in_bark, shaded_blob, tree_trunk

WILLOW_SEEDS = (321, 322, 323)
# Grey-brown, deeply furrowed bark, lit to dark.
BARK = ("bare_light", "bare", "mud_dark", "soil_dark")
# The narrow grey-green leaves, lit to dark, and their silvery undersides, which the wind shows.
# seasons.py turns them for spring and autumn.
LEAVES = ("dry_light", "dry", "olive", "green_dark")
SILVER = "frost"
# The rods in winter: golden at their tips, orange-brown low down.
RODS = ("ochre", "ochre_dark", "umber")
# Where the head sits: the top of the trunk, the rods spring from around it.
HEAD_Y = 56
TRUNK_WIDTH = 9


def _trunk_and_head(canvas, rng):
    """The trunk and the knobbly head it was cut back to."""
    ground_shadow(canvas, 12)
    tree_trunk(canvas, rng, HEAD_Y, TRUNK_WIDTH, BARK)
    # Deep furrows running up the trunk.
    for x in range(OBJECT_CENTRE - TRUNK_WIDTH // 2 + 2, OBJECT_CENTRE + TRUNK_WIDTH // 2 - 1, 2):
        start = rng.randint(HEAD_Y + 2, HEAD_Y + 8)
        for y in range(start, OBJECT_BOTTOM - rng.randint(1, 4)):
            canvas[y][x] = BARK[2]
    blobs = [
        (OBJECT_CENTRE + rng.uniform(-0.5, 0.5), HEAD_Y - 1, 6.5),
        (OBJECT_CENTRE - 5, HEAD_Y, 3.5 + rng.uniform(0, 1)),
        (OBJECT_CENTRE + 5, HEAD_Y + 1, 3.5 + rng.uniform(0, 1)),
    ]
    shaded_blob(canvas, rng, blobs, BARK[:3], BARK[3])


def _rods(rng, count):
    """The rods springing from the head, as lists of (x, y) from their foot up: straight, fanning
    out, the outer ones leaning further."""
    rods = []
    for index in range(count):
        spread = (index + rng.uniform(0, 1)) / count * 2 - 1
        foot_x = OBJECT_CENTRE + spread * 5
        angle = spread * math.radians(38) + rng.uniform(-0.08, 0.08)
        length = rng.uniform(22, 30) * (1 - 0.25 * abs(spread))
        rods.append([
            (round(foot_x + math.sin(angle) * step), round(HEAD_Y - 4 - math.cos(angle) * step))
            for step in range(round(length))
        ])
    return rods


def bare_willow(seed):
    """The willow in winter: the same trunk and head, the rods bare."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    _trunk_and_head(canvas, rng)
    for rod in _rods(rng, 15 + seed % 3 * 2):
        for step, (x, y) in enumerate(rod):
            canvas[y][x] = RODS[2] if step < 4 else RODS[1] if step < len(rod) * 0.6 else RODS[0]
    outline_in_bark(canvas, BARK[3])
    return canvas


def willow(seed):
    """The willow in leaf: a round, airy crown of leafy rods over the head, a few rods sticking
    out of it at the top."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    _trunk_and_head(canvas, rng)
    rods = _rods(rng, 15 + seed % 3 * 2)
    blobs = [(OBJECT_CENTRE + rng.uniform(-1, 1), 38 + rng.uniform(-1, 1), 12 + rng.uniform(0, 1.5))]
    for cx, cy, radius in ((13, 44, 7), (35, 44, 7), (18, 30, 7.5), (30, 30, 7.5), (24, 25, 6)):
        blobs.append((cx + rng.uniform(-1.5, 1.5), cy + rng.uniform(-1.5, 1.5), radius + rng.uniform(-1, 1)))
    shaded_blob(canvas, rng, blobs, LEAVES, "green_deep")
    # Narrow leaves along the rods: short light strokes, silvery on the lit side, so the crown
    # reads as many thin rods.
    for rod in rods:
        for x, y in (point for point in rod[6:] if rng.random() < 0.3):
            if canvas[y][x] in LEAVES[1:]:
                canvas[y][x] = SILVER if x < OBJECT_CENTRE else LEAVES[0]
                if canvas[y - 1][x] in LEAVES:
                    canvas[y - 1][x] = LEAVES[0]
        # The tips of the longest rods show above the crown.
        for x, y in rod[-3:]:
            if canvas[y][x] is None:
                canvas[y][x] = LEAVES[2]
    return canvas


def willow_row():
    """The atlas row of the willow: three trees."""
    return [willow(seed) for seed in WILLOW_SEEDS]
