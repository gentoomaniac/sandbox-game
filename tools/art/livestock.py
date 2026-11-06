"""Art for the farm animals: one sheet per species and look at assets/wildlife/<species>_<look>.png.

Every sheet has the same rows (ACTIONS): standing idle, walking, grazing (pecking, for a hen),
asleep and running, one column per frame, and the animal stands in the bottom centre of its cell,
facing right (the game flips it to face left). game/scenes/wildlife/wildlife_sprites.gd
mirrors the cell sizes and the frames. The looks are those of the region around 1700-1800 (see
docs/art-style.md, "Props and animals").

An animal is put together from parts as rows of characters, like the deer of animals.py: a
body, a head and legs. The characters stand for the parts of a coat (light, base, shade), the
white of a pied coat, horns, eyes and so on; a look is the colours given to them, and a pattern
of white patches for a pied coat. The body and the head get a one pixel outline in the darkest
colour of the coat; the legs are drawn over it, so that thin legs stay thin.
"""

import animals
from animals import outline_in_place, paste

# The rows of every sheet, with their frames.
ACTIONS = {"idle": 2, "walk": 4, "graze": 2, "sleep": 2, "run": 4}
# Characters that are drawn over the outline instead of being outlined.
LEGS = {"L", "M", "N", "K"}


def to_picture(rows, keys, outline, bare=LEGS):
    """A grid of characters as a picture: the outline goes around everything but the legs (or
    the characters of `bare`)."""
    body = [[None if char in bare else keys.get(char) for char in row] for row in rows]
    picture = outline_in_place(body, outline)
    for y, row in enumerate(rows):
        for x, char in enumerate(row):
            if char in bare:
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
    # Cattle and sheep only run from something, and then they hurry along at a walk.
    frames["run"] = frames["walk"]
    return [frames[action] for action in ACTIONS]


def cow_sheet(look):
    style = COW_LOOKS[look]
    keys = COW_SHARED_KEYS | style["keys"]
    keys |= {"L": keys["b"], "M": keys["d"], "N": keys["d"], "K": "ink"}
    if "pattern" in style:
        # Pied cattle have white stockings.
        keys |= {"L": "lime", "M": "stone_light", "N": "stone_light"}
    return four_legged_sheet(COW, style, keys)


# --- Sheep --------------------------------------------------------------------------------
#
# A small heath or marsh sheep, about 14 px long, in a round coat of wool with a lumpy edge.
# Keys: l, b, d light, base and shade of the wool; f, F face and its shade; r ear; e eye;
# L, N near and far leg, K hoof.

SHEEP_SIZE = (22, 16)
SHEEP_TORSO = (
    "..ll.lll.ll...",
    ".llllllllllll.",
    "lbbbbdbbbbbbbl",
    "bbdbbbbbbdbbbb",
    "bbbbbbdbbbbbbb",
    "bdbbbbbbbbbdbb",
    ".bbbdbbbbbbbb.",
    "..dddddddddd..",
)
SHEEP_LEG = ("L", "L", "L", "L", "L", "K")
SHEEP = {
    "size": SHEEP_SIZE,
    "torso": SHEEP_TORSO,
    "torso_at": (3, 4),
    "lying_drop": 4,
    "heads": {
        "ahead": (("..lb..", ".rbff.", "rr.fef", "...fff", "...fFF"), (11, -3)),
        "down": (("lbb...", "bbbf..", ".rfff.", "rr.fe.", "...ff.", "...fF."), (12, 4)),
    },
    "tails": {"hanging": ("l", "b", "b"), "swishing": ("b.", ".b", ".b")},
    "tail_at": (-1, 1),
    "legs": {
        "stand": SHEEP_LEG,
        "forward": ("L.", "L.", "L.", ".L", ".L", ".K"),
        "back": (".L", ".L", ".L", "L.", "L.", "K."),
    },
    "leg_x": (2, 10),
    "far_shift": (2, 2),
    "folded": (("KL",), (9, len(SHEEP_TORSO) - 1)),
    "closed_eye": "F",
}
WHITE_WOOL = {"l": "cream", "b": "lime", "d": "stone_light"}
DARK_FACE = {"f": "stone_dark", "F": "ink", "r": "stone_dark", "e": "sand", "L": "stone_dark", "N": "ink", "K": "ink"}
SHEEP_LOOKS = {
    # The white marsh sheep of the dykes, with a pale face.
    "white": {
        "keys": WHITE_WOOL
        | {"f": "sand_light", "F": "sand", "r": "skin_shade", "e": "ink", "L": "sand_light", "N": "sand", "K": "mud_dark"},
        "outline": "stone",
    },
    # The grey heath sheep of the Geest (Heidschnucke), black in the face and legs; drawn hornless.
    "grey": {"keys": {"l": "lime", "b": "stone_light", "d": "stone"} | DARK_FACE, "outline": "stone_dark"},
    # White wool and a black face.
    "black_faced": {"keys": WHITE_WOOL | DARK_FACE, "outline": "stone"},
}


def sheep_sheet(look):
    style = SHEEP_LOOKS[look]
    return four_legged_sheet(SHEEP, style, style["keys"])


# --- Chickens -----------------------------------------------------------------------------
#
# A hen of about 9x10 px, drawn whole for each frame. Keys: l, b, d light, base and shade of the
# plumage; t tail; r comb and wattles; k beak; e eye; L legs. The rooster has more: c the
# rest of his big comb, s the sickle feathers of his tail and h the hackles of his neck; a hen
# has no c or s, and her neck is plumage.

CHICKEN_SIZE = (12, 12)
CHICKEN_LEGS = ("....L.L.....", "...LL.LL....")
CHICKEN_STEPS = [
    ("...L...L....", "..LL...LL..."),
    ("....L.L.....", "...LL.LL...."),
    (".....LL.....", "....LLL....."),
    ("....L.L.....", "...LL.LL...."),
]
CHICKEN_BODY = (
    ".......c....",
    "......crr...",
    "s.....rbbb..",
    "ss....bbebk.",
    "ts....hbbrk.",
    "tt...lhhb...",
    "tbl.lbbbbb..",
    "tbbllbbbbb..",
    ".tbbbbbbbd..",
    "..ddbbbbd...",
)
CHICKEN_PECK = (
    "............",
    "............",
    "s...........",
    "ss..........",
    "tsl.........",
    "tblllbb.....",
    "tbbbbbhhb...",
    ".tbbbbbhhbc.",
    "..ddbbbbhrr.",
    "....dd.bbeb.",
    "....L.L.rbk.",
    "...LL.LL..k.",
)
CHICKEN_PECK_UP = (
    "............",
    "............",
    "s...........",
    "ss..........",
    "tsl......c..",
    "tblllbb.crr.",
    "tbbbbbhhbbb.",
    ".tbbbbbhhbek",
    "..ddbbbbbrk.",
    "....dd...r..",
    "....L.L.....",
    "...LL.LL....",
)
CHICKEN_SLEEP = (
    "............",
    "............",
    "............",
    "............",
    "s...........",
    "ss.....c....",
    "ts....crr...",
    "tt..lhrbbb..",
    "tbllhhbbdbk.",
    "tbbbbbbbbbr.",
    ".dbbbbbbbbd.",
    "..ddddddddd.",
)
# Breathing out: the head sinks into the plumage.
CHICKEN_SLEEP_LOW = CHICKEN_SLEEP[:5] + (
    "ss..........",
    "ts.....c....",
    "tt..lhcrr...",
    "tbllhhrbbb..",
    "tbbbbbbbdbk.",
) + CHICKEN_SLEEP[10:]
CHICKEN_SHARED_KEYS = {"r": "red_light", "k": "ochre", "e": "ink", "L": "ochre"}
CHICKEN_LOOKS = {
    # A brown farm hen.
    "brown": {
        "keys": {"l": "ochre", "b": "ochre_dark", "d": "umber", "t": "soil", "h": "ochre_dark"},
        "outline": "soil_dark",
    },
    "white": {"keys": {"l": "cream", "b": "lime", "d": "stone_light", "t": "lime", "h": "lime"}, "outline": "stone"},
    # The rooster: red-brown, golden hackles, a dark tail of sickle feathers and a big comb.
    "rooster": {
        "keys": {
            "l": "maple_light",
            "b": "rust",
            "d": "rust_dark",
            "t": "green_deep",
            "s": "green_deep",
            "h": "gold",
            "c": "red_light",
        },
        "outline": "russet_deep",
    },
}


def chicken_sheet(look):
    style = CHICKEN_LOOKS[look]
    keys = CHICKEN_SHARED_KEYS | style["keys"]
    blink = tuple(row.replace("e", "b") for row in CHICKEN_BODY)
    frames = {
        "idle": [CHICKEN_BODY + CHICKEN_LEGS, blink + CHICKEN_LEGS],
        "walk": [CHICKEN_BODY + step for step in CHICKEN_STEPS],
        "graze": [CHICKEN_PECK, CHICKEN_PECK_UP],
        "sleep": [CHICKEN_SLEEP, CHICKEN_SLEEP_LOW],
        "run": [CHICKEN_BODY + step for step in CHICKEN_STEPS],
    }
    return [[to_picture(rows, keys, style["outline"]) for rows in frames[action]] for action in ACTIONS]


# --- Rabbits -------------------------------------------------------------------------------
#
# The tame rabbit is the wild rabbit of animals.py in other coats: it sits, nibbles and hops in
# the same frames, and only sleeping, flat in a loaf with its ears laid back, is its own. Keys
# as there (b coat, l light underside, s tail, p inside of the ear, e eye), and w for the white
# of a Dutch rabbit.

RABBIT_SIZE = animals.RABBIT["size"]
RABBIT_SLEEP = [
    "...bbb..",
    ".bbbbbbb",
    "bbbbbbbb",
    "sbbbbbbb",
    "ssbbllll",
]
RABBIT_SLEEP_LOW = [
    "........",
    "...bbbb.",
    ".bbbbbbb",
    "sbbbbbbb",
    "ssbbllll",
]
RABBIT_LOOKS = {
    # The grey-brown of the wild rabbit (agouti).
    "agouti": {"keys": animals.RABBIT_KEYS, "outline": "mud"},
    # White with pink eyes.
    "white": {"keys": {"b": "lime", "l": "cream", "s": "snow_light", "p": "petal", "e": "red_light"}, "outline": "stone"},
    # Dutch: dark ears, muzzle and rump, a white blaze, collar and forelegs.
    "dutch": {
        "keys": {"b": "stone_dark", "l": "lime", "s": "lime", "p": "petal", "e": "ink", "w": "lime"},
        "outline": "ink",
    },
}


def dutch(rows):
    """A rabbit frame in the coat of a Dutch rabbit: a band of white from the eye down to the
    forelegs (the blaze and the collar), and the dark coat on the ears, the muzzle and the rump."""
    eye_row = next((y for y, row in enumerate(rows) if "e" in row), len(rows))
    eye_x = rows[eye_row].index("e") if eye_row < len(rows) else len(rows[0])
    result = []
    for y, row in enumerate(rows):
        if y < eye_row:
            result.append(row)
            continue
        result.append("".join("w" if char == "b" and eye_x - 3 <= x <= eye_x - 1 else char for x, char in enumerate(row)))
    return result


def rabbit_sheet(look):
    style = RABBIT_LOOKS[look]
    wild = animals.RABBIT["actions"]
    frames = {
        "idle": wild["sit"],
        "walk": wild["hop"] + [wild["sit"][0]],
        "graze": wild["nibble"],
        "sleep": [RABBIT_SLEEP, RABBIT_SLEEP_LOW],
        "run": wild["hop"] + [wild["sit"][0]],
    }
    sheet = {"size": RABBIT_SIZE, "outline": style["outline"], "keys": style["keys"]}

    def coat(frame):
        if look != "dutch":
            return frame
        if frame[0] == "lift":
            return ("lift", frame[1], dutch(frame[2]))
        return dutch(frame)

    return [[animals.frame_picture(sheet, coat(frame)) for frame in frames[action]] for action in ACTIONS]


# --- All sheets ---------------------------------------------------------------------------

SPECIES = {
    "cow": (COW_SIZE, COW_LOOKS, cow_sheet),
    "sheep": (SHEEP_SIZE, SHEEP_LOOKS, sheep_sheet),
    "chicken": (CHICKEN_SIZE, CHICKEN_LOOKS, chicken_sheet),
    "rabbit": (RABBIT_SIZE, RABBIT_LOOKS, rabbit_sheet),
}


def sheets():
    """Every sheet as (file name, cell size, rows of cells for palette.save)."""
    for species, (size, looks, sheet) in SPECIES.items():
        for look in looks:
            yield f"{species}_{look}", size, sheet(look)
