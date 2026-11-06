"""Art for the ambient wildlife: one sheet per kind at assets/wildlife/<kind>.png.

A sheet has one row per action and one column per frame, in the order of SHEETS (which
game/scenes/wildlife/wildlife_sprites.gd mirrors). Every cell has the size of its kind; the
animal stands in the bottom centre, facing right (the game flips it to face left). Pictures
are rows of characters mapped to palette colour names, as everywhere in the art. Land
animals get a one pixel outline in the darkest colour of their coat; the butterfly goes
without, and the bee has its dark outline drawn in (see the style rules in SPEC.md).
"""

from canvas import blank, copy

NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))

# Sparrow: crown and back, wing, pale cheek and belly, beak, eye.
BIRD_KEYS = {"b": "soil_mid", "d": "soil", "s": "cream", "l": "sand_light", "k": "ochre", "e": "ink"}
RABBIT_KEYS = {"b": "mud", "l": "sand", "s": "sand_light", "p": "petal", "e": "ink"}
# Red squirrel: rust coat, small cream belly, dark ear tufts; the tail shaded darker towards
# the body, with a light rim.
SQUIRREL_KEYS = {"r": "rust", "R": "rust_dark", "c": "cream", "e": "ink", "o": "maple_light"}
DEER_KEYS = {
    "b": "soil_mid",
    "l": "soil_light",
    "d": "soil",
    "c": "cream",
    "s": "sand_light",
    "e": "ink",
    # Upper legs, outlined with the body: near and far.
    "U": "soil_mid",
    "V": "soil",
    # Lower legs and hooves: drawn over the outline, so that thin legs stay thin.
    "L": "soil",
    "M": "soil_dark",
    "K": "ink",
}
BEE_KEYS = {"y": "gold", "k": "ink", "w": "snow_light"}
BUTTERFLY_KEYS = {
    "a": "maple_light",
    "b": "ink",
    "c": "cream",
    "p": "petal",
    "q": "blossom",
    "v": "heather",
}

# Each sheet: cell size, outline colour (None for none), colour keys and the actions with
# their frames. A frame is a list of rows (plain shapes; the outline is added) and may be
# lifted off the floor by writing ("lift", n, rows).
BIRD_STANDING = ["...bb.", "...sek", "ddbbl.", "..ll.."]
BIRD = {
    "size": (8, 8),
    "outline": "soil_dark",
    "keys": BIRD_KEYS,
    "actions": {
        # Head with eye and beak on the right, the tail out to the left; it looks up, pecks
        # at the ground with the tail raised, and flies with its wings up, level and down.
        "idle": [BIRD_STANDING, BIRD_STANDING, ["...bbk", "...se.", "ddbbl.", "..ll.."]],
        "peck": [BIRD_STANDING, ["d.....", ".dbbb.", "..llbs", "....ek"]],
        "hop": [("lift", 1, BIRD_STANDING), BIRD_STANDING],
        "fly": [
            ("lift", 1, ["..d.d.", "..ddbb", "dddbek", "..ll.."]),
            ("lift", 1, ["dddbbb", "ddddek", "..ll.."]),
            ("lift", 1, ["....bb", "dddbek", "..dl..", "..d..."]),
        ],
    },
}

RABBIT = {
    "size": (12, 10),
    "outline": "mud",
    "keys": RABBIT_KEYS,
    "actions": {
        "sit": [
            [
                "....b.b",
                "....bpb",
                "...bbbb",
                ".bbbbbe",
                "bbbbbbb",
                "ssbbbll",
            ],
            [
                "....b.b",
                "....bpb",
                "...bbbb",
                ".bbbbbe",
                "bbbbbbb",
                "ssbbbll",
            ],
        ],
        "nibble": [
            [
                "....b.b",
                "....bpb",
                "...bbbb",
                ".bbbbbe",
                "bbbbbbb",
                "ssbbbll",
            ],
            [
                ".......",
                "...b.b.",
                "...bpb.",
                ".bbbbbbb",
                "bbbbbbe",
                "ssbbbll",
            ],
        ],
        "hop": [
            ["...b.b", "...bpb", ".bbbbb", "bbbbbe", "sbbbbl"],
            [".....bb", "s.bbbbp", "sbbbbbb", ".bbbbe.", "..l..l."],
            ["...b.b", "...bpb", ".bbbbb", "bbbbbe", "sbbbbl"],
        ],
    },
}

SQUIRREL_SIT = [
    ".ooo........",
    "orrro.......",
    "orR....R.R..",
    "rrR...rrrr..",
    ".rrR..rrrer.",
    "..rR...rrr..",
    "..rR..rrrcr.",
    ".rrR.rrrrc..",
    "orrR.rrrrr..",
    "orRRRRRrrrr.",
]
SQUIRREL = {
    "size": (14, 12),
    "outline": "russet_deep",
    "keys": SQUIRREL_KEYS,
    "actions": {
        # Upright, the bushy S-shaped tail behind it, apart from the body; the second frame
        # twitches the nose, the last flicks the tail.
        "sit": [
            SQUIRREL_SIT,
            SQUIRREL_SIT[:4] + [".rrR..rrre.."] + SQUIRREL_SIT[5:],
            ["oo..........", "orro........", "orrR...R.R..", ".rRR..rrrr.."] + SQUIRREL_SIT[4:],
        ],
        # Running: the body stretched low, the tail streaming out behind.
        "dart": [
            ["oo.......R.R", "orrRo...rrrr", ".ooRRrrrrrer", "....Rrrrrcc.", "....r.r..r.r"],
            [".oo......R.R", "orrRo...rrrr", "..oRRrrrrrer", ".....rrrrcc.", "......rrrr.."],
            ["ooo......R.R", ".orRo...rrrr", "..oRRrrrrrer", "....Rrrrrcc.", "...r.....r.r"],
        ],
    },
}

DEER = {
    "size": (26, 26),
    "outline": "soil_dark",
    "keys": DEER_KEYS,
    # Written below: the frames are put together from parts.
    "actions": {},
}

BEE = {
    "size": (4, 4),
    "outline": None,
    "keys": BEE_KEYS,
    "actions": {
        "hover": [[".w..", "ykyk", "ykyk", ".kk."], ["....", "ykyk", "ykyk", ".kk."]],
    },
}

BUTTERFLY = {
    "size": (6, 6),
    "outline": None,
    "keys": BUTTERFLY_KEYS,
    "actions": {
        "flutter": [["a.a", "aba", ".b."], ["aa", "ab", ".b"], ["a", "b", "b"]],
        "flutter_pale": [["c.c", "cbc", ".b."], ["cc", "cb", ".b"], ["c", "b", "b"]],
        "flutter_pink": [["p.p", "pbp", ".b."], ["pp", "pb", ".b"], ["p", "b", "b"]],
    },
}


# The deer, a roe deer, is put together on its 26x26 cell, facing right with the hooves on
# the bottom row: a round body with a darker back and a white rump, a neck and head, and
# legs whose upper part is outlined with the body.
DEER_TORSO = (
    ".dddddddddddd..",
    "ccdlllllllllldd",
    "ccbbbbbbbbbbbbb",
    ".cbbbbbbbbbbbbb",
    "..ddbbbbbbbbdd.",
)
# Arched in mid-leap: the back rounder, the rump lower.
DEER_TORSO_ARCHED = (
    "...dddddddddd..",
    ".cdllllllllllld",
    "ccbbbbbbbbbbbbb",
    "ccbbbbbbbbbbbbb",
    "...dbbbbbbbbdd.",
)
TORSO_X, TORSO_Y = 3, 12
HEAD_UP = (
    "..d.d....",
    "..dldl...",
    "...ddb...",
    "...lbbb..",
    "...lbebb.",
    "...lbbbbe",
    "...lbs...",
    "...lb....",
    "...lb....",
    "..lbb....",
    "..lbb....",
)
HEAD_FORWARD = (
    "....d.d...",
    "....dldl..",
    ".....ddb..",
    ".....lbbb.",
    ".....lbebb",
    "....lbbbbe",
    "...lbbs...",
    "..lbb.....",
    ".lbb......",
    "lbb.......",
)
HEAD_DOWN = (
    "lb.......",
    "lbb......",
    ".lb......",
    ".lbb.....",
    "..lb.....",
    "..lbb.d..",
    "...lbdl..",
    "...lbbd..",
    "...lbbb..",
    "...bebb..",
    "...bbbb..",
    "...sbbs..",
    "....be...",
)
HEAD_DOWN_EAR_FLICK = HEAD_DOWN[:5] + ("..lbb..d.", "...lbdl..") + HEAD_DOWN[7:]
HEAD_UP_EAR_FLICK = ("..d......", "..dldd...") + HEAD_UP[2:]

# Legs, the top two rows inside the body: U/V is the outlined upper leg (near/far), L/M
# the thin lower leg (near/far), K the hoof. The hind leg bends back at the hock.
HIND_STANDING = (".UU", ".UU", ".UU", "..U", "..U", ".L.", ".L.", ".L.", ".L.", ".L.", ".K.")
FRONT_STANDING = ("UU", "UU", "UU", "U.", "U.", "L.", "L.", "L.", "L.", "L.", "K.")
HIND_FORWARD = ("..UU", "..UU", "..UU", "...U", "...U", "...L", "...L", "....L", "....L", ".....L", ".....K")
HIND_BACK = ("..UU", "..UU", ".UU.", ".U..", "U...", "L...", "L...", "L...", "L...", "L...", "K...")
FRONT_FORWARD = ("UU..", "UU..", ".UU.", "..U.", "..U.", "...L", "...L", "....L", "....L", "....L", "....K")
FRONT_BACK = ("..UU", "..UU", ".UU.", ".U..", "U...", "L...", "L...", "L...", "L...", "L...", "K...")
HIND_TUCKED = (".UU...", ".UUU..", "..UUU.", "....UL", "....L.", "...K..")
FRONT_TUCKED = ("UU...", "UUU..", ".UUUL", "...L.", "..L..", ".K...")
HIND_REACHING = ("...UU", "..UU.", "UUU..", "L....", "K....")
FRONT_REACHING = ("UU....", "UUU...", ".UUU..", "...LL.", ".....L", ".....K")
HIND_X, FRONT_X = 3, 13


def paste(grid, rows, x, y, far=False):
    """Draws rows of characters into the grid; `far` turns legs into far-side (darker) legs."""
    for dy, row in enumerate(rows):
        for dx, char in enumerate(row):
            if char != "." and 0 <= y + dy < len(grid) and 0 <= x + dx < len(grid[0]):
                if far:
                    char = {"U": "V", "L": "M", "K": "M"}.get(char, char)
                grid[y + dy][x + dx] = char


def deer_frame(head, head_at, legs, torso=DEER_TORSO, lift=0):
    """A deer facing right as a 26-row grid of characters. `legs` are the hind and front
    leg of the near side and of the far side: (rows, x shift) each."""
    grid = [["."] * 26 for _ in range(26)]
    top = TORSO_Y - lift
    legs_top = top + len(torso) - 2
    (near_hind, near_front), (far_hind, far_front) = legs
    for (rows, shift), x in ((far_hind, HIND_X + 2), (far_front, FRONT_X + 2)):
        paste(grid, rows, x + shift, legs_top, far=True)
    paste(grid, torso, TORSO_X, top)
    for (rows, shift), x in ((near_hind, HIND_X), (near_front, FRONT_X)):
        paste(grid, rows, x + shift, legs_top)
    paste(grid, head, head_at[0], head_at[1] - lift)
    return ["".join(row) for row in grid]


STANDING = (((HIND_STANDING, 0), (FRONT_STANDING, 0)), ((HIND_STANDING, 0), (FRONT_STANDING, -1)))
WALKING = [
    (((HIND_FORWARD, -1), (FRONT_BACK, -2)), ((HIND_BACK, -1), (FRONT_FORWARD, -1))),
    (((HIND_STANDING, 0), (FRONT_STANDING, 0)), ((HIND_STANDING, 0), (FRONT_STANDING, -1))),
    (((HIND_BACK, -1), (FRONT_FORWARD, 0)), ((HIND_FORWARD, -1), (FRONT_BACK, -3))),
    (((HIND_STANDING, 0), (FRONT_STANDING, 0)), ((HIND_STANDING, 0), (FRONT_STANDING, -1))),
]
GATHERED = (((HIND_TUCKED, 1), (FRONT_TUCKED, 0)), ((HIND_TUCKED, 0), (FRONT_TUCKED, -1)))
STRETCHED = (((HIND_REACHING, -3), (FRONT_REACHING, 0)), ((HIND_REACHING, -2), (FRONT_REACHING, -1)))

DEER["actions"] = {
    "graze": [
        ("raw", deer_frame(HEAD_DOWN, (16, 12), STANDING)),
        ("raw", deer_frame(HEAD_DOWN_EAR_FLICK, (16, 12), STANDING)),
    ],
    "look": [
        ("raw", deer_frame(HEAD_UP, (14, 5), STANDING)),
        ("raw", deer_frame(HEAD_UP_EAR_FLICK, (14, 5), STANDING)),
    ],
    "walk": [("raw", deer_frame(HEAD_FORWARD, (12, 6), legs)) for legs in WALKING],
    "bound": [
        ("raw", deer_frame(HEAD_FORWARD, (12, 6), GATHERED, DEER_TORSO_ARCHED, lift=3)),
        ("raw", deer_frame(HEAD_FORWARD, (12, 6), STRETCHED, DEER_TORSO_ARCHED, lift=4)),
        ("raw", deer_frame(HEAD_FORWARD, (12, 6), STANDING)),
    ],
}

SHEETS = {
    "bird": BIRD,
    "rabbit": RABBIT,
    "squirrel": SQUIRREL,
    "deer": DEER,
    "bee": BEE,
    "butterfly": BUTTERFLY,
}


def outlined(shape, colour):
    """The shape on a canvas one pixel larger on every side, with the outline around it."""
    height, width = len(shape), len(shape[0])
    result = blank(width + 2, height + 2)
    for y in range(height):
        for x in range(width):
            result[y + 1][x + 1] = shape[y][x]
    for y in range(height + 2):
        for x in range(width + 2):
            if result[y][x] is not None:
                continue
            for dx, dy in NEIGHBOURS:
                nx, ny = x + dx, y + dy
                if 0 <= nx < width + 2 and 0 <= ny < height + 2 and shape_pixel(shape, nx - 1, ny - 1):
                    result[y][x] = colour
                    break
    return result


def shape_pixel(shape, x, y):
    return 0 <= y < len(shape) and 0 <= x < len(shape[0]) and shape[y][x] is not None


def frame_picture(sheet, frame):
    """One frame as a grid of colour names filling a cell, the animal in the bottom centre."""
    width, height = sheet["size"]
    picture = blank(width, height)
    lift = 0
    if frame and frame[0] == "lift":
        _, lift, frame = frame
    if frame and frame[0] == "raw":
        # Already a full cell (the deer): outline it in place.
        rows = frame[1]
        shape = [[sheet["keys"].get(char) for char in row] for row in rows]
        if sheet["outline"]:
            # Legs are outside the outline: it goes around the rest only.
            legs = {"L", "M", "K"}
            body = [[None if char in legs else colour for char, colour in zip(row, line)] for row, line in zip(rows, shape)]
            shape = outline_in_place(body, sheet["outline"])
            for y, row in enumerate(rows):
                for x, char in enumerate(row):
                    if char in legs:
                        shape[y][x] = sheet["keys"][char]
        return shape
    rows = frame
    columns = max(len(row) for row in rows)
    shape = [[sheet["keys"].get(char) for char in row.ljust(columns, ".")] for row in rows]
    if sheet["outline"]:
        shape = outlined(shape, sheet["outline"])
    top = height - len(shape) - lift
    left = (width - len(shape[0])) // 2
    for y, row in enumerate(shape):
        for x, colour in enumerate(row):
            if colour is not None and 0 <= top + y < height and 0 <= left + x < width:
                picture[top + y][left + x] = colour
    return picture


def outline_in_place(shape, colour):
    """Outlines inside the same-size grid: pixels outside the shape that touch it."""
    height, width = len(shape), len(shape[0])
    result = copy(shape)
    for y in range(height):
        for x in range(width):
            if shape[y][x] is not None:
                continue
            for dx, dy in NEIGHBOURS:
                if shape_pixel(shape, x + dx, y + dy):
                    result[y][x] = colour
                    break
    return result


def sheet_rows(kind):
    """The sheet of a kind as rows of cells for palette.to_image: one list of cells per
    action, one cell per frame."""
    sheet = SHEETS[kind]
    return [[frame_picture(sheet, frame) for frame in frames] for frames in sheet["actions"].values()]


def cell_size(kind):
    return SHEETS[kind]["size"]
