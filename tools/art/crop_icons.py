"""Art for what crops give and need besides their sheets (see crops.py): the 16x16 icons of the
seed bags and the produce, and the look of damp and wet soil.
"""

import random

import items
from crops import KEYS, TILE, Surface

# The picture on a seed bag's label: 4x4 letters of crops.KEYS.
EMBLEMS = {
    "turnip": (".gg.", "pppp", ".cc.", "..c."),
    "potato": (".ee.", "eeew", "eeww", ".ww."),
    "carrot": (".lg.", "oooo", ".or.", "..r."),
    "cabbage": (".ll.", "lgdl", "ldgl", ".dd."),
    "onion": (".yy.", "yyyt", "yttt", ".tt."),
    "wheat": (".y.y", "yyyy", ".t.t", ".t.t"),
    "peas": (".gg.", "gcgg", "ggcg", ".gg."),
    "beans": ("g..g", "dg.d", "dg.d", ".dd."),
    "flax": (".f.f", "fifi", ".l.l", ".l.l"),
    "strawberries": (".ll.", "rrrr", "roro", ".rr."),
    "pumpkin": (".k..", "oooo", "orro", ".oo."),
}


def icon():
    return Surface(items.ICON, items.ICON, (0, 0))


def potato():
    picture = icon()
    picture.ball(8, 9.5, 6, 4.6, "sand_light", "sand", "mud")
    for x, y in ((6, 8), (9, 11), (5, 11), (10, 8)):
        picture.pixel(x, y, "mud")
    return picture


def carrot():
    picture = icon()
    picture.stamp(
        (
            ".........l.g....",
            "........lgl.gl..",
            ".........dgdl...",
            "........ooooo...",
            ".......oyoooor..",
            "......ooyooorr..",
            "......ooooorr...",
            ".....ooooorr....",
            ".....oooorr.....",
            "....ooooorr.....",
            "....ooorr.......",
            "...ooorr........",
            "...oorr.........",
            "..orr...........",
            "..rr............",
        ),
        0,
        0,
    )
    return picture


def cabbage():
    picture = icon()
    picture.ball(8, 9, 6.5, 5.8, "green_bright", "green_light", "green")
    picture.line(5, 6, 8, 10, "green")
    picture.line(11, 6, 8, 10, "green")
    picture.line(8, 4, 8, 9, "green")
    picture.stamp(("kd..dk", ".kddk."), 5, 13)
    return picture


def onion():
    picture = icon()
    picture.ball(8, 10, 5.5, 4.8, "gold", "straw", "reed")
    picture.stamp(("..y..", ".yty.", ".ttt."), 6, 4)
    picture.stamp(("l.g", "lgl", ".d."), 6, 0)
    picture.line(7, 15, 9, 15, "sand_light")
    return picture


def wheat():
    picture = icon()
    for top in (3, 6, 9, 12):
        picture.line(8, 15, top, 6, "straw")
        picture.stamp((".y.", "yty", "tyt", "yty", ".t."), top - 1, 0)
    picture.rect(6, 11, 10, 12, "mud")
    picture.rect(6, 11, 10, 11, "sand")
    return picture


def peas():
    picture = icon()
    picture.line(2, 12, 13, 4, "green_dark")
    picture.line(2, 11, 13, 3, "green")
    picture.line(3, 11, 12, 5, "green")
    picture.line(3, 12, 12, 6, "green")
    for x, y in ((4, 10), (6, 8), (8, 7), (10, 5)):
        picture.ball(x + 0.5, y + 0.5, 1.8, 1.8, "green_bright", "green_light", "green_light")
    picture.line(12, 3, 14, 1, "green_dark")
    return picture


def beans():
    picture = icon()
    for x, shift in ((4, 0), (8, 1), (12, 2)):
        picture.line(x, 1, x - 1 + shift, 14, "green_light")
        picture.line(x + 1, 1, x + shift, 14, "green")
        picture.pixel(x, 1, "green_dark")
        picture.pixel(x - 1 + shift, 14, "green_dark")
    return picture


def flax():
    """A bundle of flax stalks, tied, with blue flowers and seed bolls at the top."""
    picture = icon()
    for x, tilt in ((4, -2), (6, -1), (8, 0), (10, 1), (12, 2)):
        picture.line(x, 3, 8 + tilt // 2, 14, "straw" if x % 4 else "reed")
    for x, y in ((3, 2), (7, 1), (11, 2)):
        picture.stamp((".f.", "fif", ".f."), x, y)
    for x, y in ((5, 2), (9, 2), (13, 3)):
        picture.stamp(("e", "w"), x, y)
    picture.rect(6, 9, 10, 10, "soil_mid")
    picture.rect(6, 10, 10, 10, "soil")
    return picture


def strawberries():
    """Three small wild strawberries on their stalks, under a leaf."""
    picture = icon()
    picture.stamp((".lg.lg.", "lgdgdgl", ".kdgdk."), 5, 1)
    for x0, y0, x1, y1 in ((7, 4, 4, 8), (8, 4, 8, 10), (9, 4, 12, 7)):
        picture.line(x0, y0, x1, y1, "green_dark")
    for x, y in ((2, 9), (7, 11), (11, 8)):
        picture.stamp(("gdg.", "orrr", "rryr", ".rr."), x, y)
    return picture


def pumpkin():
    """A small green garden squash, ribbed and mottled (the item id stays pumpkin)."""
    picture = icon()
    picture.ball(8, 10, 6, 4.5, "dry_light", "olive", "green_deep")
    for x in (5, 8, 11):
        picture.line(x, 7, x, 13, "green_deep")
    for x, y in ((4, 9), (7, 11), (10, 9), (12, 11)):
        picture.pixel(x, y, "straw")
    picture.stamp(("kk", "kd", "k."), 7, 3)
    return picture


PRODUCE = {
    "potato": potato,
    "carrot": carrot,
    "cabbage": cabbage,
    "onion": onion,
    "wheat": wheat,
    "peas": peas,
    "beans": beans,
    "flax": flax,
    "strawberries": strawberries,
    "pumpkin": pumpkin,
}


def icons():
    """{item id: its 16x16 icon}: the seed bags of every crop and their produce, except the
    turnip, which items.py draws."""
    pictures = {f"{crop}_seeds": items.seed_sack(emblem, KEYS) for crop, emblem in EMBLEMS.items()}
    for crop, draw in PRODUCE.items():
        pictures[crop] = items.outlined(draw().rows)
    return pictures


def soil_wet():
    """The overlay of damp and of wet soil as two tiles: dashes of darker soil, in the middle of
    the tile only, so the rounded edges of a field stay clear. Wet has more of them and a few of
    the darkest, and they include all of the damp ones. The light bands of the soil texture
    turn dark where they lie."""
    rng = random.Random("soil-wet")
    spots = [(x, y) for y in range(2, TILE - 2) for x in range(2, TILE - 3)]
    rng.shuffle(spots)
    tiles = []
    for count, darkest in ((14, 0), (36, 8)):
        tile = Surface(TILE, TILE, (0, 0))
        for index, (x, y) in enumerate(spots[:count]):
            tile.stamp(("bb" if index >= darkest else "ss",), x, y)
        tiles.append(tile.rows)
    return tiles
