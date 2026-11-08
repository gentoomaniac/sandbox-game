"""Art for the meadow: tall grass and its stubble, the hint of a clay spot, and the hay and clay
items. The scythe and shovel are in tool_icons.py.

Each function returns one picture as rows of palette colour names, like the rest of the art
code, and generate.py only calls `tall_grass_row`, `clay_hint` and `icons`. Tall grass is drawn
at 32 px per tile in yellower, lighter greens than the grass on the ground (dry, dry_light,
green_bright) over a dark foot, so it stands out from it; seasons.py turns it golden in autumn
and to dry stalks in winter.
"""

import random

import items
from canvas import GAME_TILE, blank, rect
from trees import BOTTOM, CENTRE, blade, cell, dense_foot, ground_shadow

TALL_GRASS_SEEDS = (211, 212, 213)
# The blades of a clump from the back to the front: their darkest shade (the lower third, in
# shade), their shaded and their lit side. The olive edges keep the clump apart from straw
# ground in autumn.
BLADE_SHADES = (("green_deep", "olive", "dry"), ("green_dark", "olive", "dry_light"), ("green_dark", "dry", "green_bright"))


def tall_grass(seed, is_mown=False):
    """A clump of tall meadow grass about a tile wide and 36 px high: arching blades two pixels
    wide in a yellower, lighter green than the grass on the ground, the far ones darker, lit from
    the left, with seed heads on stalks above them. Or the stubble that is left once it is mown."""
    rng = random.Random(seed)
    canvas = cell()
    ground_shadow(canvas, 18)
    if is_mown:
        for x in range(CENTRE - 14, CENTRE + 14):
            if rng.random() < 0.3:
                continue
            height = rng.randint(3, 7)
            for step in range(height):
                canvas[BOTTOM - 1 - step][x] = "olive" if step < 2 else "dry"
            canvas[BOTTOM - height][x] = "straw" if x % 2 else "dry_light"
        # A few cut blades left lying.
        for _ in range(5):
            x, y = rng.randint(CENTRE - 14, CENTRE + 6), BOTTOM - rng.choice((0, 1, 2))
            for step in range(rng.randint(6, 10)):
                canvas[y][x + step] = "dry_light" if step % 3 else "straw"
                canvas[y + (y < BOTTOM)][x + step] = "olive"
        return canvas
    # The dense foot of the clump, in the two darkest greens, rimmed with the darkest one so
    # the clump stands out from the ground. The blades above it are loose and have no rim.
    dense_foot(canvas, [(BOTTOM - 2 - step, 13 - step, "green_deep" if step < 3 else "green_dark") for step in range(8)])
    # The blades from the back to the front, so the front ones, lighter, overlap the back ones.
    blades = sorted((rng.random(), CENTRE + rng.uniform(-12, 11), rng.uniform(18, 32), rng.uniform(-14, 14)) for _ in range(26))
    for depth, x, height, lean in blades:
        blade(canvas, x, BOTTOM - 2, height, lean, BLADE_SHADES[min(2, int(depth * 3))], droop=abs(lean) * 0.5)
    # Seed heads on thin stalks over the blades: a column of spikelets, lit on the left.
    for _ in range(rng.randint(3, 5)):
        x0, lean, height = CENTRE + rng.uniform(-8, 8), rng.uniform(-8, 8), rng.uniform(32, 40)
        steps = round(height * 1.5)
        for step in range(steps):
            t = step / steps
            canvas[round(BOTTOM - 3 - height * t)][round(x0 + lean * t * t)] = "olive" if t < 0.3 else "dry_light"
        hx, hy = round(x0 + lean), round(BOTTOM - 3 - height)
        for k in range(7):
            canvas[hy + k][hx - 1 + (k % 2) * 2] = "straw" if k % 2 == 0 else "reed"
            canvas[hy + k][hx] = "sand_light" if k < 3 else "straw"
        canvas[hy - 1][hx] = "straw"
    return canvas


def tall_grass_row():
    """The atlas row of tall grass: three tufts, then the same three mown."""
    return [tall_grass(seed) for seed in TALL_GRASS_SEEDS] + [
        tall_grass(seed, is_mown=True) for seed in TALL_GRASS_SEEDS
    ]


def clay_hint():
    """A tile with a few reddish-grey crumbs in the grass: all that shows of a clay spot."""
    tile = blank(GAME_TILE)
    for x, y, colour in (
        (12, 16, "soil_light"),
        (13, 16, "bare_light"),
        (13, 17, "soil_mid"),
        (16, 18, "soil_light"),
        (17, 19, "soil_mid"),
        (12, 20, "bare_light"),
        (14, 20, "soil_light"),
        (15, 21, "soil_mid"),
        (20, 14, "bare_light"),
        (21, 15, "soil_mid"),
        (18, 22, "soil_light"),
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
