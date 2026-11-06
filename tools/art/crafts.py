"""The art of the professions (task 74): what the cook, the woodworker and the mason make.

Item icons are 16x16 pictures, named after the item id of game/state/item_types.gd; generate.py
writes them with the other icons (and their 8x8 ground versions). Cooked food is warm in
colour; the meals in a bowl steam a little.
"""

from canvas import blank, rect
from items import from_rows, outlined, pixel

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


def icons():
    """The icons of the professions' items, by item id."""
    return {
        "roast_turnip": roast_turnip(),
        # Cabbage, carrot and onion in a broth.
        "pottage": bowl("green", "ochre"),
        # Yellow split peas, thick.
        "pea_soup": bowl("dry_light", "straw"),
    }

