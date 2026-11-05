"""Art for what crops give and need besides their sheets (see crops.py): the 16x16 icons of the
seed bags and the produce, and the look of damp and wet soil.
"""

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
    "tomatoes": ("..g.", ".rrr", "rorr", ".rr."),
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


def tomatoes():
    picture = icon()
    picture.ball(8, 9.5, 6, 5.2, "flame", "ember", "ember")
    picture.rect(5, 7, 6, 8, "flame")
    picture.stamp(("g.g.g", ".ggg.", "..g.."), 5, 3)
    return picture


def strawberries():
    picture = icon()
    berry = (".rrrr.", "rorrrr", "rrrryr", "yrrrrr", ".rryr.", "..rr..")
    picture.stamp(berry, 0, 8)
    picture.stamp(berry, 9, 6)
    for x, y in ((0, 6), (9, 4)):
        picture.stamp((".g.gg.", "gggggg", ".gggg."), x, y)
    return picture


def pumpkin():
    picture = icon()
    picture.ball(8, 10, 7, 5, "flame", "flame", "ember")
    picture.ball(8, 10, 4.5, 5, "gold", "flame", "ember")
    for x in (4, 8, 11):
        picture.line(x, 6, x, 14, "ember")
    picture.stamp(("kk", "kd", "k."), 7, 2)
    return picture


PRODUCE = {
    "potato": potato,
    "carrot": carrot,
    "cabbage": cabbage,
    "onion": onion,
    "wheat": wheat,
    "peas": peas,
    "beans": beans,
    "tomatoes": tomatoes,
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
    """The overlay of damp and of wet soil as two tiles: dark dither on the soil, in the middle
    of the tile only, so the rounded edges of a field stay clear. Damp covers a quarter of it
    and wet half, so wet soil reads as clearly darker."""
    tiles = []
    for is_wet in (False, True):
        tile = Surface(TILE, TILE, (0, 0))
        for y in range(2, TILE - 2):
            for x in range(2, TILE - 2):
                if (x + y) % (2 if is_wet else 4) == 0:
                    tile.pixel(x, y, "soil_dark")
        tiles.append(tile.rows)
    return tiles
