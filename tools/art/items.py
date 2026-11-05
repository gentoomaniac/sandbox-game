"""Art for items and the slots that hold them: 16x16 icons and 20x20 slot frames.

Pictures are lists of rows of palette colour names (None = clear), like every other tile in
generate.py, which writes them: icons to assets/items/<item id>.png (ids from
game/state/item_types.gd), slots to assets/ui/slot.png and slot_selected.png.
"""

ICON = 16
SLOT = 20

# The darkest colour of each ramp, which outlines it (see the style rules in SPEC.md).
OUTLINE_OF = {
    "soil": "soil_dark",
    "soil_mid": "soil_dark",
    "soil_light": "soil_dark",
    "stone": "stone_dark",
    "stone_light": "stone_dark",
    "sand": "mud_dark",
    "sand_light": "mud_dark",
    "straw": "mud_dark",
    "mud": "mud_dark",
}
# Pickups and anything else are outlined in ink.
DEFAULT_OUTLINE = "ink"


def canvas(size=ICON):
    return [[None] * size for _ in range(size)]


def pixel(picture, x, y, colour):
    picture[y][x] = colour


def rect(picture, x0, y0, x1, y1, colour):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            picture[y][x] = colour


def line(picture, x0, y0, x1, y1, colour):
    """A one pixel wide line with a pixel per step along the longer side."""
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for step in range(steps + 1):
        x = x0 + round((x1 - x0) * step / steps)
        y = y0 + round((y1 - y0) * step / steps)
        picture[y][x] = colour


def outlined(picture):
    """The picture with a one pixel outline outside it, in the darkest colour of the ramp of
    the pixel it surrounds. Drawn pixels stay."""
    size = len(picture)
    result = [row[:] for row in picture]
    for y in range(size):
        for x in range(size):
            if picture[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < size and 0 <= ny < size and picture[ny][nx] is not None:
                    result[y][x] = OUTLINE_OF.get(picture[ny][nx], DEFAULT_OUTLINE)
                    break
    return result


def shaft(picture, start, end):
    """A wooden shaft two pixels wide: light on the upper left, dark beside it."""
    (x0, y0), (x1, y1) = start, end
    line(picture, x0 + 1, y0, x1 + 1, y1, "soil")
    line(picture, x0, y0, x1, y1, "soil_mid")


def hoe():
    picture = canvas()
    shaft(picture, (2, 13), (10, 5))
    rect(picture, 8, 3, 13, 4, "stone")
    rect(picture, 8, 3, 13, 3, "stone_light")
    rect(picture, 7, 5, 9, 6, "stone")
    pixel(picture, 7, 5, "stone_light")
    return outlined(picture)


def axe():
    picture = canvas()
    shaft(picture, (2, 13), (10, 5))
    for y, left in enumerate((8, 7, 5, 5, 6, 7), 2):
        rect(picture, left, y, 11, y, "stone")
        pixel(picture, left, y, "stone_light")
    rect(picture, 5, 4, 5, 5, "stone_light")
    rect(picture, 10, 2, 11, 7, "stone")
    return outlined(picture)


def pickaxe():
    picture = canvas()
    shaft(picture, (3, 14), (9, 5))
    for x, y in ((1, 5), (2, 4), (3, 3), (5, 2), (7, 2), (9, 3), (11, 4), (12, 5), (13, 7)):
        pixel(picture, x, y, "stone")
    for x, y in ((2, 3), (4, 2), (6, 1), (8, 1)):
        pixel(picture, x, y, "stone_light")
    for x, y in ((3, 4), (4, 3), (5, 3), (6, 2), (8, 2), (10, 3), (11, 5), (12, 6)):
        pixel(picture, x, y, "stone")
    return outlined(picture)


def watering_can():
    picture = canvas()
    rect(picture, 4, 7, 10, 13, "stone")
    rect(picture, 4, 7, 10, 7, "stone_light")
    rect(picture, 4, 7, 4, 13, "stone_light")
    rect(picture, 4, 13, 10, 13, "stone_dark")
    line(picture, 11, 11, 14, 6, "stone")
    rect(picture, 13, 4, 14, 5, "stone_light")
    pixel(picture, 12, 4, "water_light")
    line(picture, 3, 9, 1, 8, "stone")
    line(picture, 1, 8, 2, 5, "stone")
    line(picture, 2, 5, 6, 5, "stone")
    pixel(picture, 7, 6, "stone")
    return outlined(picture)


def seed_sack(emblem, keys):
    """A sack tied at the neck, with a few seeds spilled in front and a small picture of the
    crop on it: `emblem` is 4 rows of 4 letters, in the colours `keys` gives them."""
    picture = canvas()
    rect(picture, 4, 6, 11, 12, "sand_light")
    rect(picture, 3, 8, 12, 11, "sand_light")
    rect(picture, 4, 6, 5, 12, "straw")
    rect(picture, 10, 8, 12, 12, "sand")
    rect(picture, 4, 12, 11, 12, "sand")
    rect(picture, 5, 3, 10, 4, "sand_light")
    rect(picture, 5, 5, 10, 5, "mud")
    rect(picture, 6, 3, 6, 4, "straw")
    for dy, row in enumerate(emblem):
        for dx, letter in enumerate(row):
            if letter != ".":
                pixel(picture, 6 + dx, 7 + dy, keys[letter])
    for x, y in ((3, 13), (6, 14), (9, 13), (12, 14)):
        pixel(picture, x, y, "soil_mid")
    return outlined(picture)


def turnip():
    picture = canvas()
    for x, y in ((6, 1), (8, 0), (10, 1)):
        rect(picture, x, y, x, y + 2, "green_light")
    rect(picture, 6, 4, 10, 4, "green")
    rect(picture, 4, 5, 11, 6, "petal")
    rect(picture, 3, 6, 12, 8, "cream")
    rect(picture, 4, 9, 11, 10, "cream")
    rect(picture, 5, 11, 10, 11, "cream")
    rect(picture, 7, 12, 8, 13, "sand_light")
    pixel(picture, 8, 14, "sand_light")
    rect(picture, 9, 8, 12, 9, "sand_light")
    rect(picture, 10, 10, 11, 10, "sand_light")
    return outlined(picture)


def wood():
    """Two logs, one above the other, their cut faces on the right."""
    picture = canvas()
    for top in (3, 8):
        rect(picture, 2, top, 11, top + 4, "soil_mid")
        rect(picture, 2, top + 3, 11, top + 4, "soil")
        rect(picture, 2, top, 11, top, "soil_light")
        pixel(picture, 4, top + 2, "soil_dark")
        pixel(picture, 5, top + 2, "soil_dark")
        pixel(picture, 8, top + 3, "soil_dark")
        rect(picture, 11, top, 13, top + 4, "sand_light")
        rect(picture, 12, top + 1, 12, top + 3, "sand")
        pixel(picture, 13, top + 4, "sand")
    return outlined(picture)


def stone():
    picture = canvas()
    rect(picture, 4, 5, 11, 12, "stone")
    rect(picture, 3, 7, 12, 11, "stone")
    rect(picture, 5, 4, 9, 4, "stone_light")
    rect(picture, 4, 5, 8, 6, "stone_light")
    rect(picture, 3, 7, 4, 9, "stone_light")
    rect(picture, 4, 12, 11, 12, "stone_dark")
    rect(picture, 11, 8, 12, 11, "stone_dark")
    line(picture, 8, 6, 9, 9, "stone_dark")
    return outlined(picture)


def fibre():
    """A bundle of long plant fibres, tied in the middle."""
    picture = canvas()
    for x, colour in ((3, "green_light"), (5, "straw"), (7, "green_light"), (9, "straw"), (11, "green_light")):
        line(picture, x, 1, x + (x - 7) // 2, 14, colour)
    rect(picture, 3, 7, 12, 8, "mud")
    rect(picture, 3, 7, 12, 7, "sand")
    return outlined(picture)


def berries():
    """A sprig of three berries under a leaf."""
    picture = canvas()
    rect(picture, 6, 2, 11, 3, "green")
    rect(picture, 8, 1, 10, 1, "green_light")
    rect(picture, 5, 3, 6, 3, "green_light")
    line(picture, 8, 4, 8, 6, "green_dark")
    for x, y, colour in ((3, 7, "ember"), (8, 8, "arcane"), (5, 11, "ember")):
        rect(picture, x, y, x + 3, y + 2, colour)
        rect(picture, x + 1, y - 1, x + 2, y + 3, colour)
        pixel(picture, x + 1, y, "cream")
    return outlined(picture)


def sapling():
    """A seedling with a root ball, two leaves on a thin stem."""
    picture = canvas()
    rect(picture, 5, 10, 10, 13, "soil_mid")
    rect(picture, 4, 11, 11, 12, "soil_mid")
    rect(picture, 5, 12, 10, 13, "soil")
    rect(picture, 5, 10, 7, 10, "soil_light")
    line(picture, 8, 9, 8, 4, "soil_light")
    for x, y in ((9, 3), (10, 3), (11, 4), (10, 5), (9, 4)):
        pixel(picture, x, y, "green_light")
    for x, y in ((6, 5), (5, 6), (6, 6), (7, 6), (6, 7)):
        pixel(picture, x, y, "green")
    pixel(picture, 8, 2, "green_bright")
    pixel(picture, 8, 3, "green_light")
    return outlined(picture)


def from_rows(rows, keys):
    """A picture from rows of characters, each mapped to a colour name by `keys` ("." is clear)."""
    return [[keys.get(character) for character in row] for row in rows]


def tunic_shaped(base, light, shade, belt):
    """A T-shaped tunic with short sleeves, outlined; with a belt if `belt`."""
    rows = [
        "................",
        "................",
        "..lbbbccccbbbs..",
        ".lbbbbbccbbbbbs.",
        ".lbbbbbbbbbbbbs.",
        ".bbbsbbbbbbsbbs.",
        ".sssslbbbbbbsss.",
        "....lbbbbbbs....",
        "....lbbbbbbs....",
        "....dddgdddd...." if belt else "....lbbbbbbs....",
        "....lbbbbbbs....",
        "....lbbbbbbs....",
        "....sbbbbbbs....",
        "....ssssssss....",
        "................",
        "................",
    ]
    keys = {"b": base, "l": light, "s": shade, "c": "cream", "d": "soil_dark", "g": "gold"}
    return outlined(from_rows(rows, keys))


def tunic():
    return tunic_shaped("water", "water_light", "water_deep", belt=True)


def shirt():
    return tunic_shaped("ember", "flame", "soil", belt=False)


def trousers():
    rows = [
        "................",
        "................",
        "....llllllll....",
        "....bbbbbbbb....",
        "...lbbbslbbbs...",
        "...lbbbslbbbs...",
        "...lbbbslbbbs...",
        "...lbbbslbbbs...",
        "...lbbs..lbbs...",
        "...lbbs..lbbs...",
        "...lbbs..lbbs...",
        "...lbbs..lbbs...",
        "...ssss..ssss...",
        "................",
        "................",
        "................",
    ]
    keys = {"b": "sand", "l": "sand_light", "s": "mud"}
    return outlined(from_rows(rows, keys))


def straw_hat():
    rows = [
        "................",
        "................",
        "................",
        ".....lllbbb.....",
        "....lllbbbbs....",
        "....lbbbbbbs....",
        "....dddddddd....",
        "....bbbbbbbs....",
        ".llllllbbbbbbbs.",
        ".lbbbbbbbbbbbbs.",
        "..ssssssssssss..",
        "................",
        "................",
        "................",
        "................",
        "................",
    ]
    keys = {"b": "straw", "l": "sand_light", "s": "reed", "d": "soil"}
    return outlined(from_rows(rows, keys))


ICONS = {
    "hoe": hoe(),
    "axe": axe(),
    "pickaxe": pickaxe(),
    "watering_can": watering_can(),
    "turnip": turnip(),
    "wood": wood(),
    "stone": stone(),
    "fibre": fibre(),
    "berries": berries(),
    "sapling": sapling(),
    "tunic": tunic(),
    "shirt": shirt(),
    "trousers": trousers(),
    "straw_hat": straw_hat(),
}


def slot(frame):
    """A 20x20 slot: a frame round a soil panel lit from the upper left. The selected one has
    a gold frame."""
    picture = canvas(SLOT)
    rect(picture, 0, 0, SLOT - 1, SLOT - 1, frame)
    rect(picture, 1, 1, SLOT - 2, SLOT - 2, "soil_dark")
    rect(picture, 2, 2, SLOT - 3, SLOT - 3, "soil")
    rect(picture, 2, 2, SLOT - 3, 2, "soil_mid")
    rect(picture, 2, 2, 2, SLOT - 3, "soil_mid")
    for x, y in ((0, 0), (SLOT - 1, 0), (0, SLOT - 1), (SLOT - 1, SLOT - 1)):
        pixel(picture, x, y, None)
    return picture


SLOTS = {"slot": slot("ink"), "slot_selected": slot("gold")}


# The faint outline an empty equipment slot shows for what fits it, as 16x16 icons in a colour
# just lighter than the slot. Each is a list of closed paths, drawn as lines between points.
HINT_COLOUR = "soil_mid"
HINT_PATHS = {
    "head": [
        [(5, 8), (5, 5), (7, 3), (10, 3), (12, 5), (12, 8)],
        [(2, 8), (15, 8), (15, 10), (2, 10), (2, 8)],
    ],
    "body": [
        [(5, 3), (7, 3), (8, 5), (9, 3), (11, 3), (14, 6), (12, 8), (11, 7), (11, 13), (4, 13), (4, 7), (3, 8), (1, 6), (5, 3)]
    ],
    "legs": [[(4, 2), (12, 2), (13, 14), (9, 14), (8, 7), (7, 14), (3, 14), (4, 2)]],
    "feet": [[(5, 2), (9, 2), (9, 8), (13, 10), (13, 13), (5, 13), (5, 2)]],
    "back": [
        [(4, 5), (11, 5), (12, 13), (3, 13), (4, 5)],
        [(5, 5), (5, 3), (10, 3), (10, 5)],
        [(6, 9), (9, 9), (9, 12), (6, 12), (6, 9)],
    ],
    "main_hand": [
        [(12, 2), (13, 3), (7, 9), (6, 8), (12, 2)],
        [(4, 8), (8, 12)],
        [(6, 10), (3, 13)],
    ],
    "off_hand": [
        [(3, 3), (12, 3), (12, 8), (8, 14), (3, 8), (3, 3)],
        [(7, 5), (7, 10)],
        [(5, 7), (10, 7)],
    ],
}


def hint(paths):
    picture = canvas()
    for path in paths:
        for start, end in zip(path, path[1:]):
            line(picture, *start, *end, HINT_COLOUR)
    return picture


SLOT_HINTS = {f"equip_{slot}": hint(paths) for slot, paths in HINT_PATHS.items()}
