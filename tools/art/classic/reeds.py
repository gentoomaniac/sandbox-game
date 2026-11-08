"""The reeds of reeds.py as they were drawn for the classic 16 px plants (commit e303759), its part
of the module unchanged.
"""

import random

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
