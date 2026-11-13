"""Art for the big birds of the marsh: one sheet per kind at assets/wildlife/<kind>.png.

The white stork walks the wet meadows and stands on the roofs; greylag geese graze the marsh in
flocks and fly over in a V (see docs/art-style.md, "Props and animals"). Like the other wildlife
sheets (animals.py) a sheet has one row per action and one column per frame, in the order of its
actions, which game/scenes/wildlife/wildlife_sprites.gd mirrors; the bird stands in the bottom
centre of its cell, facing right, and flies in its middle.

A frame is rows of characters, written as the bird is seen: side on while it stands or walks,
from a little above while it flies, so the far wing shows above the body and the near wing below
it at the level of the beat. The body gets a one pixel outline; the bill and the legs are drawn
over it, so that they stay thin.
"""

from animals import paste
from canvas import mirrored
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
    # A frog in the bill.
    "f": "dry_light",
    "F": "olive",
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
# Swallowing: the head thrown back with a frog across the bill, its legs dangling, then gone.
STORK_SWALLOWING = (
    ".......fFf........",
    "......F.rFf.......",
    "......F.rR.F......",
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
    "swallow": [stork_frame(STORK_SWALLOWING), stork_frame(STORK_CLATTER_SHUT)],
}
# Each wing beat with the row of its body.
STORK_FLIGHT = [(STORK_WINGS_UP, 10), (STORK_WINGS_LEVEL, 3), (STORK_WINGS_DOWN, 0)]


def stork_sheet():
    rows = [
        [standing(frame, STORK_SIZE, STORK_STANDING_LEFT) for frame in frames] for frames in STORK_ACTIONS.values()
    ]
    rows.append([on_cell(shape, STORK_SIZE, STORK_FLIGHT_LEFT, STORK_FLIGHT_BODY_Y - body_y) for shape, body_y in STORK_FLIGHT])
    return [[to_picture(frame, STORK_KEYS, STORK_OUTLINE, BARE) for frame in frames] for frames in rows]


# --- Greylag goose ------------------------------------------------------------------------
#
# About 12 px long and 10 px tall with the head up, a wingspan of 22 px. Keys: l, b, d light, base
# and shade of the grey-brown plumage (the shade also the barring of the folded wing); p the pale
# breast and belly, w the white under the tail, e eye, o the orange bill, L and M the pink legs.

GOOSE_SIZE = (24, 18)
GOOSE_KEYS = {
    "l": "bare_light",
    "b": "bare",
    "d": "mud",
    "p": "stone_light",
    "w": "lime",
    "e": "ink",
    "o": "flame",
    "r": "flame",
    "L": "skin",
    "M": "skin_shade",
}
GOOSE_OUTLINE = "mud_dark"

GOOSE_HEAD_UP = (
    "..........bb...",
    ".........bbeor.",
    ".........bb....",
    "..........b....",
    "..........b....",
    ".........pb....",
)
GOOSE_LOOKING_ROUND = (
    "..........bb...",
    ".........bebo..",
    ".........bb....",
    "..........b....",
    "..........b....",
    ".........pb....",
)
GOOSE_BODY = (
    "...llllllppb...",
    ".llbdbdbbbpp...",
    "wbbdbdbbbppp...",
    ".wbbbbbbpppp...",
    "...bbbpppp.....",
)
GOOSE_GRAZING = (
    "...............",
    "...............",
    "...............",
    "...............",
    "...............",
    "...............",
    "...lllllllll...",
    ".llbdbdbbbbbb..",
    "wbbdbdbbbbbbbb.",
    ".wbbbbbbpp..bb.",
    "...bbbppp....b.",
    ".............bb",
    "............bbe",
)
# Nibbling: the tip of the bill in the grass.
GOOSE_BILL_IN_GRASS = ("..............r",)
GOOSE_LEGS = ("LM", "LM", "LM")
GOOSE_STEP = ("LM", "L.M", "L..M")
GOOSE_STEP_BACK = ("LM", "M.L", "M..L")
GOOSE_LEG_AT = (5, 11)

# Flying, from a little above like the stork: the neck stretched, the long wings grey, paler in
# front and dark at the tips and along the back edge.
GOOSE_WINGS_UP = (
    ".........d.......",
    "........dd.......",
    "........ddl......",
    ".......dddl......",
    ".......ddll......",
    "......dddll......",
    "......ddlll......",
    ".....ddllll......",
    ".wwbbbbbbbbbbbbeo",
    "..wbbbbbbpppp....",
)
GOOSE_WINGS_LEVEL = (
    ".......ddd.......",
    "......dddll......",
    ".wwbbbbbbbbbbbbeo",
    "..wbbbbbbpppp....",
    "......ddllll.....",
    "......dddlll.....",
    "......dddlll.....",
    ".......ddlll.....",
    ".......dddll.....",
    "........ddl......",
    "........dd.......",
)
GOOSE_WINGS_DOWN = (
    ".wwbbbbbbbbbbbbeo",
    "..wbbbbbbpppp....",
    "......ddllll.....",
    "......dddlll.....",
    ".......ddlll.....",
    ".......dddl......",
    "........ddl......",
    "........dd.......",
)
GOOSE_FLIGHT = [(GOOSE_WINGS_UP, 8), (GOOSE_WINGS_LEVEL, 2), (GOOSE_WINGS_DOWN, 0)]
GOOSE_FLIGHT_LEFT = 3
GOOSE_FLIGHT_BODY_Y = 9
GOOSE_STANDING_LEFT = 5


# Flying down the screen (from the front: the head with the orange bill and the pale breast) or
# up it (from behind: the back, the white band over the tail), the wings up, level and down: the
# left half of each map is drawn, the right one mirrored and a shade darker (canvas.mirrored).
GOOSE_SHADED = {"p": "l", "l": "b", "b": "d", "w": "p"}
GOOSE_FRONT = (
    [
        "d.........",
        "dd........",
        ".dl.....bb",
        ".ddl....eb",
        "..ddl....o",
        "...ddlpplp",
        ".....ddllp",
        "........lp",
        ".........l",
    ],
    [
        "........bb",
        "........eb",
        ".........o",
        "...pppppbp",
        ".dllllllpp",
        "dddddd..lp",
        "........lp",
        ".........l",
    ],
    [
        "........bb",
        "........eb",
        ".........o",
        ".....ppplp",
        "...ppllllp",
        ".pllddd.lp",
        "pldd....lp",
        "ld.......l",
        "d.........",
    ],
)
GOOSE_BACK = (
    [
        "d.........",
        "dd........",
        ".dl.....bb",
        ".ddl....lb",
        "..ddl....b",
        "...ddlpplb",
        ".....ddlbd",
        "........ww",
        ".........b",
    ],
    [
        "........bb",
        "........lb",
        ".........b",
        "...ppppplb",
        ".dllllllbd",
        "dddddd..bb",
        "........ww",
        ".........b",
    ],
    [
        "........bb",
        "........lb",
        ".........b",
        ".....ppplb",
        "...ppllllb",
        ".pllddd.bd",
        "pldd....ww",
        "ld.......b",
        "d.........",
    ],
)
# The cell's row of the top of each beat's map: the head stays on one row.
GOOSE_HEAD_ON_TOP = (3, 5, 5)


def goose_head_on(view):
    return [on_cell(mirrored(half, GOOSE_SHADED), GOOSE_SIZE, 2, top) for half, top in zip(view, GOOSE_HEAD_ON_TOP)]


def goose_frame(head, legs=GOOSE_LEGS):
    return on_legs(head + GOOSE_BODY, legs, GOOSE_LEG_AT)


GOOSE_ACTIONS = {
    "stand": [goose_frame(GOOSE_HEAD_UP), goose_frame(GOOSE_LOOKING_ROUND)],
    "graze": [on_legs(GOOSE_GRAZING, GOOSE_LEGS, GOOSE_LEG_AT), on_legs(GOOSE_GRAZING + GOOSE_BILL_IN_GRASS, GOOSE_LEGS, GOOSE_LEG_AT)],
    "walk": [goose_frame(GOOSE_HEAD_UP, GOOSE_STEP), goose_frame(GOOSE_HEAD_UP, GOOSE_STEP_BACK)],
}


def goose_sheet():
    rows = [
        [standing(frame, GOOSE_SIZE, GOOSE_STANDING_LEFT) for frame in frames] for frames in GOOSE_ACTIONS.values()
    ]
    rows.append([on_cell(shape, GOOSE_SIZE, GOOSE_FLIGHT_LEFT, GOOSE_FLIGHT_BODY_Y - body_y) for shape, body_y in GOOSE_FLIGHT])
    rows += [goose_head_on(GOOSE_FRONT), goose_head_on(GOOSE_BACK)]
    return [[to_picture(frame, GOOSE_KEYS, GOOSE_OUTLINE, BARE) for frame in frames] for frames in rows]


# --- Hooded crow --------------------------------------------------------------------------
#
# About 10 px long with the bill and 8 px tall standing (a goose is 12 and 10), a wingspan of 14
# px: the black hood, wings and tail, the back and belly ash-grey. Keys: K black, k its sheen
# where the light falls, g the grey and G its shade, e the eye's glint, b the black bill, L and M
# the near and the far leg. The outline is black too, so the black parts read as one shape and
# the grey is edged.

CROW_SIZE = (16, 12)
CROW_KEYS = {
    "K": "ink",
    "k": "stone_dark",
    "g": "stone_light",
    "G": "stone",
    "e": "stone",
    "b": "ink",
    "B": "stone_dark",
    "L": "stone_dark",
    "M": "ink",
}
CROW_BARE = {"b", "L", "M"}
CROW_OUTLINE = "ink"

CROW_HEAD_UP = (
    ".......kK...",
    "......KKebb.",
)
CROW_LOOKING_ROUND = (
    ".......kK...",
    "......KeKb..",
)
CROW_BODY = (
    ".....gKKK...",
    "...kkkgKgg..",
    ".KKKKKKggg..",
    "K....gggg...",
)
# Pecking: the body tipped forward, the tail up, the bill at the ground; then in it.
CROW_PECKING = (
    "............",
    "............",
    "K...........",
    ".KKkk.......",
    "..KKKKggg...",
    "...ggggKKK..",
    "........KeK.",
    "..........b.",
)
CROW_STABBING = (
    "............",
    "K...........",
    ".KKk........",
    "..KKKkgg....",
    "...KggggKK..",
    "....ggg.KKK.",
    "........KKe.",
    ".........KK.",
)
CROW_LEGS = ("LM", "LM")
CROW_STEP = ("LM", "M.L")
CROW_STEP_BACK = ("LM", "L.M")
CROW_LEG_AT = (5, 6)
CROW_STANDING_LEFT = 2

# Flying, from a little above like the goose: the grey back between the black head and tail, the
# broad black wings with the fingers of their tips spread; up, level and down. The maps are thin:
# the outline makes every wing three pixels wide.
CROW_WINGS_UP = (
    "...K.K.......",
    "....KK.......",
    ".....KK......",
    "K.....KK.....",
    "KK.gggKKK....",
    ".KKggggggKebb",
    "....ggg......",
)
CROW_WINGS_LEVEL = (
    "......kK.....",
    "K.....KK.....",
    "KKgggggggKebb",
    ".KKgKKKKKK...",
    "....KKK......",
    "...KK........",
    "...K.........",
)
CROW_WINGS_DOWN = (
    "K............",
    "KKgggggggKebb",
    ".KKgKKKKKK...",
    ".....KKK.....",
    "....KK.......",
    "...K.K.......",
)
CROW_FLIGHT = [(CROW_WINGS_UP, 5), (CROW_WINGS_LEVEL, 2), (CROW_WINGS_DOWN, 1)]
CROW_FLIGHT_LEFT = 1
CROW_FLIGHT_BODY_Y = 6

# Flying down the screen (from the front: the head with its glints and the bill, the black bib
# over the grey breast) or up it (from behind: the grey back, the black tail), the wings up,
# level and down: the left half of each map is drawn, the right one mirrored and a shade darker.
CROW_SHADED = {"g": "G", "k": "K"}
CROW_FRONT = (
    [
        "K......",
        ".K.....",
        "..K..kk",
        "..KK.eK",
        "...KKKB",
        ".....gg",
        "......K",
    ],
    [
        ".....kk",
        ".....eK",
        "KKKKKKB",
        ".....gg",
        "......K",
    ],
    [
        ".....kk",
        ".....eK",
        "...KKKB",
        ".KK..gg",
        "K.....K",
    ],
)
CROW_BACK = (
    [
        "K......",
        ".K.....",
        "..K..kk",
        "..KK.KK",
        "...KKgg",
        ".....gg",
        "......K",
        ".....K.",
    ],
    [
        ".....kk",
        ".....KK",
        "KKKKKgg",
        ".....gg",
        "......K",
        ".....K.",
    ],
    [
        ".....kk",
        ".....KK",
        "...KKgg",
        ".KK..gg",
        "K.....K",
        ".....K.",
    ],
)
# The cell's row of the top of each beat's map: the head stays on one row.
CROW_HEAD_ON_TOP = (2, 4, 4)


def crow_frame(head, legs=CROW_LEGS):
    return on_legs(head + CROW_BODY, legs, CROW_LEG_AT)


def crow_head_on(view):
    return [on_cell(mirrored(half, CROW_SHADED), CROW_SIZE, 1, top) for half, top in zip(view, CROW_HEAD_ON_TOP)]


CROW_ACTIONS = {
    "stand": [crow_frame(CROW_HEAD_UP), crow_frame(CROW_LOOKING_ROUND)],
    "peck": [on_legs(CROW_PECKING, CROW_LEGS, CROW_LEG_AT), on_legs(CROW_STABBING, CROW_LEGS, CROW_LEG_AT)],
    "walk": [crow_frame(CROW_HEAD_UP, CROW_STEP), crow_frame(CROW_HEAD_UP, CROW_STEP_BACK)],
}


def crow_sheet():
    rows = [[standing(frame, CROW_SIZE, CROW_STANDING_LEFT) for frame in frames] for frames in CROW_ACTIONS.values()]
    rows.append([on_cell(shape, CROW_SIZE, CROW_FLIGHT_LEFT, CROW_FLIGHT_BODY_Y - body_y) for shape, body_y in CROW_FLIGHT])
    rows += [crow_head_on(CROW_FRONT), crow_head_on(CROW_BACK)]
    return [[to_picture(frame, CROW_KEYS, CROW_OUTLINE, CROW_BARE) for frame in frames] for frames in rows]


def sheets():
    """(name, cell size, rows of cells) of every sheet."""
    return [("stork", STORK_SIZE, stork_sheet()), ("goose", GOOSE_SIZE, goose_sheet()), ("crow", CROW_SIZE, crow_sheet())]
