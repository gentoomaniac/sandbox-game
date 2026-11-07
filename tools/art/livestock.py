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
# Characters that are drawn over the outline instead of being outlined: the near leg and its
# shade, the far legs, hooves or paws, and the dark lower legs of a bay horse.
LEGS = {"L", "M", "N", "K", "P"}
# The far legs are drawn in the far leg's colour.
FAR_LEG = str.maketrans("LMP", "NNN")


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


def four_legged_frame(
    animal, style, head="ahead", steps=None, tail="hanging", lying=False, head_drop=0, lift=0, saddle=None
):
    """One frame of a four-legged animal (COW, SHEEP, DOG, HORSE ...) as rows of characters on its
    cell, facing right. `style` is a look, with the patterns of white on its torso and heads, if
    any; `steps` names the near and the far hind and front leg ("stand", "forward", "back", and
    for a runner "reach", "push" and "tuck"). A lying animal has its legs folded under it and its
    eyes closed; a running one is `lift` pixels off the ground between its strides. A horse can wear
    one of its `saddles` on its back. Returns the rows as strings."""
    cells = grid(*animal["size"])
    torso_x, torso_y = animal["torso_at"]
    top = torso_y + (animal["lying_drop"] if lying else 0) - lift
    pattern = style.get("pattern")
    torso = animal["torso"] if pattern is None else patched(animal["torso"], pattern)
    legs_top = top + len(torso) - 2
    hind_x, front_x = animal["leg_x"]
    if not lying:
        (near_hind, near_front), (far_hind, far_front) = steps or (("stand", "stand"), ("stand", "stand"))
        far_hind_x, far_front_x = hind_x + animal["far_shift"][0], front_x + animal["far_shift"][1]
        for leg, x in ((far_hind, far_hind_x), (far_front, far_front_x)):
            rows = [row.translate(FAR_LEG) for row in animal["legs"][leg]]
            paste(cells, rows, torso_x + x + leg_shift(animal, leg), legs_top)
    if tail is not None:
        tail_x, tail_y = animal["tail_at"]
        paste(cells, animal["tails"][tail], torso_x + tail_x, top + tail_y)
    paste(cells, torso, torso_x, top)
    if saddle is not None:
        rows, (x, y) = animal["saddles"][saddle]
        paste(cells, rows, torso_x + x, top + y)
    if lying:
        rows, (x, y) = animal["folded"]
        paste(cells, rows, torso_x + x, top + y)
    else:
        if animal.get("under"):
            rows, (x, y) = animal["under"]
            paste(cells, rows, torso_x + x, top + y)
        for leg, x in ((near_hind, hind_x), (near_front, front_x)):
            paste(cells, animal["legs"][leg], torso_x + x + leg_shift(animal, leg), legs_top)
    rows, (x, y) = animal["heads"][head]
    if head in style.get("head_patterns", {}):
        rows = patched(rows, style["head_patterns"][head])
    if lying:
        rows = tuple(row.replace("e", animal["closed_eye"]) for row in rows)
    paste(cells, rows, torso_x + x, top + y + head_drop)
    return joined(cells)


def leg_shift(animal, leg):
    """Where a leg's rows start, from where the leg joins the torso: further left for a leg
    that reaches back from its hip (the animal's `leg_shifts`)."""
    return animal.get("leg_shifts", {}).get(leg, 0)


# A walk: the near hind and front leg, then the far ones, for each of its four frames.
WALK_STEPS = [
    (("back", "forward"), ("forward", "back")),
    (("stand", "stand"), ("stand", "stand")),
    (("forward", "back"), ("back", "forward")),
    (("stand", "stand"), ("stand", "stand")),
]

# A gallop, for the animals that have running legs: stretched out off the ground, landing on the
# hind legs, gathered under the body, and pushing off from the front legs.
RUN_STEPS = [
    ((("push", "reach"), ("push", "reach")), 1),
    ((("forward", "back"), ("stand", "back")), 0),
    ((("tuck", "fold"), ("tuck", "fold")), 1),
    ((("back", "stand"), ("back", "forward")), 0),
]


def four_legged_sheet(animal, style, keys, saddle=None):
    """The rows of cells of a four-legged animal's sheet: it flicks its tail standing, chews with
    its head down and breathes lying down. A horse may wear a saddle (see `four_legged_frame`)."""

    def frame(**pose):
        return to_picture(four_legged_frame(animal, style, saddle=saddle, **pose), keys, style["outline"])

    lying_head = animal.get("lying_head", "ahead")
    frames = {
        "idle": [frame(), frame(tail="swishing")],
        "walk": [frame(steps=steps) for steps in WALK_STEPS],
        "graze": [frame(head="down"), frame(head="down", head_drop=-1)],
        "sleep": [frame(lying=True, head=lying_head), frame(lying=True, head=lying_head, head_drop=1)],
    }
    if "reach" in animal["legs"]:
        frames["run"] = [frame(steps=steps, lift=lift, tail="flying") for steps, lift in RUN_STEPS]
    else:
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


# --- Dogs ---------------------------------------------------------------------------------
#
# A farm dog of about 14 px from the rump to the nose and 10 px to its back: a short, deep body
# on sturdy legs, drawn like the cattle with a torso, a head and legs, and running legs for its
# gallop. The head has a clear stop between the skull and the muzzle. The three looks differ in
# their ears and tails as well as their coats. Keys: l, b, d light, base and shade of the coat;
# x, w, W of its white; e eye; n nose; L, M near leg and its shade, N far legs, K paw.

DOG_SIZE = (24, 18)
DOG_TORSO = (
    "lllllllll.",
    "bbbbbbbbbl",
    "bbbbbbbbbb",
    "dbbbbbbbbb",
    ".dd..ddbbd",
)
DOG_LEGS = {
    "stand": ("LM",) * 6 + ("KK",),
    "forward": ("LM.",) * 3 + (".LM",) * 3 + (".KK",),
    "back": (".LM",) * 3 + ("LM.",) * 3 + ("KK.",),
    "reach": ("LM...", ".LM..", "..LM.", "...LM", "...KK"),
    "push": ("...LM", "..LM.", ".LM..", "LM...", "KK..."),
    "tuck": ("LM..", ".LM.", "..LM", ".KK."),
    "fold": ("..LM", ".LM.", "LM..", ".KK."),
}
DOG = {
    "size": DOG_SIZE,
    "torso": DOG_TORSO,
    "torso_at": (6, 8),
    "lying_drop": 4,
    "lying_head": "rest",
    "tail_at": (-3, 0),
    "legs": DOG_LEGS,
    "leg_shifts": {"push": -3},
    "leg_x": (1, 7),
    "far_shift": (2, -1),
    "folded": (("KKLM",), (6, len(DOG_TORSO) - 1)),
    "closed_eye": "d",
}
# The farm collie: half-pricked ears with folded tips, a bushy tail carried low with a white tip,
# a white collar and chest.
COLLIE_PARTS = {
    "heads": {
        "ahead": (
            ("...dd....", "..lbbd...", "..bbbb...", ".bbbebbb.", ".bbbbbbbn", "..bxxxx..", "..xxx....", "..bb....."),
            (6, -6),
        ),
        "down": (("bb.......", "bbbdd....", ".bbbbb...", "..bbebbb.", "..bbbbbbn", "...xxx..."), (7, 2)),
        "rest": (("..dd.....", ".bbbb....", ".bbebbbbn", "..xxxx..."), (7, 0)),
    },
    "tails": {
        "hanging": (".bb", "bbb", "bb.", "bb.", "bx."),
        "swishing": ("..b", ".bb", "bbb", "bb.", "x.."),
        "flying": ("....", "xbbb", ".bbb", "....", "...."),
    },
}
COLLIE_PATTERN = (
    "..........",
    "..........",
    ".........w",
    "........ww",
    "......www.",
)
# A spitz: pricked, pointed ears, a wedge of a head, a ruff, and its bushy tail curled over its
# back.
SPITZ_PARTS = {
    "heads": {
        "ahead": (
            ("...d.....", "..dbd....", "..bbbb...", ".bbbebb..", ".bbbbbbbn", "lbbbbb...", "lbbb.....", "bbb......"),
            (6, -6),
        ),
        "down": (("bb.d.....", "bbdbd....", ".bbbbb...", "..bbebb..", "..bbbbbbn", "..lll...."), (7, 2)),
        "rest": (("..d......", ".dbd.....", ".bbebbbbn", "lbbbbb..."), (7, 0)),
    },
    "tails": {
        "hanging": (".lll.", "lbbbl", "lb.bb", ".l..."),
        "swishing": ("..ll.", ".lbbl", "lbb.b", "l...."),
        "flying": (".....", ".....", "lllll", "bbbb."),
    },
    "tail_at": (-2, -3),
}
# The hunting dog: drop ears hanging by the cheek, a long square muzzle, a deep chest and a thin
# straight tail; liver with white patches.
POINTER_PARTS = {
    "heads": {
        "ahead": (
            ("..lbb....", ".bbbbb...", ".ddbebbb.", ".ddbbbbbn", ".ddbbbbb.", "..bbb....", "..bb....."),
            (6, -5),
        ),
        "down": (("bb.......", "bbbb.....", ".ddbbb...", ".ddbebbb.", ".ddbbbbbn", "...bbbb.."), (7, 2)),
        "rest": ((".bbbb....", "ddbebbbbn", "ddbbbbbb."), (7, 1)),
    },
    "tails": {
        "hanging": ("...", "bbb", "...", "...", "..."),
        "swishing": ("...", ".bb", "b..", "...", "..."),
        "flying": ("....", "bbbb", "....", "....", "...."),
    },
}
POINTER_PATTERN = (
    "..........",
    "..ww......",
    ".wwww..ww.",
    "..www.www.",
    "......ww..",
)
DOG_LOOKS = {
    "collie": {
        "parts": COLLIE_PARTS,
        "keys": {"l": "soil_light", "b": "soil_mid", "d": "soil", "L": "lime", "M": "stone_light", "N": "stone_light"},
        "outline": "soil_dark",
        "pattern": COLLIE_PATTERN,
    },
    "spitz": {
        "parts": SPITZ_PARTS,
        "keys": {"l": "lime", "b": "stone_light", "d": "stone", "L": "stone_light", "M": "stone", "N": "stone"},
        "outline": "stone_dark",
    },
    "pointer": {
        "parts": POINTER_PARTS,
        "keys": {"l": "soil_mid", "b": "soil", "d": "soil_dark", "L": "soil", "M": "soil_dark", "N": "soil_dark"},
        "outline": "ink",
        "pattern": POINTER_PATTERN,
    },
}
DOG_SHARED_KEYS = {"x": "lime", "w": "lime", "W": "stone_light", "e": "ink", "n": "ink", "K": "ink"}


def dog_sheet(look):
    style = DOG_LOOKS[look]
    return four_legged_sheet(DOG | style["parts"], style, DOG_SHARED_KEYS | style["keys"])


# --- Cats ---------------------------------------------------------------------------------
#
# A small farm cat, about 12 px from the tail to the nose, with pricked ears and a long tail held
# up. Keys: l, b, d light, base and shade of the coat; s its stripes; e eye; n nose; L, N near
# and far leg, K paw.

CAT_SIZE = (16, 12)
CAT = {
    "size": CAT_SIZE,
    "torso": (".llllll.", "lsbsbsbl", "bsbsbsbb", ".dddddd."),
    "torso_at": (3, 5),
    "lying_drop": 3,
    "lying_head": "rest",
    "heads": {
        "ahead": (("d.d..", "bbbb.", "bebbn", ".bbb."), (6, -3)),
        "down": (("bb...", ".bbd.", ".bbbd", "..beb", "..bbn"), (7, 1)),
        "rest": (("d.d..", "bbbb.", "bdbbn"), (6, 0)),
    },
    "tails": {
        "hanging": (".b", ".b", "b.", "b.", "b."),
        "swishing": ("b.", "b.", ".b", ".b", "b."),
        "flying": ("..", "..", "..", "bb", ".."),
    },
    "tail_at": (-2, -3),
    "legs": {
        "stand": ("L", "L", "L", "K"),
        "forward": ("L.", "L.", ".L", ".K"),
        "back": (".L", ".L", "L.", "K."),
        "reach": ("L..", ".L.", "..K"),
        "push": ("..L", ".L.", "K.."),
        "tuck": ("L.", ".L", "K."),
        "fold": (".L", "L.", ".K"),
    },
    "leg_shifts": {"push": -2},
    "leg_x": (1, 6),
    "far_shift": (1, -1),
    "folded": (("KLL",), (5, 3)),
    "closed_eye": "d",
}
CAT_LOOKS = {
    # The grey-brown tabby, striped dark.
    "tabby": {"keys": {"l": "sand_light", "b": "sand", "d": "mud", "s": "mud_dark", "e": "olive"}, "outline": "mud_dark"},
    "black": {"keys": {"l": "stone_dark", "b": "bog_dark", "d": "ink", "s": "bog_dark", "e": "gold"}, "outline": "ink"},
    "ginger": {"keys": {"l": "maple_light", "b": "flame", "d": "rust", "s": "rust", "e": "olive"}, "outline": "russet_deep"},
}


def cat_sheet(look):
    style = CAT_LOOKS[look]
    keys = style["keys"]
    keys = keys | {"n": "petal", "L": keys["b"], "N": keys["d"], "K": keys["d"]}
    return four_legged_sheet(CAT, style, keys)


# --- Horses -------------------------------------------------------------------------------
#
# A heavy marsh horse of the Oldenburg kind, about 32 px (two tiles) from the tail to the nose,
# and a small pony drawn in the same cell. The neck and head rise ahead of the back, so that the
# back between the withers and the croup, the middle of the torso's top row, stays free for a
# saddle and a rider (task 81). Keys: l, b, d light, base and shade of the coat; m
# mane and tail; e eye; n muzzle; L, M near leg and its shade, P its dark lower part (a bay's
# black points), N far legs, K hoof.

HORSE_SIZE = (44, 36)
HORSE_TORSO = (
    "..llll.........lll......",
    ".lbbbbllllllllllbbbll...",
    "lbbbbbbbbbbbbbbbbbbbbbl.",
    "bbbbbbbbbbbbbbbbbbbbbbbb",
    "bbbbbbbbbbbbbbbbbbbbbbbb",
    "bbbbbbbbbbbbbbbbbbbbbbbb",
    "dbbbbbbbbbbbbbbbbbbbbbbd",
    "ddbbbbbbbbbbbbbbbbbbbbdd",
    ".dddddddddddddddddddddd.",
)
HORSE_LEGS = {
    "stand": ("LM",) * 8 + ("PP",) * 5 + ("KK",),
    "forward": ("LM.",) * 6 + (".LM", ".LM") + (".PP",) * 5 + (".KK",),
    "back": (".LM",) * 6 + ("LM.", "LM.") + ("PP.",) * 5 + ("KK.",),
    "reach": ("LM.....", "LM.....", ".LM....", ".LM....", "..LM...", "..LPP..", "...PP..", "....PP.", ".....PP", ".....KK"),
    "push": (".....LM", ".....LM", "....LM.", "....LM.", "...LM..", "..PP...", ".PP....", "PP.....", "PP.....", "KK....."),
    "tuck": ("LM...", "LM...", ".LM..", ".LM..", "..LM.", "..PP.", "..PP.", ".PP..", "KK..."),
    "fold": ("..LM.", "..LM.", ".LM..", "LM...", "LM...", "PP...", ".PP..", "..PP.", "..KK."),
}
HORSE = {
    "size": HORSE_SIZE,
    "torso": HORSE_TORSO,
    "torso_at": (8, 15),
    "lying_drop": 12,
    "heads": {
        "ahead": (
            (
                "......mmb....",
                "....mmmbbb...",
                "...mmbbbbbb..",
                "..mmbbbbebbb.",
                "..mbbbbbbbbbb",
                ".mmbbbbb.bbbn",
                ".mbbbbbb..nn.",
                ".mbbbbbb.....",
                "mmbbbbbb.....",
                "mbbbbbbb.....",
                "mbbbbbbb.....",
                "bbbbbbbb.....",
                "bbbbbbbb.....",
            ),
            (16, -10),
        ),
        "down": (
            (
                "mbbbbb......",
                "mmbbbbb.....",
                ".mmbbbbb....",
                "..mmbbbbb...",
                "...mmbbbbb..",
                "....mmbbbb..",
                ".....mbbbb..",
                "......bbbbm.",
                "......bebbb.",
                "......bbbbb.",
                "......bbbbb.",
                "......bbbbb.",
                "......bbbbb.",
                ".......bbbb.",
                ".......bbbb.",
                ".......bbbb.",
                ".......bbnn.",
                ".......nnn..",
            ),
            (18, 0),
        ),
    },
    "tails": {
        "hanging": ("mm..", "mmm.", "mmm.", ".mm.", ".mm.", ".mm.", ".mm.", ".mmm", "..mm"),
        "swishing": (".mm.", "mmm.", "mm..", "mm..", "mm..", ".mm.", "..mm", "..mm", "...m"),
        "flying": ("mm..", "mmmm", ".mmm", "..mm", "....", "....", "....", "....", "...."),
    },
    "tail_at": (-3, 0),
    "legs": HORSE_LEGS,
    "leg_shifts": {"push": -5},
    "leg_x": (2, 19),
    "far_shift": (2, -2),
    "folded": (("KKPPLM",), (15, len(HORSE_TORSO) - 1)),
    "closed_eye": "d",
    # The saddle on the dip of the back, and where its rows start on the torso: the cantle at the
    # back, the pommel over the withers, the flap with the stirrup hanging from it and the girth.
    "saddles": {
        "on": (
            (
                "q..........",
                "cq.......qc",
                "kcqqqqqqqcc",
                ".kcccccccck",
                ".kcccccck.g",
                "..kkckkk..g",
                "....ii....g",
                "...i..i...g",
                "...iiii....",
            ),
            (5, -1),
        ),
        "ridden": (
            (
                "q..........",
                "cq.......qc",
                "kcqqqqqqqcc",
                ".kcccccccck",
                ".kcccccck.g",
                "..kkckkk..g",
                "..........g",
                "..........g",
            ),
            (5, -1),
        ),
    },
    # Ridden, from the front and from behind (see `view_frame`): rows behind and in front of the
    # rider with where they start, the near and the far legs (their left columns) and the row
    # their tops start on, and how many rows of their lower part are dark. From the front the
    # chest with the saddle's pommel and flaps, and the head; from behind the neck and ears
    # beyond the rider, the rump with the cantle, and the tail.
    "views": {
        "front": {
            "behind": [
                (
                    (
                        ".....kqqk.....",
                        "...llllllll...",
                        ".llbbbbbbbbdd.",
                        "kbbbbbbbbbbbbk",
                        "kbbbbbbbbbbbbk",
                        "kbbbbbbbbbbbbk",
                        "lbbbbbbbbbbbbd",
                        "lbbbbbbbbbbbbd",
                        ".bbbbbbbbbbbd.",
                        ".dbbbbbbbbbdd.",
                        "..dbbbbbbbdd..",
                        "...dddddddd...",
                    ),
                    (15, 15),
                ),
            ],
            "in_front": [
                (
                    (
                        "d....d",
                        "bd..db",
                        "bbmmbb",
                        "lbmmbd",
                        "ebbbbe",
                        "lbbbbd",
                        ".bbbd.",
                        ".bbbd.",
                        ".bbbd.",
                        ".bbbd.",
                        ".nnnn.",
                        ".nnnn.",
                        "..nn..",
                    ),
                    (19, 9),
                ),
            ],
            "near_legs": (15, 27),
            "far_legs": (19, 24),
            "legs_top": 23,
            "points": 5,
        },
        "back": {
            "behind": [
                (("d..d",) + ("bmmb",) * 8, (20, 6)),
                (
                    (
                        "....kcqqck....",
                        "..llllllllll..",
                        ".lbbbbbbbbbbd.",
                        "lbbbbbbbbbbbbd",
                        "lbbbbbbbbbbbbd",
                        "lbbbbbbbbbbbbd",
                        "lbbbbbbbbbbbbd",
                        "lbbbbbbbbbbbbd",
                        "lbbbbbbbbbbbbd",
                        ".bbbbbbbbbbbd.",
                        ".dbbbbbbbbbdd.",
                        "..ddd....ddd..",
                    ),
                    (15, 15),
                ),
                ((".mm.",) * 6 + ("mmmm",) * 3 + (".mm.",) * 2, (20, 16)),
            ],
            "near_legs": (15, 27),
            "far_legs": (19, 24),
            "legs_top": 23,
            "points": 5,
        },
    },
}
# The pony: a smaller, rounder body on short legs, a thick neck and a shaggy mane.
PONY_PARTS = {
    "torso": (
        "..lll.......ll...",
        ".lbbbllllllllbbl.",
        "lbbbbbbbbbbbbbbbl",
        "bbbbbbbbbbbbbbbbb",
        "bbbbbbbbbbbbbbbbb",
        "dbbbbbbbbbbbbbbbd",
        ".ddddddddddddddd.",
    ),
    "torso_at": (12, 24),
    "lying_drop": 5,
    "heads": {
        "ahead": (
            ("....mmb...", "...mmbbb..", "..mmbbebb.", "..mbbbbbbb", ".mmbbbb.nn", ".mbbbbb...", "mbbbbbb...", "bbbbbbb...", "bbbbbbb..."),
            (11, -7),
        ),
        "down": (
            ("mbbbb.....", "mmbbbb....", ".mmbbbb...", "..mbbbbb..", "...mbbbbm.", "....bbebb.", "....bbbbb.", ".....bbbb.", ".....bbnn.", ".....nnn.."),
            (13, 0),
        ),
    },
    "tails": {
        "hanging": ("mm.", "mmm", "mm.", "mm.", ".m.", ".mm"),
        "swishing": (".m.", "mm.", "m..", "mm.", ".mm", "..m"),
        "flying": ("mm..", "mmmm", "..mm", "....", "....", "...."),
    },
    "tail_at": (-2, 0),
    "legs": {
        "stand": ("LM", "LM", "LM", "PP", "PP", "PP", "KK"),
        "forward": ("LM.", "LM.", "LM.", ".PP", ".PP", ".PP", ".KK"),
        "back": (".LM", ".LM", ".LM", "PP.", "PP.", "PP.", "KK."),
        "reach": ("LM...", ".LM..", "..PP.", "...PP", "...KK"),
        "push": ("...LM", "..LM.", ".PP..", "PP...", "KK..."),
        "tuck": ("LM..", ".LM.", "..PP", ".KK."),
        "fold": ("..LM", ".LM.", "PP..", ".KK."),
    },
    "leg_shifts": {"push": -3},
    "leg_x": (2, 13),
    "far_shift": (2, -2),
    "folded": (("KKPLM",), (10, 6)),
    "saddles": {
        "on": (("q.......", "cq.....q", "kcqqqqqc", ".kccccck", ".kcccck.", "..kckk..", "...ii...", "..i..i..", "..iiii.."), (4, -1)),
        "ridden": (("q.......", "cq.....q", "kcqqqqqc", ".kccccck", ".kcccck.", "..kckk.."), (4, -1)),
    },
    "views": {
        "front": {
            "behind": [
                (
                    (
                        "....kqqk....",
                        "..llllllll..",
                        "kbbbbbbbbbbk",
                        "kbbbbbbbbbbk",
                        "lbbbbbbbbbbd",
                        ".bbbbbbbbbd.",
                        ".dbbbbbbbdd.",
                        "..dddddddd..",
                    ),
                    (16, 24),
                ),
            ],
            "in_front": [
                (("d....d", "bmmmmb", "lmmmmd", "ebbbbe", "lbbbbd", ".bbbd.", ".bbbd.", ".nnnn.", "..nn.."), (19, 19)),
            ],
            "near_legs": (16, 26),
            "far_legs": (19, 24),
            "legs_top": 29,
            "points": 3,
        },
        "back": {
            "behind": [
                (("d..d",) + ("bmmb",) * 5, (20, 19)),
                (
                    (
                        "....kqqk....",
                        "..llllllll..",
                        "lbbbbbbbbbbd",
                        "lbbbbbbbbbbd",
                        "lbbbbbbbbbbd",
                        "lbbbbbbbbbbd",
                        ".bbbbbbbbbd.",
                        "..dddddddd..",
                    ),
                    (16, 24),
                ),
                ((".mm.",) * 3 + ("mmmm",) * 3 + (".mm.",), (20, 25)),
            ],
            "near_legs": (16, 26),
            "far_legs": (19, 24),
            "legs_top": 29,
            "points": 3,
        },
    },
}
HORSE_LOOKS = {
    # Bay: a red-brown coat with the mane, the tail and the lower legs black.
    "bay": {"keys": {"l": "soil_light", "b": "soil_mid", "d": "soil", "m": "ink", "P": "ink", "n": "soil_dark"}, "outline": "soil_dark"},
    "black": {"keys": {"l": "stone", "b": "stone_dark", "d": "ink", "m": "ink", "P": "stone_dark", "n": "ink"}, "outline": "ink"},
    # Dapple grey, darker on the legs.
    "grey": {"keys": {"l": "lime", "b": "stone_light", "d": "stone", "m": "stone", "P": "stone", "n": "stone_dark"}, "outline": "stone_dark"},
    # A dun pony with a dark mane and legs.
    "pony": {
        "parts": PONY_PARTS,
        "keys": {"l": "sand_light", "b": "sand", "d": "mud", "m": "mud_dark", "P": "mud_dark", "n": "mud_dark"},
        "outline": "mud_dark",
    },
}


# The saddle's leather (light, base and shade), its girth and its iron stirrup.
SADDLE_KEYS = {"q": "rust", "c": "rust_dark", "k": "russet_deep", "g": "russet_deep", "i": "stone_light"}


def horse_keys(style):
    keys = {"e": "ink", "K": "ink"} | style["keys"] | SADDLE_KEYS
    return keys | {"L": keys["b"], "M": keys["d"], "N": keys["d"]}


def horse_sheet(look, saddle=None):
    style = HORSE_LOOKS[look]
    return four_legged_sheet(HORSE | style.get("parts", {}), style, horse_keys(style), saddle)


# --- Riding -------------------------------------------------------------------------------
#
# A ridden horse (task 81) in the rows of the player's sheets, facing down, up, left and right
# (left is the mirror of right), with nine columns: standing, four frames of the walk and four of
# the trot. Two sheets per look: horse_<look>_ridden is drawn behind the rider and
# horse_<look>_ridden_over in front of them (the head of a horse coming towards the viewer; it is
# empty in the other rows). From the side it is the saddled horse of the sheets above, the
# stirrup under the rider's foot; from the front and from behind it is drawn from the rows of its
# `views`. game/scenes/player_view.gd mirrors the columns, the lifts and where the rider sits.

RIDING_FACINGS = ("down", "up", "left", "right")
# The trot, from the side: a diagonal pair of legs forward and the other back, then all four off
# the ground (`lift` 1) with one pair folded, then the other way round.
TROT_STEPS = [
    ((("back", "forward"), ("forward", "back")), 0),
    ((("tuck", "stand"), ("stand", "fold")), 1),
    ((("forward", "back"), ("back", "forward")), 0),
    ((("stand", "fold"), ("tuck", "stand")), 1),
]
# From the front and from behind: how far each leg is raised (the near left and right legs, then
# the far left and right ones between them) and the lift, for the standing frame, the walk and the
# trot. A trot raises a near leg with the far leg of the other side.
VIEW_STEPS = [
    ((0, 0, 0, 0), 0),
    ((1, 0, 0, 1), 0),
    ((0, 0, 0, 0), 0),
    ((0, 1, 1, 0), 0),
    ((0, 0, 0, 0), 0),
    ((2, 0, 0, 2), 0),
    ((0, 0, 0, 0), 1),
    ((0, 2, 2, 0), 0),
    ((0, 0, 0, 0), 1),
]


def view_leg(cells, x, top, bottom, points, far):
    """A leg seen from the front or from behind, from `top` down to its hoof on row `bottom`: two
    pixels wide, lit on the left, its last `points` rows above the hoof dark (a bay's black
    points); a far leg is one pixel in the far legs' colour."""
    for y in range(top, bottom):
        upper = y < bottom - points
        if far:
            cells[y][x] = "N"
        else:
            cells[y][x], cells[y][x + 1] = ("L", "M") if upper else ("P", "P")
    cells[bottom][x] = "K"
    if not far:
        cells[bottom][x + 1] = "K"


def view_frame(animal, view, raised, lift):
    """The front ("front") or back ("back") view of a ridden horse as rows of characters: its body,
    the legs under it raised by `raised` (see VIEW_STEPS) and all of it `lift` pixels off the
    ground. Returns the rows behind the rider and the rows in front of them."""
    width, height = animal["size"]
    parts = animal["views"][view]
    behind, in_front = grid(width, height), grid(width, height)
    ground = height - 1 - lift
    legs_top = parts["legs_top"] - lift
    near_x, far_x = parts["near_legs"], parts["far_legs"]
    for x, up in zip(far_x, raised[2:]):
        view_leg(behind, x, legs_top + 2, ground - up, parts["points"], far=True)
    for x, up in zip(near_x, raised[:2]):
        view_leg(behind, x, legs_top, ground - up, parts["points"], far=False)
    for name, cells in (("behind", behind), ("in_front", in_front)):
        for rows, (x, y) in parts.get(name, ()):
            paste(cells, rows, x, y - lift)
    return joined(behind), joined(in_front)


def ridden_sheets(look):
    """The two sheets of a ridden horse of a look (see above), as rows of cells."""
    style = HORSE_LOOKS[look]
    animal = HORSE | style.get("parts", {})
    keys = horse_keys(style)

    def picture(rows):
        return to_picture(rows, keys, style["outline"])

    empty = [[None] * animal["size"][0] for _ in range(animal["size"][1])]
    side = [four_legged_frame(animal, style, saddle="ridden")]
    side += [four_legged_frame(animal, style, steps=steps, saddle="ridden") for steps in WALK_STEPS]
    side += [
        four_legged_frame(animal, style, steps=steps, lift=lift, tail="swishing", saddle="ridden")
        for steps, lift in TROT_STEPS
    ]
    behind, in_front = {}, {}
    for view, facing in (("front", "down"), ("back", "up")):
        frames = [view_frame(animal, view, raised, lift) for raised, lift in VIEW_STEPS]
        behind[facing] = [picture(rows) for rows, _ in frames]
        in_front[facing] = [picture(rows) for _, rows in frames]
    behind["right"] = [picture(rows) for rows in side]
    behind["left"] = [[row[::-1] for row in cell] for cell in behind["right"]]
    return (
        [behind[facing] for facing in RIDING_FACINGS],
        [in_front.get(facing, [empty] * len(VIEW_STEPS)) for facing in RIDING_FACINGS],
    )


# --- All sheets ---------------------------------------------------------------------------

SPECIES = {
    "cow": (COW_SIZE, COW_LOOKS, cow_sheet),
    "sheep": (SHEEP_SIZE, SHEEP_LOOKS, sheep_sheet),
    "chicken": (CHICKEN_SIZE, CHICKEN_LOOKS, chicken_sheet),
    "rabbit": (RABBIT_SIZE, RABBIT_LOOKS, rabbit_sheet),
    "dog": (DOG_SIZE, DOG_LOOKS, dog_sheet),
    "cat": (CAT_SIZE, CAT_LOOKS, cat_sheet),
    "horse": (HORSE_SIZE, HORSE_LOOKS, horse_sheet),
}


def sheets():
    """Every sheet as (file name, cell size, rows of cells for palette.save)."""
    for species, (size, looks, sheet) in SPECIES.items():
        for look in looks:
            yield f"{species}_{look}", size, sheet(look)
    # A saddled horse: the same sheet with the saddle on (task 81).
    for look in HORSE_LOOKS:
        yield f"horse_{look}_saddled", HORSE_SIZE, horse_sheet(look, "on")
        behind, in_front = ridden_sheets(look)
        yield f"horse_{look}_ridden", HORSE_SIZE, behind
        yield f"horse_{look}_ridden_over", HORSE_SIZE, in_front
