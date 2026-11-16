"""The player's sales cart (issue #49) in the classic 16 px art, as tools/art/sales_cart.py draws it
at 32 px, at half the size: a hand cart of oak, its shafts to the left resting on a prop, one
spoked wheel with an iron tyre, the top rail of its box painted red; on it a slate for the prices,
a cabbage, a basket of eggs, a cheese and the till with a coin in its slot. A map of letters drawn
by hand, the wheel worked out on top of it; the icon is a smaller map of its own (`icon`). The
wood is rimmed in `soil_dark` like the classic stall, the wares in a dark shade of their own
(RIM_COLOURS), so the small ones keep their colour.
"""

import math

from canvas import NEIGHBOURS, TILE, blank, outline

WIDTH, HEIGHT = 23, 20
ROWS = (
    ".......................",
    ".OOOOO.................",
    ".OcKcO.......uuu.......",
    ".OKcKO......u...u..LLLL",
    ".ooooo.gGg..uEEEu..LknL",
    "...t..gBGGg.EEeEE..MMnM",
    "...tbbgGGgdWWWWWWbbMMMM",
    "...tiidgGgdWwWwWwCCMMMM",
    "ffftiiidddiwWwWwWYYmmmm",
    "....iiiiiiiwwwwwwyyiiii",
    "....RRRRRRRRRRRRRRRRRRR",
    "....rrrrrrrrrrrrrrrrrrr",
    "SSSSSSPPPPPPPPPPPPPPPPP",
    "....ppppppppppppppppppp",
    "....qqqqqqqqqqqqqqqqqqq",
    ".....Sq................",
    ".....Sq................",
    ".....Sq................",
    ".....Sq................",
    ".....Sq................",
)
COLOURS = {
    "O": "soil_light", "o": "soil", "K": "stone_dark", "c": "lime", "t": "soil_mid",
    "g": "green", "G": "green_light", "B": "green_bright", "d": "green_dark",
    "u": "ochre_dark", "E": "cream", "e": "sand_light", "W": "ochre", "w": "ochre_dark",
    "C": "cream", "Y": "gold", "y": "ochre",
    "L": "soil_light", "M": "soil_mid", "m": "soil", "k": "ink", "n": "gold",
    "b": "bare_light", "i": "soil", "f": "soil",
    "R": "red_light", "r": "rust_dark",
    "S": "soil_light", "P": "soil_light", "p": "soil_mid", "q": "soil",
}
# The rim of the wares, by their colour; everything else is rimmed in soil_dark.
RIM_COLOURS = {
    "green": "green_dark", "green_light": "green_dark", "green_bright": "green_dark",
    "cream": "sand", "sand_light": "sand", "gold": "ochre_dark", "ochre": "umber",
    "lime": "stone_dark", "red_light": "rust_dark",
}
# The icon's body, 14x12 px: the cart with a cabbage, the basket of eggs, the cheese and the till.
ICON = (
    "....uuu.......",
    ".gg.u..u...LL.",
    "gGGgEEEe.YLnL.",
    "gGGgWWWWYYMMM.",
    ".RRRRRRRRRRRRR",
    "SSPPPPPPPPPPPP",
    "..pppppppppppp",
    "..t....IIIII..",
    "..t...It.t.tI.",
    "..t...I.tst.I.",
    "..t...It.t.tI.",
    "..t....IIIII..",
)
ICON_COLOURS = COLOURS | {"I": "stone", "s": "stone_light"}
# The wheel: its middle, the iron tyre's inner radius and the felloe's.
WHEEL_X, WHEEL_Y = 15.5, 15.5
TYRE, FELLOE, RIM = 4.6, 3.6, 2.7


def _wheel(picture):
    """The tyre lit on its upper left, the felloe, four spokes on the diagonals and the hub."""
    for y in range(HEIGHT):
        for x in range(WIDTH):
            dx, dy = x + 0.5 - WHEEL_X, y + 0.5 - WHEEL_Y
            distance = math.hypot(dx, dy)
            if distance > TYRE:
                continue
            if distance > FELLOE:
                picture[y][x] = "stone_light" if dx + dy < -2 else "stone_dark" if dx + dy > 2 else "stone"
            elif distance > RIM:
                picture[y][x] = "soil_light" if dx + dy < -1 else "soil_mid"
            elif distance <= 0.8:
                picture[y][x] = "stone_light"
            elif abs(abs(dx) - abs(dy)) < 0.6:
                picture[y][x] = "soil_light" if dx + dy < 0 else "soil_mid"


def sales_cart():
    """The cart, 23x20 px, standing (its bottom row on the ground)."""
    picture = blank(WIDTH, HEIGHT)
    for y, row in enumerate(ROWS):
        for x, key in enumerate(row):
            if key != ".":
                picture[y][x] = COLOURS[key]
    _wheel(picture)
    return _rimmed(picture)


def _rimmed(picture):
    """Each drawn pixel next to a clear one (but on the bottom row, where it stands) in its rim."""
    rims = []
    for y in range(HEIGHT - 1):
        for x in range(WIDTH):
            colour = picture[y][x]
            if colour is None:
                continue
            for dx, dy in NEIGHBOURS:
                nx, ny = x + dx, y + dy
                if not (0 <= nx < WIDTH and 0 <= ny < HEIGHT) or picture[ny][nx] is None:
                    rims.append((x, y, RIM_COLOURS.get(colour, "soil_dark")))
                    break
    for x, y, colour in rims:
        picture[y][x] = colour
    return picture


def icon():
    """The icon of the cart, 16x16 px: its body outlined in soil_dark, in the middle."""
    picture = blank()
    top, left = (TILE - len(ICON)) // 2, (TILE - len(ICON[0])) // 2
    for y, row in enumerate(ICON):
        for x, key in enumerate(row):
            if key != ".":
                picture[top + y][left + x] = ICON_COLOURS[key]
    return outline(picture, "soil_dark")
