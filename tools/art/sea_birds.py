"""Art for the sea birds of the coast: one sheet per kind at assets/wildlife/<kind>.png.

Oystercatchers probe the tidal mud in pairs and small groups (see docs/art-style.md, "Props and
animals"). The sheets are laid out and drawn like those of birds.py: one row per action and one
column per frame, in the order game/scenes/wildlife/wildlife_sprites.gd mirrors; a bird stands
in the bottom centre of its cell facing right and flies in its middle, seen from a little above.
The body gets a one pixel outline; the bill and the legs are drawn over it, so that they stay
thin.
"""

from birds import on_cell, on_legs, standing
from livestock import to_picture

# Bills and legs, drawn over the outline: o and O the bill and its shade, L and M the near and
# the far leg.
BARE = {"o", "O", "L", "M"}

# --- Oystercatcher ------------------------------------------------------------------------
#
# Black above and white below, with a long orange-red bill and pink legs: about 10 px long
# with the bill and 7 px tall (a sparrow is 5 px, a goose 12 px), a wingspan of 14 px. Keys: k
# black, w white, e the red eye, o and O the bill, L and M the legs. Its outline is black too,
# so the black parts read as one shape and the white is edged.

OYSTERCATCHER_SIZE = (16, 12)
OYSTERCATCHER_KEYS = {
    "k": "ink",
    "w": "lime",
    "e": "red_light",
    "o": "flame",
    "O": "red_light",
    "L": "skin",
    "M": "skin_shade",
}
OYSTERCATCHER_OUTLINE = "ink"

OYSTERCATCHER_HEAD_UP = (
    "......kk....",
    ".....kkeooo.",
    "......kk....",
    "..kkkkkkk...",
    "kkkkkkkkw...",
    ".kkkwwwww...",
    "...wwwww....",
)
# Looking round: the head turned towards the viewer, the bill foreshortened.
OYSTERCATCHER_LOOKING_ROUND = ("......kk....", ".....kekoo...") + OYSTERCATCHER_HEAD_UP[2:]
# Probing: the head down, the bill on the mud ahead, then pushed into it.
OYSTERCATCHER_PROBING = (
    "............",
    "............",
    "............",
    "..kkkkkkk...",
    "kkkkkkkkkk..",
    ".kkkwwwwkke.",
    "...wwwww..ko",
    "...........o",
    "...........O",
)
OYSTERCATCHER_PROBING_DEEP = OYSTERCATCHER_PROBING[:7] + ("...........O",)
OYSTERCATCHER_LEGS = ("LM", "LM")
OYSTERCATCHER_STEP = ("LM", "L.M")
OYSTERCATCHER_STEP_BACK = ("LM", "M.L")
OYSTERCATCHER_LEG_AT = (4, 7)

# Flying: black with a broad white bar along the wing and a white rump. Wings up, level (the far
# one above the body, the near one below) and down.
OYSTERCATCHER_WINGS_UP = (
    "......wk......",
    ".....wkk......",
    "....wwkk......",
    "...wwkkk......",
    "wwkkkkkkkkkeoo",
    ".wwkkkwwww....",
)
OYSTERCATCHER_WINGS_LEVEL = (
    "....wwkk......",
    "wwkkkkkkkkkeoo",
    ".wwkkkwwww....",
    "....wwkkk.....",
    ".....wwkk.....",
    "......wk......",
)
OYSTERCATCHER_WINGS_DOWN = (
    "wwkkkkkkkkkeoo",
    ".wwkkkwwww....",
    "....wwkkk.....",
    ".....wwkk.....",
    "......wwk.....",
    ".......k......",
)
OYSTERCATCHER_FLIGHT = [
    (OYSTERCATCHER_WINGS_UP, 4),
    (OYSTERCATCHER_WINGS_LEVEL, 1),
    (OYSTERCATCHER_WINGS_DOWN, 0),
]
OYSTERCATCHER_FLIGHT_LEFT = 1
OYSTERCATCHER_FLIGHT_BODY_Y = 5
OYSTERCATCHER_STANDING_LEFT = 2


def oystercatcher_frame(body, legs=OYSTERCATCHER_LEGS):
    return on_legs(body, legs, OYSTERCATCHER_LEG_AT)


OYSTERCATCHER_ACTIONS = {
    "stand": [oystercatcher_frame(OYSTERCATCHER_HEAD_UP), oystercatcher_frame(OYSTERCATCHER_LOOKING_ROUND)],
    "probe": [oystercatcher_frame(OYSTERCATCHER_PROBING), oystercatcher_frame(OYSTERCATCHER_PROBING_DEEP)],
    "walk": [
        oystercatcher_frame(OYSTERCATCHER_HEAD_UP, OYSTERCATCHER_STEP),
        oystercatcher_frame(OYSTERCATCHER_HEAD_UP, OYSTERCATCHER_STEP_BACK),
    ],
}


def oystercatcher_sheet():
    size = OYSTERCATCHER_SIZE
    rows = [[standing(frame, size, OYSTERCATCHER_STANDING_LEFT) for frame in frames] for frames in OYSTERCATCHER_ACTIONS.values()]
    rows.append(
        [on_cell(shape, size, OYSTERCATCHER_FLIGHT_LEFT, OYSTERCATCHER_FLIGHT_BODY_Y - body_y) for shape, body_y in OYSTERCATCHER_FLIGHT]
    )
    return [[to_picture(frame, OYSTERCATCHER_KEYS, OYSTERCATCHER_OUTLINE, BARE) for frame in frames] for frames in rows]


def sheets():
    """(name, cell size, rows of cells) of every sheet."""
    return [("oystercatcher", OYSTERCATCHER_SIZE, oystercatcher_sheet())]
