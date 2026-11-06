"""The art of the professions (task 74): the stations they work at and what they make.

A station is drawn once, standing (its bottom row on the ground), like the chest: generate.py puts
that picture into its cell of the object atlas (outdoors), writes it as assets/interior/<type>.png
(inside a house, and the ghost while it is placed) and makes its item icon from it, outlined all
round. Item icons are 16x16 pictures, named after the item id of game/state/item_types.gd;
generate.py writes them with the other icons (and their 8x8 ground versions). Cooked food is warm
in colour; the meals in a bowl steam a little.
"""

from canvas import TILE, blank, rect
from interior import outline
from items import from_rows, outlined, pixel

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
    return outline(picture, "soil_dark", keep_bottom=is_standing)


def icon_of(picture):
    """An item icon: the picture, outlined all round, in the middle of 16x16 px."""
    icon = blank()
    top = (TILE - len(picture)) // 2
    left = (TILE - len(picture[0])) // 2
    for y, row in enumerate(picture):
        for x, name in enumerate(row):
            icon[top + y][left + x] = name
    return icon


def stations():
    """The pictures of the stations, standing, by world object type."""
    return {"workbench": workbench()}


def icons():
    """The icons of the professions' items, by item id."""
    return {
        "workbench": icon_of(workbench(is_standing=False)),
        "roast_turnip": roast_turnip(),
        # Cabbage, carrot and onion in a broth.
        "pottage": bowl("green", "ochre"),
        # Yellow split peas, thick.
        "pea_soup": bowl("dry_light", "straw"),
    }

