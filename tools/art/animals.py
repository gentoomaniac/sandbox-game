"""Art for the small wild animals, drawn at 32 px per tile: one sheet per kind at
assets/wildlife/<kind>.png (the sparrow is "bird").

A sheet has one row per action and one column per frame, in the order of `sheets` (which
game/scenes/wildlife/wildlife_sprites.gd mirrors). Every cell has the size of its kind; the
animal stands on the bottom row in the middle, facing right (the game flips it to face left).
The animals are drawn a little larger than life, so that they read next to the people, from
rounded forms shaded by the light from the top left (forms.py), with eyes that have a glint.
Land animals get a one pixel outline in the darkest colour of their coat; the bee's dark
outline is drawn in, and the butterfly's wings are edged in the darkest shade of their own
colour (see the style rules in docs/art-style.md).
"""

import math

import forms
from bird_forms import Bird, flying, standing
from canvas import blank, outline

# --- House sparrow ------------------------------------------------------------------------
#
# About 9 px tall and 15 px long (larger than life: a person is 61 px). Brown above with a grey
# crown, a pale cheek and belly and a black bib; it hops, pecks and flies with quick beats.


def sparrow_marks(picture, parts):
    (cx, cy), radius = parts.head_centre, parts.head_radius
    height, width = len(picture), len(picture[0])
    xs, ys = forms.grid(width, height)
    forms.paint(picture, parts.head & (ys < cy - radius * 0.45) & (xs > cx - radius * 0.8), "stone")
    x, y = math.floor(cx), math.floor(cy)
    forms.dots(picture, [(x - 1, y + 1), (x, y + 1), (x - 1, y)], "cream")
    forms.dots(picture, [(x + 2, y + 1), (x + 1, y + 2), (x + 2, y + 2)], "ink")
    if parts.wing is not None:
        # A pale bar across the folded wing and dark streaks on it.
        wx, wy = (math.floor(v) for v in parts.centre)
        forms.dots(picture, [(wx - 2, wy), (wx - 1, wy), (wx, wy - 1)], "cream")
        forms.dots(picture, [(wx - 3, wy - 2), (wx - 1, wy - 2), (wx - 2, wy + 1), (wx, wy + 1)], "soil_dark")


SPARROW = Bird(
    body=(5.5, 3.6),
    neck=2.4,
    head=3.2,
    bill=(2.2, 1.0),
    legs=4,
    leg_width=1,
    tail=3.5,
    span=12.0,
    chord=2.6,
    ramp=["soil", "soil_mid", "soil_light"],
    belly=["sand", "sand_light", "cream"],
    back=None,
    head_ramp=["soil", "soil_mid", "soil_light"],
    wing=["soil", "soil_mid", "soil_light"],
    flight_wing=["soil", "soil_mid", "soil_light"],
    tail_ramp=["soil_dark", "soil"],
    outline="soil_dark",
    eye="ink",
    bill_colours=("stone", "stone_dark"),
    leg_colours=("mud", "mud_dark"),
    wing_tip="soil",
    trailing_edge=None,
    primaries="soil",
    marks=sparrow_marks,
)
SPARROW_SIZE = (22, 18)
SPARROW_AT = (9.0, 10.6)


def sparrow(**pose):
    return standing(SPARROW_SIZE, SPARROW, SPARROW_AT, **({"angle": 18, "head_at": (1.5, -2.6), "bill_angle": 5} | pose))[0]


def sparrow_sheet():
    hop = 3
    return {
        "idle": [sparrow(), sparrow(), sparrow(head_at=(1.0, -3.4), bill_angle=-15)],
        "peck": [sparrow(), sparrow(angle=-22, head_at=(2.6, 3.8), bill_angle=70)],
        "hop": [sparrow(lift=hop, steps=((1, hop), (1, hop))), sparrow()],
        "fly": [flying(SPARROW_SIZE, SPARROW, (9.0, 10.0), beat)[0] for beat in ("up", "level", "down")],
    }


# --- Rabbit -------------------------------------------------------------------------------
#
# The wild rabbit: grey-brown, a white scut, long ears with dark tips, a big dark eye.

RABBIT_SIZE = (26, 22)
RABBIT_COAT = ["mud_dark", "mud", "sand", "sand_light"]
RABBIT_FAR = ["mud_dark", "mud", "sand"]


def rabbit(body, haunch, head, ears, front=None, hind=None, lift=0, chew=False):
    """A rabbit put together from its parts: the body, haunch and head as ellipses (x, y,
    rx, ry), the tips of its two ears, a front leg and a hind leg as (top, foot)."""
    width, height = RABBIT_SIZE
    picture = blank(width, height)

    def up(point):
        return (point[0], point[1] - lift)

    hx, hy = up(head[:2])
    for tip, radius, ramp in ((ears[0], 1.3, RABBIT_FAR), (ears[1], 1.6, RABBIT_COAT)):
        ear = forms.capsule(width, height, (hx - 1.5, hy - 1.5), up(tip), radius, radius * 0.75)
        forms.shade(picture, ear, ramp, radius=1)
    if hind is not None:
        forms.shade(picture, forms.capsule(width, height, up(hind[0]), up(hind[1]), 1.8, 1.2), RABBIT_COAT, radius=1)
    bx, by = up(haunch[:2])
    forms.shade(picture, forms.ellipse(width, height, bx - haunch[2] - 0.5, by - 1, 2.2, 2.2), ["sand_light", "lime"], radius=1)
    forms.shade(picture, forms.ellipse(width, height, bx, by, *haunch[2:]), RABBIT_COAT, radius=3)
    forms.shade(picture, forms.ellipse(width, height, *up(body[:2]), *body[2:]), RABBIT_COAT, radius=3)
    head_mask = forms.ellipse(width, height, hx, hy, *head[2:])
    forms.shade(picture, head_mask, RABBIT_COAT, radius=2)
    if front is not None:
        forms.shade(picture, forms.capsule(width, height, up(front[0]), up(front[1]), 1.3, 1.1), RABBIT_COAT, radius=1)
    # The pale throat and belly, the ear's pink inside, the eye, the nose.
    rx = head[2]
    forms.dots(picture, [(math.floor(hx + rx * 0.7), math.floor(hy + 1.5 + (1 if chew else 0)))], "sand_light")
    ear_x, ear_y = up(ears[1])
    forms.dots(picture, [(math.floor(hx - 1.5 + (ear_x - hx + 1.5) * f), math.floor(hy - 1.5 + (ear_y - hy + 1.5) * f)) for f in (0.4, 0.6)], "petal")
    forms.dots(picture, [(math.floor(ear_x), math.floor(ear_y))], "mud_dark")
    eye = (math.floor(hx + 0.5), math.floor(hy - 0.8))
    forms.dots(picture, [eye, (eye[0] + 1, eye[1]), (eye[0], eye[1] + 1), (eye[0] + 1, eye[1] + 1)], "ink")
    forms.dots(picture, [eye], "cream")
    forms.dots(picture, [(math.floor(hx + rx - 0.5), math.floor(hy + 0.2))], "petal")
    return outline(picture, "mud_dark")


RABBIT_SITTING = {
    "body": (14.5, 15.0, 5.0, 5.0),
    "haunch": (9.5, 16.0, 6.0, 5.0),
    "head": (19.5, 10.0, 4.0, 3.4),
    "ears": ((14.0, 1.5), (16.5, 0.8)),
    "front": ((17.5, 16.0), (18.0, 20.0)),
    "hind": ((10.0, 19.5), (15.5, 20.0)),
}
RABBIT_NIBBLING = RABBIT_SITTING | {"head": (20.5, 16.0, 4.0, 3.4), "ears": ((12.0, 9.0), (13.0, 7.5))}


def rabbit_sheet():
    return {
        "sit": [rabbit(**RABBIT_SITTING), rabbit(**RABBIT_SITTING | {"ears": ((14.0, 1.5), (14.0, 2.0))})],
        "nibble": [rabbit(**RABBIT_NIBBLING), rabbit(**RABBIT_NIBBLING, chew=True)],
        "hop": [
            # Pushing off, stretched out in the air, landing on the front paws.
            rabbit(body=(14.5, 14.0, 6.0, 4.5), haunch=(8.5, 15.0, 5.5, 4.5), head=(21.0, 10.5, 4.0, 3.4),
                   ears=((13.0, 5.0), (14.0, 4.0)), front=((19.5, 16.0), (22.0, 19.5)), hind=((8.0, 18.0), (2.5, 20.5))),
            rabbit(body=(14.0, 12.5, 7.0, 4.0), haunch=(8.0, 12.5, 5.0, 4.0), head=(21.5, 10.0, 4.0, 3.4),
                   ears=((13.5, 5.0), (14.5, 4.5)), front=((19.0, 14.5), (23.0, 16.5)), hind=((7.0, 15.0), (1.5, 16.5)), lift=2),
            rabbit(body=(15.0, 15.0, 5.5, 4.5), haunch=(9.0, 13.5, 5.5, 5.0), head=(20.5, 12.0, 4.0, 3.4),
                   ears=((13.0, 6.0), (14.5, 5.0)), front=((18.5, 17.0), (19.5, 20.5)), hind=((9.0, 17.0), (13.0, 19.0))),
        ],
    }


# --- Red squirrel -------------------------------------------------------------------------
#
# Rust red with a cream belly, ear tufts and a bushy tail held up behind it in an S.

SQUIRREL_SIZE = (28, 24)
SQUIRREL_COAT = ["rust_dark", "rust", "leaf_orange"]


def squirrel_sitting(nose_up=0, tail_tip=(12.0, 2.0)):
    width, height = SQUIRREL_SIZE
    picture = blank(width, height)
    tail = forms.limb(width, height, [(11.0, 21.0), (5.5, 19.0), (3.5, 13.0), (4.5, 7.0), (8.0, 3.0), tail_tip],
                      [2.5, 3.5, 4.0, 3.8, 3.0, 2.0])
    forms.shade(picture, tail, SQUIRREL_COAT, radius=2)
    forms.shade(picture, forms.ellipse(width, height, 15.5, 18.5, 4.5, 4.2), SQUIRREL_COAT, radius=2)
    body = forms.ellipse(width, height, 17.5, 14.5, 3.8, 6.0, angle=-12)
    forms.shade(picture, body, SQUIRREL_COAT, radius=2)
    forms.shade(picture, body & forms.ellipse(width, height, 19.6, 15.5, 1.8, 4.5), ["sand_light", "cream"], radius=1)
    head_y = 8.5 - nose_up
    for ear in ([(17.0, head_y - 2), (17.5, head_y - 7), (19.0, head_y - 3)], [(19.5, head_y - 2.5), (21.0, head_y - 7.5), (21.8, head_y - 2.5)]):
        forms.shade(picture, forms.polygon(width, height, ear), ["russet_deep", "rust_dark"], radius=1)
    forms.shade(picture, forms.ellipse(width, height, 20.0, head_y, 3.8, 3.3), SQUIRREL_COAT, radius=2)
    forms.shade(picture, forms.ellipse(width, height, 23.2, head_y + 1.0, 1.9, 1.6), SQUIRREL_COAT, radius=1)
    forms.shade(picture, forms.capsule(width, height, (20.0, 12.0), (22.5, 12.5), 1.1), SQUIRREL_COAT, radius=1)
    forms.shade(picture, forms.ellipse(width, height, 23.5, 12.5, 1.3, 1.3), ["umber", "ochre"], radius=1)
    forms.shade(picture, forms.ellipse(width, height, 17.5, 22.3, 3.8, 1.3), SQUIRREL_COAT, radius=1)
    eye = (21, math.floor(head_y - 1))
    forms.dots(picture, [eye, (eye[0], eye[1] + 1)], "ink")
    forms.dots(picture, [eye], "cream")
    forms.dots(picture, [(25, math.floor(head_y + 0.5))], "ink")
    return outline(picture, "russet_deep")


def squirrel_darting(tail, near_legs, far_legs):
    """Running low: the body stretched, the tail streaming out behind; the legs as (front foot,
    hind foot) x positions of the near and the far pair."""
    width, height = SQUIRREL_SIZE
    picture = blank(width, height)
    for (front, hind), ramp in ((far_legs, ["russet_deep", "rust_dark"]), (near_legs, SQUIRREL_COAT)):
        forms.shade(picture, forms.capsule(width, height, (19.0, 18.0), (front, 22.5), 1.2), ramp, radius=1)
        forms.shade(picture, forms.capsule(width, height, (12.0, 18.0), (hind, 22.5), 1.6, 1.1), ramp, radius=1)
    forms.shade(picture, forms.limb(width, height, tail, [2.4, 3.2, 3.4, 2.6]), SQUIRREL_COAT, radius=2)
    body = forms.ellipse(width, height, 15.5, 17.0, 6.5, 3.5, angle=4)
    forms.shade(picture, body, SQUIRREL_COAT, radius=2)
    _, ys = forms.grid(width, height)
    forms.paint(picture, body & (ys > 19.0) & forms.ellipse(width, height, 17.0, 20.0, 4.0, 1.5), "cream")
    for ear in ([(20.0, 13.0), (20.5, 9.0), (22.0, 12.5)],):
        forms.shade(picture, forms.polygon(width, height, ear), ["russet_deep", "rust_dark"], radius=1)
    forms.shade(picture, forms.ellipse(width, height, 22.5, 15.0, 3.4, 2.9), SQUIRREL_COAT, radius=2)
    forms.shade(picture, forms.ellipse(width, height, 25.0, 16.0, 1.6, 1.4), SQUIRREL_COAT, radius=1)
    forms.dots(picture, [(23, 14), (23, 15)], "ink")
    forms.dots(picture, [(23, 14)], "cream")
    forms.dots(picture, [(26, 16)], "ink")
    return outline(picture, "russet_deep")


def squirrel_sheet():
    return {
        "sit": [squirrel_sitting(), squirrel_sitting(nose_up=1), squirrel_sitting(tail_tip=(10.0, 1.5))],
        "dart": [
            squirrel_darting([(9.0, 16.0), (5.0, 12.5), (2.0, 11.5), (0.5, 14.0)], (24.0, 8.0), (22.0, 11.0)),
            squirrel_darting([(9.0, 16.0), (5.0, 13.5), (2.0, 13.0), (0.5, 11.5)], (21.0, 12.0), (20.0, 13.0)),
            squirrel_darting([(9.0, 16.0), (5.0, 12.0), (2.0, 12.5), (0.5, 15.0)], (18.0, 15.0), (19.5, 14.0)),
        ],
    }


# --- Roe deer -----------------------------------------------------------------------------
#
# A roe deer, about 40 px tall with the head up: red-brown, a pale belly, the white rump patch,
# a dark muzzle with a pale chin, big ears; thin legs with joints, the hind leg bent back at
# the hock.

DEER_SIZE = (52, 52)
DEER_COAT = ["soil", "soil_mid", "soil_light"]
DEER_FAR = ["soil_dark", "soil", "soil_mid"]
DEER_GROUND = 51
# Where the legs leave the body, standing: near hind and front; the far ones stand a little
# further on.
HIP = (16.0, 30.0)
SHOULDER = (33.0, 31.0)
FAR = 4.0


def deer_leg(picture, top, hoof, ramp, is_hind, lift):
    """A leg from the body to the hoof, with its joints: the front leg straight with a knee that
    bends forward when it is lifted, the hind leg with the stifle forward and the hock back."""
    width, height = DEER_SIZE
    length = hoof[1] - top[1]
    if is_hind:
        points = [top, (top[0] + 1.5, top[1] + length * 0.3), (hoof[0] - 2.5 - lift * 0.5, top[1] + length * 0.58), hoof]
        radii = [2.8, 1.7, 1.0, 0.9]
    else:
        knee = (top[0] + (hoof[0] - top[0]) * 0.5 + lift * 0.8, top[1] + length * 0.55)
        points = [top, (top[0], top[1] + length * 0.25), knee, hoof]
        radii = [2.2, 1.4, 1.0, 0.9]
    forms.shade(picture, forms.limb(width, height, points, radii), ramp, radius=1)


def deer(head, legs, lift=0, arched=False, ear_flick=False):
    """A deer facing right. `head` is "up", "forward" or "down"; `legs` the (hoof shift, lift)
    of the near hind, near front, far hind and far front leg."""
    width, height = DEER_SIZE
    picture = blank(width, height)
    body_y = 28.0 - lift
    # The far legs, behind the body.
    for (shift, leg_lift), top, is_hind in ((legs[2], (HIP[0] + FAR, HIP[1]), True), (legs[3], (SHOULDER[0] + FAR, SHOULDER[1]), False)):
        top = (top[0], top[1] - lift)
        deer_leg(picture, top, (top[0] + shift, DEER_GROUND - 1 - leg_lift - lift), DEER_FAR, is_hind, leg_lift)
    # The neck and the head behind the body's front.
    neck_root = (34.0, 25.0 - lift)
    head_at = {"up": (40.0, 11.5), "forward": (42.0, 17.0), "down": (42.0, 44.0)}[head]
    head_at = (head_at[0], head_at[1] - (lift if head != "down" else 0))
    forms.shade(picture, forms.capsule(width, height, neck_root, (head_at[0] - 1.0, head_at[1] + 1.5), 4.2, 2.4), DEER_COAT, radius=2)
    haunch = forms.ellipse(width, height, 15.5, body_y - (1.0 if arched else 0.0), 6.5, 6.5)
    barrel = forms.ellipse(width, height, 24.0, body_y, 12.0, 6.0, angle=3 if arched else 0)
    chest = forms.ellipse(width, height, 32.0, body_y + 0.5, 5.5, 6.0)
    forms.shade(picture, haunch | barrel | chest, DEER_COAT, radius=3)
    xs, ys = forms.grid(width, height)
    forms.paint(picture, (barrel | chest) & (ys > body_y + 4.0) & (xs > 17) & (xs < 34), "sand")
    forms.shade(picture, forms.ellipse(width, height, 10.0, body_y - 1.0, 2.0, 3.6) & haunch, ["sand_light", "cream"], radius=1)
    # The head: skull and muzzle, pointing down when it grazes.
    hx, hy = head_at
    if head == "down":
        skull = forms.ellipse(width, height, hx, hy, 3.0, 3.6)
        muzzle = forms.ellipse(width, height, hx + 1.0, hy + 3.5, 2.0, 2.4)
        ears = [(hx - 3.5, hy - 3.0), (hx - 1.0, hy - 4.5)]
        eye, nose = (math.floor(hx + 0.5), math.floor(hy - 0.5)), (math.floor(hx + 1.5), math.floor(hy + 5.5))
    else:
        skull = forms.ellipse(width, height, hx, hy, 3.6, 3.0)
        muzzle = forms.ellipse(width, height, hx + 3.5, hy + 1.2, 2.4, 1.9, angle=-20)
        ears = [(hx - 3.5, hy - 5.5), (hx - 1.5, hy - 6.5)] if not ear_flick else [(hx - 5.0, hy - 4.0), (hx - 1.5, hy - 6.5)]
        eye, nose = (math.floor(hx + 0.5), math.floor(hy - 0.8)), (math.floor(hx + 5.5), math.floor(hy + 1.5))
    for tip, ramp in zip(ears, (DEER_FAR, DEER_COAT)):
        forms.shade(picture, forms.capsule(width, height, (hx - 1.0, hy - 1.5), tip, 1.6, 1.0), ramp, radius=1)
        forms.dots(picture, [(math.floor(tip[0]), math.floor(tip[1]))], "soil_dark")
    forms.shade(picture, skull | muzzle, DEER_COAT, radius=2)
    forms.paint(picture, muzzle & ~forms.ellipse(width, height, hx, hy, 3.6, 3.0), "soil")
    forms.dots(picture, [nose, (nose[0] - 1, nose[1])], "ink")
    forms.dots(picture, [(nose[0] - 1, nose[1] + 1), (nose[0] - 2, nose[1] + 1)], "cream")
    forms.dots(picture, [eye, (eye[0] + 1, eye[1]), (eye[0], eye[1] + 1)], "ink")
    forms.dots(picture, [eye], "cream")
    picture = outline(picture, "soil_dark")
    # The near legs over the body's outline, outlined on their own, so they stay thin.
    near = blank(width, height)
    for (shift, leg_lift), top, is_hind in ((legs[0], HIP, True), (legs[1], SHOULDER, False)):
        top = (top[0], top[1] - lift)
        deer_leg(near, top, (top[0] + shift, DEER_GROUND - 1 - leg_lift - lift), DEER_COAT, is_hind, leg_lift)
    near = outline(near, "soil_dark")
    for y, row in enumerate(near):
        for x, colour in enumerate(row):
            if colour is not None and (colour != "soil_dark" or picture[y][x] is None):
                picture[y][x] = colour
    # The hooves.
    for (shift, leg_lift), top in ((legs[0], HIP), (legs[1], SHOULDER), (legs[2], (HIP[0] + FAR, HIP[1])), (legs[3], (SHOULDER[0] + FAR, SHOULDER[1]))):
        x, y = math.floor(top[0] + shift), DEER_GROUND - leg_lift - lift
        forms.dots(picture, [(x - 1, y - 1), (x, y - 1)], "ink")
    return picture


STAND = ((0, 0), (0, 0), (-2, 0), (2, 0))
# A walk: each leg goes back, lifts as it passes, steps forward and stands, a quarter of the
# cycle after the one before it (near hind, near front, far hind, far front).
WALK_PHASES = ((-3, 0), (0, 3), (3, 0), (0, 0))


def deer_sheet():
    walk = [tuple(WALK_PHASES[(frame + offset) % 4] for offset in (0, 1, 2, 3)) for frame in range(4)]
    return {
        "graze": [deer("down", STAND), deer("down", STAND, ear_flick=True)],
        "look": [deer("up", STAND), deer("up", STAND, ear_flick=True)],
        "walk": [deer("forward", legs) for legs in walk],
        "bound": [
            deer("forward", ((5, 3), (-5, 4), (4, 3), (-5, 4)), lift=5, arched=True),
            deer("forward", ((-7, 1), (8, 2), (-6, 1), (7, 2)), lift=8),
            deer("forward", STAND),
        ],
    }


# --- Bee and butterfly --------------------------------------------------------------------

BEE_SIZE = (10, 10)


def bee(wings_up):
    """A honey bee seen side on: a gold body with dark bands, outlined dark, and pale wings
    above it, raised or blurred low."""
    width, height = BEE_SIZE
    picture = blank(width, height)
    body = forms.ellipse(width, height, 4.5, 6.5, 3.2, 2.0)
    forms.shade(picture, body, ["ochre", "gold"], radius=1)
    xs, _ = forms.grid(width, height)
    forms.paint(picture, body & ((xs.astype(int) == 3) | (xs.astype(int) == 5)), "umber")
    forms.shade(picture, forms.ellipse(width, height, 8.0, 6.0, 1.4, 1.4), ["ink", "stone_dark"], radius=1)
    picture = outline(picture, "ink")
    wings = forms.ellipse(width, height, 4.5, 2.5, 2.0, 1.8) if wings_up else forms.ellipse(width, height, 3.5, 4.0, 2.5, 1.0)
    forms.paint(picture, wings, "snow_light")
    forms.paint(picture, forms.edge(wings) & (forms.grid(width, height)[1] > 2.5 if wings_up else wings), "snow")
    return picture


BUTTERFLY_SIZE = (14, 14)
# The wings of each variant, dark to light: a small tortoiseshell's orange, a white, a pink.
BUTTERFLY_WINGS = {
    "flutter": ["rust", "leaf_orange", "gold"],
    "flutter_pale": ["sand", "cream", "snow_light"],
    "flutter_pink": ["heather", "petal", "blossom"],
}


def butterfly(ramp, opening):
    """A butterfly seen from above, its wings open by `opening` (1 spread, 0 shut and seen
    edge on): fore and hind wings either side of a dark body, edged in their darkest shade, with
    dark spots near the tips."""
    width, height = BUTTERFLY_SIZE
    picture = blank(width, height)
    middle = width / 2
    for side in (-1, 1):
        reach = 0.6 + 4.4 * opening
        fore = forms.ellipse(width, height, middle + side * (0.5 + reach * 0.6), 5.0, max(0.7, reach * 0.65), 3.0, angle=-side * 30)
        hind = forms.ellipse(width, height, middle + side * (0.5 + reach * 0.45), 9.5, max(0.7, reach * 0.5), 2.2, angle=side * 20)
        wings = fore | hind
        forms.shade(picture, wings, ramp[1:], radius=1)
        forms.paint(picture, forms.edge(wings), ramp[0])
        if opening > 0.5:
            forms.dots(picture, [(math.floor(middle + side * (reach + 0.2)), 3)], "ink")
    forms.paint(picture, forms.capsule(width, height, (middle, 3.5), (middle, 11.0), 0.7), "ink")
    forms.dots(picture, [(math.floor(middle) - 1, 2), (math.floor(middle) + 1, 2), (math.floor(middle) - 2, 1), (math.floor(middle) + 2, 1)], "ink")
    return picture


# --- Firefly ------------------------------------------------------------------------------
#
# A glow-worm flying at dusk, drawn as three states of one point of light: dark between its
# flashes, glowing, and at its brightest. The game lays a real light over it (see Firefly).

FIREFLY_SIZE = (6, 6)
FIREFLY_CORE = [(2, 2), (3, 2), (2, 3), (3, 3)]
FIREFLY_HALO = [(2, 1), (3, 1), (1, 2), (1, 3), (4, 2), (4, 3), (2, 4), (3, 4)]
FIREFLY_CORNERS = [(1, 1), (4, 1), (1, 4), (4, 4)]


def firefly(core, halo, corners=None):
    """The point of light: a 2x2 core in the colour `core`, with a halo around it."""
    width, height = FIREFLY_SIZE
    picture = blank(width, height)
    if halo:
        forms.dots(picture, FIREFLY_HALO, halo)
    if corners:
        forms.dots(picture, FIREFLY_CORNERS, corners)
    forms.dots(picture, FIREFLY_CORE, core)
    return picture


def firefly_sheet():
    return {
        "dark": [firefly("green_dark", None)],
        "glow": [firefly("gold", "green_bright")],
        "bright": [firefly("cream", "gold", "green_bright")],
    }


# --- Mouse --------------------------------------------------------------------------------
#
# A wood mouse, drawn larger than life: grey-brown, a pale belly, a big round ear pink inside,
# a beady eye with a glint, a long bare tail.

MOUSE_SIZE = (24, 14)
MOUSE_COAT = ["mud_dark", "mud", "bare_light"]


def mouse(body, head, ear, tail, feet, nose_up=0):
    width, height = MOUSE_SIZE
    picture = blank(width, height)
    forms.shade(picture, forms.ellipse(width, height, *body) | forms.ellipse(width, height, *head), MOUSE_COAT, radius=3)
    _, ys = forms.grid(width, height)
    forms.paint(picture, forms.ellipse(width, height, *body) & (ys > body[1] + body[3] - 1.5), "sand_light")
    ex, ey = ear
    forms.shade(picture, forms.ellipse(width, height, ex, ey, 2.3, 2.3), ["mud", "bare_light"], radius=1)
    forms.dots(picture, [(math.floor(ex), math.floor(ey)), (math.floor(ex), math.floor(ey) + 1), (math.floor(ex) - 1, math.floor(ey) + 1)], "petal")
    hx, hy = head[0], head[1]
    eye = (math.floor(hx + 1.5), math.floor(hy - 1 - nose_up * 0.5))
    forms.dots(picture, [eye, (eye[0] + 1, eye[1])], "ink")
    forms.dots(picture, [eye], "cream")
    nose = (math.floor(hx + head[2] + 0.5), math.floor(hy - nose_up))
    forms.dots(picture, [nose], "petal")
    forms.dots(picture, feet, "petal")
    picture = outline(picture, "mud_dark")
    # The tail and the whiskers over the outline, one pixel thin.
    forms.dots(picture, tail, "skin_shade")
    forms.dots(picture, [(nose[0], nose[1] - 2), (nose[0] + 1, nose[1] - 1)], "stone_light")
    return picture


def mouse_sheet():
    crouched = dict(body=(12.5, 9.5, 6.5, 3.6), head=(18.0, 8.5, 3.8, 3.0), ear=(15.5, 5.0),
                    tail=[(0, 9), (1, 10), (2, 11), (3, 12), (4, 12), (5, 13), (6, 13), (7, 13)],
                    feet=[(11, 13), (12, 13), (17, 12), (18, 12)])
    sniffing = crouched | dict(head=(18.0, 7.5, 3.8, 3.0), ear=(15.5, 4.0), nose_up=1)
    running = dict(body=(12.0, 9.8, 7.0, 3.0), head=(18.5, 9.5, 3.8, 2.6), ear=(15.5, 6.0),
                   tail=[(0, 7), (1, 7), (2, 8), (3, 8), (4, 9), (5, 9)])
    return {
        "sit": [mouse(**crouched), mouse(**sniffing)],
        "scurry": [
            mouse(**running, feet=[(7, 13), (8, 13), (17, 13), (18, 13)]),
            mouse(**running | {"tail": [(0, 9), (1, 9), (2, 9), (3, 9), (4, 9), (5, 9)]}, feet=[(10, 13), (11, 13), (14, 13), (15, 13)]),
        ],
    }


# --- Frog ---------------------------------------------------------------------------------
#
# The common frog: olive with dark blotches, a pale throat, the eye high on the head with a gold
# ring, the hind leg folded along its side while it sits, barred.

FROG_SIZE = (24, 16)
FROG_SKIN = ["olive", "dry", "dry_light"]


def frog_sitting(croaking=False):
    width, height = FROG_SIZE
    picture = blank(width, height)
    body = forms.polygon(width, height, [(3, 13), (5, 8), (10, 5), (16, 4), (20, 6), (22, 10), (20, 12), (15, 13)])
    forms.shade(picture, body, FROG_SKIN, radius=3)
    forms.shade(picture, forms.ellipse(width, height, 7.5, 11.0, 4.5, 2.8), FROG_SKIN, radius=2)
    forms.dots(picture, [(x, y) for x in (5, 8, 10) for y in (10, 11)], "green_dark")
    forms.shade(picture, forms.polygon(width, height, [(3, 13), (10, 13), (12, 15), (2, 15)]), FROG_SKIN, radius=1)
    forms.shade(picture, forms.limb(width, height, [(16, 10), (17, 13), (18, 15)], [1.6, 1.2, 1.2]), FROG_SKIN, radius=1)
    forms.dots(picture, [(17, 15), (19, 15)], "dry_light")
    forms.dots(picture, [(10, 7), (11, 7), (13, 6), (7, 9), (12, 9), (13, 9)], "green_dark")
    forms.dots(picture, [(17, 8), (18, 8), (18, 9)], "soil")
    if croaking:
        forms.shade(picture, forms.ellipse(width, height, 19.5, 11.0, 2.6, 2.2), ["sand_light", "cream"], radius=1)
    else:
        forms.dots(picture, [(20, 10), (21, 10), (19, 11)], "sand_light")
    eye = forms.ellipse(width, height, 17.5, 5.0, 2.0, 2.0)
    forms.paint(picture, eye, "ochre")
    forms.dots(picture, [(17, 5), (18, 5)], "ink")
    forms.dots(picture, [(17, 4)], "cream")
    forms.dots(picture, [(21, 9)], "ink")
    return outline(picture, "green_deep")


def frog_hopping(stretched):
    width, height = FROG_SIZE
    picture = blank(width, height)
    if stretched:
        # In the air, the hind legs trailing straight out behind.
        forms.shade(picture, forms.limb(width, height, [(9, 8), (4, 9), (0.5, 9.5)], [2.2, 1.4, 1.1]), FROG_SKIN, radius=1)
        body = forms.ellipse(width, height, 14.0, 7.0, 7.5, 3.2, angle=8)
        forms.shade(picture, body, FROG_SKIN, radius=2)
        forms.shade(picture, forms.limb(width, height, [(18, 9), (20, 11), (22, 12)], [1.4, 1.1, 1.0]), FROG_SKIN, radius=1)
        eye_at, throat = (18.5, 4.5), [(20, 9), (21, 8)]
    else:
        # Pushing off: the body up at the front, the hind legs straightening behind.
        forms.shade(picture, forms.limb(width, height, [(8, 11), (5, 13), (2, 15)], [2.6, 1.6, 1.2]), FROG_SKIN, radius=1)
        body = forms.ellipse(width, height, 13.0, 9.5, 7.0, 3.6, angle=22)
        forms.shade(picture, body, FROG_SKIN, radius=2)
        forms.shade(picture, forms.limb(width, height, [(16, 11), (17, 13), (18, 15)], [1.5, 1.1, 1.1]), FROG_SKIN, radius=1)
        eye_at, throat = (17.0, 5.5), [(19, 10), (20, 9)]
    forms.dots(picture, [(9, 8), (11, 7), (12, 9)], "green_dark")
    forms.dots(picture, throat, "sand_light")
    forms.paint(picture, forms.ellipse(width, height, *eye_at, 2.0, 2.0), "ochre")
    ex, ey = math.floor(eye_at[0]), math.floor(eye_at[1])
    forms.dots(picture, [(ex, ey), (ex + 1, ey)], "ink")
    forms.dots(picture, [(ex, ey - 1)], "cream")
    return outline(picture, "green_deep")


def sheets():
    """(name, cell size, rows of cells) of every sheet, a row per action in the order of
    WildlifeSprites."""
    actions = {
        "bird": (SPARROW_SIZE, sparrow_sheet()),
        "rabbit": (RABBIT_SIZE, rabbit_sheet()),
        "squirrel": (SQUIRREL_SIZE, squirrel_sheet()),
        "deer": (DEER_SIZE, deer_sheet()),
        "bee": (BEE_SIZE, {"hover": [bee(True), bee(False)]}),
        "butterfly": (
            BUTTERFLY_SIZE,
            {name: [butterfly(ramp, opening) for opening in (1.0, 0.5, 0.0)] for name, ramp in BUTTERFLY_WINGS.items()},
        ),
        "firefly": (FIREFLY_SIZE, firefly_sheet()),
        "mouse": (MOUSE_SIZE, mouse_sheet()),
        "frog": (FROG_SIZE, {"sit": [frog_sitting(), frog_sitting(croaking=True)], "hop": [frog_hopping(False), frog_hopping(True)]}),
    }
    return [(name, size, list(rows.values())) for name, (size, rows) in actions.items()]

