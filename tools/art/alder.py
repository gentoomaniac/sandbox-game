"""Art for the black alder (Schwarzerle, rødel), the tree of wet ground, ditches and brooks: a
straight, dark, fissured stem running up through a narrow, rounded cone of a crown of dark green
leaves. It stays green late into autumn and drops its leaves dull green-brown; in winter its short
side branches carry the little black cones of last year and the purple-brown catkins of the next.

Each picture is an object cell (48x80, see canvas.py) with its foot at the bottom centre, in
palette colour names. generate.py calls `alder_row` and draws the winter looks with `bare_alder`.
"""

import random

from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank
from trees import ground_shadow, outline_in_bark, shade_under_crown, shaded_blob, tree_trunk, twigs

ALDER_SEEDS = (351, 352, 353)
# Dark, fissured bark, lit to dark; the darkest also outlines it.
BARK = ("mud", "mud_dark", "soil_dark", "ink")
# The dark leaves, lit to dark, and the crown's outline.
LEAVES = ("green_light", "green", "green_dark", "green_dark", "green_deep")
LEAF_OUTLINE = "green_deep"
# The bare twigs, lit and shaded, the old cones and the catkins.
TWIGS = ("soil_mid", "soil_dark")
CONE = "ink"
CATKIN = ("umber", "russet_deep")
# The stem runs up to here, through the crown.
TOP = 16
TRUNK_WIDTH = 5


def _stem(canvas, rng):
    """The straight dark stem from the ground to the top, with fissures down it, thinning above."""
    ground_shadow(canvas, 11)
    tree_trunk(canvas, rng, 48, TRUNK_WIDTH, BARK)
    for y in range(TOP, 48):
        width = 3 if y > 30 else 2
        left = OBJECT_CENTRE - width // 2
        for x in range(left, left + width):
            canvas[y][x] = BARK[1] if x == left else BARK[2]
    for x in range(OBJECT_CENTRE - 1, OBJECT_CENTRE + 2, 2):
        start = rng.randint(50, 58)
        for y in range(start, OBJECT_BOTTOM - rng.randint(2, 6)):
            canvas[y][x] = BARK[3] if rng.random() < 0.7 else BARK[2]


def bare_alder(seed):
    """The alder in winter: the stem with short side branches spreading in tiers, narrower towards
    the top, hung with cones and catkins."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    _stem(canvas, rng)
    outline_in_bark(canvas, BARK[3])
    side = rng.choice((-1, 1))
    for y in range(TOP + 3, 50, 4):
        # The lower branches reach further, so the bare tree keeps the crown's cone.
        length = 4 + (y - TOP) // 5
        twigs(canvas, rng, OBJECT_CENTRE, y, side * rng.uniform(0.8, 1.1), length, TWIGS, 2, 0.5)
        side = -side
    tips = [(x, y) for y in range(OBJECT_CELL_HEIGHT - 30) for x in range(OBJECT_CELL_WIDTH) if canvas[y][x] == TWIGS[1]]
    for x, y in rng.sample(tips, min(len(tips), 26)):
        if rng.random() < 0.5:
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                if canvas[y + dy][x + dx] in (None, TWIGS[1]):
                    canvas[y + dy][x + dx] = CONE
        elif all(canvas[y + dy][x] is None for dy in (1, 2, 3)):
            canvas[y + 1][x] = canvas[y + 2][x] = CATKIN[0]
            canvas[y + 3][x] = CATKIN[1]
    return canvas


def alder(seed):
    """The alder in leaf: a narrow, rounded cone of dark leaves round the stem."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    _stem(canvas, rng)
    # Tiers of uneven clumps round the stem, widening down to the middle and then no further, so
    # the crown is a rounded cone with a lumpy outline.
    blobs = [(OBJECT_CENTRE + rng.uniform(-1, 1), TOP + 2, 4.5)]
    for index, y in enumerate(range(TOP + 7, 54, 6)):
        reach = 4 + 7 * min(1.0, index / 3) + rng.uniform(-1, 1.5)
        for side in (-1, 1):
            radius = 4.5 + min(index, 3) * 0.6 + rng.uniform(-1, 1.5)
            blobs.append((OBJECT_CENTRE + side * reach + rng.uniform(-2, 2), y + rng.uniform(-2, 2), radius))
        blobs.append((OBJECT_CENTRE + rng.uniform(-2, 2), y + rng.uniform(-1, 1), 4.5 + rng.uniform(0, 1.5)))
    shaded_blob(canvas, rng, blobs, LEAVES, LEAF_OUTLINE)
    shade_under_crown(canvas, BARK)
    return canvas


def alder_row():
    """The atlas row of the alder: three trees."""
    return [alder(seed) for seed in ALDER_SEEDS]
