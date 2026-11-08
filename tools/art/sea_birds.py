"""Art for the sea birds of the coast, drawn at 32 px per tile: one sheet per kind at
assets/wildlife/<kind>.png.

Oystercatchers and dunlin probe the tidal mud, herring gulls walk the shore and swim, common terns
plunge into the sea for fish (see docs/art-style.md, "Props and animals").

The sheets are laid out like those of birds.py: one row per action and one column per frame, in
the order game/scenes/wildlife/wildlife_sprites.gd mirrors; a bird stands on the bottom row of
its cell facing right and flies in its middle. The birds are put together by bird_forms.py.
"""

import math

import forms
from bird_forms import Bird, flying, standing
from canvas import blank

# --- Oystercatcher ------------------------------------------------------------------------
#
# Black above and white below, with a long orange-red bill, a red eye and pink legs: about 20 px
# long with the bill and 16 px tall, a wingspan of about 30 px, with a broad white bar along the
# wing. Its outline is black too, so the black parts read as one shape and the white is edged.

OYSTERCATCHER = Bird(
    body=(6.5, 4.0),
    neck=2.2,
    head=2.6,
    bill=(7.0, 1.0),
    legs=6,
    leg_width=2,
    tail=3.0,
    span=14.0,
    chord=3.5,
    ramp=["ink", "stone_dark"],
    belly=["snow_shadow", "snow", "lime"],
    back=None,
    head_ramp=["ink", "stone_dark"],
    wing=["ink", "stone_dark"],
    flight_wing=["ink", "stone_dark"],
    tail_ramp=["ink", "stone_dark"],
    outline="ink",
    eye="red_light",
    bill_colours=("flame", "red_light"),
    leg_colours=("skin", "skin_shade"),
    wing_tip="ink",
    trailing_edge="lime",
    primaries="ink",
    marks=None,
)
OYSTERCATCHER_SIZE = (32, 24)
OYSTERCATCHER_AT = (13.0, 14.0)
OYSTERCATCHER_STANDING = {"angle": 5, "head_at": (2.0, -5.0), "bill_angle": 15}
OYSTERCATCHER_PROBING = {"angle": -15, "head_at": (5.0, 3.0), "bill_angle": 62}


def oystercatcher(**pose):
    return standing(OYSTERCATCHER_SIZE, OYSTERCATCHER, OYSTERCATCHER_AT, **pose)[0]


def oystercatcher_sheet():
    size = OYSTERCATCHER_SIZE
    return [
        [oystercatcher(**OYSTERCATCHER_STANDING), oystercatcher(**OYSTERCATCHER_STANDING, look_round=True)],
        [oystercatcher(**OYSTERCATCHER_PROBING), oystercatcher(**OYSTERCATCHER_PROBING | {"head_at": (5.0, 4.5), "bill_angle": 72})],
        [oystercatcher(**OYSTERCATCHER_STANDING, steps=((3, 2), (0, 0))), oystercatcher(**OYSTERCATCHER_STANDING, steps=((0, 0), (3, 2)))],
        [flying(size, OYSTERCATCHER, (13.0, 13.0), beat)[0] for beat in ("up", "level", "down")],
    ]


# --- Dunlin -------------------------------------------------------------------------------
#
# A small wader in tight flocks, grey above and white below in its winter dress, with a black
# bill drooping at the tip: about 14 px long and 11 px tall (drawn larger than life), a wingspan
# of about 20 px with a white bar.

DUNLIN = Bird(
    body=(4.5, 3.0),
    neck=1.8,
    head=2.2,
    bill=(4.0, 0.8),
    legs=4,
    leg_width=1,
    tail=2.0,
    span=9.0,
    chord=2.4,
    ramp=["stone", "stone_light", "snow"],
    belly=["snow_shadow", "snow", "lime"],
    back=None,
    head_ramp=["stone", "stone_light", "snow"],
    wing=["stone_dark", "stone", "stone_light"],
    flight_wing=["stone", "stone_light"],
    tail_ramp=["stone_dark", "stone"],
    outline="stone_dark",
    eye="ink",
    bill_colours=("stone_dark", "ink"),
    leg_colours=("stone_dark", "ink"),
    wing_tip="stone_dark",
    trailing_edge="lime",
    primaries="stone_dark",
    marks=None,
)
DUNLIN_SIZE = (22, 16)
DUNLIN_AT = (9.0, 8.8)
DUNLIN_STANDING = {"angle": 5, "head_at": (1.5, -3.0), "bill_angle": 25}
DUNLIN_PROBING = {"angle": -15, "head_at": (3.5, 2.5), "bill_angle": 70}


def dunlin(**pose):
    return standing(DUNLIN_SIZE, DUNLIN, DUNLIN_AT, **pose)[0]


def dunlin_sheet():
    return [
        [dunlin(**DUNLIN_STANDING), dunlin(**DUNLIN_STANDING, look_round=True)],
        [dunlin(**DUNLIN_PROBING), dunlin(**DUNLIN_PROBING | {"head_at": (3.5, 3.5), "bill_angle": 80})],
        [dunlin(**DUNLIN_STANDING, steps=((2, 1), (0, 0))), dunlin(**DUNLIN_STANDING, steps=((0, 0), (2, 1)))],
        [flying(DUNLIN_SIZE, DUNLIN, (9.0, 8.0), beat)[0] for beat in ("up", "level", "down")],
    ]


# --- Herring gull -------------------------------------------------------------------------
#
# White with a pale blue-grey back and black wing tips, a yellow bill with a red spot and pink
# legs: about 26 px long and 22 px tall, a wingspan of about 44 px. It walks the mud and the
# shore, and swims on the sea in a ring of foam.

GULL = Bird(
    body=(8.5, 5.0),
    neck=2.4,
    head=3.2,
    bill=(5.0, 1.3),
    legs=7,
    leg_width=2,
    tail=3.0,
    span=20.0,
    chord=4.5,
    ramp=["snow_shadow", "snow", "lime"],
    belly=None,
    back=["snow_deep", "snow_shadow", "snow"],
    head_ramp=["snow_shadow", "snow", "lime"],
    wing=["snow_deep", "snow_shadow", "snow"],
    flight_wing=["snow_deep", "snow_shadow", "snow"],
    tail_ramp=["snow_shadow", "lime"],
    outline="stone",
    eye="ink",
    bill_colours=("gold", "ochre"),
    leg_colours=("skin", "skin_shade"),
    wing_tip="ink",
    trailing_edge=None,
    primaries="ink",
    marks=None,
)
GULL_SIZE = (40, 32)
GULL_AT = (17.0, 20.0)
GULL_STANDING = {"angle": 5, "head_at": (2.0, -6.0), "bill_angle": 8}
# Calling: the head thrown up, the bill open.
GULL_CALLING = {"angle": 10, "head_at": (1.0, -7.0), "bill_angle": -40, "is_open": True}
GULL_PECKING = {"angle": -12, "head_at": (6.0, 4.0), "bill_angle": 60}
# The row of the water line of a swimming gull.
WATER_LINE = 28


def gull(**pose):
    """A gull with the red spot near the tip of its bill (not on an open one)."""
    picture, parts = standing(GULL_SIZE, GULL, GULL_AT, **pose)
    if not pose.get("is_open"):
        tip_x, tip_y = parts.bill_tip
        forms.dots(picture, [(math.floor(tip_x) - 1, math.floor(tip_y) + 1)], "red_light")
    return picture


def gull_swimming(sink):
    """Sitting on the water, the body cut by the water line and ringed by foam, `sink` pixels
    lower in the swell."""
    picture = gull(**GULL_STANDING, swimming=True, lift=-(WATER_LINE - 25 + sink))
    for y in range(WATER_LINE, len(picture)):
        picture[y] = [None] * len(picture[0])
    width = len(picture[0])
    drawn = [x for x in range(width) if picture[WATER_LINE - 1][x] is not None]
    left, right = drawn[0] - 2, drawn[-1] + 2
    foam = [(x, WATER_LINE) for x in range(left, right + 1) if x not in (left + 2, right - 3)]
    forms.dots(picture, foam, "foam")
    forms.dots(picture, [(left - 1, WATER_LINE + 1), (left - 2, WATER_LINE + 1), (right + 1, WATER_LINE + 1), (right + 2, WATER_LINE + 1)], "water_light")
    return picture


def gull_sheet():
    return [
        [gull(**GULL_STANDING), gull(**GULL_CALLING)],
        [gull(**GULL_STANDING, steps=((3, 2), (0, 0))), gull(**GULL_STANDING, steps=((0, 0), (3, 2)))],
        [gull(**GULL_PECKING), gull(**GULL_PECKING | {"head_at": (6.0, 5.5), "bill_angle": 75})],
        [gull_swimming(0), gull_swimming(1)],
        [flying(GULL_SIZE, GULL, (17.0, 17.0), beat)[0] for beat in ("up", "level", "down")],
    ]


# --- Common tern --------------------------------------------------------------------------
#
# Slender, pale grey and white with a black cap, a red bill and a long forked tail: about 22 px
# long, a wingspan of about 40 px with narrow, pointed wings. It flies over the sea, hovers,
# plunges in with a splash and comes up, now and then with a fish.


def tern_marks(picture, parts):
    (cx, cy), radius = parts.head_centre, parts.head_radius
    height, width = len(picture), len(picture[0])
    xs, ys = forms.grid(width, height)
    forms.paint(picture, parts.head & (ys < cy + 0.3) & (xs < cx + radius * 0.6), "ink")
    if parts.wing is None:
        # The fork of the tail, in flight.
        bx, by = parts.centre
        end = math.floor(bx - TERN.body[0] * 0.85 - TERN.tail)
        forms.dots(picture, [(end, math.floor(by)), (end + 1, math.floor(by)), (end + 2, math.floor(by))], None)


TERN = Bird(
    body=(6.5, 3.0),
    neck=1.8,
    head=2.4,
    bill=(5.0, 1.0),
    legs=3,
    leg_width=1,
    tail=6.0,
    span=17.0,
    chord=3.2,
    ramp=["snow_shadow", "snow", "lime"],
    belly=None,
    back=["snow_shadow", "snow"],
    head_ramp=["snow_shadow", "snow", "lime"],
    wing=["snow_shadow", "snow"],
    flight_wing=["snow_shadow", "snow"],
    tail_ramp=["snow_shadow", "lime"],
    outline="stone",
    eye="ink",
    bill_colours=("red_light", "ember"),
    leg_colours=("red_light", "ember"),
    wing_tip="snow_deep",
    trailing_edge=None,
    primaries="snow_deep",
    marks=tern_marks,
)
TERN_SIZE = (40, 28)
TERN_FLYING_AT = (19.0, 14.0)


def tern_flying(beat, bill_angle=0.0):
    return flying(TERN_SIZE, TERN, TERN_FLYING_AT, beat, bill_angle=bill_angle)


def with_fish(picture, tip):
    """A silver fish crosswise in the bill, its tail hanging."""
    x, y = math.floor(tip[0]), math.floor(tip[1])
    forms.dots(picture, [(x - 2, y + 1), (x - 1, y + 1), (x, y + 1), (x + 1, y + 1)], "stone_light")
    forms.dots(picture, [(x - 3, y + 2), (x + 2, y + 1), (x + 2, y + 2), (x - 1, y + 2)], "stone")
    return picture


def tern_diving(steep):
    """Plunging: wings shut and the bill first, then straight down."""
    pose = {"angle": -88, "head_at": (0.0, 0.0), "bill_angle": 90} if steep else {"angle": -55, "head_at": (1.0, 0.0), "bill_angle": 62}
    return standing(TERN_SIZE, TERN, (20.0, 12.0), swimming=True, **pose)[0]


# The splash where a tern went in, from the water line at the bottom of the cell: a crown of
# spray (white and foam, as (x, y) from the middle of the bottom row), falling back, then a ring
# on the water.
SPLASH = (
    {
        "lime": [(0, -9), (-3, -8), (3, -8), (-5, -6), (5, -6), (-1, -6), (1, -5), (-2, -4), (2, -4), (0, -3), (-6, -3), (6, -3)],
        "foam": [(-1, -2), (0, -2), (1, -2), (-3, -1), (-2, -1), (2, -1), (3, -1), (-1, 0), (0, 0), (1, 0)],
    },
    {
        "lime": [(-5, -5), (5, -5), (-7, -3), (7, -3), (-1, -4), (2, -3)],
        "foam": [(-4, -1), (-3, -1), (3, -1), (4, -1), (-2, 0), (-1, 0), (1, 0), (2, 0), (0, -1)],
        "water_light": [(0, 0), (-5, 0), (5, 0)],
    },
    {
        "foam": [(-7, -1), (7, -1), (-6, 0), (-5, 0), (5, 0), (6, 0), (-3, 0), (3, 0)],
        "water_light": [(-4, 0), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0), (4, 0)],
    },
)


def splash(drops):
    width, height = TERN_SIZE
    picture = blank(width, height)
    for colour, points in drops.items():
        forms.dots(picture, [(width // 2 + x, height - 1 + y) for x, y in points], colour)
    return picture


def tern_sheet():
    fishing = [tern_flying(beat) for beat in ("up", "level", "down")]
    return [
        [picture for picture, _ in fishing],
        [tern_flying(beat, bill_angle=50)[0] for beat in ("high", "down")],
        [tern_diving(False), tern_diving(True)],
        [splash(drops) for drops in SPLASH],
        [with_fish([row[:] for row in picture], parts.bill_tip) for picture, parts in fishing],
    ]


def sheets():
    """(name, cell size, rows of cells) of every sheet."""
    return [
        ("oystercatcher", OYSTERCATCHER_SIZE, oystercatcher_sheet()),
        ("dunlin", DUNLIN_SIZE, dunlin_sheet()),
        ("gull", GULL_SIZE, gull_sheet()),
        ("tern", TERN_SIZE, tern_sheet()),
    ]
