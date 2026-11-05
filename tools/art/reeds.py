"""Placeholder art for the reeds on the banks and the reeds item (task 37).

Meant to be redrawn by a proper art pass: each function returns one picture as rows of palette
colour names, like the rest of the art code, and generate.py only calls `reeds_row` and `icons`.
The reeds are drawn green; seasons.py turns them golden for autumn and winter and caps them
with snow. Nothing in here needs a colour that is not in the palette already.
"""

import random

import items

# The object atlas cell, as in generate.py (the reeds stand at the bottom centre).
CELL_WIDTH = 48
CELL_HEIGHT = 80
CENTRE = CELL_WIDTH // 2
BOTTOM = CELL_HEIGHT - 1

REEDS_SEEDS = (311, 312, 313)


def _cell():
    return [[None] * CELL_WIDTH for _ in range(CELL_HEIGHT)]


def reeds(seed, is_cut=False):
    """A dense stand of upright stalks, 14 px wide and up to 26 px high, a few topped by a brown
    seed head; or the stubble left once it is cut."""
    rng = random.Random(seed)
    canvas = _cell()
    for x in range(CENTRE - 7, CENTRE + 7):
        if rng.random() < 0.15:
            continue
        height = rng.randint(2, 4) if is_cut else rng.randint(16, 26)
        lean = rng.choice((-1, 0, 0, 1))
        for step in range(height):
            colour = "green_dark" if step < 3 else "green" if step < height - 4 else "green_light"
            canvas[BOTTOM - step][x + lean * step // 9] = colour
        tip_x = x + lean * (height - 1) // 9
        if is_cut:
            canvas[BOTTOM - height][tip_x] = "straw"
        elif rng.random() < 0.3:
            for head in range(3):
                canvas[BOTTOM - height - head][tip_x] = "soil_mid"
    return canvas


def reeds_row():
    """The atlas row of reeds: three stands, then the same three cut."""
    return [reeds(seed) for seed in REEDS_SEEDS] + [
        reeds(seed, is_cut=True) for seed in REEDS_SEEDS
    ]


def reeds_item():
    """A bundle of reed stalks with brown heads, tied in the middle."""
    picture = items.canvas()
    for x, colour in ((4, "green"), (6, "green_light"), (8, "green"), (10, "green_light"), (12, "green")):
        items.line(picture, x, 3, x + (x - 8) // 3, 14, colour)
    for x in (6, 10):
        items.rect(picture, x, 1, x, 3, "soil_mid")
    items.rect(picture, 3, 8, 13, 9, "soil_mid")
    items.rect(picture, 3, 8, 13, 8, "soil_light")
    return items.outlined(picture)


def icons():
    """The 16x16 icons by item id."""
    return {"reeds": reeds_item()}
