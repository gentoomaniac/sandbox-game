"""The farm yard of task 122 in the classic art, drawn at 16 px per tile (see tools/art/yard.py for
the same things at 32 px): the draw well with its sweep, the trough, the hay rack and the chicken
coop, and the icons of the items that place them.

Each is drawn once, standing (its bottom row on the ground); classic/generate.py puts the world
objects into their cells of the object atlas and the coop into buildings/. Light from the top left.
"""

import item_icons as items
from canvas import TILE, blank, outline, outline_edge, rect
from palette import darkest_of

# The wet oak of posts, poles and planks, lit to dark.
OAK = ("soil_light", "soil_mid", "soil", "soil_dark")


def _pole(picture, start, end):
    """A one pixel thick oak pole from `start` to `end` (x, y), lit above, shaded below."""
    (x0, y0), (x1, y1) = start, end
    for x in range(min(x0, x1), max(x0, x1) + 1):
        y = round(y0 + (x - x0) * (y1 - y0) / (x1 - x0))
        picture[y][x] = OAK[0]
        picture[y + 1][x] = OAK[2]


def draw_well():
    """The draw well, 30x40 px: a ring of fieldstones under an oak coping round dark water, a
    forked post beside it with the balanced sweep on it, a rope and bucket from the long end over
    the well and a stone hung from the short end."""
    picture = blank(30, 40)
    # The post and the sweep.
    rect(picture, 24, 7, 25, 38, OAK[1])
    rect(picture, 24, 7, 24, 38, OAK[0])
    rect(picture, 25, 8, 25, 38, OAK[2])
    rect(picture, 23, 4, 23, 8, OAK[1])
    rect(picture, 26, 4, 26, 8, OAK[2])
    _pole(picture, (29, 3), (10, 14))
    rect(picture, 28, 4, 28, 6, "sand")
    rect(picture, 27, 7, 29, 9, "stone")
    rect(picture, 27, 7, 28, 7, "stone_light")
    rect(picture, 29, 9, 29, 9, "stone_dark")
    # The rope and the oak bucket.
    rect(picture, 11, 15, 11, 21, "sand")
    rect(picture, 9, 22, 13, 26, OAK[1])
    rect(picture, 9, 22, 9, 26, OAK[0])
    rect(picture, 13, 22, 13, 26, OAK[2])
    rect(picture, 9, 24, 13, 24, "stone")
    # The ring of fieldstones in two courses, and the water in its mouth under the oak coping.
    rect(picture, 5, 33, 24, 38, "stone")
    rect(picture, 5, 33, 6, 38, "stone_light")
    rect(picture, 22, 33, 24, 38, "stone_dark")
    for x in range(7, 24, 5):
        rect(picture, x, 33, x, 38, "stone_dark")
    rect(picture, 5, 36, 24, 36, "stone_dark")
    rect(picture, 4, 28, 25, 32, OAK[1])
    rect(picture, 4, 28, 25, 28, OAK[0])
    rect(picture, 4, 32, 25, 32, OAK[2])
    rect(picture, 7, 29, 22, 31, "water_deep")
    rect(picture, 8, 30, 21, 31, "water")
    rect(picture, 9, 30, 10, 30, "water_light")
    for x, y in ((4, 28), (25, 28), (4, 38), (24, 38)):
        picture[y][x] = None
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def _icon(picture):
    """The icon of a picture drawn at a tile's size or bigger: halved if it is wider than an icon,
    cut to what is drawn, rows and columns from its middle left out until it fits, in the middle of
    16x16 px and outlined."""
    picture = [[None if name == "shadow" else name for name in row] for row in picture]
    if len(picture[0]) > TILE:
        size = max(len(picture), len(picture[0]))
        square = blank(size)
        for y, row in enumerate(picture):
            square[size - len(picture) + y][: len(row)] = row
        picture = items.small(square)
    picture = [row for row in picture if any(row)]
    columns = [column for column in zip(*picture) if any(column)]
    while len(columns) > TILE - 2:
        del columns[len(columns) // 2]
    picture = [list(row) for row in zip(*columns)]
    while len(picture) > TILE - 2:
        del picture[len(picture) // 2]
    icon = blank()
    top, left = (TILE - len(picture)) // 2, (TILE - len(picture[0])) // 2
    for y, row in enumerate(picture):
        for x, name in enumerate(row):
            icon[top + y][left + x] = name
    return outline(icon, darkest_of)


def icons():
    """The icons of the yard's items, by item id."""
    return {"draw_well": _icon(draw_well()), "trough": _icon(trough(3)), "hay_rack": _icon(hay_rack(3))}


# What the trough and the hay rack look like at each of their four fills: empty, low, half, full.
STOCK_LOOKS = 4


def trough(level):
    """The trough, 32x13 px: a box of oak planks on two feet, seen from the front and a little above,
    with water inside by `level` (0 empty, 1 low, 2 half, 3 full)."""
    picture = blank(32, 13)
    for x0 in (3, 26):
        rect(picture, x0, 11, x0 + 2, 12, OAK[2])
    rect(picture, 0, 5, 31, 10, OAK[1])
    rect(picture, 0, 5, 31, 5, "sand_light")
    rect(picture, 0, 8, 31, 8, OAK[2])
    rect(picture, 0, 10, 31, 10, OAK[2])
    rect(picture, 3, 5, 3, 10, "stone")
    rect(picture, 28, 5, 28, 10, "stone")
    rect(picture, 0, 0, 31, 4, OAK[2])
    rect(picture, 0, 0, 31, 0, OAK[0])
    rect(picture, 1, 1, 30, 1, OAK[3])
    rect(picture, 0, 0, 0, 10, OAK[0])
    rect(picture, 31, 0, 31, 10, OAK[2])
    water = {1: (12, 3, 19, 4), 2: (4, 2, 27, 4), 3: (2, 2, 29, 4)}.get(level)
    if water:
        x0, y0, x1, y1 = water
        rect(picture, x0, y0, x1, y1, "water")
        rect(picture, x0, y0, x1, y0, "water_deep")
        rect(picture, x0 + 2, y0 + 1, x0 + 4, y0 + 1, "water_light")
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def hay_rack(level):
    """The hay rack, 32x22 px: two oak posts, a rail and a manger board, slats between them and the
    hay behind them by `level` (0 empty, 1 low, 2 half, 3 full)."""
    picture = blank(32, 22)
    rect(picture, 4, 3, 27, 14, OAK[3])
    top = {0: 15, 1: 11, 2: 7, 3: 3}[level]
    for y in range(top, 15):
        for x in range(4, 28):
            picture[y][x] = ("straw", "gold", "ochre")[(x * 3 + y * 5) % 3] if (x + y) % 4 else "ochre_dark"
    for x0 in (1, 28):
        rect(picture, x0, 0, x0 + 2, 19, OAK[1])
        rect(picture, x0, 0, x0, 19, OAK[0])
        rect(picture, x0 + 2, 1, x0 + 2, 19, OAK[2])
    rect(picture, 1, 2, 30, 3, OAK[1])
    rect(picture, 1, 2, 30, 2, OAK[0])
    rect(picture, 1, 15, 30, 17, OAK[1])
    rect(picture, 1, 15, 30, 15, "sand_light")
    rect(picture, 1, 17, 30, 17, OAK[2])
    for x in range(5, 28, 3):
        rect(picture, x, 4, x, 14, OAK[0])
        rect(picture, x + 1, 4, x + 1, 14, OAK[2])
    if level:
        for x, y in ((6, 19), (11, 20), (17, 19), (22, 20)):
            rect(picture, x, y, x + 1, y, "straw")
    return outline_edge(picture, "soil_dark", keep_bottom=True)
