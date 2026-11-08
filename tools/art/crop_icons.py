"""Art for what crops give and need besides their sheets (see crops.py): the 16x16 icons of the
seed bags and the produce.
"""

import items

# The letters of the pictures drawn as rows of text.
KEYS = {
    "g": "green_bright",
    "l": "green_light",
    "d": "green",
    "k": "green_dark",
    "h": "soil_light",
    "m": "soil_mid",
    "s": "soil_dark",
    "b": "soil",
    "c": "cream",
    "p": "petal",
    "e": "sand_light",
    "w": "sand",
    "a": "heather",
    "o": "flame",
    "r": "ember",
    "y": "gold",
    "t": "straw",
    "x": "reed",
    "n": "mud",
    "u": "dry_light",
    "v": "dry",
    "f": "foam",
    "i": "water_light",
}


class Surface:
    """A picture drawn on in its own coordinates, whose (0, 0) lies at `origin` in the picture,
    with y growing downwards."""

    def __init__(self, width, height, origin):
        self.rows = [[None] * width for _ in range(height)]
        self.origin_x, self.origin_y = origin

    def pixel(self, x, y, colour):
        column, row = x + self.origin_x, y + self.origin_y
        if 0 <= row < len(self.rows) and 0 <= column < len(self.rows[0]):
            self.rows[row][column] = colour

    def rect(self, x0, y0, x1, y1, colour):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.pixel(x, y, colour)

    def line(self, x0, y0, x1, y1, colour):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for step in range(steps + 1):
            self.pixel(x0 + round((x1 - x0) * step / steps), y0 + round((y1 - y0) * step / steps), colour)

    def stamp(self, rows, x, y):
        """Draws rows of KEYS letters with their top left corner at (x, y)."""
        for dy, row in enumerate(rows):
            for dx, letter in enumerate(row):
                if letter != ".":
                    self.pixel(x + dx, y + dy, KEYS[letter])

    def ball(self, cx, cy, rx, ry, light, mid, dark):
        """A shaded ellipse centred on (cx, cy), lit from the upper left."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy > 1:
                    continue
                lit = -(dx * 0.6 + dy * 0.8)
                self.pixel(x, y, light if lit > 0.45 else dark if lit < -0.35 else mid)


# What tells each crop's seed sack apart (see items.seed_sack): the colour of its string, the
# colour of its seeds, and the crop painted on it, 5 rows of 6 letters of KEYS.
SACKS = {
    "turnip": ("heather", "soil_dark", ("..gl..", ".aaaa.", "aacccc", ".cccc.", "..cc..")),
    "potato": ("soil", "soil_light", ("......", ".hhhh.", "hhmhhm", "hmhhmm", ".mmmm.")),
    "carrot": ("flame", "soil_dark", (".l.g..", "..gl..", "oooooo", ".ooor.", "..or..")),
    "cabbage": ("green_light", "soil_dark", (".gllg.", "glllld", "llggld", "dlgldd", ".dddd.")),
    "onion": ("gold", "soil_dark", ("..g...", "..tt..", ".yyyt.", "yyyytt", ".ttt..")),
    "wheat": ("ochre", "straw", ("y.y.y.", "yyyyyy", "y.y.y.", "x.x.x.", "x.x.x.")),
    "peas": ("green_bright", "green_light", ("..dd..", ".dgdg.", "dgdgdd", ".dgdd.", "..dd..")),
    "beans": ("green_dark", "soil_light", ("hh.hh.", "hmmhmm", "mm.mm.", ".hh.hh", ".mmmmm")),
    "flax": ("water_light", "soil_light", (".f..f.", "fif.fi", ".f..f.", ".l..l.", ".l..l.")),
    "strawberries": ("ember", "red_light", ("..g...", ".rrr..", "rryrr.", ".rrr..", "..r...")),
    "pumpkin": ("olive", "sand", ("..k...", ".kddk.", "dkddkd", "dkddkd", ".dkkd.")),
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
    pictures = {f"{crop}_seeds": items.seed_sack(emblem, KEYS, tie, seed) for crop, (tie, seed, emblem) in SACKS.items()}
    for crop, draw in PRODUCE.items():
        pictures[crop] = items.outlined(draw().rows)
    return pictures

