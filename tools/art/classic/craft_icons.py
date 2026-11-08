"""The item icons drawn outside items.py, tool_icons.py and crop_icons.py, as they were at 16 px
per tile (commit 91742f0): the hay and clay of `meadow.py`, the reeds of `reeds.py`, the icons of
`crafts.py`, the grave marker of `church.py` and the landing's items of `landing.py`, unchanged
but for their imports and `icons`, which gathers them. The stations, the grave marker and the
landing's items are icons of their world pictures, which are still drawn at 16 px (task 111).
"""

import item_icons as items
from canvas import TILE, blank, outline, outline_edge, rect
from crafts import carved_chest, cupboard, kiln, oven, workbench
from graves import oak_cross
from item_icons import from_rows, outlined, pixel
from landing import EAST, WEST, eel_traps, jetty, net_frame, rowing_boat
from palette import darkest_of


def hay():
    """A golden sheaf: stalks fanning out from a red band, ears spread on top, lit from the
    left."""
    picture = blank()
    band = 10
    # The sheaf's shape in the shade colour, so gaps between the stalks read as depth.
    for y in range(2, 15):
        half = 1.8 + (band - y) * 0.55 if y < band else 1.8 + (y - band) * 0.4
        for x in range(16):
            if abs(x + 0.5 - 8) <= half:
                picture[y][x] = "ochre_dark"
    for stalk in range(-3, 4):
        colour = "gold" if stalk < 0 else "straw" if stalk < 2 else "ochre"
        items.line(picture, round(8 + stalk * 0.5), 14, round(8 + stalk * 1.8), 3, colour)
        # The ear: a seed head leaning out at the top.
        x = round(8 + stalk * 2)
        picture[2][x] = picture[1][x + (stalk > 0) - (stalk < 0)] = "gold" if stalk < 1 else "straw"
    rect(picture, 5, band - 1, 10, band, "rust")
    rect(picture, 5, band - 1, 7, band - 1, "red_light")
    rect(picture, 9, band, 10, band, "rust_dark")
    return items.outlined(picture, "mud_dark")


def clay():
    """A smooth lump of reddish-grey clay with a thumb dent and a wet highlight."""
    rows = [
        "................",
        "................",
        "................",
        "......hhll......",
        "....hhllllll....",
        "...hlllddlllb...",
        "..hlllldbllllb..",
        "..hlllllllllbb..",
        ".hllllllllllbbb.",
        ".llllllllllbbbs.",
        ".lllllllbbbbbss.",
        "..llbbbbbbbbss..",
        "...ssbbbbbsss...",
        ".....ssssss.....",
        "................",
        "................",
    ]
    keys = {"h": "bare_light", "l": "soil_light", "d": "soil_mid", "b": "soil_mid", "s": "rust_dark"}
    return items.outlined(items.from_rows(rows, keys), "soil_dark")


def reeds_item():
    """A bundle of long cut reeds lying on the diagonal, tied twice, with brown cattail heads at
    the top right."""
    picture = blank()
    # Five stalks on the diagonals x + y = 13..17, the upper left one lit. Each ends at its own
    # length, so the ends are not cut square.
    stalks = ((13, "sand_light", 1, 10), (14, "straw", 1, 11), (15, "straw", 2, 12), (16, "reed", 3, 12), (17, "olive", 4, 13))
    for diagonal, colour, first, last in stalks:
        for x in range(first, last + 1):
            picture[diagonal - x][x] = colour
    # Cattail heads beyond the ends of three stalks, 2 px thick along them.
    for diagonal, last in ((14, 11), (15, 12), (16, 12)):
        for x in range(last + 1, last + 3):
            picture[diagonal - x][x] = "soil_mid"
            picture[diagonal - x - 1][x] = "soil_light" if diagonal == 14 else "soil"
    # Two ties across the bundle.
    for across in (-4, 4):
        for x in range(16):
            for y in range(16):
                if x - y in (across, across + 1) and 13 <= x + y <= 17:
                    picture[y][x] = "rust" if x + y < 16 else "rust_dark"
    return items.outlined(picture, "ink")


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


def planks():
    """Three sawn boards, stacked, their ends showing on the right."""
    picture = blank()
    for top in (3, 7, 11):
        rect(picture, 1, top, 13, top + 2, "sand")
        rect(picture, 1, top, 13, top, "sand_light")
        rect(picture, 14, top, 14, top + 2, "soil_light")
        pixel(picture, 4 + top % 5, top + 1, "straw")
    return outlined(picture, "soil_dark")


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


def stool():
    """The stool of its item icon, 10x10: the stool of the 16 px interior (the room's is drawn at
    32 px in interior.py)."""
    picture = blank(10, 10)
    rect(picture, 0, 0, 9, 4, "soil_light")
    rect(picture, 0, 4, 9, 4, "soil_mid")
    for x in (1, 7):
        rect(picture, x, 5, x + 1, 9, "soil")
    rect(picture, 4, 5, 5, 8, "soil_dark")
    return outline_edge(picture, "soil_dark", keep_bottom=True)


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


def _icon(picture):
    """An item icon of a picture: halved if it is wider than an icon, its bottom rows if it is
    taller, without its contact shadow, in the middle of 16x16 px and outlined."""
    if len(picture[0]) > TILE:
        size = len(picture[0])
        square = blank(size)
        top = (size - len(picture)) // 2
        for y, row in enumerate(picture):
            square[top + y] = list(row)
        picture = items.small(square)
    picture = [row for row in picture if any(name not in (None, "shadow") for name in row)][-(TILE - 2) :]
    icon = blank()
    top = (TILE - len(picture)) // 2
    left = (TILE - len(picture[0])) // 2
    for y, row in enumerate(picture):
        for x, name in enumerate(row):
            if name not in (None, "shadow"):
                icon[top + y][left + x] = name
    return outline(icon, darkest_of)


def icons():
    """The 16x16 icons by item id."""
    return {
        "hay": hay(),
        "clay": clay(),
        "reeds": reeds_item(),
        "workbench": icon_of(workbench(is_standing=False)),
        "kiln": _shrunk(kiln(is_standing=False)),
        "oven": icon_of(oven(is_standing=False)),
        "planks": planks(),
        "cupboard": _shrunk(cupboard(is_standing=False)),
        # Dried clay, grey-brown, and fired, red.
        "raw_brick": bricks("mud", "sand", "mud_dark"),
        "brick": bricks("rust", "red_light", "rust_dark"),
        "stool": icon_of(stool()),
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
        "grave_marker": icon_of(oak_cross()),
        "jetty": _icon(jetty(EAST | WEST)),
        "rowing_boat": _icon(rowing_boat()),
        "net_frame": _icon(net_frame()),
        "eel_traps": _icon(eel_traps()),
    }
