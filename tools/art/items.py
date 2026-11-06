"""Art for items and the slots that hold them: 16x16 icons and 20x20 slot frames.

Pictures are lists of rows of palette colour names (None = clear), like every other tile in
canvas.py. generate.py writes them: icons to assets/items/<item id>.png (ids from
game/state/item_types.gd), their half size versions for the ground to
assets/ground_items/<item id>.png, slots to assets/ui/slot.png and slot_selected.png.
"""

import chest
from canvas import TILE, blank, copy, rect

ICON = TILE
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


def pixel(picture, x, y, colour):
    picture[y][x] = colour


def line(picture, x0, y0, x1, y1, colour):
    """A one pixel wide line with a pixel per step along the longer side."""
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for step in range(steps + 1):
        x = x0 + round((x1 - x0) * step / steps)
        y = y0 + round((y1 - y0) * step / steps)
        picture[y][x] = colour


def outlined(picture, colour=None):
    """The picture with a one pixel outline outside it, in `colour`, or by default in the
    darkest colour of the ramp of the pixel it surrounds. Drawn pixels stay."""
    size = len(picture)
    result = copy(picture)
    for y in range(size):
        for x in range(size):
            if picture[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < size and 0 <= ny < size and picture[ny][nx] is not None:
                    result[y][x] = colour or OUTLINE_OF.get(picture[ny][nx], DEFAULT_OUTLINE)
                    break
    return result


def seed_sack(emblem, keys, tie, seed):
    """A sack tied at the neck with a string of the crop's colour, its crop painted large on the
    front and a few of its seeds spilled in front, so each crop's sack is told apart at a
    glance. `emblem` is 5 rows of 6 letters, in the colours `keys` gives them; `tie` and `seed`
    are colours."""
    picture = blank()
    rect(picture, 4, 6, 11, 12, "sand_light")
    rect(picture, 3, 8, 12, 11, "sand_light")
    rect(picture, 4, 6, 4, 12, "straw")
    rect(picture, 11, 8, 12, 12, "sand")
    rect(picture, 4, 12, 11, 12, "sand")
    rect(picture, 5, 3, 10, 4, "sand_light")
    rect(picture, 6, 3, 6, 4, "straw")
    rect(picture, 5, 5, 10, 5, tie)
    rect(picture, 11, 5, 11, 6, tie)
    pixel(picture, 12, 7, tie)
    for dy, row in enumerate(emblem):
        for dx, letter in enumerate(row):
            if letter != ".":
                pixel(picture, 5 + dx, 7 + dy, keys[letter])
    for x, y in ((2, 13), (7, 14), (12, 13)):
        rect(picture, x, y, x + 1, y, seed)
    return outlined(picture)


def turnip():
    picture = blank()
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


def logs():
    """Two logs, one above the other, their cut faces on the right."""
    picture = blank()
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
    picture = blank()
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
    picture = blank()
    for x, colour in ((3, "green_light"), (5, "straw"), (7, "green_light"), (9, "straw"), (11, "green_light")):
        line(picture, x, 1, x + (x - 7) // 2, 14, colour)
    rect(picture, 3, 7, 12, 8, "mud")
    rect(picture, 3, 7, 12, 7, "sand")
    return outlined(picture)


def berries():
    """A sprig of three berries under a leaf."""
    picture = blank()
    rect(picture, 6, 2, 11, 3, "green")
    rect(picture, 8, 1, 10, 1, "green_light")
    rect(picture, 5, 3, 6, 3, "green_light")
    line(picture, 8, 4, 8, 6, "green_dark")
    for x, y, colour in ((3, 7, "ember"), (8, 8, "heather"), (5, 11, "ember")):
        rect(picture, x, y, x + 3, y + 2, colour)
        rect(picture, x + 1, y - 1, x + 2, y + 3, colour)
        pixel(picture, x + 1, y, "cream")
    return outlined(picture)


def acorn():
    """An acorn: a glossy nut in a scaly cap with a short stem."""
    rows = [
        "................",
        "................",
        ".......ss.......",
        "........s.......",
        ".....cCCCCc.....",
        "....cCcCcCcd....",
        "...cCcCcCcCdd...",
        "...ddddddddddd..",
        "....hnnnnnnb....",
        "....hnnnnnbb....",
        "....hhnnnnbb....",
        ".....hnnnbbb....",
        ".....nnnnbb.....",
        "......nnbb......",
        ".......bb.......",
        "................",
    ]
    keys = {"s": "soil", "c": "soil_mid", "C": "soil_light", "d": "soil", "h": "ochre", "n": "ochre_dark", "b": "umber"}
    return outlined(from_rows(rows, keys), "soil_dark")


def cone(rows, keys):
    """A cone from rows: `rows` gives each row's left edge and width. Its scales form a diamond
    lattice: dark seams along both diagonals, each scale lit at its top; the right edge is in
    shade."""
    picture = blank()
    for y, (left, width) in enumerate(rows):
        for x in range(left, left + width):
            rising, falling = (x + y) % 4, (x - y) % 4
            if rising == 0 or falling == 0:
                colour = keys["seam"]
            elif rising == 2 and falling == 2:
                colour = keys["tip"]
            else:
                colour = keys["body"]
            if x >= left + width - 1 and colour != keys["seam"]:
                colour = keys["shade"]
            picture[y][x] = colour
    return picture


def spruce_cone():
    """A long, narrow cone hanging from a twig, its scales in a lattice."""
    rows = [(0, 0)] * 3 + [(7, 2), (6, 4), (5, 5), (5, 6), (5, 6), (5, 6), (5, 6), (5, 6), (5, 6), (5, 5), (6, 4), (6, 3), (7, 2)]
    picture = cone(rows, {"tip": "soil_light", "body": "soil_mid", "seam": "soil", "shade": "soil"})
    rect(picture, 7, 1, 7, 2, "soil")
    rect(picture, 8, 1, 9, 1, "green")
    return outlined(picture, "ink")


def pine_cone():
    """A fat, rounded cone with open, pale-tipped scales."""
    rows = [(0, 0)] * 3 + [(6, 4), (5, 6), (4, 8), (3, 10), (3, 10), (3, 10), (3, 10), (4, 8), (4, 8), (5, 6), (6, 4)]
    picture = cone(rows, {"tip": "sand_light", "body": "mud", "seam": "mud_dark", "shade": "mud_dark"})
    rect(picture, 7, 1, 8, 2, "soil")
    return outlined(picture, "ink")


def from_rows(rows, keys):
    """A picture from rows of characters, each mapped to a colour name by `keys` ("." is clear)."""
    return [[keys.get(character) for character in row] for row in rows]


# The linen shirt with its long sleeves; the waistcoat icon draws the waistcoat over it.
SHIRT_ROWS = (
    "................",
    "................",
    "....lbbnnbbs....",
    "..lbbbbbnbbbbs..",
    ".lbbbbbbbbbbbbs.",
    ".lbbslbbbbbsbbs.",
    ".lbbslbbbbbsbbs.",
    ".lbbslbbbbbsbbs.",
    ".lbbslbbbbbsbbs.",
    ".lbbslbbbbbsbbs.",
    ".lbbslbbbbbsbbs.",
    ".sss.lbbbbs.sss.",
    ".....lbbbbs.....",
    ".....ssssss.....",
    "................",
    "................",
)
SHIRT_KEYS = {"b": "lime", "l": "lime", "s": "sand_light", "n": "skin_shade"}


def shirt():
    """A linen shirt with long sleeves and an open neck."""
    return outlined(from_rows(SHIRT_ROWS, SHIRT_KEYS))


def waistcoat():
    """A long red waistcoat with tin buttons, over the white sleeves of the shirt."""
    rows = [
        "................",
        "................",
        "....lbbnnbbs....",
        "..lbRrrbbrrdbs..",
        ".lbbRrrrbrrdbbs.",
        ".lbbRrrrrrrdbbs.",
        ".lbbRrrrorrdbbs.",
        ".lbbRrrrrrrdbbs.",
        ".lbbRrrrorrdbbs.",
        ".lbbRrrrrrrdbbs.",
        ".lbbRrrrorrdbbs.",
        ".sssRrrrrrrdsss.",
        "...Rrrrrrrrrd...",
        "...dddddddddd...",
        "................",
        "................",
    ]
    keys = SHIRT_KEYS | {"R": "red_light", "r": "rust", "d": "rust_dark", "o": "stone_light"}
    return outlined(from_rows(rows, keys))


def breeches():
    """Knee breeches of brown wool, banded at the knee, with the white stockings below them."""
    rows = [
        "................",
        "................",
        "....llllllll....",
        "....bbbbbbbb....",
        "...lbbbsbbbbs...",
        "...lbbbslbbbs...",
        "...lbbbslbbbs...",
        "...lbbs..lbbs...",
        "...dddd..dddd...",
        "...wwwh..wwwh...",
        "...wwwh..wwwh...",
        "...wwwh..wwwh...",
        "...wwwh..wwwh...",
        "...hhhh..hhhh...",
        "................",
        "................",
    ]
    keys = {"b": "soil_mid", "l": "soil_light", "s": "soil", "d": "soil_dark", "w": "lime", "h": "sand_light"}
    return outlined(from_rows(rows, keys))


def straw_hat():
    """A low crown with a dark band, on a wide brim that droops at its ends."""
    rows = [
        "................",
        "................",
        "................",
        "................",
        "......lllbb.....",
        ".....lbbbbbs....",
        ".....lbbbbbs....",
        ".....dddddds....",
        "..lllllbbbbbbs..",
        ".lbbbbbbbbbbbbs.",
        ".bsssbbbbbbssss.",
        ".ss........ss.s.",
        "................",
        "................",
        "................",
        "................",
    ]
    keys = {"b": "straw", "l": "sand_light", "s": "reed", "d": "soil"}
    return outlined(from_rows(rows, keys))


def knitted_cap():
    """A red wool stocking cap: a ribbed cuff, and the tip flopping over to one side."""
    rows = [
        "................",
        "................",
        "................",
        "......lrrr......",
        ".....lrrrrrd....",
        "....lrrrrrrrd...",
        "....lrrrrrrrrdd.",
        "...lrrrrrrrrrd.d",
        "...rrrrrrrrrrd.d",
        "...ccccccccccc..",
        "...dkdkdkdkdkd..",
        "...kdkdkdkdkdk..",
        "................",
        "................",
        "................",
        "................",
    ]
    keys = {"l": "red_light", "r": "rust", "d": "rust_dark", "c": "ember", "k": "russet_deep"}
    return outlined(from_rows(rows, keys))


def small(picture):
    """The icon at half size, for items lying on the ground: each 2x2 block of pixels becomes
    the colour that most of its opaque pixels have (the first of them on a tie), or clear
    where fewer than two are opaque."""
    size = len(picture) // 2
    result = blank(size)
    for y in range(size):
        for x in range(size):
            block = [picture[2 * y + dy][2 * x + dx] for dy in (0, 1) for dx in (0, 1)]
            opaque = [colour for colour in block if colour is not None]
            if len(opaque) >= 2:
                result[y][x] = max(opaque, key=opaque.count)
    return result


ICONS = {
    "chest": chest.icon(),
    "turnip": turnip(),
    "logs": logs(),
    "stone": stone(),
    "fibre": fibre(),
    "berries": berries(),
    "acorn": acorn(),
    "spruce_cone": spruce_cone(),
    "pine_cone": pine_cone(),
    "tunic": waistcoat(),
    "shirt": shirt(),
    "trousers": breeches(),
    "straw_hat": straw_hat(),
    "knitted_cap": knitted_cap(),
}


def slot(frame):
    """A 20x20 slot: a frame round a soil panel lit from the upper left. The selected one has
    a gold frame."""
    picture = blank(SLOT)
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
    picture = blank()
    for path in paths:
        for start, end in zip(path, path[1:]):
            line(picture, *start, *end, HINT_COLOUR)
    return picture


SLOT_HINTS = {f"equip_{slot}": hint(paths) for slot, paths in HINT_PATHS.items()}
