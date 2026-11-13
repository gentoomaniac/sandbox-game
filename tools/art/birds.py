"""Art for the big birds of the marsh, drawn at 32 px per tile: one sheet per kind at
assets/wildlife/<kind>.png.

The white stork walks the wet meadows and stands on the roofs; greylag geese graze the marsh in
flocks and fly over in a V (see docs/art-style.md, "Props and animals"). Like the other wildlife
sheets (animals.py) a sheet has one row per action and one column per frame, in the order of its
actions, which game/scenes/wildlife/wildlife_sprites.gd mirrors; the bird stands on the bottom
row of its cell, facing right, and flies in its middle. The birds are put together by
bird_forms.py: side on while they stand or walk, from a little above while they fly.
"""

import math

import forms
from bird_forms import WINGBEAT, Bird, flying, head_on, standing
from canvas import mirrored

# --- White stork --------------------------------------------------------------------------
#
# About 38 px tall standing (a metre; a person is 61 px), with a wingspan of about 60 px: white,
# with black flight feathers, a long red bill and long red legs.


def stork_marks(picture, parts):
    if parts.wing is None:
        return
    # The black flight feathers along the bottom and the back of the folded wing.
    height, width = len(picture), len(picture[0])
    xs, ys = forms.grid(width, height)
    turn = math.radians(parts.angle)
    cx, cy = parts.centre
    across = (xs - cx) * math.sin(turn) + (ys - cy) * math.cos(turn)
    along = (xs - cx) * math.cos(turn) - (ys - cy) * math.sin(turn)
    forms.paint(picture, parts.wing & ((across > 0.5) | (along < -4.0)), "ink")
    forms.paint(picture, parts.wing & (across > 0.5) & (across < 1.5) & (along > -4.0), "stone_dark")


STORK = Bird(
    body=(10.5, 6.0),
    neck=2.2,
    head=3.0,
    bill=(10.0, 1.5),
    legs=17,
    leg_width=2,
    tail=4.0,
    span=26.0,
    chord=6.5,
    ramp=["snow_shadow", "snow", "lime"],
    belly=None,
    back=None,
    head_ramp=["snow_shadow", "snow", "lime"],
    wing=["snow_shadow", "snow", "lime"],
    flight_wing=["snow_shadow", "snow", "lime"],
    tail_ramp=["snow_shadow", "lime"],
    outline="stone",
    eye="ink",
    bill_colours=("red_light", "ember"),
    leg_colours=("red_light", "ember"),
    wing_tip="ink",
    trailing_edge="ink",
    primaries="ink",
    marks=stork_marks,
)
STORK_SIZE = (64, 52)
STORK_AT = (26.0, 29.5)
STORK_STANDING = {"angle": 8, "head_at": (3.0, -12.0), "bill_angle": 50}
STORK_HUNTING = {"angle": 0, "head_at": (9.0, -3.0), "bill_angle": 60}
STORK_STRIKING = {"angle": -12, "head_at": (12.0, 5.0), "bill_angle": 82}
# The head thrown back onto the shoulders, the bill pointing at the sky.
STORK_CLATTERING = {"angle": 10, "head_at": (-1.0, -9.0), "bill_angle": -95}
STEP = 4


def stork(**pose):
    return standing(STORK_SIZE, STORK, STORK_AT, **pose)


def frog_in_bill(picture, tip):
    """A frog held across the tip of the bill, its legs dangling."""
    x, y = math.floor(tip[0]), math.floor(tip[1])
    forms.dots(picture, [(x - 2, y + 1), (x - 1, y + 1), (x, y + 1), (x + 1, y + 1), (x - 1, y + 2), (x, y + 2), (x + 1, y)], "dry_light")
    forms.dots(picture, [(x - 3, y + 2), (x - 3, y + 3), (x + 2, y + 2), (x + 2, y + 3), (x - 1, y + 3)], "olive")
    return picture


def stork_sheet():
    swallowing, parts = stork(**STORK_CLATTERING)
    return [
        [stork(**STORK_STANDING)[0], stork(**STORK_STANDING, look_round=True)[0]],
        [
            stork(**STORK_HUNTING, steps=((STEP, 3), (0, 0)))[0],
            stork(**STORK_HUNTING)[0],
            stork(**STORK_HUNTING, steps=((0, 0), (STEP, 3)))[0],
            stork(**STORK_HUNTING)[0],
        ],
        [stork(**STORK_HUNTING)[0], stork(**STORK_STRIKING)[0]],
        [stork(**STORK_CLATTERING)[0], stork(**STORK_CLATTERING, is_open=True)[0]],
        [frog_in_bill(swallowing, parts.bill_tip), stork(**STORK_CLATTERING)[0]],
        [flying(STORK_SIZE, STORK, (30.0, 26.0), beat, legs_trailing=True)[0] for beat in ("up", "level", "down")],
    ]


# --- Greylag goose ------------------------------------------------------------------------
#
# About 24 px long and 22 px tall with the head up, a wingspan of about 44 px: grey-brown, the
# folded wing barred with pale feather edges, a pale belly, white under the tail, an orange bill
# and pink legs.


def goose_marks(picture, parts):
    if parts.wing is None:
        return
    height, width = len(picture), len(picture[0])
    xs, ys = forms.grid(width, height)
    cx, cy = parts.centre
    # Pale edges across the folded wing, and the white under the tail.
    forms.paint(picture, parts.wing & ((ys.astype(int) - math.floor(cy)) % 3 == 1) & (xs < cx + 4), "bare_light")
    forms.dots(picture, [(math.floor(cx - 9), math.floor(cy + 2)), (math.floor(cx - 8), math.floor(cy + 2)), (math.floor(cx - 9), math.floor(cy + 1))], "lime")


GOOSE = Bird(
    body=(9.0, 5.5),
    neck=2.0,
    head=2.8,
    bill=(4.0, 1.4),
    legs=6,
    leg_width=2,
    tail=3.0,
    span=19.0,
    chord=4.5,
    ramp=["mud", "bare", "bare_light"],
    belly=["bare", "stone_light", "lime"],
    back=None,
    head_ramp=["mud", "bare", "bare_light"],
    wing=["mud_dark", "mud", "bare"],
    flight_wing=["mud", "bare", "bare_light"],
    tail_ramp=["mud_dark", "mud"],
    outline="mud_dark",
    eye="ink",
    bill_colours=("flame", "ember"),
    leg_colours=("skin", "skin_shade"),
    wing_tip="mud_dark",
    trailing_edge="mud",
    primaries="mud_dark",
    marks=goose_marks,
)
GOOSE_SIZE = (48, 36)
GOOSE_AT = (20.0, 25.0)
GOOSE_STANDING = {"angle": 5, "head_at": (2.0, -10.0), "bill_angle": 8}
GOOSE_GRAZING = {"angle": -8, "head_at": (8.0, 6.0), "bill_angle": 70}


# Flying straight down the screen (seen from the front: the head with the orange bill, the neck
# and the pale breast) or up it (seen from behind: the back, the white band over the grey tail),
# both wings spread at the levels of the side view's beat: pale grey in front, the flight
# feathers dark. Hand-drawn maps of the left half, the body laid over the wings of the beat,
# each with its top row in the cell; the right half is mirrored and a shade darker
# (canvas.mirrored). Keys: P l b d D the plumage from its palest to its darkest, w white, k eye,
# o r the bill and its shade.
GOOSE_FLIGHT_KEYS = {
    "P": "stone_light",
    "l": "bare_light",
    "b": "bare",
    "d": "mud",
    "D": "mud_dark",
    "w": "lime",
    "k": "ink",
    "o": "flame",
    "r": "ember",
}
GOOSE_SHADED = {"P": "l", "l": "b", "b": "d", "d": "D", "w": "P", "o": "r"}
# The body (head, neck, and the breast or the back and tail) is one map for every beat, laid over
# the wings of the beat (GOOSE_WINGS); the classic art, smaller, draws a whole map per beat.
# Every map is GOOSE_HALF_WIDTH wide: half the 40 px of the spread wings.
GOOSE_HALF_WIDTH = 20
GOOSE_FRONT_BODY = (9, [
    "..................bb",
    ".................lbb",
    ".................kbb",
    "..................bo",
    "..................lo",
    "..................bb",
    "..................lb",
    "...............lPPPP",
    "...............lPPPP",
    "...............lPPPP",
    "................lPPP",
    ".................lPP",
    "..................ll",
])
GOOSE_BACK_BODY = (9, [
    "..................bb",
    ".................lbb",
    ".................lbb",
    "..................bb",
    "..................bb",
    "..................bb",
    "..................lb",
    "...............lbbbb",
    "...............bbdbb",
    "...............bdbbd",
    "................bbdb",
    ".................www",
    ".................lbb",
    "..................ww",
])
GOOSE_WINGS = {
    "up": (2, [
        "D...................",
        "Dd..................",
        "Ddd.................",
        ".Ddl................",
        ".Dddl...............",
        "..DdlP..............",
        "..DdblP.............",
        "...DdblP............",
        "...DdbblP...........",
        "....DdbblP..........",
        ".....DdbblP.........",
        "......DdbblP........",
        ".......DdbblP.......",
        "........DdbblP......",
        ".........DdbblPP....",
        "...........DdblPP...",
        ".............DdlPP..",
    ]),
    "level": (16, [
        "....PPPPPPPPPPPP....",
        "..dPllllllllllllll..",
        ".DddbbbbbbbbbbbbbP..",
        "DDdDddddbdbdbdbb....",
        ".D.DdDdDdddd........",
    ]),
    "down": (16, [
        "............PPPPP...",
        ".........PPPllllll..",
        "......PPPllllbbbb...",
        "....PPllbbbbddd.....",
        "..Pllbbbdddd........",
        ".Plbbddd............",
        "Plbdd...............",
        "lbdD................",
        "bdD.................",
        "dD..................",
    ]),
}


def goose_head_on(body, beat):
    """A frame of the front or back view: the wings of the beat with the body over them."""
    width, height = GOOSE_SIZE
    half = [["."] * GOOSE_HALF_WIDTH for _ in range(height)]
    for top, rows in (GOOSE_WINGS[beat], body):
        for y, row in enumerate(rows):
            for x, char in enumerate(row):
                if char != ".":
                    half[top + y][x] = char
    return head_on(GOOSE_SIZE, mirrored(["".join(row) for row in half], GOOSE_SHADED), GOOSE_FLIGHT_KEYS, GOOSE.outline, 0)


def goose(**pose):
    return standing(GOOSE_SIZE, GOOSE, GOOSE_AT, **pose)[0]


def goose_sheet():
    return [
        [goose(**GOOSE_STANDING), goose(**GOOSE_STANDING, look_round=True)],
        [goose(**GOOSE_GRAZING), goose(**GOOSE_GRAZING | {"head_at": (8.0, 7.0)})],
        [goose(**GOOSE_STANDING, steps=((3, 2), (0, 0))), goose(**GOOSE_STANDING, steps=((0, 0), (3, 2)))],
        [flying(GOOSE_SIZE, GOOSE, (22.0, 18.0), beat)[0] for beat in WINGBEAT],
        [goose_head_on(GOOSE_FRONT_BODY, beat) for beat in WINGBEAT],
        [goose_head_on(GOOSE_BACK_BODY, beat) for beat in WINGBEAT],
    ]


def sheets():
    """(name, cell size, rows of cells) of every sheet."""
    return [("stork", STORK_SIZE, stork_sheet()), ("goose", GOOSE_SIZE, goose_sheet())]
