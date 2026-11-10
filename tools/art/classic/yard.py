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
    return {"draw_well": _icon(draw_well())}
