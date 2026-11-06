"""Art for the big birds of the marsh: one sheet per kind at assets/wildlife/<kind>.png.

The white stork walks the wet meadows and stands on the roofs (see docs/art-style.md, "Props and
animals"). Like the other wildlife sheets (animals.py) a sheet has one row per action and one
column per frame, in the order of its actions, which game/scenes/wildlife/wildlife_sprites.gd
mirrors; the bird stands in the bottom centre of its cell, facing right, and flies in its middle.

A frame is rows of characters, written as the bird is seen: side on while it stands or walks,
from a little above while it flies, so the far wing shows above the body and the near wing below
it at the level of the beat. The body gets a one pixel outline; the bill and the legs are drawn
over it, so that they stay thin.
"""

from animals import paste
from livestock import to_picture

# Bills and legs (red or orange, shaded, and the near and far leg): drawn over the outline.
BARE = {"r", "R", "L", "M"}

# --- White stork --------------------------------------------------------------------------
#
# About 16 px tall standing (a metre; the character is 27 px), with a wingspan of 28 px. Keys: w
# white and s its shade, k the black flight feathers, e eye; r and R the red bill and its shaded
# side; L and M the near and the far leg.

STORK_SIZE = (32, 26)
STORK_KEYS = {
    "w": "lime",
    "s": "stone_light",
    "k": "ink",
    "e": "ink",
    "r": "red_light",
    "R": "ember",
    "L": "red_light",
    "M": "ember",
}
STORK_OUTLINE = "stone"

# Standing: the body and the head, the neck between them; the legs come below (STORK_LEGS).
STORK_STANDING = (
    "...........ww.....",
    "..........wwerrr..",
    "..........ww..Rrr.",
    "...........w......",
    "...........ww.....",
    "..........sww.....",
    "...wwwwwwwwww.....",
    ".wwwwwwwwwwws.....",
    "kkkkkkkwwwwss.....",
    ".kkkkkkkkssss.....",
    "....kkkk..........",
)
# The head turned towards the viewer: the bill foreshortened.
STORK_LOOKING_ROUND = ("...........ww.....", "..........wwerr...", "..........ww..R...") + STORK_STANDING[3:]
# Hunting: the neck held forward and down, the bill pointing at the grass ahead.
STORK_HUNTING = (
    "..................",
    "..................",
    "..................",
    "..................",
    "..................",
    "..................",
    "...wwwwwwww.......",
    ".wwwwwwwwwwww.....",
    "kkkkkkkwwwwwsww...",
    ".kkkkkkkkssss.ww..",
    "....kkkk.......ww.",
    "...............wwe",
    "................wr",
    ".................r",
    ".................R",
)
# Striking: the bill stabs into the grass.
STORK_STRIKING = (
    "..................",
    "..................",
    "..................",
    "..................",
    "..................",
    "..................",
    "...wwwwwwww.......",
    ".wwwwwwwwwwww.....",
    "kkkkkkkwwwwwsw....",
    ".kkkkkkkkssss.w...",
    "....kkkk......ww..",
    "...............w..",
    "...............ww.",
    "...............wwe",
    "................wr",
    ".................r",
    ".................r",
    ".................R",
)
# Clattering: the head thrown back onto the shoulders, the bill pointing at the sky, shut and
# open.
STORK_CLATTER_SHUT = (
    "........r.........",
    "........rR........",
    "........rR........",
    ".......wer........",
    ".......www........",
    "........ww........",
    "...wwwwwwww.......",
    ".wwwwwwwwwws......",
    "kkkkkkkwwwwss.....",
    ".kkkkkkkkssss.....",
    "....kkkk..........",
)
STORK_CLATTER_OPEN = (
    ".......r.R........",
    ".......r.R........",
    "........rR........",
    ".......wer........",
    ".......www........",
    "........ww........",
) + STORK_CLATTER_SHUT[6:]
# The legs below the body: standing, and a step with the near or the far leg lifted.
STORK_LEGS = (".LM.", ".LM.", ".LM.", ".LM.", ".LM.", ".LM.", "LLMM")
STORK_NEAR_STEP = (".LM..", ".LM..", ".ML..", ".M.L.", ".M..L", ".M..L", "MM....")
STORK_FAR_STEP = (".LM..", ".LM..", ".LM..", ".L.M.", ".L..M", ".L..M", "LL....")

# Flying, seen from a little above: legs trailing, neck stretched, the wings white in front and
# black behind and at the tips. Wings up, level (the far one above the body, the near one below)
# and down.
STORK_WINGS_UP = (
    ".........k.k.k.........",
    ".........kkkkkk........",
    "........kkkkkww........",
    "........kkkkkww........",
    ".......kkkkkwww........",
    ".......kkkkwwww........",
    "......kkkkwwwww........",
    "......kkkkwwwww........",
    ".....kkkkwwwwww........",
    ".....kkkwwwwwww........",
    "LLL.wwwwwwwwwwwwwwwerrr",
    "...wwwwwwwwwwwsssss..RR",
)
STORK_WINGS_LEVEL = (
    "........kkkkkk.........",
    ".......kkkkkwww........",
    "......kkkkwwwww........",
    "LLL.wwwwwwwwwwwwwwwerrr",
    "...wwwwwwwwwwwsssss..RR",
    ".....kkkkwwwwwww.......",
    ".....kkkkkwwwwww.......",
    "......kkkkwwwwww.......",
    "......kkkkkwwwww.......",
    ".......kkkkkwwww.......",
    ".......kkkkkkwww.......",
    "........kkkkkkkk.......",
    "........k.k.k.k........",
)
STORK_WINGS_DOWN = (
    "LLL.wwwwwwwwwwwwwwwerrr",
    "...wwwwwwwwwwwsssss..RR",
    ".....kkkkkwwwwww.......",
    "......kkkkkwwwww.......",
    "......kkkkkwwwww.......",
    ".......kkkkkwwww.......",
    ".......kkkkkkwww.......",
    "........kkkkkkww.......",
    "........kkkkkkk........",
    ".........k.k.k.........",
)


# The legs stand at this column of a standing frame, from this row down to its last.
STORK_LEG_AT = (5, 11)
# Where the frames sit on the cell: standing ones at the bottom centre, flying ones with the
# body on the row of STORK_FLIGHT_BODY_Y (each names the row of its shape the body is on).
STORK_STANDING_LEFT = 8
STORK_FLIGHT_LEFT = 4
STORK_FLIGHT_BODY_Y = 13


def on_legs(rows, legs, leg_at):
    """A standing or walking bird as rows of characters: its rows (counted from the top of the
    frame) with the legs drawn in from `leg_at` (column, row) down."""
    leg_x, leg_y = leg_at
    width = max(len(row) for row in rows)
    cells = [list(row.ljust(width, ".")) for row in rows]
    cells += [list("." * width) for _ in range(leg_y + len(legs) - len(cells))]
    paste(cells, legs, leg_x, leg_y)
    return ["".join(row) for row in cells]


def stork_frame(body, legs=STORK_LEGS):
    return on_legs(body, legs, STORK_LEG_AT)


def on_cell(shape, size, left, top):
    """The shape on a cell of `size`, its top left corner at (`left`, `top`)."""
    width, height = size
    rows = []
    for y in range(height):
        row = shape[y - top] if 0 <= y - top < len(shape) else ""
        rows.append(("." * left + row).ljust(width, ".")[:width])
    return rows


def standing(shape, size, left):
    return on_cell(shape, size, left, size[1] - len(shape))


STORK_ACTIONS = {
    "stand": [stork_frame(STORK_STANDING), stork_frame(STORK_LOOKING_ROUND)],
    "walk": [
        stork_frame(STORK_HUNTING, STORK_NEAR_STEP),
        stork_frame(STORK_HUNTING),
        stork_frame(STORK_HUNTING, STORK_FAR_STEP),
        stork_frame(STORK_HUNTING),
    ],
    "strike": [stork_frame(STORK_HUNTING), stork_frame(STORK_STRIKING)],
    "clatter": [stork_frame(STORK_CLATTER_SHUT), stork_frame(STORK_CLATTER_OPEN)],
}
# Each wing beat with the row of its body.
STORK_FLIGHT = [(STORK_WINGS_UP, 10), (STORK_WINGS_LEVEL, 3), (STORK_WINGS_DOWN, 0)]


def stork_sheet():
    rows = [
        [standing(frame, STORK_SIZE, STORK_STANDING_LEFT) for frame in frames] for frames in STORK_ACTIONS.values()
    ]
    rows.append([on_cell(shape, STORK_SIZE, STORK_FLIGHT_LEFT, STORK_FLIGHT_BODY_Y - body_y) for shape, body_y in STORK_FLIGHT])
    return [[to_picture(frame, STORK_KEYS, STORK_OUTLINE, BARE) for frame in frames] for frames in rows]


def sheets():
    """(name, cell size, rows of cells) of every sheet."""
    return [("stork", STORK_SIZE, stork_sheet())]
