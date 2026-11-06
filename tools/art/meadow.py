"""Art for the meadow: tall grass and its stubble, the hint of a clay spot, and the hay and clay
items. The scythe and shovel are in tool_icons.py.

Each function returns one picture as rows of palette colour names, like the rest of the art
code, and generate.py only calls `tall_grass_row`, `clay_hint` and `icons`. Tall grass is drawn
in yellower, lighter greens than the grass on the ground (dry, dry_light, green_bright), so it
stands out from it; seasons.py turns it golden in autumn and to dry stalks in winter.
"""

import random

import items
from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank, rect

TALL_GRASS_SEEDS = (211, 212, 213)


def tall_grass(seed, is_mown=False):
    """A clump of tall meadow grass about 16 px wide and 18 high: arching blades in a yellower,
    lighter green than the grass on the ground, some with a seed head, lit from the left. Or the
    stubble that is left once it is mown."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    # A small shadow at the foot of the clump.
    for x in range(OBJECT_CENTRE - 7, OBJECT_CENTRE + 8):
        canvas[OBJECT_BOTTOM][x] = "shadow"
    if is_mown:
        for x in range(OBJECT_CENTRE - 7, OBJECT_CENTRE + 7):
            if rng.random() < 0.25:
                continue
            height = rng.randint(2, 4)
            for step in range(height):
                canvas[OBJECT_BOTTOM - step][x] = "olive" if step == 0 else "dry"
            canvas[OBJECT_BOTTOM - height + 1][x] = "straw" if x % 2 else "dry_light"
        # A few cut blades left lying.
        for _ in range(3):
            x = rng.randint(OBJECT_CENTRE - 7, OBJECT_CENTRE + 3)
            for step in range(rng.randint(3, 5)):
                canvas[OBJECT_BOTTOM - rng.choice((0, 1))][x + step] = "dry_light"
        return canvas
    # The back blades first, darker, then the front ones over them.
    for row, colours in ((0, ("olive", "dry", "dry", "dry_light")), (1, ("olive", "dry_light", "green_bright", "green_bright"))):
        for _ in range(7):
            base = OBJECT_CENTRE + rng.uniform(-6, 6)
            height = rng.randint(11, 15) if row == 0 else rng.randint(9, 14)
            # Blades arch away from the middle of the clump.
            bend = (base - OBJECT_CENTRE) / 6 * rng.uniform(2, 4) + rng.uniform(-1, 1)
            for step in range(height):
                t = step / height
                x = round(base + bend * t * t)
                colour = colours[min(3, int(t * 4))]
                # Light from the left: the left half of the clump is a step lighter.
                if x < OBJECT_CENTRE - 2 and colour == "dry":
                    colour = "dry_light"
                canvas[OBJECT_BOTTOM - step][x] = colour
            tip = round(base + bend)
            if rng.random() < 0.45:
                for head in range(1, 4):
                    canvas[OBJECT_BOTTOM - height - head + 1][tip] = "straw" if head < 3 else "sand_light"
    return canvas


def tall_grass_row():
    """The atlas row of tall grass: three tufts, then the same three mown."""
    return [tall_grass(seed) for seed in TALL_GRASS_SEEDS] + [
        tall_grass(seed, is_mown=True) for seed in TALL_GRASS_SEEDS
    ]


def clay_hint():
    """A 16x16 tile with a few reddish-grey pixels: all that shows of a clay spot."""
    tile = blank()
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


def hay():
    """A golden sheaf: stalks fanning out from a red band, ears spread on top, lit from the
    left."""
    picture = blank()
    band = 10
    # The sheaf's shape in the shade colour, so gaps between the stalks read as depth.
    for y in range(2, 15):
        half = 1.8 + (band - y) * 0.55 if y < band else 1.8 + (y - band) * 0.4
        for x in range(16):
            if abs(x + 0.5 - 8) <= half:
                picture[y][x] = "ochre_dark"
    for stalk in range(-3, 4):
        colour = "gold" if stalk < 0 else "straw" if stalk < 2 else "ochre"
        items.line(picture, round(8 + stalk * 0.5), 14, round(8 + stalk * 1.8), 3, colour)
        # The ear: a seed head leaning out at the top.
        x = round(8 + stalk * 2)
        picture[2][x] = picture[1][x + (stalk > 0) - (stalk < 0)] = "gold" if stalk < 1 else "straw"
    rect(picture, 5, band - 1, 10, band, "rust")
    rect(picture, 5, band - 1, 7, band - 1, "red_light")
    rect(picture, 9, band, 10, band, "rust_dark")
    return items.outlined(picture, "mud_dark")


def clay():
    """A smooth lump of reddish-grey clay with a thumb dent and a wet highlight."""
    rows = [
        "................",
        "................",
        "................",
        "......hhll......",
        "....hhllllll....",
        "...hlllddlllb...",
        "..hlllldbllllb..",
        "..hlllllllllbb..",
        ".hllllllllllbbb.",
        ".llllllllllbbbs.",
        ".lllllllbbbbbss.",
        "..llbbbbbbbbss..",
        "...ssbbbbbsss...",
        ".....ssssss.....",
        "................",
        "................",
    ]
    keys = {"h": "bare_light", "l": "soil_light", "d": "soil_mid", "b": "soil_mid", "s": "rust_dark"}
    return items.outlined(items.from_rows(rows, keys), "soil_dark")


def icons():
    """The 16x16 icons by item id."""
    return {"hay": hay(), "clay": clay()}
