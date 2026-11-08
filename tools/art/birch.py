"""Art for the birch (Birke, birk), the light tree of the Geest and the wet woods: a slender white
trunk with black marks, rough and dark at its foot, under a narrow, airy crown of small leaves on
hanging twigs, with the sky showing through. It turns yellow in autumn; in winter its white limbs
end in a haze of fine brown twigs that hang at their tips.

Each picture is an object cell (96x160 at 32 px per tile, see trees.py) with its foot at the
bottom centre, in palette colour names. generate.py calls `birch_row` and draws the winter looks
with `bare_birch`.
"""

import math
import random

from trees import BOTTOM, CENTRE, HEIGHT, WIDTH, cell, foliage, ground_shadow, outline_in_bark, twigs

BIRCH_SEEDS = (341, 342, 343)
# White bark, lit to shaded, and its outline.
BARK = ("lime", "stone_light", "stone", "stone_dark")
# The black marks across the bark, and the rough dark bark at the foot.
MARKS = "ink"
FOOT_BARK = ("mud", "mud_dark", "soil_dark")
# How many rows up the dark foot reaches.
FOOT_HEIGHT = 14
# The small, light leaves, lit to dark, and the outline of the crown.
LEAVES = ("green_bright", "green_light", "green_light", "green")
LEAF_OUTLINE = "green_deep"
# The thin twigs of winter: the limbs are white, the fine twigs purple-brown.
TWIGS = ("stone_light", "soil")
TOP = 36


def _trunk(canvas, rng, seed):
    """The slender white trunk from the ground to the top of the crown, leaning a little, with its
    black marks and its dark foot. Returns the trunk's centre per row."""
    ground_shadow(canvas, 18, rows=6)
    lean = (-4, 3, 5)[seed % 3]
    centres = {}
    for y in range(TOP, BOTTOM + 1):
        rise = (BOTTOM - y) / (BOTTOM - TOP)
        centres[y] = CENTRE + lean * rise
        width = 8 if rise < 0.45 else 6 if rise < 0.8 else 4
        spread = 3 * max(0.0, 1 - (BOTTOM - y) / 5) ** 2
        left = round(centres[y] - width / 2 - spread)
        right = round(centres[y] + width / 2 + spread)
        shades = FOOT_BARK if y > BOTTOM - FOOT_HEIGHT + rng.randint(-2, 2) else BARK
        for x in range(left, right):
            across = (x + 0.5 - left) / (right - left)
            canvas[y][x] = shades[0] if across < 0.34 else shades[2] if across > 0.75 else shades[1]
    # The black marks: short dashes across the white bark, wider low down, and the dark rough
    # bark breaking up into the white above the foot.
    for _ in range(22):
        y = rng.randint(TOP + 14, BOTTOM - FOOT_HEIGHT - 2)
        x = round(centres[y]) + rng.randint(-3, 1)
        for dx in range(rng.randint(2, 4)):
            for dy in range(rng.choice((1, 1, 2))):
                if canvas[y + dy][x + dx] in BARK:
                    canvas[y + dy][x + dx] = MARKS
    for _ in range(10):
        y = rng.randint(BOTTOM - FOOT_HEIGHT - 10, BOTTOM - FOOT_HEIGHT)
        x = round(centres[y]) + rng.randint(-3, 2)
        if canvas[y][x] in BARK:
            canvas[y][x] = canvas[y + 1][x] = FOOT_BARK[2]
    return centres


def _hanging_tips(canvas, rng, ends, colour, count, length=(4, 9)):
    """Strands hanging from pixels of `ends` that have nothing below them."""
    spots = [
        (x, y)
        for y in range(1, BOTTOM - 40)
        for x in range(WIDTH)
        if canvas[y][x] in ends and canvas[y + 1][x] is None
    ]
    for x, y in rng.sample(spots, min(count, len(spots))):
        for step in range(1, rng.randint(*length)):
            if y + step >= HEIGHT or canvas[y + step][x] is not None:
                break
            canvas[y + step][x] = colour


def bare_birch(seed):
    """The birch in winter: the white trunk and limbs, fine brown twigs at their ends, many
    hanging down."""
    rng = random.Random(seed)
    canvas = cell()
    centres = _trunk(canvas, rng, seed)
    outline_in_bark(canvas, BARK[3])
    side = rng.choice((-1, 1))
    for index, y in enumerate(range(TOP + 12, 100, 11)):
        angle = side * rng.uniform(0.55, 0.9)
        twigs(canvas, rng, centres[y], y, angle, 14 + 2 * index, TWIGS, 3, 0.5)
        side = -side
    twigs(canvas, rng, centres[TOP], TOP, rng.uniform(-0.2, 0.2), 10, TWIGS, 3, 0.4)
    _hanging_tips(canvas, rng, {TWIGS[1]}, TWIGS[1], 40)
    return canvas


def birch(seed):
    """The birch in leaf: the white trunk through a narrow, open crown of small clumps of leaves
    along hanging twigs."""
    rng = random.Random(seed)
    canvas = cell()
    centres = _trunk(canvas, rng, seed)
    outline_in_bark(canvas, BARK[3])
    # Small clumps over a narrow oval round the trunk; gaps between them let the sky through.
    blobs = []
    for ring, count in ((0.35, 5), (0.7, 9), (1.0, 13)):
        for index in range(count):
            angle = 2 * math.pi * (index + rng.uniform(0, 0.6)) / count
            y = 68 + math.sin(angle) * 36 * ring
            x = centres[max(TOP, round(y))] + math.cos(angle) * 22 * ring
            blobs.append((x, y, rng.uniform(5, 8)))
    # Leave a few holes, so the crown stays open.
    blobs = rng.sample(blobs, len(blobs) - 5)
    foliage(canvas, rng, blobs, LEAVES, LEAF_OUTLINE, leaf_size=2.4)
    # The twigs hang: strands of leaves dangle from the clumps' undersides.
    _hanging_tips(canvas, rng, {LEAF_OUTLINE}, LEAVES[3], 40, (3, 8))
    return canvas


def birch_row():
    """The atlas row of the birch: three trees."""
    return [birch(seed) for seed in BIRCH_SEEDS]
