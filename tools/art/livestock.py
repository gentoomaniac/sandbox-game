"""Art for the farm animals: one sheet per species and look at assets/wildlife/<species>_<look>.png,
drawn at 32 px per tile.

Every sheet has the same rows (ACTIONS): standing idle, walking, grazing (pecking, for a hen),
asleep and running, one column per frame, and the animal stands in the bottom centre of its cell,
facing right (the game flips it to face left). game/scenes/wildlife/wildlife_sprites.gd
mirrors the cell sizes and the frames. The looks are those of the region around 1700-1800 (see
docs/art-style.md, "Props and animals").

The animals are drawn in the style of the people (character.py): rounded forms (forms.py)
shaded by the light from the top left, faces with an eye and its glint, and the outline in the
darkest colour of the coat. The four-legged ones (cattle, sheep, dogs, cats, horses) share one
way of putting a frame together (`quadruped_frame`); the hen and the rabbit are drawn whole for
each pose.
"""

import math

import forms
import numpy as np
from canvas import blank, outline

# The rows of every sheet, with their frames.
ACTIONS = {"idle": 2, "walk": 4, "graze": 2, "sleep": 2, "run": 4}
# --- Drawing at 32 px per tile ------------------------------------------------------------
#
# The animals drawn at 32 px per tile are put together from rounded forms (forms.py), like the
# people: the body and the neck with the head as polygons, shaded as one form by the light from
# the top left; the legs as limbs through their joints (for a horse the shoulder or hip, knee or
# hock, fetlock and hoof), the far ones a step darker; then by hand the eye with its glint, the
# nostril, the ears, the mane and the marks of the coat. Every point is where it is on the
# animal standing in its cell, facing right; a pose moves and turns them. The outline is the
# darkest colour of the coat, and goes round the legs too (they are thick enough now).

# How a leg is set for a step of a walk or a gallop: how far it swings forward from its top, and
# how far its lower part folds at its bend (the knee or the hock), in degrees.
LEG_STEPS = {
    "stand": (0, 0),
    "forward": (14, 0),
    "back": (-14, 0),
    "reach": (42, 15),
    "push": (-40, 10),
    "tuck": (35, 20),
    "fold": (-20, 55),
}
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
    ((("push", "reach"), ("push", "reach")), 3),
    ((("forward", "back"), ("stand", "back")), 0),
    ((("tuck", "fold"), ("tuck", "fold")), 3),
    ((("back", "stand"), ("back", "forward")), 0),
]
# The steps of a leg on the ground: it reaches down to the ground however it swings.
STANDING_STEPS = ("stand", "forward", "back")
# Light added at the top of a body and taken from its bottom (forms.light_level).
TOP_LIGHT = 0.28


def turned(point, origin, degrees):
    """`point` turned about `origin`: a point below the origin swings forward (to the right) for
    a positive angle."""
    angle = math.radians(degrees)
    x, y = point[0] - origin[0], point[1] - origin[1]
    return (
        origin[0] + x * math.cos(angle) + y * math.sin(angle),
        origin[1] - x * math.sin(angle) + y * math.cos(angle),
    )


def is_point(value):
    return isinstance(value, tuple) and len(value) == 2 and all(isinstance(v, (int, float)) for v in value)


def mapped(value, function, radius_function=None):
    """`value` with `function` applied to every point in it, however deep in lists, tuples and
    dicts: the parts of a head moved for a pose. `radius_function`, if given, is applied to every
    list of numbers: the radii of the legs and the ellipses."""
    if is_point(value):
        return function(value)
    if radius_function and isinstance(value, list) and value and all(isinstance(item, (int, float)) for item in value):
        return [radius_function(item) for item in value]
    if isinstance(value, dict):
        return {key: mapped(item, function, radius_function) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return type(value)(mapped(item, function, radius_function) for item in value)
    return value


def moved(value, dx, dy):
    return mapped(value, lambda point: (point[0] + dx, point[1] + dy))


def rounded(points):
    return [(round(x), round(y)) for x, y in points]


def leg_joints(leg, step, dy=0):
    """The joints of a leg set for a step (LEG_STEPS) on a body `dy` pixels lower than standing:
    swung from its top, its lower part folded at its bend (a foreleg's hoof backwards, a hind
    leg's forwards), and on the ground stretched or shortened to reach it (unless the body is off
    the ground, `dy` < 0)."""
    swing, fold = LEG_STEPS[step]
    joints = leg["joints"]
    top, bend = joints[0], leg["bend"]
    points = [turned(point, top, swing) for point in joints]
    fold = -fold if leg["front"] else fold
    points = points[: bend + 1] + [turned(point, points[bend], fold) for point in points[bend + 1 :]]
    if step in STANDING_STEPS and dy >= 0:
        reach = (joints[-1][1] - top[1] - dy) / (points[-1][1] - top[1])
        points = [(x, top[1] + (y - top[1]) * reach) for x, y in points]
    return moved(points, 0, dy)


def draw_leg(picture, animal, leg, joints, look, far, hidden=None):
    """A leg through its joints: shaded in the coat (that of the far side, a step darker, for a
    far leg), its lower part from the joint `leg["points"]` in the colour of the points if the
    look has them, and its hoof. `hidden` is the body in front of its top."""
    width, height = animal["size"]
    radii = leg["radii"]
    mask = forms.limb(width, height, joints, radii)
    if hidden is not None:
        mask &= ~hidden
    forms.shade(picture, mask, look["far_legs" if far else "legs"], 2)
    if "points" in look:
        start = leg["points"]
        lower = forms.limb(width, height, joints[start:], radii[start:]) & mask
        forms.shade(picture, lower, look["far_points" if far else "points"], 2)
    if animal.get("hoof"):
        (x, y), (rx, ry) = joints[-1], animal["hoof"]
        hoof = forms.ellipse(width, height, x + 0.5, y + ry, rx, ry)
        forms.shade(picture, hoof, look["hoof"], 1)


def draw_folded(picture, animal, look, dy):
    """The legs a lying animal has folded under it that show (its `folded` joints and radii)."""
    width, height = animal["size"]
    for joints, radii in moved(animal["folded"], 0, dy):
        forms.shade(picture, forms.limb(width, height, joints, radii), look["legs"], 2)
        if animal.get("hoof"):
            (x, y), (rx, ry) = joints[-1], animal["hoof"]
            forms.shade(picture, forms.ellipse(width, height, x + 0.5, y, rx, ry), look["hoof"], 1)


def strands(picture, start, end, bend, spread, ramp, count, seed):
    """A tail or a mane: `count` strands from `start` to around `end`, bowed by `bend`, `spread`
    wide at the end; dark, every third one lit along its middle."""
    height, width = len(picture), len(picture[0])
    rng = np.random.RandomState(seed)
    for index in range(count):
        offset = index / max(1, count - 1) - 0.5
        x0, y0 = start[0] + offset * spread * 0.4, start[1]
        x1, y1 = end[0] + offset * spread + rng.uniform(-1, 1), end[1] + rng.uniform(-2, 2)
        for step in range(41):
            t = step / 40
            x = round(x0 + (x1 - x0) * t + bend * math.sin(t * math.pi))
            y = round(y0 + (y1 - y0) * t)
            lit = index % 3 == 1 and 0.15 < t < 0.8
            if 0 <= y < height and 0 <= x < width:
                picture[y][x] = ramp[1] if lit else ramp[0]
                if index % 2 == 0 and x + 1 < width:
                    picture[y][x + 1] = ramp[0]


def shapes_mask(size, shapes):
    """The mask of a list of shapes: polygons (lists of points) and ellipses ((x, y), [rx, ry])."""
    width, height = size
    mask = np.zeros((height, width), bool)
    for shape in shapes:
        if isinstance(shape, tuple):
            (x, y), (rx, ry) = shape
            mask |= forms.ellipse(width, height, x, y, rx, ry)
        else:
            mask |= forms.polygon(width, height, shape)
    return mask


def quadruped_frame(
    animal, look, steps=None, head="ahead", tail="hanging", lying=False, head_drop=0, lift=0, crouch=0, saddle=None
):
    """One frame of a four-legged animal drawn at 32 px per tile, facing right: the far legs, the
    tail, the body with the neck and the head of `head` ("ahead", "down", ...), the marks of the
    coat, a saddle, the near legs and the face. `steps` names the near and the far hind and front
    leg's steps (LEG_STEPS); a lying animal has its legs folded under it and its eyes shut; a
    running one is `lift` pixels off the ground, a crouching one `crouch` pixels lower on bent
    legs, and a head moved `head_drop` pixels down."""
    width, height = animal["size"]
    picture = blank(width, height)
    dy = animal["lying_drop"] if lying else crouch - lift
    legs = animal["legs"]
    (near_hind, near_front), (far_hind, far_front) = steps or (("stand", "stand"), ("stand", "stand"))
    if not lying:
        for name, step in (("far_hind", far_hind), ("far_front", far_front)):
            draw_leg(picture, animal, legs[name], leg_joints(legs[name], step, dy), look, far=True)
    animal["draw_tail"](picture, look, animal, tail, dy)
    torso = shapes_mask(animal["size"], moved(animal["torso"], 0, dy))
    parts = moved(animal["heads"][head], 0, dy + head_drop)
    body = torso | shapes_mask(animal["size"], parts["shape"])
    level = forms.light_level(body, animal["shade_radius"], TOP_LIGHT)
    forms.shade_by_level(picture, body, look["coat"], level)
    animal["draw_coat"](picture, look, animal, body, level, dy)
    if saddle is not None:
        draw_saddle(picture, animal, saddle, dy)
    if lying:
        draw_folded(picture, animal, look, dy)
    else:
        for name, step in (("near_hind", near_hind), ("near_front", near_front)):
            joints = leg_joints(legs[name], step, dy)
            draw_leg(picture, animal, legs[name], joints, look, far=False, hidden=torso)
    animal["draw_head"](picture, look, animal, parts, lying)
    return outline(picture, look["outline"])


def quadruped_sheet(animal, look, saddle=None):
    """The rows of cells of a four-legged animal's sheet (ACTIONS): it flicks its tail standing,
    chews with its head down, breathes lying down and gallops, or hurries at a walk if it has no
    gallop (cattle and sheep)."""

    def frame(**pose):
        return quadruped_frame(animal, look, saddle=saddle, **pose)

    lying_head = animal.get("lying_head", "ahead")
    walk = [frame(steps=steps) for steps in WALK_STEPS]
    frames = {
        "idle": [frame(), frame(tail="swishing")],
        "walk": walk,
        "graze": [frame(head="down"), frame(head="down", head_drop=-1)],
        "sleep": [
            frame(lying=True, head=lying_head, tail="lying"),
            frame(lying=True, head=lying_head, tail="lying", head_drop=1),
        ],
        "run": [frame(steps=steps, lift=lift, tail="flying") for steps, lift in RUN_STEPS] if animal["gallops"] else walk,
    }
    return [frames[action] for action in ACTIONS]


def scaled(animal, factor, size=None):
    """The animal drawn `factor` times as big, standing on the ground in the middle of a cell of
    `size` (its own if not given): the pony is the horse made smaller."""
    width, height = animal["size"]
    new_width, new_height = size or animal["size"]
    ground, new_ground = height - 2, new_height - 2

    def scale(point):
        return (new_width / 2 + (point[0] - width / 2) * factor, new_ground + (point[1] - ground) * factor)

    result = mapped(animal, scale, lambda radius: radius * factor)
    return result | {"size": (new_width, new_height), "lying_drop": round(animal["lying_drop"] * factor)}


# --- Cattle -------------------------------------------------------------------------------
#
# A small cow of the period, 66 px long and 40 px to the top of the back (a person is 61 px
# tall): a long straight back with the hip and pin bones showing, a deep belly, an udder, short
# legs with cloven hooves and a tail with a tuft. The head is drawn by hand, a pixel at a time,
# since a head put together from shapes reads badly: looking ahead, and transposed (its rows as
# columns) to look down at the grass, which keeps the light from the top left. The cow is drawn
# in a 64x48 cell and set in its own cell 15 % larger (`scaled`).

COW_SIZE = (72, 54)
# The head facing right: d, b coat dark and base; F, f, W the face's shade, base and light (the
# white of a pied face); m, M muzzle and its shade; n nostril; e eye; g its glint.
COW_HEAD = (
    "...ddbF........",
    "..dbbbFf.......",
    ".dbbbbFWf......",
    "dbbeebFWWf.....",
    "dbbegbFffWf....",
    "FdbbbFffffWf...",
    "FFdbFffffffWf..",
    ".FFffffffffWf..",
    "..FFfffffffWWf.",
    "...FFfffffffWf.",
    "....FFfffffmmm.",
    ".....FFffmmmmmm",
    "......FFMmmmnmm",
    ".......FMmmmmmM",
    "........MMMMM..",
)
# The parts around the head, from its top left corner (looking ahead): the ear out to the side
# behind the eye with its pink inside, and the horn curving up and forward.
COW_EAR = [(3, 2), (-3, 1), (-2, 4), (3, 5)]
COW_EAR_INSIDE = [(-1, 2), (0, 2), (1, 3)]
COW_HORN = [(4, 1), (3, -2), (5, -4)]
COW_SMALL = {
    "size": (64, 48),
    "torso": [
        [(10, 12), (14, 10), (40, 11), (47, 12), (51, 18), (50, 30), (44, 34), (20, 35), (12, 31), (9, 22)],
        ((30, 27), [17, 9]),
        ((14, 15), [6, 5]),
    ],
    # The neck, and where the head's top left corner is; grazing, the head hangs to the grass.
    "heads": {
        "ahead": {"shape": [[(44, 12), (51, 12), (55, 18), (55, 27), (50, 33), (45, 24)]], "at": (48, 13)},
        "down": {"shape": [[(44, 12), (50, 13), (55, 20), (57, 29), (53, 34), (47, 26)]], "at": (49, 31), "down": True},
    },
    "legs": {
        "near_front": {"joints": [(47, 30), (48, 38), (48, 44)], "radii": [3.4, 2.1, 2.1], "bend": 1, "front": True},
        "far_front": {"joints": [(44, 30), (45, 38), (45, 44)], "radii": [3.0, 1.9, 1.9], "bend": 1, "front": True},
        "near_hind": {"joints": [(21, 28), (23, 33), (18, 39), (19, 44)], "radii": [4.6, 3.4, 2.1, 2.1], "bend": 2, "front": False},
        "far_hind": {"joints": [(17, 30), (15, 38), (16, 44)], "radii": [3.6, 1.9, 1.9], "bend": 1, "front": False},
    },
    "hoof": [2.7, 1.8],
    # The tail, a thin rope from the tail head down the back of the thigh, and its tuft.
    "tails": {
        "hanging": ([(9, 13), (7, 22), (7, 33)], (7, 35)),
        "swishing": ([(9, 13), (5, 21), (2, 30)], (2, 32)),
        "lying": ([(9, 13), (5, 19), (1, 24)], (1, 26)),
    },
    # The patches of a pied coat, by look.
    "spots": {
        "black_pied": [((22, 18), [9, 7]), ((38, 15), [7, 5.5]), ((13, 25), [4.5, 6]), ((47, 21), [3.5, 6]), ((31, 24), [4, 3])],
        "red_pied": [((16, 16), [7, 6]), ((34, 14), [8, 4.5]), ((49, 17), [5, 7]), ((26, 23), [4, 3])],
    },
    "udder": ((18, 35), [4.5, 3.4]),
    "teats": [(16, 38), (19, 38)],
    "bones": [(15, 11), (16, 11), (17, 12), (11, 13)],
    "folded": [
        ([(47, 30), (51, 35), (43, 36)], [2.8, 2.0, 1.8]),
        ([(21, 29), (27, 34), (34, 36)], [3.0, 2.2, 1.8]),
    ],
    "shade_radius": 5,
    "lying_drop": 10,
    "gallops": False,
}

COW_LOOKS = {
    # Angler: the dark red cattle of Angeln on the Baltic side, red in the face too.
    "angler": {
        "coat": ("russet_deep", "rust_dark", "rust_dark", "rust"),
        "face": {"F": "russet_deep", "f": "rust_dark", "W": "rust"},
        "muzzle": ("skin_shade", "russet_deep"),
        "outline": "russet_deep",
    },
    # Black and white marsh cattle of the North Sea coast, a white face with black round the eye.
    "black_pied": {
        "coat": ("stone_light", "lime", "lime", "snow_light"),
        "patches": ("bog_dark", "stone_dark", "stone"),
        "head_coat": ("bog_dark", "stone_dark"),
        "outline": "ink",
    },
    # Red pied: mostly white with red patches, the cattle of the marsh farms.
    "red_pied": {
        "coat": ("stone_light", "lime", "lime", "snow_light"),
        "patches": ("rust_dark", "rust", "red_light"),
        "head_coat": ("rust_dark", "rust"),
        "outline": "russet_deep",
    },
}
COW_WHITE_FACE = {"F": "stone_light", "f": "lime", "W": "snow_light"}
COW_SHARED = {"hoof": ("ink", "bog_dark", "stone_dark"), "muzzle": ("petal", "skin_shade"), "face": COW_WHITE_FACE}


def cow_look(look):
    style = COW_SHARED | COW_LOOKS[look] | {"name": look}
    coat = style["coat"]
    head_coat = style.get("head_coat", coat[:2])
    style |= {"legs": coat, "far_legs": (coat[0], coat[0], coat[1], coat[2]), "head_coat": head_coat}
    return style


def draw_cow_tail(picture, look, animal, tail, dy):
    width, height = animal["size"]
    rope, tuft = moved(animal["tails"][tail], 0, dy)
    dark = look.get("patches", look["coat"])[0]
    forms.paint(picture, forms.limb(width, height, rope, [1.2, 0.9, 0.9]), look["head_coat"][1])
    forms.paint(picture, forms.ellipse(width, height, tuft[0], tuft[1], 1.8, 3), dark)


def draw_cow_coat(picture, look, animal, body, level, dy):
    """The patches of a pied coat, shaded with the body, the hip bones, and the udder of a cow on
    its feet."""
    width, height = animal["size"]
    if "patches" in look:
        top = np.arange(height)[:, None] < animal["udder"][0][1] - 6 + dy
        patches = shapes_mask(animal["size"], moved(animal["spots"][look["name"]], 0, dy)) & body & top
        forms.shade_by_level(picture, patches, look["patches"], level)
    forms.dots(picture, rounded(moved(animal["bones"], 0, dy)), look["coat"][0])
    if dy <= 0:
        (x, y), (rx, ry) = moved(animal["udder"], 0, dy)
        forms.shade(picture, forms.ellipse(width, height, x, y, rx, ry), ("skin_shade", "petal", "petal"), 2)
        forms.dots(picture, rounded(moved(animal["teats"], 0, dy)), "skin_shade")


def draw_cow_head(picture, look, animal, head, asleep):
    """The hand-drawn head at its place, the ear and the horn; transposed for looking down."""
    left, top = rounded([head["at"]])[0]
    down = head.get("down", False)
    keys = {"d": look["head_coat"][0], "b": look["head_coat"][1], "e": "ink", "g": "stone_light", "n": "rust_dark"}
    keys |= look["face"] | {"m": look["muzzle"][0], "M": look["muzzle"][1]}
    if asleep:
        keys |= {"e": look["head_coat"][0], "g": look["head_coat"][0]}
    rows = COW_HEAD
    if down:
        rows = ["".join(row[x] for row in COW_HEAD) for x in range(len(COW_HEAD[0]))]

    def place(points):
        return [(left + (y if down else x), top + (x if down else y)) for x, y in points]

    width, height = animal["size"]
    forms.shade(picture, forms.polygon(width, height, place(COW_EAR)), (look["head_coat"][0], look["head_coat"][1]), 1)
    forms.dots(picture, place(COW_EAR_INSIDE), "petal")
    for y, row in enumerate(rows):
        for x, key in enumerate(row):
            if key != ".":
                forms.dots(picture, [(left + x, top + y)], keys[key])
    forms.paint(picture, forms.limb(width, height, place(COW_HORN), [1.2, 1.0, 0.7]), "cream")
    forms.dots(picture, place(COW_HORN[-1:]), "stone")


COW = scaled(
    COW_SMALL | {"draw_tail": draw_cow_tail, "draw_coat": draw_cow_coat, "draw_head": draw_cow_head},
    1.15,
    COW_SIZE,
)


def cow_sheet(look):
    return quadruped_sheet(COW, cow_look(look))


# --- Sheep --------------------------------------------------------------------------------
#
# A small heath or marsh sheep, 38 px from the tail to the nose and 22 px to its back: a cloud of
# wool with a lumpy edge and curls in it, a narrow face with the ears out to the sides, and thin
# legs with dark hooves.

SHEEP_SIZE = (44, 32)
SHEEP = {
    "size": SHEEP_SIZE,
    "torso": [
        ((19, 16), [12, 7.5]),
        ((10, 12), [5, 4]),
        ((17, 10), [5, 4]),
        ((24, 10), [5, 4]),
        ((30, 13), [4, 4]),
        ((8, 18), [4, 4]),
    ],
    # The wool of the neck, and the face drawn on it: its outline, the ear, the eye and the mouth.
    "heads": {
        "ahead": {
            "shape": [((30, 12), [4, 4])],
            "face": [(31, 9), (35, 7), (39, 9), (41, 13), (40, 16), (37, 16), (33, 14)],
            "ear": [(32, 8), (28, 9), (29, 11), (32, 10)],
            "eye": (35, 10),
            "mouth": [(39, 15), (40, 15)],
            "topknot": ((34, 8), [2.5, 1.8]),
        },
        "down": {
            "shape": [((31, 15), [4, 5])],
            "face": [(31, 14), (34, 13), (37, 17), (39, 24), (38, 28), (35, 28), (33, 21)],
            "ear": [(32, 14), (28, 15), (29, 17), (32, 16)],
            "eye": (35, 18),
            "mouth": [(36, 27), (37, 27)],
            "topknot": ((33, 14), [2.5, 1.8]),
        },
    },
    "legs": {
        "near_front": {"joints": [(29, 21), (29, 25), (29, 28)], "radii": [1.8, 1.4, 1.4], "bend": 1, "front": True},
        "far_front": {"joints": [(27, 21), (27, 25), (27, 28)], "radii": [1.6, 1.3, 1.3], "bend": 1, "front": True},
        "near_hind": {"joints": [(11, 20), (12, 24), (10, 26), (10, 28)], "radii": [2.2, 1.6, 1.4, 1.4], "bend": 2, "front": False},
        "far_hind": {"joints": [(13, 21), (12, 25), (12, 28)], "radii": [1.6, 1.3, 1.3], "bend": 1, "front": False},
    },
    "hoof": [1.6, 1.0],
    "tails": {
        "hanging": ((7, 13), [2, 3]),
        "swishing": ((6, 15), [2.5, 2]),
        "lying": ((7, 14), [2, 3]),
    },
    "folded": [([(28, 22), (31, 23), (25, 24)], [1.4, 1.2, 1.2])],
    "shade_radius": 4,
    "lying_drop": 6,
    "gallops": False,
}

SHEEP_LOOKS = {
    # The white marsh sheep of the dykes, with a pale face.
    "white": {
        "coat": ("stone_light", "lime", "lime", "cream"),
        "face": ("sand", "sand_light", "sand_light"),
        "ear": "sand",
        "legs": ("sand", "sand_light", "sand_light", "sand_light"),
        "outline": "stone",
    },
    # The grey heath sheep of the Geest (Heidschnucke), black in the face and legs; drawn hornless.
    "grey": {
        "coat": ("stone", "stone_light", "stone_light", "lime"),
        "face": ("ink", "stone_dark", "stone_dark"),
        "ear": "stone_dark",
        "legs": ("ink", "stone_dark", "stone_dark", "stone_dark"),
        "outline": "stone_dark",
    },
    # White wool and a black face.
    "black_faced": {
        "coat": ("stone_light", "lime", "lime", "cream"),
        "face": ("ink", "stone_dark", "stone_dark"),
        "ear": "stone_dark",
        "legs": ("ink", "stone_dark", "stone_dark", "stone_dark"),
        "outline": "stone",
    },
}


def sheep_look(look):
    style = SHEEP_LOOKS[look] | {"hoof": ("ink", "ink", "stone_dark")}
    legs = style["legs"]
    return style | {"far_legs": (legs[0], legs[0], legs[1], legs[1])}


def draw_sheep_tail(picture, look, animal, tail, dy):
    (x, y), (rx, ry) = moved(animal["tails"][tail], 0, dy)
    width, height = animal["size"]
    forms.shade(picture, forms.ellipse(width, height, x, y, rx, ry), look["coat"][:3], 1)


def draw_sheep_coat(picture, look, animal, body, level, dy):
    """Curls in the wool: little dark hooks scattered in rows, on what is not in the light."""
    height, width = body.shape
    curls = np.zeros(body.shape, bool)
    for y in range(1, height - 1, 3):
        for x in range((y * 5) % 4, width - 1, 4):
            curls[y, x] = curls[y + 1, x + 1] = True
    curls &= forms.shrunk(forms.shrunk(body)) & (level < 0.85)
    forms.paint(picture, curls, look["coat"][0])


def draw_sheep_head(picture, look, animal, head, asleep):
    width, height = animal["size"]
    forms.shade(picture, forms.polygon(width, height, head["face"]), look["face"], 2)
    forms.paint(picture, forms.polygon(width, height, head["ear"]), look["ear"])
    (x, y), (rx, ry) = head["topknot"]
    if look["face"][0] != "ink":
        forms.shade(picture, forms.ellipse(width, height, x, y, rx, ry), look["coat"][1:], 1)
    x, y = rounded([head["eye"]])[0]
    if asleep:
        forms.dots(picture, [(x, y + 1), (x + 1, y + 1)], look["face"][0])
    else:
        eye = "ink" if look["face"][0] != "ink" else "sand_light"
        forms.dots(picture, [(x, y), (x + 1, y)], eye)
        forms.dots(picture, [(x, y + 1), (x + 1, y + 1)], "ink" if eye == "ink" else look["face"][0])
    forms.dots(picture, rounded(head["mouth"]), look["face"][0] if look["face"][0] != "ink" else "stone")


SHEEP |= {"draw_tail": draw_sheep_tail, "draw_coat": draw_sheep_coat, "draw_head": draw_sheep_head}


def sheep_sheet(look):
    return quadruped_sheet(SHEEP, sheep_look(look))


# --- Chickens -----------------------------------------------------------------------------
#
# A hen drawn a little larger than life, 22 px from the tail to the beak: a plump body with the
# breast forward, the tail raised behind, a folded wing in rows of feathers, a red comb and
# wattle, an eye with a glint and yellow legs with spread toes. She is drawn whole for each
# frame: her head and body move for a pose (`hen_frame`). The rooster has a bigger comb, golden
# hackles and dark sickle feathers in his tail.

CHICKEN_SIZE = (24, 24)
CHICKEN_GROUND = 22
# A walk: how far each foot is ahead and how high it is lifted, the near foot then the far one.
CHICKEN_STEPS = [(2, 0, -2, 0), (0, 2, 0, 0), (-2, 0, 2, 0), (0, 0, 0, 2)]
# The head's middle standing, pecking at the ground and coming up from it, and drawn in asleep
# (breathing out, it sinks a little).
HEN_HEADS = {"up": (18, 5), "peck": (21, 17), "peck_up": (21, 11), "tucked": (17, 10), "sunk": (17, 11)}
CHICKEN_LOOKS = {
    # A brown farm hen.
    "brown": {
        "plumage": ("umber", "ochre_dark", "ochre", "maple_light"),
        "wing": ("soil_dark", "umber", "ochre_dark"),
        "tail": ("soil_dark", "umber", "ochre_dark"),
        "scallop": "ochre",
        "outline": "soil_dark",
    },
    "white": {
        "plumage": ("stone_light", "lime", "lime", "snow_light"),
        "wing": ("stone", "stone_light", "lime"),
        "tail": ("stone", "stone_light", "lime"),
        "scallop": "snow_light",
        "outline": "stone",
    },
    # The rooster: red-brown, golden hackles, a dark tail of sickle feathers and a big comb.
    "rooster": {
        "plumage": ("rust_dark", "rust", "rust", "maple_light"),
        "wing": ("russet_deep", "rust_dark", "rust"),
        "tail": ("ink", "green_deep", "green_dark"),
        "scallop": "red_light",
        "hackle": ("ochre_dark", "ochre", "gold"),
        "sickles": True,
        "outline": "russet_deep",
    },
}


def chicken_legs(picture, steps):
    """The legs and toes, standing or in a step (CHICKEN_STEPS); `steps` None for a sitting hen."""
    if steps is None:
        return
    for x, (ahead, lift) in ((10, steps[2:]), (13, steps[:2])):
        x, foot = x + ahead, CHICKEN_GROUND - lift
        forms.dots(picture, [(x, y) for y in range(16, foot)], "ochre_dark")
        forms.dots(picture, [(x + 1, y) for y in range(17, foot - 1)], "ochre")
        forms.dots(picture, [(x + dx, foot) for dx in range(-2, 3)] + [(x - 1, foot - 1)], "ochre")


def hen_frame(look, head="up", steps=(0, 0, 0, 0), eye_shut=False):
    """One frame of a hen of `look`: her head at HEN_HEADS[head], her legs in `steps` (None: she
    sits on them), her eye open or shut."""
    style = CHICKEN_LOOKS[look]
    width, height = CHICKEN_SIZE
    picture = blank(width, height)
    sitting = steps is None
    drop = 4 if sitting else 0
    hx, hy = HEN_HEADS[head]
    # Pecking, the body tips forward and the tail rises.
    tip = 2 if head.startswith("peck") else 0
    chicken_legs(picture, steps)
    tail = moved([(2, 3), (5, 2), (8, 8), (8, 14), (3, 13), (1, 7)], 0, drop - tip)
    forms.shade(picture, forms.polygon(width, height, tail), style["tail"], 2)
    forms.dots(picture, rounded(moved([(3, 5), (4, 7), (4, 9), (5, 11)], 0, drop - tip)), style["tail"][0])
    if style.get("sickles"):
        sickles = forms.limb(width, height, moved([(6, 6), (2, 1), (0, 6), (1, 12)], 0, drop - tip), [1.2, 1.0, 0.8, 0.6])
        forms.shade(picture, sickles, style["tail"], 1)
    body = forms.ellipse(width, height, 12, 12 + drop, 8, 6.5) | forms.ellipse(width, height, 15 + tip, 10 + drop + tip, 5.5, 5)
    neck = forms.capsule(width, height, (15 + tip, 9 + drop + tip), (hx - 1, hy + 1), 2.8, 2.4)
    forms.shade(picture, body | neck, style["plumage"], 4)
    if "hackle" in style:
        forms.shade(picture, neck & ~body, style["hackle"], 1)
    wing = forms.ellipse(width, height, 11, 12 + drop, 5.2, 3.6)
    forms.shade(picture, wing, style["wing"], 2)
    for y in (12, 14, 16):
        forms.dots(picture, [(x, y + drop) for x in range(7 + (y // 2) % 2, 16, 2) if wing[y + drop, x]], style["scallop"])
    forms.shade(picture, forms.ellipse(width, height, hx, hy, 3.4, 3.4), style["plumage"], 2)
    # The comb on the crown, the beak, the wattle under it and the eye.
    big = style.get("sickles", False)
    comb = [(hx - 2, hy - 4), (hx - 1, hy - 4), (hx, hy - 4), (hx - 1, hy - 5), (hx + 1, hy - 4), (hx - 3, hy - 3)]
    if big:
        comb += [(hx - 2, hy - 5), (hx, hy - 5), (hx + 1, hy - 5), (hx - 1, hy - 6), (hx + 1, hy - 6)]
    forms.dots(picture, comb, "red_light")
    forms.dots(picture, [(hx + 3, hy), (hx + 4, hy), (hx + 3, hy + 1)], "gold")
    forms.dots(picture, [(hx + 4, hy + 1)], "ochre_dark")
    wattle = [(hx + 2, hy + 2), (hx + 2, hy + 3), (hx + 1, hy + 3)] + ([(hx + 1, hy + 4), (hx + 2, hy + 4)] if big else [])
    forms.dots(picture, wattle, "red_light")
    if eye_shut:
        forms.dots(picture, [(hx + 1, hy - 1)], style["plumage"][0])
    else:
        forms.dots(picture, [(hx + 1, hy - 2), (hx + 1, hy - 1)], "ink")
        forms.dots(picture, [(hx + 2, hy - 2)], "cream")
    return outline(picture, style["outline"])


def chicken_sheet(look):
    walk = [hen_frame(look, steps=steps) for steps in CHICKEN_STEPS]
    frames = {
        "idle": [hen_frame(look), hen_frame(look, eye_shut=True)],
        "walk": walk,
        "graze": [hen_frame(look, head="peck"), hen_frame(look, head="peck_up")],
        "sleep": [hen_frame(look, head="tucked", steps=None, eye_shut=True), hen_frame(look, head="sunk", steps=None, eye_shut=True)],
        "run": walk,
    }
    return [frames[action] for action in ACTIONS]


# --- Rabbits -------------------------------------------------------------------------------
#
# A tame rabbit drawn a little larger than life, 20 px long sitting: round haunches, a short
# front, a round head with long ears, a white scut. It sits, nibbles with its head down, hops
# stretched out, and sleeps flat in a loaf with its ears laid back. Each pose places the parts
# (`RABBIT_POSES`): the haunch, the front, the head and the ears (from their roots to their
# tips), the hind foot, the front paw and how high it is off the ground.

RABBIT_SIZE = (24, 20)
RABBIT_POSES = {
    "sit": {"haunch": ((9, 13), [6.5, 5]), "front": ((14, 12), [4, 4.5]), "head": (17, 8), "ears": [((16, 6), (13, 0)), ((17, 6), (16, 0))], "foot": ((9, 17), [4, 1.5]), "paw": [(15, 14), (16, 17)]},
    "twitch": {"haunch": ((9, 13), [6.5, 5]), "front": ((14, 12), [4, 4.5]), "head": (17, 8), "ears": [((16, 6), (12, 1)), ((17, 6), (17, 0))], "foot": ((9, 17), [4, 1.5]), "paw": [(15, 14), (16, 17)]},
    "nibble": {"haunch": ((9, 13), [6.5, 5]), "front": ((14, 13), [4, 4]), "head": (18, 13), "ears": [((16, 11), (11, 7)), ((17, 11), (13, 6))], "foot": ((9, 17), [4, 1.5]), "paw": [(15, 15), (16, 17)]},
    "stretch": {"haunch": ((8, 11), [6, 4]), "front": ((15, 10), [5, 3.5]), "head": (19, 7), "ears": [((18, 5), (13, 2)), ((19, 5), (15, 1))], "foot": ((2, 13), [3, 1.5]), "paw": [(19, 12), (21, 14)]},
    "land": {"haunch": ((8, 12), [6, 4.5]), "front": ((15, 12), [4.5, 4]), "head": (19, 9), "ears": [((18, 7), (14, 2)), ((19, 7), (16, 1))], "foot": ((6, 15), [3.5, 1.5]), "paw": [(18, 15), (19, 17)]},
    "loaf": {"haunch": ((9, 15), [7, 3.5]), "front": ((14, 15), [4, 3]), "head": (18, 12), "ears": [((16, 10), (9, 9)), ((17, 9), (11, 7))], "foot": None, "paw": None},
    "loaf_low": {"haunch": ((9, 15), [7, 3.3]), "front": ((14, 15), [4, 2.8]), "head": (18, 13), "ears": [((16, 11), (9, 10)), ((17, 10), (11, 8))], "foot": None, "paw": None},
}
RABBIT_LOOKS = {
    # The grey-brown of the wild rabbit (agouti).
    "agouti": {"coat": ("mud", "sand", "sand", "sand_light"), "ear": "petal", "eye": "ink", "outline": "mud_dark"},
    # White with pink eyes.
    "white": {"coat": ("stone_light", "lime", "lime", "snow_light"), "ear": "petal", "eye": "red_light", "outline": "stone"},
    # Dutch: dark ears, head and rump, a white blaze, collar and forelegs.
    "dutch": {"coat": ("ink", "stone_dark", "stone_dark", "stone"), "ear": "petal", "eye": "ink", "white": ("stone_light", "lime", "lime"), "outline": "ink"},
}


def rabbit_frame(look, pose, lift=0, eye_shut=False):
    style = RABBIT_LOOKS[look]
    parts = moved(RABBIT_POSES[pose], 0, -lift)
    width, height = RABBIT_SIZE
    picture = blank(width, height)
    coat = style["coat"]
    ears = [forms.capsule(width, height, root, tip, 1.5, 1.1) for root, tip in parts["ears"]]
    forms.shade(picture, ears[0], (coat[0], coat[0], coat[1]), 1)
    if parts["foot"]:
        (x, y), (rx, ry) = parts["foot"]
        forms.shade(picture, forms.ellipse(width, height, x, y, rx, ry), coat[:3], 1)
    (x, y), (rx, ry) = parts["haunch"]
    body = forms.ellipse(width, height, x, y, rx, ry)
    (fx, fy), (frx, fry) = parts["front"]
    front = forms.ellipse(width, height, fx, fy, frx, fry)
    hx, hy = parts["head"]
    head = forms.ellipse(width, height, hx, hy, 3.6, 3.2) | forms.ellipse(width, height, hx + 2, hy + 1, 2.2, 2)
    whole = body | front | head
    level = forms.light_level(whole, 4, TOP_LIGHT)
    forms.shade_by_level(picture, whole, coat, level)
    if "white" in style:
        # The Dutch rabbit's white: the blaze down the face, the collar and the forelegs.
        blaze = forms.polygon(width, height, [(hx + 1, hy - 3), (hx + 2, hy - 3), (hx + 4, hy + 3), (hx, hy + 3)])
        forms.shade_by_level(picture, (front | blaze) & whole, style["white"], level)
    if parts["paw"]:
        paw = forms.capsule(width, height, *parts["paw"], 1.3, 1.1)
        forms.shade(picture, paw, style.get("white", coat)[:3], 1)
    forms.shade(picture, ears[1], (coat[1], coat[2], coat[3]), 1)
    (root_x, root_y), (tip_x, tip_y) = parts["ears"][1]
    forms.dots(picture, [(round((root_x + tip_x) / 2), round((root_y + tip_y) / 2))], style["ear"])
    # The scut, the eye and the nose.
    forms.shade(picture, forms.ellipse(width, height, x - rx + 0.5, y - 1, 1.8, 1.8), ("stone_light", "lime", "snow_light"), 1)
    ex, ey = round(hx + 1), round(hy - 1)
    if eye_shut:
        forms.dots(picture, [(ex, ey + 1), (ex + 1, ey + 1)], coat[0])
    else:
        forms.dots(picture, [(ex, ey), (ex, ey + 1)], style["eye"])
        forms.dots(picture, [(ex + 1, ey)], "cream")
    forms.dots(picture, [(round(hx + 4), round(hy + 1))], "petal")
    return outline(picture, style["outline"])


def rabbit_sheet(look):
    sit = rabbit_frame(look, "sit")
    hop = [rabbit_frame(look, "stretch", lift=2), rabbit_frame(look, "stretch", lift=4), rabbit_frame(look, "land"), sit]
    frames = {
        "idle": [sit, rabbit_frame(look, "twitch")],
        "walk": hop,
        "graze": [rabbit_frame(look, "nibble"), rabbit_frame(look, "nibble", lift=1)],
        "sleep": [rabbit_frame(look, "loaf", eye_shut=True), rabbit_frame(look, "loaf_low", eye_shut=True)],
        "run": hop,
    }
    return [frames[action] for action in ACTIONS]


# --- Dogs ---------------------------------------------------------------------------------
#
# A farm dog, 40 px from the rump to the nose and 22 px to its back: a deep chest, a tucked-up
# belly and sturdy legs, a skull with a clear stop before the muzzle. The three looks differ in
# their ears and tails as well as their coats: the collie's ears half pricked with folded tips
# and its bushy tail carried low, the spitz's pricked ears, ruff and tail curled over its back,
# the pointer's drop ears and thin straight tail.

DOG_SIZE = (48, 36)
DOG = {
    "size": DOG_SIZE,
    "torso": [[(10, 11), (16, 9), (28, 9), (33, 10), (36, 14), (35, 20), (30, 22), (22, 20), (14, 21), (10, 18), (9, 14)]],
    # The neck, the skull and the muzzle, and where the eye, the nose and the ears are.
    "heads": {
        "ahead": {
            "shape": [[(31, 11), (34, 6), (38, 3), (41, 7), (38, 14), (33, 16)], ((40, 6), [4, 3.5]), [(42, 4), (47, 6), (47, 9), (42, 10)]],
            "skull": (40, 6),
            "eye": (41, 4),
            "nose": [(46, 6), (47, 6), (46, 7)],
            "mouth": [(44, 9), (45, 9)],
        },
        "down": {
            "shape": [[(31, 11), (35, 10), (39, 15), (42, 20), (37, 22), (33, 16)], ((40, 20), [4, 3.5]), [(39, 21), (44, 23), (44, 28), (40, 27)]],
            "skull": (40, 20),
            "eye": (41, 20),
            "nose": [(43, 27), (44, 27), (43, 28)],
            "mouth": [(40, 26)],
        },
        "rest": {
            "shape": [[(31, 11), (35, 10), (39, 13), (37, 18), (33, 17)], ((40, 15), [4, 3.5]), [(42, 14), (47, 16), (47, 19), (42, 19)]],
            "skull": (40, 15),
            "eye": (41, 13),
            "nose": [(46, 15), (47, 15), (46, 16)],
            "mouth": [(44, 18), (45, 18)],
        },
    },
    "legs": {
        "near_front": {"joints": [(31, 17), (32, 25), (32, 32)], "radii": [2.6, 1.8, 1.6], "bend": 1, "front": True},
        "far_front": {"joints": [(29, 18), (30, 25), (30, 32)], "radii": [2.2, 1.6, 1.4], "bend": 1, "front": True},
        "near_hind": {"joints": [(13, 16), (15, 22), (11, 27), (12, 32)], "radii": [3.4, 2.4, 1.6, 1.6], "bend": 2, "front": False},
        "far_hind": {"joints": [(16, 17), (15, 24), (14, 32)], "radii": [2.4, 1.6, 1.4], "bend": 1, "front": False},
    },
    # The paws, drawn like hooves in the colour of the legs.
    "hoof": [2.0, 1.2],
    "folded": [([(31, 17), (36, 21), (43, 21)], [2.2, 1.6, 1.6])],
    "shade_radius": 4,
    "lying_drop": 10,
    "lying_head": "rest",
    "gallops": True,
}
# The tails of the looks, as a limb through its points and how thick at each, by pose.
DOG_TAILS = {
    "collie": {
        "hanging": [(9, 12), (6, 18), (6, 24)],
        "swishing": [(9, 12), (5, 16), (2, 21)],
        "flying": [(9, 12), (4, 11), (1, 11)],
        "lying": [(9, 12), (5, 17), (2, 20)],
    },
    "spitz": {
        "hanging": [(10, 10), (8, 5), (11, 2), (15, 4)],
        "swishing": [(10, 10), (9, 5), (12, 2), (16, 3)],
        "flying": [(10, 10), (7, 6), (9, 2), (13, 3)],
        "lying": [(10, 10), (8, 5), (11, 2), (15, 4)],
    },
    "pointer": {
        "hanging": [(9, 11), (5, 13), (2, 16)],
        "swishing": [(9, 11), (5, 9), (2, 8)],
        "flying": [(9, 11), (5, 10), (1, 10)],
        "lying": [(9, 11), (5, 14), (2, 17)],
    },
}
DOG_TAIL_RADII = {"collie": [2.0, 2.4, 1.8], "spitz": [2.2, 2.8, 2.6, 2.0], "pointer": [1.4, 1.1, 0.8]}
# The ears from the middle of the skull: a polygon each, and the folded tip of the collie's.
DOG_EARS = {
    "collie": [[(-3, -2), (-2, -7), (1, -3)], [(-1, -2), (1, -7), (2, -2)]],
    "spitz": [[(-3, -2), (-2, -8), (1, -3)], [(-1, -2), (1, -8), (3, -2)]],
    "pointer": [[(-3, -3), (1, -3), (0, 2), (-3, 4)]],
}
DOG_EAR_TIPS = {"collie": [(-1, -7), (0, -6), (2, -6)]}

DOG_LOOKS = {
    # The farm collie: sable, with a white collar, chest, legs and tail tip.
    "collie": {
        "coat": ("soil", "soil_mid", "soil_mid", "soil_light"),
        "white": ("stone_light", "lime", "lime"),
        "bib": [[(32, 10), (37, 10), (38, 19), (31, 21)], ((36, 10), [4, 3])],
        "legs": ("stone_light", "lime", "lime", "lime"),
        "outline": "soil_dark",
    },
    # A spitz: white with a cream shade and a ruff.
    "spitz": {
        "coat": ("stone_light", "lime", "lime", "cream"),
        "white": ("stone_light", "lime", "cream"),
        "bib": [((36, 11), [4, 5])],
        "legs": ("stone_light", "lime", "lime", "lime"),
        "outline": "stone",
    },
    # The hunting dog: liver with white patches on its body.
    "pointer": {
        "coat": ("soil_dark", "soil", "soil", "soil_mid"),
        "white": ("stone_light", "lime", "lime"),
        "bib": [((17, 16), [5, 3.5]), ((28, 18), [5, 2.5]), ((35, 15), [2.5, 4])],
        "legs": ("soil_dark", "soil", "soil", "soil_mid"),
        "outline": "ink",
    },
}


def dog_look(look):
    style = DOG_LOOKS[look] | {"name": look}
    legs = style["legs"]
    return style | {"far_legs": (legs[0], legs[0], legs[1], legs[2]), "hoof": legs[1:]}


def draw_dog_tail(picture, look, animal, tail, dy):
    width, height = animal["size"]
    points = moved(DOG_TAILS[look["name"]][tail], 0, dy)
    forms.shade(picture, forms.limb(width, height, points, DOG_TAIL_RADII[look["name"]]), look["coat"], 2)
    if look["name"] == "collie":
        x, y = points[-1]
        forms.paint(picture, forms.ellipse(width, height, x, y, 1.8, 1.8), look["white"][1])


def draw_dog_coat(picture, look, animal, body, level, dy):
    """The white of the coat (the collie's collar and chest, the spitz's ruff, the pointer's
    patches), shaded with the body."""
    width, height = animal["size"]
    white = shapes_mask(animal["size"], moved(look["bib"], 0, dy)) & body
    forms.shade_by_level(picture, white, look["white"], level)


def draw_dog_head(picture, look, animal, head, asleep):
    width, height = animal["size"]
    cx, cy = head["skull"]
    ears = DOG_EARS[look["name"]]
    for index, ear in enumerate(ears):
        shades = look["coat"][:2] if index == 0 or len(ears) == 1 else look["coat"][1:3]
        forms.shade(picture, forms.polygon(width, height, moved(ear, cx, cy)), shades, 1)
    forms.dots(picture, rounded(moved(DOG_EAR_TIPS.get(look["name"], []), cx, cy)), look["coat"][0])
    x, y = rounded([head["eye"]])[0]
    if asleep:
        forms.dots(picture, [(x, y + 1), (x + 1, y + 1)], look["coat"][0])
    else:
        forms.dots(picture, [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)], "ink")
        forms.dots(picture, [(x, y)], "cream")
    forms.dots(picture, rounded(head["nose"]), "ink")
    forms.dots(picture, rounded(head["mouth"]), look["coat"][0])


DOG |= {"draw_tail": draw_dog_tail, "draw_coat": draw_dog_coat, "draw_head": draw_dog_head}


def dog_sheet(look):
    return quadruped_sheet(DOG, dog_look(look))


# --- Cats ---------------------------------------------------------------------------------
#
# A farm cat, drawn a little larger than life: 28 px from the rump to the nose, a long low body,
# the head turned a little to the viewer with both eyes, pointed ears pink inside, whiskers, and
# a long ringed tail held up. The tabby has stripes over its back and flank.

CAT_SIZE = (32, 24)
CAT = {
    "size": CAT_SIZE,
    "torso": [((15, 12), [9.5, 4.4])],
    # The neck and the round head, and where the head's middle is (the face is drawn from it).
    "heads": {
        "ahead": {"shape": [((22, 10), [3, 3]), ((26, 8), [4.4, 4])], "skull": (26, 8)},
        "down": {"shape": [((22, 12), [3, 3]), ((27, 15), [4.4, 4])], "skull": (27, 15)},
        "rest": {"shape": [((22, 11), [3, 3]), ((27, 12), [4.4, 4])], "skull": (27, 12)},
        # On the hunt: low, level with the back.
        "low": {"shape": [((22, 11), [3, 3]), ((27, 10), [4.4, 3.8])], "skull": (27, 10)},
    },
    "legs": {
        "near_front": {"joints": [(22, 13), (21, 18), (21, 21)], "radii": [2.4, 1.5, 1.5], "bend": 1, "front": True},
        "far_front": {"joints": [(24, 13), (24, 18), (24, 21)], "radii": [2.2, 1.4, 1.4], "bend": 1, "front": True},
        "near_hind": {"joints": [(10, 13), (12, 17), (10, 21)], "radii": [3.0, 1.6, 1.5], "bend": 1, "front": False},
        "far_hind": {"joints": [(8, 13), (8, 17), (8, 21)], "radii": [2.6, 1.4, 1.4], "bend": 1, "front": False},
    },
    # The paws, drawn like hooves in the light of the coat.
    "hoof": [1.6, 0.9],
    "tails": {
        "hanging": [(6, 11), (3, 8), (3, 4), (5, 2), (7, 2)],
        "swishing": [(6, 11), (2, 9), (1, 5), (2, 2), (4, 1)],
        "flying": [(6, 11), (3, 10), (0, 10)],
        "lying": [(6, 11), (3, 14), (5, 18), (10, 19)],
        "flat": [(6, 12), (3, 16), (0, 19)],
        "flicking": [(6, 12), (3, 15), (1, 15), (0, 13)],
    },
    "stripes": [(x, 8) for x in range(8, 23, 3)],
    "folded": [([(21, 13), (24, 16), (28, 16)], [1.8, 1.4, 1.3])],
    "shade_radius": 3,
    "lying_drop": 5,
    "lying_head": "rest",
    "gallops": True,
}
# The face, from the middle of the head: the ears with their pink inside, the forehead bars of a
# tabby, the eyes (iris over pupil), the light muzzle, the nose and the whiskers.
CAT_EARS = [[(-4, -3), (-2, -8), (0, -3)], [(0, -3), (2, -8), (4, -3)]]
CAT_EAR_INSIDE = [(-2, -5), (-2, -4), (2, -5), (2, -4)]
CAT_BARS = [(-1, -3), (0, -3), (1, -3), (0, -2)]
CAT_EYES = [(-1, 0), (2, 0)]
CAT_MUZZLE = [(3, 2), (3, 3), (4, 2)]
CAT_NOSE = [(4, 1)]
CAT_WHISKERS = [(5, 3), (6, 2), (5, 4)]

CAT_LOOKS = {
    # The grey-brown tabby, striped dark, with olive-green eyes.
    "tabby": {"coat": ("mud", "sand", "sand", "sand_light"), "stripe": "mud_dark", "eye": "olive", "outline": "mud_dark"},
    "black": {"coat": ("ink", "stone_dark", "stone_dark", "stone"), "eye": "gold", "outline": "ink"},
    "ginger": {"coat": ("rust", "flame", "flame", "maple_light"), "stripe": "rust", "eye": "olive", "outline": "russet_deep"},
}


def cat_look(look):
    style = CAT_LOOKS[look]
    coat = style["coat"]
    return style | {"legs": coat, "far_legs": (coat[0], coat[0], coat[1], coat[2]), "hoof": coat[1:]}


def draw_cat_tail(picture, look, animal, tail, dy):
    width, height = animal["size"]
    points = moved(animal["tails"][tail], 0, dy)
    tail_mask = forms.limb(width, height, points, [1.6, 1.5, 1.4, 1.3, 1.2][: len(points)])
    forms.shade(picture, tail_mask, look["coat"][:3], 1)
    if "stripe" in look:
        rings = tail_mask & (np.arange(height)[:, None] % 3 == 0)
        forms.paint(picture, rings, look["stripe"])


def draw_cat_coat(picture, look, animal, body, level, dy):
    """A tabby's stripes down the back and the flank, and the pale belly."""
    width, height = animal["size"]
    if "stripe" in look:
        for x, y in rounded(moved(animal["stripes"], 0, dy)):
            forms.dots(picture, [(x, y), (x, y + 1), (x + 1, y + 2), (x + 1, y + 3)], look["stripe"])
    torso = shapes_mask(animal["size"], moved(animal["torso"], 0, dy))
    belly = torso & ~np.roll(torso, -1, axis=0) & body
    forms.paint(picture, belly & (np.arange(width)[None, :] > 10), look["coat"][3])


def draw_cat_head(picture, look, animal, head, asleep):
    width, height = animal["size"]
    cx, cy = rounded([head["skull"]])[0]
    for ear in CAT_EARS:
        forms.shade(picture, forms.polygon(width, height, moved(ear, cx, cy)), look["coat"][:3], 1)
    forms.dots(picture, moved(CAT_EAR_INSIDE, cx, cy), "petal")
    if "stripe" in look:
        forms.dots(picture, moved(CAT_BARS, cx, cy), look["stripe"])
    for x, y in moved(CAT_EYES, cx, cy):
        if asleep:
            forms.dots(picture, [(x, y + 1)], look["coat"][0])
        else:
            forms.dots(picture, [(x, y)], look["eye"])
            forms.dots(picture, [(x, y + 1)], "ink")
    forms.dots(picture, moved(CAT_MUZZLE, cx, cy), look["coat"][3])
    forms.dots(picture, moved(CAT_NOSE, cx, cy), "petal")
    forms.dots(picture, moved(CAT_WHISKERS, cx, cy), "stone_light")


CAT |= {"draw_tail": draw_cat_tail, "draw_coat": draw_cat_coat, "draw_head": draw_cat_head}

# On the hunt (task 82) the cat goes low: crouched with its belly near the ground, the head level
# with the back and the tail flat behind it; creeping on bent legs, a little higher; and
# pouncing, from the crouch with its tail flicking, a leap stretched out off the ground, and the
# landing with the head down on the mouse. These are the rows every cat's sheet has after those
# of ACTIONS.
CAT_HUNT_ACTIONS = {"crouch": 2, "creep": 4, "pounce": 3}
CROUCH, CREEP = 4, 2


def cat_sheet(look):
    style = cat_look(look)

    def frame(**pose):
        return quadruped_frame(CAT, style, **pose)

    crouch = frame(head="low", tail="flat", crouch=CROUCH)
    hunt = {
        "crouch": [crouch, frame(head="low", tail="flicking", crouch=CROUCH)],
        "creep": [frame(head="low", tail="flat", steps=steps, crouch=CREEP) for steps in WALK_STEPS],
        "pounce": [
            frame(head="low", tail="flicking", crouch=CROUCH),
            frame(steps=(("push", "reach"), ("push", "reach")), lift=4, tail="flying"),
            frame(head="down", steps=(("tuck", "stand"), ("tuck", "stand")), tail="flying"),
        ],
    }
    return quadruped_sheet(CAT, style) + [hunt[action] for action in CAT_HUNT_ACTIONS]


# --- Horses -------------------------------------------------------------------------------
#
# A heavy marsh horse of the Oldenburg kind, 88 px from the tail to the nose and 57 px to the
# withers (a person is 61 px tall), and a small pony drawn in the same cell. The legs have a
# forearm, knee, cannon, fetlock and hoof, the hind leg a gaskin and a hock pointing back; the
# neck and head rise ahead of the back, so that the back between the withers and the croup stays
# free for a saddle and a rider (task 81).

HORSE_SIZE = (88, 76)
HORSE_TORSO = [
    (20, 22), (24, 19), (30, 18), (37, 20), (44, 22), (50, 21), (55, 19), (60, 19), (64, 23),
    (67, 30), (66, 37), (63, 43), (58, 45), (46, 47), (36, 45), (31, 45), (26, 46), (21, 45),
    (18, 40), (17, 33), (18, 27),
]
# The neck and head, looking ahead and grazing, with the parts drawn on them: the mane's crest
# and where its locks fall, the ears, the eye (its top left pixel), the nostril, the mouth, the
# line of the jaw and the white blaze.
HORSE_HEADS = {
    "ahead": {
        "shape": [[
            (52, 22), (55, 19), (59, 16), (63, 12), (68, 8), (71, 6), (74, 7), (76, 10), (80, 15),
            (84, 21), (85, 25), (84, 28), (80, 29), (77, 27), (73, 24), (70, 24), (68, 28), (66, 33),
            (60, 33),
        ]],
        "crest": [(52, 23), (57, 18), (62, 13), (67, 8), (71, 6), (71, 10), (67, 14), (63, 19), (59, 24), (56, 28)],
        "locks": [(57, 24), (60, 20), (63, 16), (66, 13)],
        "forelock": [(73, 8), (74, 9), (75, 10), (74, 10), (73, 9)],
        "ears": [[(69, 8), (70, 2), (72, 7)], [(71, 8), (73, 2), (74, 7)]],
        "eye": (74, 13),
        "nostril": [(83, 24), (83, 25), (82, 25)],
        "mouth": [(80, 28), (81, 28), (82, 28), (83, 27)],
        "jaw": [(71, 17), (72, 21), (75, 24), (78, 25)],
        "blaze": [(76, 10), (78, 11), (84, 21), (84, 25), (82, 23)],
    },
    "down": {
        "shape": [[
            (52, 22), (55, 19), (60, 20), (65, 24), (70, 30), (74, 36), (78, 41), (81, 48), (84, 57),
            (86, 65), (86, 70), (84, 73), (79, 73), (78, 67), (75, 59), (71, 52), (68, 46), (64, 40),
            (60, 34),
        ]],
        "crest": [(52, 23), (56, 19), (61, 21), (66, 25), (71, 31), (75, 37), (78, 41), (75, 42), (71, 37), (66, 31), (61, 27), (56, 27)],
        "locks": [(58, 25), (63, 27), (68, 32), (72, 37)],
        "forelock": [(78, 43), (79, 44), (80, 46), (79, 46)],
        "ears": [[(76, 41), (79, 36), (79, 41)], [(77, 42), (81, 38), (80, 43)]],
        "eye": (77, 49),
        "nostril": [(84, 70), (85, 70), (85, 69)],
        "mouth": [(80, 72), (81, 72)],
        "jaw": [(74, 50), (76, 56), (78, 62)],
        "blaze": [(80, 45), (82, 46), (85, 62), (85, 70), (83, 70)],
    },
}
# The legs through their joints, standing, and the joint the lower leg folds at and from which
# it is in the colour of the points (a bay's black from the knee and the hock down).
HORSE_LEGS = {
    "near_front": {"joints": [(62, 38), (62, 57), (62, 67), (63, 71)], "radii": [3.6, 2.2, 1.6, 1.9], "bend": 1, "points": 1, "front": True},
    "far_front": {"joints": [(57, 40), (57, 57), (57, 67), (58, 71)], "radii": [3.0, 2.0, 1.5, 1.8], "bend": 1, "points": 1, "front": True},
    "near_hind": {"joints": [(27, 40), (30, 46), (22, 58), (24, 67), (24, 71)], "radii": [5.0, 3.6, 2.2, 1.6, 1.9], "bend": 2, "points": 2, "front": False},
    "far_hind": {"joints": [(32, 40), (31, 46), (28, 58), (30, 67), (30, 71)], "radii": [3.8, 3.0, 2.0, 1.5, 1.8], "bend": 2, "points": 2, "front": False},
}
# The tail falling from the dock in a long switch: where its strands start and end, how they bow
# and how wide they spread.
HORSE_TAILS = {
    "hanging": {"start": (19, 23), "end": (14, 56), "bend": -4, "spread": 9},
    "swishing": {"start": (19, 23), "end": (8, 52), "bend": 3, "spread": 9},
    "flying": {"start": (19, 23), "end": (3, 38), "bend": -4, "spread": 8},
    "lying": {"start": (19, 23), "end": (5, 47), "bend": -3, "spread": 9},
}
# Lines of the muscles one shade down (the hip, the stifle, the back of the shoulder blade, the
# elbow and the girth) and a gleam on the croup and the shoulder.
HORSE_MUSCLES = [
    [(27, 23), (31, 27), (32, 33), (30, 39)],
    [(32, 37), (34, 44)],
    [(56, 21), (59, 28), (58, 37)],
    [(55, 38), (58, 44)],
    [(40, 30), (46, 31)],
]
HORSE_GLEAM = [(24, 21), (25, 21), (26, 20), (27, 20), (28, 20), (29, 20), (25, 22), (61, 26), (62, 25), (61, 27), (62, 30), (62, 31)]
# Lying, legs folded under it: the near foreleg tucked under the chest and the near hind hoof
# showing under the belly.
HORSE_FOLDED = [
    ([(62, 38), (66, 44), (58, 47)], [2.6, 2.0, 1.8]),
    ([(27, 41), (34, 46), (44, 47)], [3.0, 2.2, 1.8]),
]
# The saddle on the dip of the back: the cloth under it, the seat with the cantle at the back and
# the pommel over the withers, the flap and the girth; a saddle with no rider has its stirrup
# hanging. The seat's lowest row is where the rider sits (PlayerView SEAT).
HORSE_SADDLE = {
    "cloth": [(32, 19), (49, 21), (50, 34), (33, 34)],
    "seat": [(33, 16), (36, 20), (45, 21), (48, 17), (50, 19), (48, 24), (35, 24), (32, 19)],
    "flap": [(37, 23), (46, 23), (46, 32), (38, 32)],
    "girth": [(44, 32), (46, 32), (47, 46), (45, 46)],
    "leather": [(41, 24), (41, 37)],
    "stirrup": [(40, 37), (41, 37), (42, 37), (39, 38), (43, 38), (39, 39), (40, 39), (41, 39), (42, 39), (43, 39)],
}
HORSE_SHARED = {"hoof": ("mud_dark", "stone_dark", "stone"), "eye": "ink", "glint": "cream"}
# The saddle cloth is blue wool, so that the rider's brown breeches stand out from a bay (task
# 114); the saddle is leather.
SADDLE_CLOTH = ("water_deep", "water_deep", "water")
SADDLE_LEATHER = ("russet_deep", "rust_dark", "rust")


def horse_look(look):
    """A look with the shades of its legs, the far ones a step darker."""
    style = HORSE_SHARED | HORSE_LOOKS[look]
    coat = style["coat"]
    style |= {"legs": coat, "far_legs": (coat[0], coat[0], coat[1], coat[2])}
    if "points" in style:
        points = style["points"]
        style["far_points"] = (points[0], points[0], points[1])
    return style


def draw_horse_tail(picture, look, animal, tail, dy):
    spec = moved(animal["tails"][tail], 0, dy)
    count = 12 if look.get("shaggy") else 9
    strands(picture, spec["start"], spec["end"], spec["bend"], spec["spread"], look["mane"], count, 3)


def draw_horse_coat(picture, look, animal, body, level, dy):
    width, height = animal["size"]
    drawn = forms.drawn(picture)
    for points in moved(animal["muscles"], 0, dy):
        line = forms.limb(width, height, points, [0.55] * len(points)) & body & (level > 0.3)
        forms.paint(picture, line, look["line"])
    forms.dots(picture, rounded(moved(animal["gleam"], 0, dy)), look["gleam"])
    if "dapples" in look:
        # Small rings in rows, every other row shifted, on the lit upper body.
        rings = [
            (x + dx, y + dy + ry)
            for y in range(0, height, 4)
            for x in range(3 * (y // 4 % 2), width, 6)
            for dx, ry in ((-1, 0), (1, 0), (0, -1), (0, 1))
        ]
        mask = np.zeros(body.shape, bool)
        for x, y in rings:
            if 0 <= x < width and 0 <= y < height:
                mask[y, x] = True
        forms.paint(picture, mask & body & drawn & (level > 0.25) & (np.arange(height)[:, None] < 40 + dy), look["dapples"])
    if "stripe" in look:
        back = moved(animal["torso"][0][1:8], 0, dy + 1)
        forms.paint(picture, forms.limb(width, height, back, [0.6] * len(back)) & body, look["stripe"])


def draw_horse_head(picture, look, animal, head, asleep):
    width, height = animal["size"]
    crest = forms.polygon(width, height, head["crest"])
    forms.shade(picture, crest, (look["mane"][0], look["mane"][0], look["mane"][1]), 2)
    drop = 4 if look.get("shaggy") else 2
    for x, y in head["locks"]:
        forms.dots(picture, [(round(x), round(y) + step) for step in range(1, drop + 1)] + [(round(x) + 1, round(y) + drop + 1)], look["mane"][0])
    for ear, shade in zip(head["ears"], (look["coat"][1], look["coat"][2])):
        forms.paint(picture, forms.polygon(width, height, ear), shade)
    if look.get("blaze"):
        blaze = forms.polygon(width, height, head["blaze"]) & shapes_mask(animal["size"], head["shape"])
        forms.paint(picture, blaze, "lime")
    jaw = forms.limb(width, height, head["jaw"], [0.55] * len(head["jaw"]))
    forms.paint(picture, jaw & shapes_mask(animal["size"], head["shape"]), look["coat"][1])
    forms.dots(picture, rounded(head["forelock"]), look["mane"][0])
    x, y = rounded([head["eye"]])[0]
    if asleep:
        forms.dots(picture, [(x, y + 1), (x + 1, y + 1)], look["coat"][0])
    else:
        forms.dots(picture, [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)], look["eye"])
        forms.dots(picture, [(x, y)], look["glint"])
    forms.dots(picture, rounded(head["nostril"]), "ink")
    forms.dots(picture, rounded(head["mouth"]), look["coat"][0])


def view_leg(x, top, ground):
    """The joints of a leg seen from the front or from behind, straight down from its top to the
    hoof on `ground`: the knee or hock, the fetlock and the hoof."""
    return [(x, top), (x, ground - 14), (x, ground - 4), (x, ground)]


# The horse ridden towards the viewer ("front") and away ("back"), seen from in front and from
# behind: the barrel or the rump, the near legs (the forelegs from the front, the hind legs from
# behind) and the far ones between them, a little higher up and darker; from the front the head
# and neck that come in front of the rider, from behind the neck and ears beyond them and the tail.
HORSE_VIEWS = {
    "front": {
        "body": [((44, 32), [14, 13]), ((36, 30), [7, 9]), ((52, 30), [7, 9])],
        "cloth": [[(28, 22), (32, 20), (32, 36), (29, 36)], [(56, 20), (60, 22), (59, 36), (56, 36)]],
        "seat": [(40, 17), (48, 17), (49, 21), (39, 21)],
        "head": [(39, 12), (49, 12), (50, 20), (49, 30), (48, 38), (44, 42), (40, 38), (39, 30), (38, 20)],
        "neck": ((44, 27), [8, 8]),
        "ears": [[(38, 13), (39, 5), (42, 12)], [(46, 12), (49, 5), (50, 13)]],
        "eyes": [(38, 19), (49, 19)],
        "forelock": [(43, 12), (44, 12), (45, 12), (43, 13), (44, 13), (44, 14), (45, 14), (44, 15)],
        "blaze": [(43, 15), (45, 15), (46, 36), (42, 36)],
        "nostrils": [(41, 39), (47, 39)],
        "near_legs": [view_leg(37.5, 40, 71), view_leg(50.5, 40, 71)],
        "far_legs": [view_leg(40.5, 44, 69), view_leg(47.5, 44, 69)],
        "leg_radii": [3.6, 2.3, 1.7, 1.9],
        "far_leg_radii": [2.8, 1.9, 1.5, 1.7],
        "tail": None,
    },
    "back": {
        "body": [((44, 33), [14, 13]), ((38, 25), [7, 6]), ((50, 25), [7, 6])],
        "cloth": [[(28, 22), (32, 20), (32, 36), (29, 36)], [(56, 20), (60, 22), (59, 36), (56, 36)]],
        "seat": [(39, 17), (49, 17), (49, 21), (39, 21)],
        "neck": ((44, 14), [5, 7]),
        "crest": [(43, 6), (45, 6), (46, 20), (42, 20)],
        "ears": [[(39, 9), (40, 3), (43, 8)], [(45, 8), (48, 3), (49, 9)]],
        "near_legs": [view_leg(37.5, 42, 71), view_leg(50.5, 42, 71)],
        "far_legs": [view_leg(40.5, 44, 69), view_leg(47.5, 44, 69)],
        "leg_radii": [4.0, 2.3, 1.7, 1.9],
        "far_leg_radii": [2.8, 1.9, 1.5, 1.7],
        "tail": {"start": (44, 21), "end": (44, 56), "bend": 0, "spread": 7},
    },
}

HORSE = {
    "size": HORSE_SIZE,
    "torso": [HORSE_TORSO],
    "heads": HORSE_HEADS,
    "legs": HORSE_LEGS,
    "hoof": [2.9, 1.9],
    "tails": HORSE_TAILS,
    "muscles": HORSE_MUSCLES,
    "gleam": HORSE_GLEAM,
    "folded": HORSE_FOLDED,
    "saddle": HORSE_SADDLE,
    "views": HORSE_VIEWS,
    "shade_radius": 9,
    # Lying, the body is this much lower, the belly on the ground.
    "lying_drop": 25,
    "gallops": True,
    "draw_tail": draw_horse_tail,
    "draw_coat": draw_horse_coat,
    "draw_head": draw_horse_head,
}


# The pony: the horse at four fifths, with a thicker neck and legs and a shaggy mane (its looks'
# `shaggy`).
PONY = scaled(HORSE, 0.8)
for _leg in PONY["legs"].values():
    _leg["radii"] = [radius * 1.15 for radius in _leg["radii"]]

HORSE_LOOKS = {
    # Bay: a red-brown coat with the mane, the tail and the lower legs black, and a white blaze.
    "bay": {
        "coat": ("soil_dark", "soil", "soil_mid", "soil_light"),
        "points": ("ink", "ink", "stone_dark"),
        "mane": ("ink", "stone_dark"),
        "line": "soil",
        "gleam": "sand",
        "blaze": True,
        "outline": "soil_dark",
    },
    # Black, the gleam blue-grey.
    "black": {
        "coat": ("ink", "stone_dark", "stone_dark", "stone"),
        "mane": ("ink", "stone_dark"),
        "line": "ink",
        "gleam": "stone_light",
        "outline": "ink",
    },
    # Dapple grey: rings of grey on a pale coat, darker on the legs, a grey mane.
    "grey": {
        "coat": ("stone", "stone_light", "lime", "snow_light"),
        "points": ("stone_dark", "stone", "stone_light"),
        "mane": ("stone", "stone_light"),
        "line": "stone_light",
        "gleam": "snow_light",
        "dapples": "stone_light",
        "outline": "stone_dark",
    },
    # A dun pony: sandy, with a dark stripe down its back, a dark mane and legs.
    "pony": {
        "animal": PONY,
        "coat": ("mud", "sand", "sand_light", "cream"),
        "points": ("mud_dark", "mud_dark", "mud"),
        "mane": ("mud_dark", "mud"),
        "line": "sand",
        "gleam": "cream",
        "stripe": "mud",
        "shaggy": True,
        "outline": "mud_dark",
    },
}


def draw_saddle(picture, animal, saddle, dy):
    """The saddle (see HORSE_SADDLE) on a horse's back; "on" has its stirrup hanging, "ridden"
    leaves it to the rider's foot."""
    width, height = animal["size"]
    parts = moved(animal["saddle"], 0, dy)
    forms.shade(picture, forms.polygon(width, height, parts["cloth"]), SADDLE_CLOTH, 2)
    forms.shade(picture, forms.polygon(width, height, parts["flap"]), SADDLE_LEATHER[:2] + SADDLE_LEATHER[1:2], 1)
    forms.paint(picture, forms.polygon(width, height, parts["girth"]), SADDLE_LEATHER[0])
    forms.shade(picture, forms.polygon(width, height, parts["seat"]), SADDLE_LEATHER, 2)
    if saddle == "on":
        forms.paint(picture, forms.limb(width, height, parts["leather"], [0.5, 0.5]), SADDLE_LEATHER[0])
        forms.dots(picture, rounded(parts["stirrup"]), "stone_light")


def horse_sheet(look, saddle=None):
    style = horse_look(look)
    return quadruped_sheet(style.get("animal", HORSE), style, saddle)


# --- Riding -------------------------------------------------------------------------------
#
# A ridden horse (task 81) in the rows of the player's sheets, facing down, up, left and right
# (left is the mirror of right), with nine columns: standing, four frames of the walk and four of
# the trot. Two sheets per look: horse_<look>_ridden is drawn behind the rider and
# horse_<look>_ridden_over in front of them (the head of a horse coming towards the viewer; it is
# empty in the other rows). From the side it is the horse with the saddle on, the stirrup under
# the rider's foot; from the front and from behind it is drawn from its `views`.
# game/scenes/player_view.gd mirrors the columns, the lifts and where the rider sits.

RIDING_FACINGS = ("down", "up", "left", "right")
# The trot, from the side: a diagonal pair of legs forward and the other back, then all four off
# the ground (`lift` 2) with one pair folded, then the other way round.
TROT_STEPS = [
    ((("back", "forward"), ("forward", "back")), 0),
    ((("tuck", "stand"), ("stand", "fold")), 2),
    ((("forward", "back"), ("back", "forward")), 0),
    ((("stand", "fold"), ("tuck", "stand")), 2),
]
# From the front and from behind: how far each hoof is raised (the near left and right legs,
# then the far left and right ones between them) and the lift, for the standing frame, the walk
# and the trot. A trot raises a near leg with the far leg of the other side.
VIEW_STEPS = [
    ((0, 0, 0, 0), 0),
    ((3, 0, 0, 3), 0),
    ((0, 0, 0, 0), 0),
    ((0, 3, 3, 0), 0),
    ((0, 0, 0, 0), 0),
    ((5, 0, 0, 5), 0),
    ((0, 0, 0, 0), 2),
    ((0, 5, 5, 0), 0),
    ((0, 0, 0, 0), 2),
]


def raised_leg(joints, up):
    """A leg seen from the front or from behind with its hoof `up` pixels off the ground."""
    top, ground = joints[0][1], joints[-1][1]
    shrink = (ground - up - top) / (ground - top)
    return [(x, top + (y - top) * shrink) for x, y in joints]


def view_frame(animal, look, view, raised, lift):
    """The front ("front") or back ("back") view of a ridden horse (see HORSE_VIEWS): the legs
    raised by `raised` (see VIEW_STEPS) and all of it `lift` pixels off the ground. Returns the
    picture behind the rider and the one in front of them."""
    width, height = animal["size"]
    parts = moved(animal["views"][view], 0, -lift)
    behind, in_front = blank(width, height), blank(width, height)

    def ellipse(shape):
        (x, y), (rx, ry) = shape
        return forms.ellipse(width, height, x, y, rx, ry)

    def leg(joints, up, radii, far):
        draw_leg(behind, animal, {"radii": radii, "points": 1}, raised_leg(joints, up), look, far)

    for joints, up in zip(parts["far_legs"], raised[2:]):
        leg(joints, up, parts["far_leg_radii"], far=True)
    if view == "back":
        # The neck and the ears beyond the rider, the mane down the middle of the neck.
        neck = ellipse(parts["neck"])
        for ear in parts["ears"]:
            neck |= forms.polygon(width, height, ear)
        forms.shade(behind, neck, look["coat"], 3)
        mane = (look["mane"][0], look["mane"][0], look["mane"][1])
        forms.shade(behind, forms.polygon(width, height, parts["crest"]), mane, 1)
    body = np.zeros((height, width), bool)
    for shape in parts["body"]:
        body |= ellipse(shape)
    forms.shade(behind, body, look["coat"], 6, TOP_LIGHT)
    for cloth in parts["cloth"]:
        forms.shade(behind, forms.polygon(width, height, cloth), SADDLE_CLOTH, 1)
    forms.shade(behind, forms.polygon(width, height, parts["seat"]), SADDLE_LEATHER, 1)
    if parts["tail"]:
        tail = parts["tail"]
        strands(behind, tail["start"], tail["end"], tail["bend"], tail["spread"], look["mane"], 7, 5)
    for joints, up in zip(parts["near_legs"], raised[:2]):
        leg(joints, up, parts["leg_radii"], far=False)
    if view == "front":
        draw_face(in_front, animal, look, parts)
    return outline(behind, look["outline"]), outline(in_front, look["outline"])


def draw_face(picture, animal, look, parts):
    """The head of a horse coming towards the viewer, with its neck: the ears, the forelock, the
    eyes at the sides, the blaze and the nostrils."""
    width, height = animal["size"]
    (x, y), (rx, ry) = parts["neck"]
    head = forms.ellipse(width, height, x, y, rx, ry) | forms.polygon(width, height, parts["head"])
    for ear in parts["ears"]:
        head |= forms.polygon(width, height, ear)
    forms.shade(picture, head, look["coat"], 3, TOP_LIGHT)
    if look.get("blaze"):
        forms.paint(picture, forms.polygon(width, height, parts["blaze"]) & head, "lime")
    forms.dots(picture, rounded(parts["forelock"]), look["mane"][0])
    for x, y in rounded(parts["eyes"]):
        forms.dots(picture, [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)], look["eye"])
    forms.dots(picture, rounded(parts["eyes"][:1]), look["glint"])
    forms.dots(picture, rounded(parts["nostrils"]), "ink")


def ridden_sheets(look):
    """The two sheets of a ridden horse of a look (see above), as rows of cells."""
    style = horse_look(look)
    animal = style.get("animal", HORSE)
    empty = blank(*animal["size"])
    side = [quadruped_frame(animal, style, saddle="ridden")]
    side += [quadruped_frame(animal, style, steps=steps, saddle="ridden") for steps in WALK_STEPS]
    side += [
        quadruped_frame(animal, style, steps=steps, lift=lift, tail="swishing", saddle="ridden")
        for steps, lift in TROT_STEPS
    ]
    behind, in_front = {}, {}
    for view, facing in (("front", "down"), ("back", "up")):
        frames = [view_frame(animal, style, view, raised, lift) for raised, lift in VIEW_STEPS]
        behind[facing] = [picture for picture, _ in frames]
        in_front[facing] = [picture for _, picture in frames]
    behind["right"] = side
    behind["left"] = [[row[::-1] for row in cell] for cell in side]
    return (
        [behind[facing] for facing in RIDING_FACINGS],
        [in_front.get(facing, [empty] * len(VIEW_STEPS)) for facing in RIDING_FACINGS],
    )


SPECIES = {
    "rabbit": (RABBIT_SIZE, RABBIT_LOOKS, rabbit_sheet),
    "chicken": (CHICKEN_SIZE, CHICKEN_LOOKS, chicken_sheet),
    "cat": (CAT_SIZE, CAT_LOOKS, cat_sheet),
    "dog": (DOG_SIZE, DOG_LOOKS, dog_sheet),
    "sheep": (SHEEP_SIZE, SHEEP_LOOKS, sheep_sheet),
    "cow": (COW_SIZE, COW_LOOKS, cow_sheet),
    "horse": (HORSE_SIZE, HORSE_LOOKS, horse_sheet),
}


def sheets():
    """Every sheet as (file name, cell size, rows of cells for palette.save)."""
    for species, (size, looks, sheet) in SPECIES.items():
        for look in looks:
            yield f"{species}_{look}", size, sheet(look)
    for look in HORSE_LOOKS:
        yield f"horse_{look}_saddled", HORSE_SIZE, horse_sheet(look, "on")
        behind, in_front = ridden_sheets(look)
        yield f"horse_{look}_ridden", HORSE_SIZE, behind
        yield f"horse_{look}_ridden_over", HORSE_SIZE, in_front
