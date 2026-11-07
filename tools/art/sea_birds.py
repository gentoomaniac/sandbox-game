"""Art for the sea birds of the coast: one sheet per kind at assets/wildlife/<kind>.png.

Oystercatchers and dunlin probe the tidal mud, herring gulls walk the shore and swim
(see docs/art-style.md, "Props and animals").

The sheets are laid out and drawn like those of birds.py: one row per action and one column per
frame, in the order game/scenes/wildlife/wildlife_sprites.gd mirrors; a bird stands in the bottom
centre of its cell facing right and flies in its middle, seen from a little above. The body gets a
one pixel outline; the bill and the legs are drawn over it, so that they stay thin.
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


# --- Dunlin -------------------------------------------------------------------------------
#
# A small wader in tight flocks, grey above and white below in its winter dress, with a black
# bill drooping at the tip: about 7 px long and 6 px tall, a wingspan of 9 px. Keys: l and s the
# light and the base grey, w white, e eye, o the bill, L and M the legs.

DUNLIN_SIZE = (10, 8)
DUNLIN_KEYS = {
    "l": "stone_light",
    "s": "stone",
    "w": "lime",
    "e": "ink",
    "o": "ink",
    "L": "stone_dark",
    "M": "ink",
}
DUNLIN_OUTLINE = "stone_dark"

DUNLIN_HEAD_UP = (
    "....ll..",
    "...lseo.",
    "lsssslwo",
    ".ssswww.",
    "..www...",
)
DUNLIN_LOOKING_ROUND = ("....ll..", "...leso.") + DUNLIN_HEAD_UP[2:]
# Probing: the head down and the bill on the mud, then in it, quick as a sewing machine.
DUNLIN_PROBING = (
    "........",
    "........",
    "lsssss..",
    ".ssswwle",
    "..www..o",
    ".......o",
    "........",
)
DUNLIN_PROBING_DEEP = DUNLIN_PROBING[:4] + ("..www..o", "........", "........")
DUNLIN_LEGS = ("LM", "LM")
DUNLIN_STEP = ("LM", "L.M")
DUNLIN_STEP_BACK = ("LM", "M.L")
DUNLIN_LEG_AT = (3, 5)

# Flying: grey wings with a white bar, a white belly.
DUNLIN_WINGS_UP = (
    "....wl...",
    "...wls...",
    "..wlss...",
    "ssssssleo",
    ".wwwww...",
)
DUNLIN_WINGS_LEVEL = (
    "..wlss...",
    "ssssssleo",
    ".wwwww...",
    "...wlss..",
    "....wl...",
)
DUNLIN_WINGS_DOWN = (
    "ssssssleo",
    ".wwwww...",
    "...wlss..",
    "....wls..",
    ".....w...",
)
DUNLIN_FLIGHT = [(DUNLIN_WINGS_UP, 3), (DUNLIN_WINGS_LEVEL, 1), (DUNLIN_WINGS_DOWN, 0)]
DUNLIN_FLIGHT_LEFT = 0
DUNLIN_FLIGHT_BODY_Y = 4
DUNLIN_STANDING_LEFT = 1


def dunlin_frame(body, legs=DUNLIN_LEGS):
    return on_legs(body, legs, DUNLIN_LEG_AT)


DUNLIN_ACTIONS = {
    "stand": [dunlin_frame(DUNLIN_HEAD_UP), dunlin_frame(DUNLIN_LOOKING_ROUND)],
    "probe": [dunlin_frame(DUNLIN_PROBING), dunlin_frame(DUNLIN_PROBING_DEEP)],
    "walk": [dunlin_frame(DUNLIN_HEAD_UP, DUNLIN_STEP), dunlin_frame(DUNLIN_HEAD_UP, DUNLIN_STEP_BACK)],
}


def dunlin_sheet():
    size = DUNLIN_SIZE
    rows = [[standing(frame, size, DUNLIN_STANDING_LEFT) for frame in frames] for frames in DUNLIN_ACTIONS.values()]
    rows.append([on_cell(shape, size, DUNLIN_FLIGHT_LEFT, DUNLIN_FLIGHT_BODY_Y - body_y) for shape, body_y in DUNLIN_FLIGHT])
    return [[to_picture(frame, DUNLIN_KEYS, DUNLIN_OUTLINE, BARE) for frame in frames] for frames in rows]


# --- Herring gull -------------------------------------------------------------------------
#
# White with a pale blue-grey back and black wing tips, a yellow bill with a red spot and pink
# legs: about 13 px long and 11 px tall, a wingspan of 18 px. It walks the mud and the shore,
# and swims on the sea. Keys: w white, g and G the grey of the back and wings and its shade, k
# the black tips, e eye, o the bill and O its red spot, L and M the legs, f the ring of foam
# around a swimming gull.

GULL_SIZE = (20, 16)
GULL_KEYS = {
    "w": "lime",
    "g": "snow_shadow",
    "G": "snow_deep",
    "k": "ink",
    "e": "ink",
    "o": "gold",
    "O": "red_light",
    "L": "skin",
    "M": "skin_shade",
    "f": "foam",
}
GULL_OUTLINE = "stone"
# The foam is drawn over the outline as well.
GULL_BARE = BARE | {"f"}

GULL_HEAD_UP = (
    "........ww....",
    ".......wwew...",
    ".......wwwwooo",
    "........ww..O.",
    "..gggggggww...",
    "kggggggggwww..",
    "kkGGGGGwwwww..",
    "...wwwwwww....",
)
# Calling: the head thrown up, the bill open.
GULL_CALLING = (
    ".........wwo..",
    "........wwe.o.",
    "........www...",
    "........ww....",
    "..gggggggww...",
    "kggggggggwww..",
    "kkGGGGGwwwww..",
    "...wwwwwww....",
)
# Pecking: the head down to the mud, then the bill on it.
GULL_PECKING = (
    "..............",
    "..............",
    "..............",
    "..............",
    "..gggggggww...",
    "kggggggggwwww.",
    "kkGGGGGwwwwwwe",
    "...wwwwwww..ww",
    "............oo",
)
GULL_PECKING_DOWN = GULL_PECKING[:8] + ("............wo", "............oO")
GULL_LEGS = ("LM", "LM", "LM")
GULL_STEP = ("LM", "L.M", "L..M")
GULL_STEP_BACK = ("LM", "M.L", "M..L")
GULL_LEG_AT = (6, 8)
# Swimming: sitting on the water with a ring of foam around it, rising and sinking a little.
GULL_SWIMMING = GULL_HEAD_UP[:7] + ("ff.fffffff.ff",)
GULL_SWIMMING_LOW = GULL_HEAD_UP[:6] + (".fffffffffff.",)

# Flying: long grey wings with black tips, a white body and tail.
GULL_WINGS_UP = (
    ".........kk.......",
    "........kkg.......",
    ".......kggg.......",
    ".......gggg.......",
    "......ggggG.......",
    ".wwwwwwwwwwwwwweoo",
    "..wwwwwwwwwww.....",
)
GULL_WINGS_LEVEL = (
    "......ggggg.......",
    ".wwwwwwwwwwwwwweoo",
    "..wwwwwwwwwww.....",
    "......gGggg.......",
    ".......Gggg.......",
    ".......kggg.......",
    "........kkg.......",
    "........kk........",
)
GULL_WINGS_DOWN = (
    ".wwwwwwwwwwwwwweoo",
    "..wwwwwwwwwww.....",
    "......gGggg.......",
    ".......Gggg.......",
    "........kgg.......",
    "........kk........",
)
GULL_FLIGHT = [(GULL_WINGS_UP, 5), (GULL_WINGS_LEVEL, 1), (GULL_WINGS_DOWN, 0)]
GULL_FLIGHT_LEFT = 1
GULL_FLIGHT_BODY_Y = 8
GULL_STANDING_LEFT = 3


def gull_frame(body, legs=GULL_LEGS):
    return on_legs(body, legs, GULL_LEG_AT)


GULL_ACTIONS = {
    "stand": [gull_frame(GULL_HEAD_UP), gull_frame(GULL_CALLING)],
    "walk": [gull_frame(GULL_HEAD_UP, GULL_STEP), gull_frame(GULL_HEAD_UP, GULL_STEP_BACK)],
    "peck": [gull_frame(GULL_PECKING), gull_frame(GULL_PECKING_DOWN)],
    "swim": [GULL_SWIMMING, GULL_SWIMMING_LOW],
}


def gull_sheet():
    size = GULL_SIZE
    rows = [[standing(frame, size, GULL_STANDING_LEFT) for frame in frames] for frames in GULL_ACTIONS.values()]
    rows.append([on_cell(shape, size, GULL_FLIGHT_LEFT, GULL_FLIGHT_BODY_Y - body_y) for shape, body_y in GULL_FLIGHT])
    return [[to_picture(frame, GULL_KEYS, GULL_OUTLINE, GULL_BARE) for frame in frames] for frames in rows]


def sheets():
    """(name, cell size, rows of cells) of every sheet."""
    return [
        ("oystercatcher", OYSTERCATCHER_SIZE, oystercatcher_sheet()),
        ("dunlin", DUNLIN_SIZE, dunlin_sheet()),
        ("gull", GULL_SIZE, gull_sheet()),
    ]
