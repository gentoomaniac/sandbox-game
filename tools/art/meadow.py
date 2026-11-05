"""Placeholder art for tall grass, clay spots and their tools and items (task 35).

Everything here is meant to be redrawn by a proper art pass: each function returns one
picture as rows of palette colour names, like the rest of the art code, and generate.py only
calls `tall_grass_row`, `clay_hint` and `icons`. Nothing in here needs a colour that is not
in the palette already.
"""

import random

import items

# The object atlas cell, as in generate.py (the grass stands at the bottom centre).
CELL_WIDTH = 48
CELL_HEIGHT = 80
CENTRE = CELL_WIDTH // 2
BOTTOM = CELL_HEIGHT - 1

TALL_GRASS_SEEDS = (211, 212, 213)


def _cell():
    return [[None] * CELL_WIDTH for _ in range(CELL_HEIGHT)]


def tall_grass(seed, is_mown=False):
    """A tuft of tall blades about 13 px high and 14 wide, some with a straw seed head; or
    the stubble that is left once it is mown."""
    rng = random.Random(seed)
    canvas = _cell()
    if is_mown:
        for x in range(CENTRE - 6, CENTRE + 6):
            if rng.random() < 0.7:
                height = rng.randint(1, 3)
                for y in range(BOTTOM - height + 1, BOTTOM + 1):
                    canvas[y][x] = "green_dark" if y == BOTTOM else "green"
                canvas[BOTTOM - height + 1][x] = "straw" if rng.random() < 0.3 else "green_light"
        return canvas
    for x in range(CENTRE - 7, CENTRE + 7, 2):
        x += rng.randint(0, 1)
        height = rng.randint(8, 13)
        lean = rng.choice((-1, 0, 0, 1))
        for step in range(height):
            blade_x = x + lean * step // 5
            colour = "green_dark" if step < 3 else "green" if step < height - 3 else "green_light"
            canvas[BOTTOM - step][blade_x] = colour
            if step < 2:
                canvas[BOTTOM - step][blade_x + 1] = "green_deep"
        tip_x = x + lean * (height - 1) // 5
        canvas[BOTTOM - height][tip_x] = "straw" if rng.random() < 0.4 else "green_bright"
    return canvas


def tall_grass_row():
    """The atlas row of tall grass: three tufts, then the same three mown."""
    return [tall_grass(seed) for seed in TALL_GRASS_SEEDS] + [
        tall_grass(seed, is_mown=True) for seed in TALL_GRASS_SEEDS
    ]


def clay_hint():
    """A 16x16 tile with a few reddish-grey pixels: all that shows of a clay spot."""
    tile = items.canvas()
    for x, y, colour in (
        (6, 8, "soil_light"),
        (7, 8, "bare_light"),
        (8, 9, "soil_light"),
        (6, 10, "bare_light"),
        (7, 10, "soil_light"),
        (10, 7, "bare_light"),
        (9, 11, "soil_light"),
    ):
        tile[y][x] = colour
    return tile


def scythe():
    picture = items.canvas()
    items.shaft(picture, (3, 14), (9, 4))
    for x, y in ((9, 3), (11, 2), (13, 3), (14, 5), (13, 6)):
        picture[y][x] = "stone"
    for x, y in ((10, 3), (12, 3), (13, 4)):
        picture[y][x] = "stone_light"
    items.rect(picture, 5, 8, 6, 8, "soil_dark")
    return items.outlined(picture)


def shovel():
    picture = items.canvas()
    items.line(picture, 8, 4, 8, 9, "soil_mid")
    items.line(picture, 9, 4, 9, 9, "soil")
    items.rect(picture, 6, 2, 11, 3, "soil_mid")
    items.rect(picture, 6, 10, 11, 12, "stone")
    items.rect(picture, 7, 13, 10, 13, "stone")
    items.rect(picture, 6, 10, 6, 12, "stone_light")
    items.rect(picture, 7, 14, 9, 14, "stone_dark")
    return items.outlined(picture)


def hay():
    """A bundle of dry stalks, tied in the middle."""
    picture = items.canvas()
    for x, colour in ((3, "straw"), (5, "sand_light"), (7, "straw"), (9, "sand_light"), (11, "straw")):
        items.line(picture, x, 2, x + (x - 7) // 2, 14, colour)
    items.rect(picture, 3, 7, 12, 8, "soil_mid")
    items.rect(picture, 3, 7, 12, 7, "soil_light")
    return items.outlined(picture)


def clay():
    """A lump of reddish-grey clay."""
    picture = items.canvas()
    items.rect(picture, 4, 6, 11, 12, "soil_light")
    items.rect(picture, 3, 8, 12, 11, "soil_light")
    items.rect(picture, 5, 5, 9, 5, "bare_light")
    items.rect(picture, 4, 6, 7, 7, "bare_light")
    items.rect(picture, 3, 8, 4, 9, "bare_light")
    items.rect(picture, 4, 12, 11, 12, "rust_dark")
    items.rect(picture, 11, 8, 12, 11, "rust_dark")
    items.line(picture, 7, 8, 8, 10, "rust")
    return items.outlined(picture)


def icons():
    """The 16x16 icons by item id."""
    return {"scythe": scythe(), "shovel": shovel(), "hay": hay(), "clay": clay()}
