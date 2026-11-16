"""The art of the professions (task 74): the stations they work at and what they make.

A station is drawn once, standing (its bottom row on the ground), like the chest: generate.py puts
that picture into its cell of the object atlas (outdoors), writes it as assets/interior/<type>.png
(inside a house, and the ghost while it is placed) and makes its item icon from it, outlined all
round. Item icons are 16x16 pictures, named after the item id of game/state/item_types.gd;
generate.py writes them with the other icons (and their 8x8 ground versions). Cooked food is warm
in colour; the meals in a bowl steam a little.
"""

import chest
import interior
from canvas import TILE, blank, outline_edge, rect
from item_icons import from_rows, outlined, pixel

# The workbench: a thick beech top on four legs with a stretcher, a vice screw at its left end
# and a saw lying on it.
WORKBENCH_ROWS = (
    ".TTTTTTTTTTTTTT.",
    "TTTTTTTTTTTTTTTT",
    "tttttttttttttttt",
    "FFFFFFFFFFFFFFFF",
    "FiiFFFFFFFFFFFFF",
    "fiiffffffffffffs",
    "LLl..........LLl",
    "LLl..........LLl",
    "LLlSSSSSSSSSSLLl",
    "LLl..........LLl",
    "LLl..........LLl",
)
WORKBENCH_KEYS = {
    "T": "sand_light",
    "t": "sand",
    "F": "soil_light",
    "f": "soil_mid",
    "s": "soil",
    "i": "stone_light",
    "L": "soil_light",
    "l": "soil_mid",
    "S": "soil_mid",
}

# A wooden bowl seen from the side and a little above; letters "a" and "b" are its contents.
BOWL_ROWS = (
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "....aabababa....",
    "..aababbabbaba..",
    ".lmmmmmmmmmmmmd.",
    ".lmmmmmmmmmmmdd.",
    "..lmmmmmmmmmdd..",
    "...lmmmmmmmdd...",
    "....llmmmmdd....",
    "......dddd......",
    "................",
    "................",
)
BOWL_KEYS = {"l": "soil_light", "m": "soil_mid", "d": "soil"}
# The wisps of steam over a hot meal.
STEAM = ((6, 2), (7, 3), (6, 4), (9, 1), (10, 2), (9, 3))


def bowl(food, bits):
    """A steaming wooden bowl of a meal: `food` is the colour of the broth, `bits` that of what
    floats in it."""
    picture = outlined(from_rows(BOWL_ROWS, BOWL_KEYS | {"a": food, "b": bits}))
    for x, y in STEAM:
        pixel(picture, x, y, "stone_light")
    return picture


def roast_turnip():
    """A turnip roasted golden in the embers, its leaves cut off, with dark marks of the fire."""
    picture = blank()
    rect(picture, 7, 3, 8, 4, "umber")
    rect(picture, 4, 5, 11, 6, "rust")
    rect(picture, 3, 6, 12, 8, "ochre")
    rect(picture, 4, 9, 11, 10, "ochre")
    rect(picture, 5, 11, 10, 11, "ochre")
    rect(picture, 7, 12, 8, 13, "ochre_dark")
    rect(picture, 9, 8, 12, 9, "ochre_dark")
    rect(picture, 10, 10, 11, 10, "ochre_dark")
    for x, y in ((5, 7), (9, 6), (7, 9), (11, 8)):
        pixel(picture, x, y, "umber")
    return outlined(picture)


def workbench(is_standing=True):
    """The workbench, 16x11 px with its outline; standing, its bottom row has none."""
    picture = from_rows(WORKBENCH_ROWS, WORKBENCH_KEYS)
    # The saw on the top: its blade with teeth along the front and, at the right, its handle.
    rect(picture, 4, 1, 10, 1, "stone_light")
    for x in range(4, 11, 2):
        pixel(picture, x, 2, "stone")
    rect(picture, 11, 1, 12, 2, "soil")
    return outline_edge(picture, "soil_dark", keep_bottom=is_standing)


# The carved chest is the chest painted as the Frisian chests were: blue-green with a pale lid,
# flowers on its front.
PAINTED_CHEST = {"soil_light": "water_light", "soil_mid": "paint_teal", "soil": "water", "sand": "foam"}
CHEST_FLOWERS = ((4, 8), (11, 8), (4, 3), (11, 3))


def carved_chest(is_standing=True):
    """The chest, painted and with a flower on each side of its lock."""
    picture = [[PAINTED_CHEST.get(name, name) for name in row] for row in chest.chest(is_standing)]
    for x, y in CHEST_FLOWERS:
        pixel(picture, x, y, "petal")
        pixel(picture, x, y + 1, "cream")
    return picture


def planks():
    """Three sawn boards, stacked, their ends showing on the right."""
    picture = blank()
    for top in (3, 7, 11):
        rect(picture, 1, top, 13, top + 2, "sand")
        rect(picture, 1, top, 13, top, "sand_light")
        rect(picture, 14, top, 14, top + 2, "soil_light")
        pixel(picture, 4 + top % 5, top + 1, "straw")
    return outlined(picture, "soil_dark")


KILN_WIDTH = 16
KILN_HEIGHT = 18


def kiln(is_standing=True):
    """A small beehive kiln of clay on a fieldstone footing, 16x18 px: the smoke hole at its top,
    courses of clay round its dome, and the arched mouth where the fire is laid."""
    picture = blank(KILN_WIDTH, KILN_HEIGHT)
    for y in range(2, KILN_HEIGHT):
        half = min(7, 3 + (y - 2) // 2)
        left, right = 8 - half - 1, 8 + half
        rect(picture, left, y, right, y, "mud")
        picture[y][left] = "sand"
        rect(picture, right - 1, y, right, y, "mud_dark")
        if y % 3 == 0:
            for x in range(left + 1 + y % 2, right - 1, 3):
                picture[y][x] = "mud_dark"
    # The rim and the smoke hole.
    rect(picture, 5, 0, 10, 1, "sand")
    rect(picture, 6, 1, 9, 2, "soil_dark")
    # The mouth, an arch over the ash.
    rect(picture, 6, 11, 9, 15, "soil_dark")
    rect(picture, 7, 10, 8, 10, "soil_dark")
    rect(picture, 6, 15, 9, 15, "stone_dark")
    # The footing of field stones.
    rect(picture, 0, 16, 15, 17, "stone")
    for x in (2, 6, 11, 14):
        picture[16][x] = "stone_light"
    for x in (4, 9, 13):
        picture[17][x] = "stone_dark"
    return outline_edge(picture, "soil_dark", keep_bottom=is_standing)


def oven(is_standing=True):
    """A bake oven of brick, 16x15 px: a dome with an arched mouth on a fieldstone base."""
    picture = blank(16, 15)
    for y in range(9):
        half = (4, 5, 6, 7, 7, 7, 7, 7, 7)[y]
        left, right = 8 - half - 1, 8 + half
        rect(picture, left, y, right, y, "rust")
        picture[y][left] = "red_light"
        rect(picture, right - 1, y, right, y, "rust_dark")
        # Courses of brick, the joints staggered.
        if y % 2 == 1:
            rect(picture, left + 1, y, right - 2, y, "rust_dark")
        elif y > 0:
            for x in range(left + 2 + y % 4, right - 1, 4):
                picture[y][x] = "rust_dark"
    # The mouth, with its iron door leaning aside.
    rect(picture, 6, 4, 9, 8, "soil_dark")
    rect(picture, 7, 3, 8, 3, "soil_dark")
    rect(picture, 11, 6, 12, 8, "stone_dark")
    # The base of field stones, with a hearth ledge in front of the mouth.
    rect(picture, 0, 9, 15, 14, "stone")
    rect(picture, 0, 9, 15, 9, "stone_light")
    for x, y in ((3, 11), (9, 12), (13, 11), (6, 13)):
        picture[y][x] = "stone_dark"
    return outline_edge(picture, "soil_dark", keep_bottom=is_standing)


def flour():
    """A small linen sack of flour, open at the top, with flour spilt in front."""
    picture = blank()
    rect(picture, 4, 5, 11, 13, "lime")
    rect(picture, 3, 8, 12, 12, "lime")
    rect(picture, 10, 6, 12, 13, "stone_light")
    rect(picture, 5, 3, 10, 4, "cream")
    rect(picture, 6, 3, 9, 3, "snow_light")
    rect(picture, 4, 14, 7, 14, "cream")
    pixel(picture, 9, 14, "cream")
    return outlined(picture, "stone_dark")


def bread():
    """A round rye loaf with cuts across its crust."""
    picture = blank()
    rect(picture, 4, 5, 11, 12, "ochre_dark")
    rect(picture, 2, 7, 13, 11, "ochre_dark")
    rect(picture, 3, 6, 12, 7, "ochre")
    rect(picture, 3, 11, 12, 12, "umber")
    for x in (5, 8, 11):
        rect(picture, x - 1, 7, x, 8, "sand_light")
    return outlined(picture, "soil_dark")


def berry_tart():
    """A round tart in its pastry, full of berries."""
    picture = blank()
    rect(picture, 2, 7, 13, 11, "ochre")
    rect(picture, 3, 6, 12, 6, "ochre")
    rect(picture, 3, 11, 12, 12, "ochre_dark")
    rect(picture, 4, 7, 11, 9, "heather_dark")
    for x, y in ((5, 7), (8, 8), (10, 7), (6, 9)):
        pixel(picture, x, y, "petal")
    return outlined(picture, "soil_dark")


def cupboard(is_standing=True):
    """A joined oak cupboard, 16x24 px: a cornice, two panelled doors with brass knobs over a
    drawer, on short feet. It stands in a house."""
    picture = blank(16, 24)
    rect(picture, 0, 0, 15, 2, "soil_light")
    rect(picture, 0, 2, 15, 2, "soil")
    rect(picture, 1, 3, 14, 21, "soil_mid")
    rect(picture, 1, 3, 1, 21, "soil_light")
    rect(picture, 14, 3, 14, 21, "soil")
    # The doors, each with two sunk panels, and the seam between them.
    for left in (2, 8):
        for top, bottom in ((4, 9), (11, 16)):
            rect(picture, left + 1, top, left + 4, bottom, "soil")
            rect(picture, left + 1, top, left + 4, top, "soil_dark")
    rect(picture, 7, 3, 8, 17, "soil")
    pixel(picture, 6, 10, "gold")
    pixel(picture, 9, 10, "gold")
    # The drawer under the doors, and the feet.
    rect(picture, 2, 18, 13, 20, "soil")
    rect(picture, 2, 18, 13, 18, "soil_light")
    pixel(picture, 7, 19, "gold")
    pixel(picture, 8, 19, "gold")
    rect(picture, 1, 22, 3, 23, "soil")
    rect(picture, 12, 22, 14, 23, "soil")
    return outline_edge(picture, "soil_dark", keep_bottom=is_standing)


def feast_cake():
    """A tall round cake, iced, with strawberries and berries on top."""
    picture = blank()
    rect(picture, 3, 6, 12, 13, "ochre")
    rect(picture, 3, 6, 12, 7, "cream")
    rect(picture, 3, 9, 12, 9, "red_light")
    rect(picture, 11, 8, 12, 13, "ochre_dark")
    rect(picture, 3, 13, 12, 13, "ochre_dark")
    for x, y, colour in ((4, 5, "red_light"), (7, 4, "red_light"), (10, 5, "red_light"), (6, 5, "heather_dark"), (9, 5, "heather_dark")):
        pixel(picture, x, y, colour)
    pixel(picture, 7, 3, "green")
    return outlined(picture, "soil_dark")


def bricks(face, top, shade):
    """Two bricks, one on the other and set back: `face` is their front, `top` the lit top and
    `shade` the dark end."""
    picture = blank()
    for left, bottom in ((4, 8), (2, 13)):
        rect(picture, left, bottom - 4, left + 10, bottom, face)
        rect(picture, left, bottom - 4, left + 10, bottom - 4, top)
        rect(picture, left + 10, bottom - 3, left + 11, bottom, shade)
    return outlined(picture, "soil_dark")


def icon_of(picture):
    """An item icon: the picture, outlined all round, in the middle of 16x16 px."""
    icon = blank()
    top = (TILE - len(picture)) // 2
    left = (TILE - len(picture[0])) // 2
    for y, row in enumerate(picture):
        for x, name in enumerate(row):
            icon[top + y][left + x] = name
    return icon


def _shrunk(picture):
    """The icon of a picture taller than one: rows from its middle left out until it fits."""
    while len(picture) > TILE:
        middle = len(picture) // 2
        picture = picture[:middle] + picture[middle + 1 :]
    return icon_of(picture)


def stations():
    """The pictures of the stations, standing, by world object type."""
    return {"workbench": workbench(), "carved_chest": carved_chest(), "kiln": kiln(), "oven": oven(), "cupboard": cupboard()}


def icons():
    """The icons of the professions' items, by item id."""
    return {
        "workbench": icon_of(workbench(is_standing=False)),
        "kiln": _shrunk(kiln(is_standing=False)),
        "oven": icon_of(oven(is_standing=False)),
        "planks": planks(),
        "cupboard": _shrunk(cupboard(is_standing=False)),
        # Dried clay, grey-brown, and fired, red.
        "raw_brick": bricks("mud", "sand", "mud_dark"),
        "brick": bricks("rust", "red_light", "rust_dark"),
        "stool": icon_of(interior.stool()),
        "carved_chest": icon_of(carved_chest(is_standing=False)),
        "roast_turnip": roast_turnip(),
        # Cabbage, carrot and onion in a broth.
        "pottage": bowl("green", "ochre"),
        # Yellow split peas, thick.
        "pea_soup": bowl("dry_light", "straw"),
        "flour": flour(),
        "bread": bread(),
        "berry_tart": berry_tart(),
        "feast_cake": feast_cake(),
    }

