"""Art for the reeds on the banks and the reeds item.

Each function returns one picture as rows of palette colour names, like the rest of the art
code, and generate.py only calls `reeds_row` and `icons`. Reeds are tall, straight and dark,
with brown cattails, where tall grass is a low, light, yellow-green clump. They are drawn green;
seasons.py turns them golden for autumn and winter and caps them with snow.
"""

import random

import items
from canvas import blank
from items import ICON
from trees import BOTTOM, CENTRE, blade, cell, dense_foot, ground_shadow

REEDS_SEEDS = (311, 312, 313)
# The leaves from the back of the stand to the front: their darkest shade (their foot), their
# shaded and their lit side. The back ones stay dark in every season, so the golden stand of
# autumn keeps an edge on straw ground.
LEAF_SHADES = (("green_deep", "green_deep", "green_dark"), ("green_deep", "green_dark", "green"), ("green_dark", "green", "green_light"))


def reeds(seed, is_cut=False):
    """A dense stand of reeds about 36 px wide and up to 60 high: long leaves standing up thick and
    bending over at their tips, the far ones in shade, and two or three brown velvet heads on
    stalks; or the low stubble left once it is cut. Drawn in dark, cool greens with a dark foot,
    so it stands apart from tall grass."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 22)
    # The wet, dense foot of the stand, in the two darkest shades with a rim of the darkest.
    dense_foot(canvas, [(BOTTOM - 2 - step, 15 - 2 * step, "green_deep" if step < 2 else "olive") for step in range(4)])
    if is_cut:
        for x in range(CENTRE - 16, CENTRE + 16):
            if rng.random() < 0.3:
                continue
            height = rng.randint(5, 10)
            for step in range(height):
                canvas[BOTTOM - 2 - step][x] = "green_deep" if step < 2 else "olive"
            canvas[BOTTOM - 1 - height][x] = "straw" if x % 3 else "sand_light"
        return canvas
    leaves = sorted((rng.random(), CENTRE + rng.uniform(-15, 13), rng.uniform(26, 54), rng.uniform(-12, 12)) for _ in range(34))
    for depth, x, height, lean in leaves:
        blade(canvas, x, BOTTOM - 2, height, lean, LEAF_SHADES[min(2, int(depth * 3))], droop=abs(lean) * 0.6, shaded=0.2)
    # The bulrush heads: a stalk, a long brown velvet head lit on the left, a thin spike above.
    for _ in range(2 + seed % 2):
        x = round(CENTRE + rng.uniform(-9, 9))
        top = round(BOTTOM - rng.uniform(50, 58))
        for y in range(top, BOTTOM - 2):
            canvas[y][x] = "olive" if y > BOTTOM - 20 else "green_dark"
        for y in range(top + 2, top + 13):
            canvas[y][x - 1] = "soil_mid" if y > top + 2 else "soil"
            canvas[y][x] = "soil"
            canvas[y][x + 1] = "soil_dark"
        canvas[top + 3][x - 1] = canvas[top + 4][x - 1] = "soil_light"
        canvas[top + 1][x] = canvas[top + 13][x] = "soil_dark"
        for y in range(top - 5, top + 1):
            canvas[y][x] = "reed"
    return canvas


def reeds_row():
    """The atlas row of reeds: three stands, then the same three cut."""
    return [reeds(seed) for seed in REEDS_SEEDS] + [
        reeds(seed, is_cut=True) for seed in REEDS_SEEDS
    ]


def reeds_item():
    """A bundle of long cut reeds lying on the diagonal, tied twice, with brown cattail heads at
    the top right."""
    picture = blank(ICON)
    # Five stalks along the diagonal, the upper left one lit, each ending at its own length.
    for offset, colour, first, last in ((-2, "sand_light", 3, 21), (-1, "straw", 2, 22), (0, "straw", 3, 24), (1, "reed", 4, 23), (2, "olive", 5, 25)):
        for x in range(first, last + 1):
            items.dots(picture, [(x, 31 - x + offset)], colour)
    for offset, last in ((-1, 22), (0, 24), (1, 23)):
        head = items.capsule((last + 1, 31 - last - 1 + offset), (last + 5, 31 - last - 5 + offset), 1.4)
        items.shade(picture, head, ("soil", "soil_mid", "soil_light"), radius=1)
    for middle in (9, 17):
        tie = items.capsule((middle - 2, 31 - middle - 2), (middle + 2, 31 - middle + 2), 1.2)
        items.shade(picture, tie, ("rust_dark", "rust", "red_light"), radius=1)
    return picture


def icons():
    """The body of the reeds' icon, by item id."""
    return {"reeds": reeds_item()}
