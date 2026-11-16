"""The player's sales cart (issue #49, `WorldObjectStall`), drawn at 32 px per tile: a hand cart of
oak seen from the side and a little above, its shafts to the left resting on a prop, one big
spoked wheel with an iron tyre, the top rail of its box painted red. On it the wares of a marsh
farm, from the left: a slate on a stick for the prices, a cabbage, a basket of eggs, a round
cheese, and at the right end the till, a little oak box with a slot in its lid and a brass hasp.

Light from the top left: the lit sides are the top and the left of each thing, the rails are lit
along the top, the wheel's tyre and rim are lit on their upper left. Each part is rimmed in the
darkest shade of its own colours (`items.rim_of`), the bottom row (where the wheel and the prop
stand) is not. `sales_cart()` is the picture, set into its atlas cell by
`generate.standing_outdoors`; it is also the body of the item's icon and the picture indoors.
"""

import math

from canvas import blank, rect
from items import rim_of

WIDTH, HEIGHT = 46, 40
# The box: its back board's top, the painted rail, the planks of the side and its bottom.
BOARD_TOP = 13
RAIL_TOP = 17
SIDE_TOP, SIDE_BOTTOM = 20, 26
BOX_LEFT, BOX_RIGHT = 8, 43
# The stakes that hold the rails, by their left column.
STAKES = (8, 25, 42)
# The wheel: its middle and its radii, out to in: the tyre, the felloe and the hub.
WHEEL_X, WHEEL_Y = 30.5, 30.5
TYRE, FELLOE, HUB = 9.5, 8.3, 2.3
SPOKES = 8
SPOKE_REACH = 6.9
# The tyre and the felloe are lit where they face the light by more than this cosine (within
# about 65 degrees of it) and shaded where they face as far away.
RING_LIT = 0.6 / math.sqrt(2)

OAK = ("soil_dark", "soil", "soil_mid", "soil_light")
RAIL = ("rust_dark", "ember", "red_light")
IRON = ("stone_dark", "stone", "stone_light")

# The wares, each (left, top, rows) in the letters of WARE_COLOURS, drawn from the back to the front.
WARES = (
    # The slate on its stick, a price in chalk on it.
    (5, 2, (
        "OOOOOOOOO",
        "OSSSSSSSo",
        "OScSccSSo",
        "OSSSSSSco",
        "OScccScSo",
        "OSSSSSSSo",
        "ooooooooo",
        "....t....",
        "....t....",
        "....t....",
        "....t....",
        "....t....",
        "....t....",
        "....t....",
    )),
    # The cabbage, its outer leaves curled round its head.
    (11, 8, (
        "...gGGg...",
        ".gGBBGGGg.",
        "gGBBGGgGGd",
        "gGBGGGGgGd",
        "gGGgGGGGgd",
        "gGGGgGGgdd",
        ".gGGGggddd",
        "..dddddd..",
    )),
    # The basket of eggs, its handle over them.
    (20, 4, (
        "...hhhhh...",
        "..h.....u..",
        ".h.......u.",
        ".h.Ee.Ee.u.",
        ".hEEeEEeEeu",
        "EEeEEeEEeEe",
        "WWWWWWWWWWw",
        "WwWwWwWwWwu",
        "wWwWwWwWwuu",
        "WwWwWwWwWwu",
        ".wwwwwwwuu.",
        "..uuuuuuu..",
    )),
    # The round cheese, its rind lit on the top.
    (30, 11, (
        ".CCCCC.",
        "CCCCCCY",
        "YYYYYYy",
        "YYYYYyy",
        "YYYYyyy",
        ".yyyyy.",
    )),
    # The till: an oak box with its lid, a slot in the lid and a brass hasp.
    (36, 7, (
        "LLLLLLL.",
        "LLkbkLLm",
        "mmmbmmmm",
        "MMMbMMMm",
        "MMMoMMMm",
        "MMMMMMMm",
        "MMMMMMMm",
        "MMMMMMmm",
        "mmmmmmmm",
    )),
)
WARE_COLOURS = {
    "O": "soil_light", "o": "soil", "S": "stone_dark", "c": "lime", "t": "soil_mid",
    "B": "green_bright", "G": "green_light", "g": "green", "d": "green_dark",
    "h": "ochre", "u": "umber", "E": "cream", "e": "sand_light", "W": "ochre", "w": "ochre_dark",
    "C": "cream", "Y": "gold", "y": "ochre",
    "L": "soil_light", "M": "soil_mid", "m": "soil", "k": "ink", "b": "gold",
}


# Rims of their own: the eggs and the cheese's top in a warm shade, not the purple of cream.
RIMS = {"cream": "sand", "sand_light": "sand"}


def _far_shaft(picture):
    """The far shaft, higher up behind the box and in its shade."""
    rect(picture, 1, 15, BOX_LEFT, 15, OAK[2])
    rect(picture, 1, 16, BOX_LEFT, 16, OAK[1])


def _box_back(picture):
    """The back board's top edge and the shaded inside of the box, behind the wares."""
    rect(picture, BOX_LEFT + 1, BOARD_TOP, BOX_RIGHT - 1, BOARD_TOP, "bare_light")
    rect(picture, BOX_LEFT + 1, BOARD_TOP + 1, BOX_RIGHT - 1, RAIL_TOP - 1, OAK[1])


def _box(picture):
    """The rail, the side planks and the stakes, in front of the wares."""
    for dy, colour in enumerate(reversed(RAIL)):
        rect(picture, BOX_LEFT, RAIL_TOP + dy, BOX_RIGHT, RAIL_TOP + dy, colour)
    for y in range(SIDE_TOP, SIDE_BOTTOM + 1):
        seam = y in (23, SIDE_BOTTOM)
        lit = y in (SIDE_TOP, 24)
        rect(picture, BOX_LEFT, y, BOX_RIGHT, y, OAK[1] if seam else OAK[3] if lit else OAK[2])
    for x, y, length in ((12, 21, 5), (31, 22, 6), (16, 25, 4), (36, 25, 5)):
        rect(picture, x, y, x + length - 1, y, OAK[1])
    for left in STAKES:
        rect(picture, left, SIDE_TOP, left, SIDE_BOTTOM, OAK[3])
        rect(picture, left + 1, SIDE_TOP, left + 1, SIDE_BOTTOM, OAK[1])


def _near_shaft(picture):
    """The near shaft along the box, out to the left, and the prop under its end of the box."""
    rect(picture, 0, 21, BOX_LEFT + 4, 21, OAK[3])
    rect(picture, 0, 22, BOX_LEFT + 4, 22, OAK[1])
    rect(picture, 10, SIDE_BOTTOM + 1, 10, HEIGHT - 1, OAK[2])
    rect(picture, 11, SIDE_BOTTOM + 1, 11, HEIGHT - 1, OAK[1])


def _ramp_at(ramp, x, y):
    """The shade of `ramp` (dark, middle, lit) of a ring's pixel, by its side of the wheel."""
    dx, dy = x + 0.5 - WHEEL_X, y + 0.5 - WHEEL_Y
    # How far the pixel's side of the ring faces the light from the top left: the cosine of the
    # angle between its direction from the middle and the light's, from 1 (facing it) to -1.
    facing = (-dx - dy) / math.hypot(dx, dy) / math.sqrt(2)
    return ramp[2] if facing > RING_LIT else ramp[0] if facing < -RING_LIT else ramp[1]


def _wheel(picture):
    """The near wheel over the box: iron tyre, oak felloe, spokes and the hub with its iron cap."""
    for y in range(HEIGHT):
        for x in range(WIDTH):
            dx, dy = x + 0.5 - WHEEL_X, y + 0.5 - WHEEL_Y
            distance = math.hypot(dx, dy)
            if distance > TYRE:
                continue
            if distance > FELLOE:
                picture[y][x] = _ramp_at(IRON, x, y)
            elif distance > SPOKE_REACH:
                picture[y][x] = _ramp_at(OAK[1:], x, y)
            elif distance <= 1.0:
                picture[y][x] = IRON[2]
            elif distance <= HUB:
                picture[y][x] = _ramp_at(OAK[1:], x, y)
            else:
                angle = math.atan2(dy, dx) % (2 * math.pi / SPOKES)
                off = min(angle, 2 * math.pi / SPOKES - angle) * distance
                if off < 0.62:
                    picture[y][x] = OAK[3] if dx + dy < 0 else OAK[2]


def _wares(picture):
    """Draws WARES into the picture, in their order, from the back to the front."""
    for left, top, rows in WARES:
        for y, row in enumerate(rows):
            for x, key in enumerate(row):
                if key != ".":
                    picture[top + y][left + x] = WARE_COLOURS[key]


def _rim(picture):
    """Rims each part's edge in the darkest shade of its colours, but the bottom row."""
    rims = []
    for y in range(HEIGHT - 1):
        for x in range(WIDTH):
            colour = picture[y][x]
            if colour is None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < WIDTH and 0 <= ny < HEIGHT) or picture[ny][nx] is None:
                    rims.append((x, y, RIMS.get(colour) or rim_of(colour) or colour))
                    break
    for x, y, colour in rims:
        picture[y][x] = colour


def sales_cart():
    """The cart, 46x40 px, standing (its bottom row on the ground)."""
    picture = blank(WIDTH, HEIGHT)
    _far_shaft(picture)
    _box_back(picture)
    _wares(picture)
    _box(picture)
    _near_shaft(picture)
    _wheel(picture)
    _rim(picture)
    return picture
