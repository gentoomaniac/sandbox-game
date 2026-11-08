"""The meadow flowers of the region: the flower row of assets/decorations.png (see terrain.py),
drawn at 32 px per tile.

Each species of `SPECIES` has `VARIANTS` tiles side by side, in the order of the list, which
game/scenes/terrain_tileset.gd repeats (FLOWER_SPECIES): a lone small plant (just opened or
fading), a few plants, and two of the thick of a drift, whose plants are spread evenly over
the tile so neighbouring tiles run together into a carpet without a visible grid. Plants stand
on a stem of their own over a leaf or two, lit from the left; their heads are small pictures (a
few pixels, lit on the upper left) in the palette's flower accents. The seasons remap them like
the other decorations (autumn browns `cream`, `gold` and `petal`; `lime`, `blossom` and
`heather` keep).
"""

import random

from canvas import GAME_TILE, blank

# The order of the atlas row, in the order they come into bloom over the year.
SPECIES = (
    "wood_anemone",
    "dandelion",
    "cuckooflower",
    "daisy",
    "buttercup",
    "red_campion",
    "thrift",
    "red_clover",
    "white_clover",
    "yarrow",
    "knapweed",
    "meadowsweet",
    "sea_lavender",
    "heather",
)
VARIANTS = 4
SMALL, FEW = 0, 1
# A drift tile has a plant in most cells of a grid this many pixels wide, jittered.
DRIFT_CELL = 8
DRIFT_CHANCE = 0.85

STEM = "green_dark"
LEAF = ("green_light", "green")

# The letters of the heads below.
KEYS = {
    "l": "lime", "c": "cream", "s": "stone_light", "y": "gold", "o": "ochre", "p": "petal",
    "b": "blossom", "h": "heather", "H": "heather_dark", "g": "green_light", "d": "green_dark",
}
# Per species: the stem's height (small plant, grown: from, to), its colour, the leaves at its foot
# ("rosette" lies flat, "pair" stands off the stem, "trefoil" is clover), and its head, small and
# grown, as rows of KEYS letters ("." clear) whose bottom middle sits on the stem's top. A second
# head ("side") branches off the stem of a grown plant.
PLANTS = {
    "wood_anemone": {"stem": (3, (5, 6)), "leaves": "pair", "small": [".l.", "lyl", ".s."],
                     "head": [".l.l.", "llyll", ".lsl.", "..s.."]},
    "dandelion": {"stem": (2, (3, 5)), "leaves": "rosette", "small": ["yy", "oo"],
                  "head": [".yy.", "yyyy", "yyyo", ".oo."]},
    "cuckooflower": {"stem": (6, (8, 12)), "leaves": "pair", "small": [".b.", "bpb"],
                     "head": [".b.b", "bpbb", ".bpb", "..d."], "side": [".b", "bp"]},
    "daisy": {"stem": (2, (3, 4)), "leaves": "rosette", "small": ["l", "s"],
              "head": [".l.l.", "lsyyl", "llyls", ".lsl."]},
    "buttercup": {"stem": (6, (10, 14)), "leaves": "pair", "small": ["yy", "o."],
                  "head": ["y.y", "yyy", "oyo"], "side": ["yy", "oy"]},
    "red_campion": {"stem": (6, (10, 13)), "leaves": "pair", "small": ["pb", "pH"],
                    "head": [".b.p.", "bpHpp", ".ppH.", "..d.."]},
    "thrift": {"stem": (4, (6, 8)), "leaves": "cushion", "small": ["bp", "pH"],
               "head": [".bp.", "bbpp", "bppH", ".pH."]},
    "red_clover": {"stem": (2, (2, 3)), "leaves": "trefoil", "small": ["bp", "pH"],
                   "head": [".bp.", "bppp", "pphH", ".HH."]},
    "white_clover": {"stem": (1, (1, 2)), "leaves": "trefoil", "small": ["ll", "ss"],
                     "head": [".ll.", "llcl", "lcls", ".ss."]},
    "yarrow": {"stem": (6, (8, 12)), "leaves": "feather", "small": ["ll", "ss"],
               "head": [".l.l.", "llcll", "lslsl", ".d.d."]},
    "knapweed": {"stem": (6, (8, 12)), "leaves": "pair", "small": ["p", "H"],
                 "head": ["p.p.", "phpp", ".phh", ".HH.", ".dd."]},
    "meadowsweet": {"stem": (8, (10, 16)), "leaves": "pair", "small": [".c", "cl", "lc"],
                    "head": [".c..", "clc.", "lcl.", "clcs", "lcls", ".ls.", ".d.."]},
    "sea_lavender": {"stem": (4, (6, 10)), "leaves": "cushion", "small": ["h.h", ".H."],
                     "head": ["h.h.h", "hHhHh", ".d.d.", "..d.."]},
}


def put(tile, x, y, colour):
    if 0 <= x < GAME_TILE and 0 <= y < GAME_TILE:
        tile[y][x] = colour


def picture(tile, rows, x, y):
    """Draws `rows` of KEYS letters with their bottom middle at (x, y)."""
    width = len(rows[0])
    for row_index, row in enumerate(rows):
        for column, letter in enumerate(row):
            if letter != ".":
                put(tile, x - width // 2 + column, y - len(rows) + 1 + row_index, KEYS[letter])


def leaves(tile, kind, x, foot, rng):
    """The leaves at the foot of a stem."""
    if kind == "rosette":
        for dx, colour in ((-3, LEAF[1]), (-2, LEAF[0]), (-1, LEAF[0]), (1, LEAF[1]), (2, LEAF[1]), (3, STEM)):
            put(tile, x + dx, foot, colour)
        put(tile, x - 2, foot - 1, LEAF[0])
        put(tile, x + 2, foot - 1, LEAF[1])
    elif kind == "trefoil":
        for dx, dy, colour in ((-2, 0, LEAF[0]), (-1, -1, LEAF[0]), (-1, 0, LEAF[1]), (1, 0, LEAF[0]), (2, -1, LEAF[0]), (2, 0, LEAF[1]), (0, 0, STEM)):
            put(tile, x + dx, foot + dy, colour)
    elif kind == "cushion":
        for dx in range(-3, 4):
            put(tile, x + dx, foot, "olive" if dx % 2 else STEM)
        for dx in (-2, 0, 2):
            put(tile, x + dx, foot - 1, "olive")
    elif kind == "feather":
        for dy, dx in ((1, -1), (2, 1), (3, -1), (4, 1)):
            put(tile, x + dx, foot - dy, LEAF[0])
            put(tile, x + 2 * dx, foot - dy + 1, LEAF[1])
    else:
        side = rng.choice((-1, 1))
        put(tile, x + side, foot - 1, LEAF[0])
        put(tile, x + 2 * side, foot - 2, LEAF[0])
        put(tile, x - side, foot - 3, LEAF[1])


def plant(tile, name, x, foot, rng, is_small):
    """One plant of a species with its foot at (x, foot)."""
    if name == "heather":
        heather(tile, x, foot, rng, is_small)
        return
    kind = PLANTS[name]
    small_height, (low, high) = kind["stem"]
    height = small_height if is_small else rng.randint(low, high)
    for step in range(height):
        put(tile, x, foot - step, STEM if step < height - 1 or name != "red_campion" else "green")
    leaves(tile, kind["leaves"], x, foot, rng)
    top = foot - height
    if is_small:
        picture(tile, kind["small"], x, top)
        return
    if "side" in kind:
        side = rng.choice((-1, 1))
        branch_y = foot - height // 2
        put(tile, x + side, branch_y - 1, STEM)
        put(tile, x + 2 * side, branch_y - 2, STEM)
        picture(tile, kind["side"], x + 2 * side + (side > 0), branch_y - 3)
    picture(tile, kind["head"], x, top)


def heather(tile, x, foot, rng, is_small):
    """A low bush of woody twigs covered in tiny purple bells: the Geest heath in late summer.
    Lit on the left, the bells darker on the right and low down."""
    width = 2 if is_small else rng.randint(4, 6)
    for dx in range(-width, width + 1):
        put(tile, x + dx, foot, "olive" if dx % 2 else STEM)
        height = 1 + round((width - abs(dx)) * (1.2 if is_small else 1.0)) + rng.randint(0, 1)
        for step in range(1, height + 1):
            lit = dx < 0 or step == height
            colour = "heather" if lit and rng.random() < 0.8 else "heather_dark"
            put(tile, x + dx, foot - step, colour if (dx + step) % 3 else STEM)
        if height > 1 and rng.random() < 0.5:
            put(tile, x + dx, foot - height - 1, "blossom" if dx < 0 else "heather")


def flower_tile(name, variant):
    """One tile of a species: its plants over the tile, the back ones first."""
    rng = random.Random(f"{name}-{variant}")
    if variant == SMALL:
        feet = [(rng.randint(9, GAME_TILE - 10), rng.randint(20, 26))]
    elif variant == FEW:
        feet = [(rng.randint(5, 12), rng.randint(18, 24)), (rng.randint(18, 26), rng.randint(24, 30))]
    else:
        # Feet on a jittered grid, the top row low enough for the tallest stem.
        feet = [
            (cell_x + rng.randrange(DRIFT_CELL), cell_y + rng.randrange(DRIFT_CELL))
            for cell_y in range(DRIFT_CELL + 2, GAME_TILE, DRIFT_CELL)
            for cell_x in range(2, GAME_TILE - 4, DRIFT_CELL)
            if rng.random() < DRIFT_CHANCE
        ]
    tile = blank(GAME_TILE)
    for x, foot in sorted(feet, key=lambda f: f[1]):
        plant(tile, name, x, min(foot, GAME_TILE - 1), rng, variant == SMALL)
    return tile


def flower_row():
    """The flower row of the decoration atlas: every species' variants, in `SPECIES` order."""
    return [flower_tile(name, variant) for name in SPECIES for variant in range(VARIANTS)]
