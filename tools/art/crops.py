"""Art for the crops: a picture sheet per crop, the icons of their seed bags and produce, and the
look of wet soil.

A crop's sheet (assets/crops/<crop>.png, named by `sheet` in data/crops.cfg) has its four growth
stages and then the dead one side by side. Every cell is a tile wide (16 px) and as tall as the
sheet: a tall crop (wheat, peas, beans, tomatoes) has a taller sheet, with its bottom on the
bottom of its tile. A crop looks the same in every season, so the seasons never touch these.

Pictures are lists of rows of palette colour names (None = clear), as in generate.py. Crops
have no outline: the dark shades inside them separate them from the soil.
"""

import items

TILE = 16
STAGES = 4

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
}

# What the greens of a dead crop turn into.
DEAD_COLOURS = {
    "green_bright": "sand",
    "green_light": "mud",
    "green": "mud_dark",
    "green_dark": "soil_dark",
    "cream": "sand_light",
    "gold": "sand",
    "flame": "mud",
    "ember": "mud_dark",
    "heather": "mud_dark",
    "petal": "sand",
}


class Surface:
    """A picture drawn in the coordinates of a tile: (0, 0) is its top left corner, and y
    grows downwards, so a tall crop has negative y above the tile. `origin` is where that
    corner lies in the picture."""

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

    def recoloured(self, mapping):
        """A copy with colours replaced as the mapping says."""
        copy = Surface(0, 0, (self.origin_x, self.origin_y))
        copy.rows = [[mapping.get(colour, colour) for colour in row] for row in self.rows]
        return copy


def cell(height=TILE):
    """A blank cell of a crop's sheet, drawn on in the coordinates of its tile (see Surface)."""
    return Surface(TILE, height, (0, height - TILE))


# A mound of freshly sown soil: the first stage of every crop, and under the next ones.
MOUND = ("..ehhe..", ".ehhmhm.", "ehhmmmms", "hmmmmmss", ".ssssss.")


def sown(height, *plants):
    """A cell with the seed mound and the plants on it, each as (rows, x, y)."""
    surface = cell(height)
    surface.stamp(MOUND, 4, 11)
    for rows, x, y in plants:
        surface.stamp(rows, x, y)
    return surface


def grown(height, *plants):
    """A cell with only the plants, each as (rows, x, y): they cover the mound."""
    surface = cell(height)
    for rows, x, y in plants:
        surface.stamp(rows, x, y)
    return surface


def turnip():
    sprout = ((".gl....lg.", "..dgkkgd..", "....kk...."), 3, 8)
    rosette = (
        (
            "....g..g....",
            "..gl....lg..",
            ".lgdl..ldgl.",
            "lgddgllgddgl",
            ".kdgdggdgdk.",
            "..kdgddgdk..",
            "...kkddkk...",
        ),
        2,
        4,
    )
    leaves = (
        (
            "..gl..lg..gl..",
            ".lgdl.gdl.ldgl",
            "lgddgllgddgdgl",
            ".kdgdkdgdgdkd.",
            "..kkdkkdkkkk..",
        ),
        1,
        2,
    )
    root = (
        (
            "..aaaaaa..",
            ".appppppa.",
            ".ppppccpp.",
            ".cccccccc.",
            "..cccccce.",
            "...cccce..",
            "....cce...",
            ".....e....",
        ),
        3,
        7,
    )
    height = TILE
    return [sown(height), sown(height, sprout), sown(height, rosette), grown(height, root, leaves)], 2


def potato():
    small = (
        (
            "...g...g....",
            "..lgl.lgl...",
            ".lgdglgdgl..",
            "lgddgdddgdl.",
            ".kdgddgddgdk",
            "..kkdkkddkk.",
            "....kkkk....",
        ),
        2,
        4,
    )
    bush = (
        (
            "....c....c....",
            "...lgl..lgl...",
            ".lgdgllgdgdl..",
            "lgdgllgdgllgdl",
            "gddgdgddgdgddg",
            ".kdddgddddgddk",
            "..kkdkddkddkk.",
            "...kkkkkkkkk..",
        ),
        1,
        5,
    )
    dying = (
        (
            "...u..v..u....",
            "..uvu.vxu.vu..",
            ".uxvuvxvuvxvu.",
            "xvvxvuvvxvuvvx",
            ".xvvxvvvvxvvx.",
            "..xxvxvvxvxx..",
        ),
        1,
        5,
    )
    tubers = ((".eee..eee..eee.", "eeeew.eeew.eeew", ".www..www..www."), 0, 11)
    height = TILE
    return [sown(height), sown(height, small), grown(height, bush), grown(height, tubers, dying)], 2


def carrot():
    sprout = (("l..g..l", ".l.g.l.", "..lgl..", "...k..."), 4, 7)
    fronds = (
        (
            "l..l.g..l..l",
            ".l.lgl.gl.l.",
            "..lgdlgdgl..",
            "..ldgdgdgl..",
            "...kdgddk...",
            "....kddk....",
        ),
        2,
        2,
    )
    roots = (
        (
            "..kooook.kook.",
            ".oyooorooyoor.",
            "..rrrr..rrrr..",
            "....r....r....",
        ),
        1,
        8,
    )
    height = TILE
    return [sown(height), sown(height, sprout), grown(height, fronds), grown(height, fronds, roots)], 2


def cabbage():
    seedling = ((".lg....gl.", "lgdg..gdgl", ".kdgddgdk.", "..kkkkkk.."), 3, 7)
    forming = (
        (
            "....gggggg....",
            "..lgglllgggl..",
            ".lgdgllllgdgl.",
            "lgddgllllgddgl",
            "gddgdgllgdgddg",
            ".kddgdgdgddgk.",
            "..kkkddddkkk..",
            "....kkkkkk....",
        ),
        1,
        3,
    )
    # The ripe head: a pale round ball in a collar of dark outer leaves.
    ripe = grown(TILE, ((".kdd......ddk.", "kdgdd....ddgdk", "kdggddddddggdk", ".kdgggggggdk.."), 1, 8))
    ripe.ball(8, 8, 6.2, 5.2, "green_bright", "green_light", "green")
    ripe.line(5, 5, 8, 9, "green")
    ripe.line(11, 5, 8, 9, "green")
    ripe.line(8, 4, 8, 8, "green")
    ripe.stamp((".kddd..ddk.", "kdgdddddgdk", ".kkkkkkkkk."), 2, 13)
    return [sown(TILE), sown(TILE, seedling), grown(TILE, forming), ripe], 2


def onion():
    blades = (("g.l.g", "gllgg", "dlgdg", ".kdk."), 5, 7)
    clump = (
        (
            "..g.l.g..",
            ".lg.lgl..",
            ".lgglgdl.",
            "lgdglgdgl",
            ".ldgldgd.",
            "..kdkdk..",
            "...kkk...",
        ),
        4,
        4,
    )
    ripe = grown(TILE, (("g..l..g...", "gl.gl.lg.g", ".lgdl.dg.l", "..dkgdkd.."), 3, 3))
    for x in (3, 8.5, 13):
        ripe.ball(x, 12, 2.6, 2.6, "gold", "straw", "reed")
        ripe.pixel(round(x), 9, "cream")
        ripe.pixel(round(x), 10, "straw")
    return [sown(TILE), sown(TILE, blades), sown(TILE, clump), ripe], 2


def wheat():
    height = 32

    def stalks(heights, colour, shade, ears=False):
        surface = cell(height)
        for x, stalk in zip((2, 5, 8, 11, 13), heights):
            surface.line(x, 15, x, 15 - stalk, colour)
            surface.line(x + 1, 15, x + 1, 13 - stalk // 2, shade)
            if ears:
                surface.stamp((".y.", "yty", "tyt", "yty", ".t."), x - 1, 15 - stalk - 5)
                surface.pixel(x, 15 - stalk - 6, "gold")
        return surface

    young = stalks((6, 8, 7, 9, 6), "green_light", "green")
    tall = stalks((14, 17, 15, 18, 13), "green_light", "green")
    ripe = stalks((20, 24, 22, 26, 19), "straw", "reed", ears=True)
    return [sown(height), young, tall, ripe], 2


def trellis(height, top):
    """Two stakes, for climbing crops, from the ground up to y = top."""
    surface = cell(height)
    for x in (4, 11):
        surface.line(x, 15, x, top, "soil_mid")
        surface.line(x + 1, 15, x + 1, top, "soil")
        surface.pixel(x, top, "soil_light")
    return surface


def leaf_spots(surface, spots, leaf=(".lg.", "lgdl", ".dk.")):
    for x, y in spots:
        surface.stamp(leaf, x, y)


def peas():
    height = 32
    # Dark leaves, so that the pale pods and flowers show.
    leaf = (".ld.", "ldkd", ".dk.")
    small = trellis(height, 3)
    leaf_spots(small, ((2, 9), (10, 8), (6, 11)), leaf)
    leafy = ((1, 10), (9, 7), (5, 12), (2, 2), (10, -1), (5, -4), (1, -7), (9, -10))
    flowering = trellis(height, -14)
    leaf_spots(flowering, leafy, leaf)
    for x, y in ((3, 4), (12, 3), (7, -7), (3, -9), (10, 10), (1, 12)):
        flowering.stamp(("c.", ".c"), x, y)
    ripe = trellis(height, -14)
    leaf_spots(ripe, leafy, leaf)
    for x, y in ((0, 5), (9, 11), (12, 2), (6, 0), (1, -4), (11, -8), (6, -9)):
        ripe.stamp(("gc", "gg", "gg", ".g"), x, y)
    return [sown(height), small, flowering, ripe], 2


def beans():
    height = 32

    def pole(top):
        surface = cell(height)
        surface.line(7, 15, 7, top, "soil_mid")
        surface.line(8, 15, 8, top, "soil")
        surface.pixel(7, top, "soil_light")
        return surface

    def vine(surface, top):
        """A vine winding round the pole, with a leaf at every turn."""
        for y in range(15, top, -1):
            surface.pixel(7 + round(2.2 * ((y // 3) % 2 * 2 - 1)), y, "green_dark")
        for index, y in enumerate(range(13, top, -4)):
            x = 1 if index % 2 == 0 else 9
            surface.stamp((".dd..", "dkddk", ".kdk."), x, y)

    young = pole(2)
    vine(young, 6)
    flowering = pole(-12)
    vine(flowering, -8)
    for x, y in ((4, 4), (10, -2), (4, -8)):
        flowering.stamp(("aa", ".a"), x, y)
    ripe = pole(-12)
    vine(ripe, -8)
    for x, y in ((3, 6), (10, 1), (3, -3), (10, -7)):
        ripe.stamp(("lg", "lg", "gd", "gd", ".d"), x, y)
    return [sown(height), young, flowering, ripe], 2


def tomatoes():
    height = 32

    def stake(top):
        surface = cell(height)
        surface.line(7, 15, 7, top, "soil_mid")
        surface.line(8, 15, 8, top, "soil")
        return surface

    small = stake(4)
    leaf_spots(small, ((2, 9), (8, 8), (5, 5)))
    bush = stake(-10)
    leaf_spots(bush, ((1, 8), (9, 9), (5, 3), (2, -2), (9, -3), (5, -7), (5, 11)))
    for x, y in ((4, 6), (11, 2), (3, 0), (9, -6)):
        bush.stamp((".y.", "yyy", ".y."), x, y)
    ripe = stake(-10)
    leaf_spots(ripe, ((1, 8), (9, 9), (5, 3), (2, -2), (9, -3), (5, -7), (5, 11)))
    for x, y in ((3, 7), (10, 6), (2, -1), (10, 0), (6, 3)):
        ripe.ball(x + 1.5, y + 1.5, 2.6, 2.6, "flame", "ember", "ember")
        ripe.pixel(x, y, "gold")
        ripe.pixel(x + 1, y - 1, "green")
    return [sown(height), small, bush, ripe], 2


def strawberries():
    def leaf_cluster(surface, x, y):
        surface.stamp((".lg.lg.", "lgdgdgl", ".kdgdk.", "..kdk.."), x, y)

    low = cell()
    for x, y in ((2, 8), (7, 8), (4, 4)):
        leaf_cluster(low, x, y)
    flowering = cell()
    for x, y in ((1, 8), (8, 8), (4, 5)):
        leaf_cluster(flowering, x, y)
    for x, y in ((3, 6), (11, 5), (8, 3)):
        flowering.stamp((".c.", "cyc", ".c."), x, y)
    for x, y in ((6, 11), (2, 11)):
        flowering.stamp(("ll", "ll"), x, y)
    ripe = cell()
    for x, y in ((1, 7), (8, 7), (4, 3)):
        leaf_cluster(ripe, x, y)
    for x, y in ((2, 11), (6, 12), (10, 10), (4, 6), (9, 5)):
        ripe.stamp(("oro", "rrr", "rry", ".r."), x, y)
        ripe.pixel(x + 1, y - 1, "green")
    return [sown(TILE), low, flowering, ripe], 2


def pumpkin():
    seedling = (("ll.ll", "lgdgl", ".dkd.", "..k.."), 5, 7)
    vine = ("..lgl.....lgl..", ".lgdgl...lgdgl.", "lgdddgl.lgdddgl", ".kdddkkkkdddk..", "..kkd..kk.dkk..")
    sprawling = cell()
    sprawling.stamp(vine, 0, 3)
    sprawling.line(7, 8, 7, 10, "green_dark")
    sprawling.ball(7.5, 11.5, 3.2, 2.8, "green_light", "green", "green_dark")
    sprawling.stamp(("y.y", ".y."), 11, 9)
    ripe = cell()
    ripe.stamp(("..lgl.........", ".lgdgl....lgl.", "lgdddgl..lgdgl", ".kkkdk....kkk."), 0, 0)
    ripe.ball(7.5, 9.5, 7, 5.5, "flame", "flame", "ember")
    ripe.ball(7.5, 9.5, 5.2, 5.5, "gold", "flame", "ember")
    for x in (4, 7, 10):
        ripe.line(x, 5, x, 14, "ember")
    ripe.stamp(("..kk.", ".kdk.", ".kk.."), 6, 1)
    ripe.line(9, 3, 12, 1, "green")
    return [sown(TILE), sown(TILE, seedling), sprawling, ripe], 2


# Each crop's art: a function giving its four growth stages and the index of the one its dead
# look is made from (the grown plant without its produce).
ARTISTS = {
    "turnip": turnip,
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


def sheet_rows(crop):
    """The picture of a crop's sheet as a row of cells: four stages and the dead one."""
    stages, dead_from = ARTISTS[crop]()
    assert len(stages) == STAGES, f"{crop}: {len(stages)} stages"
    return [stage.rows for stage in stages] + [stages[dead_from].recoloured(DEAD_COLOURS).rows]


def sheets():
    """{crop id: its sheet as a row of cells} for every crop."""
    return {crop: sheet_rows(crop) for crop in ARTISTS}
