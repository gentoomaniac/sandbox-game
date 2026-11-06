"""Art for the farm animals: one sheet per species and look at assets/wildlife/<species>_<look>.png.

Every sheet has the same rows (ACTIONS): standing idle, walking, grazing (pecking, for a hen)
and asleep, one column per frame, and the animal stands in the bottom centre of its cell,
facing right (the game flips it to face left). game/scenes/wildlife/wildlife_sprites.gd
mirrors the cell sizes and the frames. The looks are those of the region around 1700-1800 (see
docs/art-style.md, "Props and animals").

An animal is put together from parts as rows of characters, like the deer of animals.py: a
body, a head and legs. The characters stand for the parts of a coat (light, base, shade), the
white of a pied coat, horns, eyes and so on; a look is the colours given to them, and a pattern
of white patches for a pied coat. The body and the head get a one pixel outline in the darkest
colour of the coat; the legs are drawn over it, so that thin legs stay thin.
"""

from animals import outline_in_place, paste

# The rows of every sheet, with their frames.
ACTIONS = {"idle": 2, "walk": 4, "graze": 2, "sleep": 2}
# Characters that are drawn over the outline instead of being outlined.
LEGS = {"L", "M", "N", "K"}


def to_picture(rows, keys, outline):
    """A grid of characters as a picture: the outline goes around everything but the legs."""
    body = [[None if char in LEGS else keys.get(char) for char in row] for row in rows]
    picture = outline_in_place(body, outline)
    for y, row in enumerate(rows):
        for x, char in enumerate(row):
            if char in LEGS:
                picture[y][x] = keys[char]
    return picture


def grid(width, height):
    return [["."] * width for _ in range(height)]


def joined(cells):
    return ["".join(row) for row in cells]


def patched(rows, pattern):
    """The rows with the coat turned white where the pattern has a "w": light, base and shade
    of the coat become those of the white."""
    white = {"l": "x", "b": "w", "d": "W"}
    result = []
    for row, mask in zip(rows, pattern):
        mask = mask.ljust(len(row), ".")
        result.append("".join(white.get(char, char) if mask[x] == "w" else char for x, char in enumerate(row)))
    return tuple(result)


# --- Cattle -------------------------------------------------------------------------------
#
# A small cow of the period, about 22 px long and 15 px to the top of the back: the deer is 18
# px long. Keys: l, b, d light, base and shade of the coat; x, w, W of the white of a pied
# coat; h and H horn and its tip; r inside of the ear; n muzzle; e eye; u udder; t the tuft of
# the tail; L, M near and far leg, K hoof.

COW_SIZE = (32, 24)
COW_TORSO_X, COW_TORSO_Y = 5, 9
COW_TORSO = (
    "llllllllllllllllll...",
    "lbbbbbbbbbbbbbbbbbll.",
    "bbbbbbbbbbbbbbbbbbbbl",
    "bbbbbbbbbbbbbbbbbbbbb",
    "bbbbbbbbbbbbbbbbbbbbb",
    "bbbbbbbbbbbbbbbbbbbbb",
    "dbbbbbbbbbbbbbbbbbbbd",
    "ddbbbbbbbbbbbbbbbbbdd",
    ".dddddddddddddddddd..",
)
COW_UDDER = ("uu", "u.")
# The heads, with the neck that joins them to the torso: their top left corner sits this far from
# the torso's. Looking ahead, and down at the grass in front of the forelegs.
COW_HEAD_AHEAD = (
    ".....Hh....",
    "......h....",
    "....rlbbl..",
    "...rrbbbebb",
    "...lbbbbbbb",
    "..lbbbbbbbb",
    ".lbbbbbbbnn",
    "lbbbbbbbnnn",
    "bbbbbbbb.n.",
    "bbbbbbb....",
)
COW_HEAD_AHEAD_AT = (12, -5)
COW_HEAD_DOWN = (
    "lbbb.......",
    "lbbbb......",
    ".lbbbb.....",
    "..lbbbb....",
    "...lbbbbH..",
    "....bbbbh..",
    "...rrbbbb..",
    "....rbbbbb.",
    ".....bbebb.",
    ".....bbbbb.",
    ".....bbbbb.",
    ".....bbbbb.",
    ".....lnnnn.",
    "......nnn..",
)
COW_HEAD_DOWN_AT = (15, 1)
COW_TAIL = (
    "b.",
    "b.",
    "b.",
    "b.",
    "b.",
    "b.",
    "b.",
    "t.",
    "tt",
)
COW_TAIL_SWISH = (
    "b...",
    ".b..",
    ".b..",
    "..b.",
    "..b.",
    "..b.",
    "..t.",
    ".tt.",
)
COW_LEG = ("LM", "LM", "LM", "LM", "LM", "LM", "LM", "KK")
COW_LEG_FORWARD = ("LM.", "LM.", "LM.", "LM.", ".LM", ".LM", ".LM", ".KK")
COW_LEG_BACK = (".LM", ".LM", ".LM", ".LM", "LM.", "LM.", "LM.", "KK.")
COW_HIND_X, COW_FRONT_X = 1, 16

# Each look: the colours of the characters, the outline, and the pattern of a pied coat.
COW_LOOKS = {
    # Angler: the red-brown cattle of Angeln on the Baltic side.
    "angler": {
        "keys": {"l": "rust", "b": "rust_dark", "d": "russet_deep", "n": "skin_shade"},
        "outline": "soil_dark",
    },
    # Black and white marsh cattle of the North Sea coast.
    "black_pied": {
        "keys": {"l": "stone", "b": "stone_dark", "d": "bog_dark", "n": "stone_dark"},
        "outline": "ink",
        "pattern": (
            "......www............",
            ".....wwwww.......w...",
            "....wwwwww......www..",
            ".....wwww......wwww..",
            "...............www...",
            "ww...................",
            "www.....wwwww.......w",
            "wwwwwwwwwwwwwwwwwwwww",
            "wwwwwwwwwwwwwwwwwwwww",
        ),
        # A white blaze down the face.
        "head_patterns": {
            "ahead": (
                "...........",
                "...........",
                ".......w...",
                "......ww...",
                "......wwww.",
                "......wwwww",
                ".....wwwwww",
            ),
            "down": (
                "...........",
                "...........",
                "...........",
                "...........",
                "...........",
                "...........",
                "......w....",
                "......ww...",
                "......w.w..",
                "......wwww.",
                "......wwww.",
                "......wwww.",
                "......wwww.",
            ),
        },
    },
    # Red pied: mostly white with red patches, the cattle of the marsh farms.
    "red_pied": {
        "keys": {"l": "red_light", "b": "rust", "d": "rust_dark", "n": "skin_shade"},
        "outline": "russet_deep",
        "pattern": (
            "...........wwwwww....",
            "wwww......wwwwwwww...",
            "wwwww......wwwwww....",
            "wwwwww...........ww..",
            "wwwww...........www..",
            "wwww..wwww.....wwww..",
            "wwwwwwwwwwww...wwwwww",
            "wwwwwwwwwwwwwwwwwwwww",
            "wwwwwwwwwwwwwwwwwwwww",
        ),
    },
}
COW_SHARED_KEYS = {
    "x": "lime",
    "w": "lime",
    "W": "stone_light",
    "h": "cream",
    "H": "stone",
    "r": "skin_shade",
    "e": "ink",
    "u": "skin",
    "t": "soil_dark",
}


COW = {
    "size": COW_SIZE,
    "torso": COW_TORSO,
    "torso_at": (COW_TORSO_X, COW_TORSO_Y),
    # Lying, the torso is this much lower, on the ground.
    "lying_drop": 6,
    "heads": {"ahead": (COW_HEAD_AHEAD, COW_HEAD_AHEAD_AT), "down": (COW_HEAD_DOWN, COW_HEAD_DOWN_AT)},
    "tails": {"hanging": COW_TAIL, "swishing": COW_TAIL_SWISH},
    "tail_at": (-1, 1),
    "under": (COW_UDDER, (4, len(COW_TORSO))),
    "legs": {"stand": COW_LEG, "forward": COW_LEG_FORWARD, "back": COW_LEG_BACK},
    # Where the near hind and front legs stand on the torso, and how far the far ones are behind.
    "leg_x": (COW_HIND_X, COW_FRONT_X),
    "far_shift": (2, 1),
    # The near front leg folded under the chest of a lying cow: rows, and where on the torso.
    "folded": (("KKLM",), (COW_FRONT_X - 2, len(COW_TORSO) - 1)),
    "closed_eye": "d",
}


def four_legged_frame(animal, style, head="ahead", steps=None, tail="hanging", lying=False, head_drop=0):
    """One frame of a four-legged animal (COW, SHEEP) as rows of characters on its cell, facing
    right. `style` is a look, with the patterns of white on its torso and heads, if any; `steps`
    names the near and the far hind and front leg ("stand", "forward", "back"). A lying animal
    has its legs folded under it and its eyes closed. Returns the rows as strings."""
    cells = grid(*animal["size"])
    torso_x, torso_y = animal["torso_at"]
    top = torso_y + (animal["lying_drop"] if lying else 0)
    pattern = style.get("pattern")
    torso = animal["torso"] if pattern is None else patched(animal["torso"], pattern)
    legs_top = top + len(torso) - 2
    hind_x, front_x = animal["leg_x"]
    if not lying:
        (near_hind, near_front), (far_hind, far_front) = steps or (("stand", "stand"), ("stand", "stand"))
        far_hind_x, far_front_x = hind_x + animal["far_shift"][0], front_x + animal["far_shift"][1]
        for leg, x in ((far_hind, far_hind_x), (far_front, far_front_x)):
            rows = [row.replace("L", "N").replace("M", "N") for row in animal["legs"][leg]]
            paste(cells, rows, torso_x + x, legs_top)
    if tail is not None:
        tail_x, tail_y = animal["tail_at"]
        paste(cells, animal["tails"][tail], torso_x + tail_x, top + tail_y)
    paste(cells, torso, torso_x, top)
    if lying:
        rows, (x, y) = animal["folded"]
        paste(cells, rows, torso_x + x, top + y)
    else:
        if animal.get("under"):
            rows, (x, y) = animal["under"]
            paste(cells, rows, torso_x + x, top + y)
        for leg, x in ((near_hind, hind_x), (near_front, front_x)):
            paste(cells, animal["legs"][leg], torso_x + x, legs_top)
    rows, (x, y) = animal["heads"][head]
    if head in style.get("head_patterns", {}):
        rows = patched(rows, style["head_patterns"][head])
    if lying:
        rows = tuple(row.replace("e", animal["closed_eye"]) for row in rows)
    paste(cells, rows, torso_x + x, top + y + head_drop)
    return joined(cells)


# A walk: the near hind and front leg, then the far ones, for each of its four frames.
WALK_STEPS = [
    (("back", "forward"), ("forward", "back")),
    (("stand", "stand"), ("stand", "stand")),
    (("forward", "back"), ("back", "forward")),
    (("stand", "stand"), ("stand", "stand")),
]


def four_legged_sheet(animal, style, keys):
    """The rows of cells of a four-legged animal's sheet: it flicks its tail standing, chews with
    its head down and breathes lying down."""

    def frame(**pose):
        return to_picture(four_legged_frame(animal, style, **pose), keys, style["outline"])

    frames = {
        "idle": [frame(), frame(tail="swishing")],
        "walk": [frame(steps=steps) for steps in WALK_STEPS],
        "graze": [frame(head="down"), frame(head="down", head_drop=-1)],
        "sleep": [frame(lying=True), frame(lying=True, head_drop=1)],
    }
    return [frames[action] for action in ACTIONS]


def cow_sheet(look):
    style = COW_LOOKS[look]
    keys = COW_SHARED_KEYS | style["keys"]
    keys |= {"L": keys["b"], "M": keys["d"], "N": keys["d"], "K": "ink"}
    if "pattern" in style:
        # Pied cattle have white stockings.
        keys |= {"L": "lime", "M": "stone_light", "N": "stone_light"}
    return four_legged_sheet(COW, style, keys)


# --- All sheets ---------------------------------------------------------------------------

SPECIES = {
    "cow": (COW_SIZE, COW_LOOKS, cow_sheet),
}


def sheets():
    """Every sheet as (file name, cell size, rows of cells for palette.save)."""
    for species, (size, looks, sheet) in SPECIES.items():
        for look in looks:
            yield f"{species}_{look}", size, sheet(look)
