"""Art for the reeds on the banks and the reeds item.

Each function returns one picture as rows of palette colour names, like the rest of the art
code, and generate.py only calls `reeds_row` and `icons`. Reeds are tall, straight and dark,
with brown cattails, where tall grass is a low, light, yellow-green clump. They are drawn green;
seasons.py turns them golden for autumn and winter and caps them with snow.
"""

import random

import items
from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank
from trees import dense_foot, ground_shadow

REEDS_SEEDS = (311, 312, 313)


def reeds(seed, is_cut=False):
    """A dense stand of reeds about 18 px wide and up to 30 high: straight stems packed close,
    long leaves bending off them, and brown cattail heads on a few; or the low stubble left once
    it is cut. Drawn in dark, cool greens with a dark foot, so it stands apart from tall grass."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 11)
    # The wet, dense foot of the stand, in the two darkest shades with a rim of the darkest.
    dense_foot(canvas, [(OBJECT_BOTTOM - 1 - step, 7 - 2 * step, "green_deep" if step == 0 else "olive") for step in range(2)])
    if is_cut:
        for x in range(OBJECT_CENTRE - 8, OBJECT_CENTRE + 8):
            if rng.random() < 0.3:
                continue
            height = rng.randint(3, 5)
            for step in range(height):
                canvas[OBJECT_BOTTOM - 1 - step][x] = "green_deep" if step == 0 else "olive"
            canvas[OBJECT_BOTTOM - height][x] = "straw" if x % 3 else "sand_light"
        return canvas
    # Back stems first, darker and taller; then the front ones, lit on the left of the stand.
    stems = []
    # A packed row of back stems, and front stems scattered unevenly over them.
    for row in range(2):
        for x in range(OBJECT_CENTRE - 8, OBJECT_CENTRE + 8):
            if rng.random() < (0.15 if row == 0 else 0.6):
                continue
            height = rng.randint(17, 28) if row == 0 else rng.randint(9, 24)
            stems.append((row, x, height))
    for row, x, height in stems:
        lean = rng.choice((-1, 0, 0, 1))
        for step in range(height):
            y = OBJECT_BOTTOM - 1 - step
            stem_x = x + lean * step // 12
            if row == 0:
                colour = "olive" if step < 2 else "green_dark" if step < height * 0.6 else "green"
            else:
                colour = "olive" if step < 2 else "green_light" if stem_x < OBJECT_CENTRE - 2 else "green"
            canvas[y][stem_x] = colour
        top_x, top_y = x + lean * (height - 1) // 12, OBJECT_BOTTOM - height
        # Some stems end in a cattail on a thin spike, some in a leaf bending over.
        if rng.random() < 0.25:
            for head in range(4):
                canvas[top_y - head][top_x] = "soil" if head < 3 else "soil_mid"
                canvas[top_y - head][top_x + 1] = "soil_dark" if head < 3 else "soil"
            canvas[top_y - 1][top_x] = "soil_mid"
            canvas[top_y - 4][top_x] = canvas[top_y - 5][top_x] = "straw"
        else:
            direction = rng.choice((-1, 1))
            for step in range(rng.randint(3, 6)):
                canvas[top_y + step // 2][top_x + direction * (step + 1)] = "green_light" if row else "green"
    return canvas


def reeds_row():
    """The atlas row of reeds: three stands, then the same three cut."""
    return [reeds(seed) for seed in REEDS_SEEDS] + [
        reeds(seed, is_cut=True) for seed in REEDS_SEEDS
    ]


def reeds_item():
    """A bundle of long cut reeds lying on the diagonal, tied twice, with brown cattail heads at
    the top right."""
    picture = blank()
    # Five stalks on the diagonals x + y = 13..17, the upper left one lit. Each ends at its own
    # length, so the ends are not cut square.
    stalks = ((13, "sand_light", 1, 10), (14, "straw", 1, 11), (15, "straw", 2, 12), (16, "reed", 3, 12), (17, "olive", 4, 13))
    for diagonal, colour, first, last in stalks:
        for x in range(first, last + 1):
            picture[diagonal - x][x] = colour
    # Cattail heads beyond the ends of three stalks, 2 px thick along them.
    for diagonal, last in ((14, 11), (15, 12), (16, 12)):
        for x in range(last + 1, last + 3):
            picture[diagonal - x][x] = "soil_mid"
            picture[diagonal - x - 1][x] = "soil_light" if diagonal == 14 else "soil"
    # Two ties across the bundle.
    for across in (-4, 4):
        for x in range(16):
            for y in range(16):
                if x - y in (across, across + 1) and 13 <= x + y <= 17:
                    picture[y][x] = "rust" if x + y < 16 else "rust_dark"
    return items.outlined(picture, "ink")


def icons():
    """The 16x16 icons by item id."""
    return {"reeds": reeds_item()}
