"""Art for the black alder (Schwarzerle, rødel), the tree of wet ground, ditches and brooks: a
straight, dark, fissured stem running up through a narrow, rounded cone of a crown of dark green
leaves. It stays green late into autumn and drops its leaves dull green-brown; in winter its short
side branches carry the little black cones of last year and the purple-brown catkins of the next.

Each picture is an object cell (96x160 at 32 px per tile, see trees.py) with its foot at the
bottom centre, in palette colour names. generate.py calls `alder_row` and draws the winter looks
with `bare_alder`.
"""

import random

from trees import CENTRE, HEIGHT, WIDTH, cell, foliage, ground_shadow, shade_under_crown, tree_trunk, twigs

ALDER_SEEDS = (351, 352, 353)
# Dark, fissured bark, lit to dark; the darkest also outlines it.
BARK = ("mud", "mud_dark", "soil_dark", "soil_dark")
# The dark leaves, lit to dark, and the crown's outline.
LEAVES = ("green_light", "green", "green_dark", "green_dark")
LEAF_OUTLINE = "green_deep"
# The bare twigs, lit and shaded, the old cones and the catkins.
TWIGS = ("soil_mid", "soil_dark")
CONE = "soil_dark"
CATKIN = ("umber", "russet_deep")
# The stem runs up to here, through the crown.
TOP = 32
TRUNK_WIDTH = 10


def _stem(canvas, rng):
    """The straight dark stem from the ground to the top, with fissures down it, thinning above."""
    ground_shadow(canvas, 22, rows=6)
    tree_trunk(canvas, rng, 96, TRUNK_WIDTH, BARK)
    for y in range(TOP, 98):
        width = 6 if y > 60 else 4
        left = CENTRE - width // 2
        for x in range(left - 1, left + width + 1):
            canvas[y][x] = BARK[3] if x in (left - 1, left + width) else BARK[0] if x == left else BARK[1] if x < left + width - 1 else BARK[2]


def bare_alder(seed):
    """The alder in winter: the stem with short side branches spreading in tiers, narrower towards
    the top, hung with cones and catkins."""
    rng = random.Random(seed)
    canvas = cell()
    _stem(canvas, rng)
    side = rng.choice((-1, 1))
    for y in range(TOP + 6, 100, 8):
        # The lower branches reach further, so the bare tree keeps the crown's cone.
        length = 8 + (y - TOP) // 5
        twigs(canvas, rng, CENTRE + side * 2, y, side * rng.uniform(0.8, 1.1), length, TWIGS, 3, 0.5)
        side = -side
    tips = [(x, y) for y in range(HEIGHT - 60) for x in range(1, WIDTH - 2) if canvas[y][x] == TWIGS[1] and canvas[y + 1][x] is None]
    for x, y in rng.sample(tips, min(len(tips), 30)):
        if rng.random() < 0.5:
            # An old cone: a little dark knob, lit on its upper left.
            for dx, dy, colour in ((0, 1, "umber"), (1, 1, CONE), (0, 2, CONE), (1, 2, CONE), (0, 3, CONE)):
                if canvas[y + dy][x + dx] is None:
                    canvas[y + dy][x + dx] = colour
        elif all(canvas[y + dy][x] is None for dy in range(1, 7)):
            for dy in range(1, 6):
                canvas[y + dy][x] = CATKIN[0] if dy < 5 else CATKIN[1]
                if dy in (2, 4):
                    canvas[y + dy][x + 1] = CATKIN[1]
    return canvas


def alder(seed):
    """The alder in leaf: a narrow, rounded cone of dark leaves round the stem."""
    rng = random.Random(seed)
    canvas = cell()
    _stem(canvas, rng)
    # Tiers of uneven clumps round the stem, widening down to the middle and then no further, so
    # the crown is a rounded cone with a lumpy outline.
    blobs = [(CENTRE + rng.uniform(-2, 2), TOP + 4, 9)]
    for index, y in enumerate(range(TOP + 14, 108, 12)):
        reach = 8 + 14 * min(1.0, index / 3) + rng.uniform(-2, 3)
        for side in (-1, 1):
            radius = 9 + min(index, 3) * 1.2 + rng.uniform(-2, 3)
            blobs.append((CENTRE + side * reach + rng.uniform(-4, 4), y + rng.uniform(-4, 4), radius))
        blobs.append((CENTRE + rng.uniform(-4, 4), y + rng.uniform(-2, 2), 9 + rng.uniform(0, 3)))
    foliage(canvas, rng, blobs, LEAVES, LEAF_OUTLINE, leaf_size=3.0, holes=3)
    shade_under_crown(canvas, BARK)
    return canvas


def alder_row():
    """The atlas row of the alder: three trees."""
    return [alder(seed) for seed in ALDER_SEEDS]
