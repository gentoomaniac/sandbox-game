"""What the farm animals' art shares: the poses, the legs and the way a frame is put together.

Their sheets are assets/wildlife/<species>_<look>.png, drawn at 32 px per tile, by the species
modules (livestock_<family>.py) that farm_animals.py collects. Every sheet has the same rows
(ACTIONS): standing idle, walking, grazing (pecking, for a hen), asleep and running, one column
per frame, and the animal stands in the bottom centre of its cell, facing right (the game flips it
to face left). game/scenes/wildlife/wildlife_sprites.gd mirrors the cell sizes and the frames. The
looks are those of the region around 1700-1800 (see docs/art-style.md, "Props and animals").

The animals are drawn in the style of the people (character.py): rounded forms (forms.py)
shaded by the light from the top left, faces with an eye and its glint, and the outline in the
darkest colour of the coat. The sheep, dogs, cats and horses share one way of putting a frame
together (`quadruped_frame`); the cow, the pig and the rooster are drawn by hand as maps of
letters, laid over each other for a pose (`place_piece`); the hen and the rabbit are drawn whole
for each pose.
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
    near_joints = {
        name: leg_joints(legs[name], step, dy)
        for name, step in (("near_hind", near_hind), ("near_front", near_front))
    }
    # The top of a near leg (its forearm or thigh) is shaded with the body, so that the belly's
    # shadow stops at the legs and the leg flows into the shoulder or the haunch.
    upper_legs = np.zeros_like(torso)
    if not lying:
        for name, count in animal.get("upper_legs", {}).items():
            upper_legs |= forms.limb(width, height, near_joints[name][:count], legs[name]["radii"][:count])
    parts = moved(animal["heads"][head], 0, dy + head_drop)
    body = torso | upper_legs | shapes_mask(animal["size"], parts["shape"])
    level = forms.light_level(body, animal["shade_radius"], TOP_LIGHT)
    forms.shade_by_level(picture, body, look["coat"], level)
    animal["draw_coat"](picture, look, animal, body, level, dy)
    if not lying:
        for name, count in animal.get("upper_legs", {}).items():
            # A gleam on the lit front of the shoulder or the haunch and the line of its muscle
            # behind it, so that they read as the body's front and rear ends.
            muscle = near_joints[name][:count]
            radii = [0.6] * count
            lit = forms.limb(width, height, moved(muscle, -1.5, 0), radii) & upper_legs & (level > 0.35)
            forms.paint(picture, lit, look["coat"][2])
            line = forms.limb(width, height, moved(muscle, 1.5, 1), radii) & upper_legs & (level > 0.3)
            forms.paint(picture, line, look["line"])
    if saddle is not None:
        draw_saddle(picture, animal, saddle, dy)
    if lying:
        draw_folded(picture, animal, look, dy)
    else:
        for name in ("near_hind", "near_front"):
            draw_leg(picture, animal, legs[name], near_joints[name], look, far=False, hidden=torso | upper_legs)
    animal["draw_head"](picture, look, animal, parts, lying)
    return outline(picture, look["outline"])


def quadruped_sheet(animal, look, saddle=None):
    """The rows of cells of a four-legged animal's sheet (ACTIONS): it flicks its tail standing,
    chews with its head down, breathes lying down and gallops, or hurries at a walk if it has no
    gallop (sheep)."""

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


def place_piece(letters, piece, dy=0, stride=0):
    """Lays a piece of a map of letters ((left, top), rows) into `letters` `dy` lower, a leg's
    rows leaning so its hoof is `stride` forward. Returns where it put a letter."""
    height, width = letters.shape
    placed = np.zeros(letters.shape, bool)
    (left, top), rows = piece
    for row_index, row in enumerate(rows):
        dx = round(stride * row_index / max(1, len(rows) - 1))
        for column, key in enumerate(row):
            x, y = left + dx + column, top + dy + row_index
            if key != "." and 0 <= x < width and 0 <= y < height:
                letters[y, x] = key
                placed[y, x] = True
    return placed


# The saddle cloth is blue wool, so that the rider's brown breeches stand out from a bay (task
# 114); the saddle is leather.
SADDLE_CLOTH = ("water_deep", "water_deep", "water")
SADDLE_LEATHER = ("russet_deep", "rust_dark", "rust")


def draw_saddle(picture, animal, saddle, dy):
    """The saddle (see HORSE_SADDLE in livestock_horse.py) on a horse's back; "on" has its stirrup
    hanging, "ridden" leaves it to the rider's foot."""
    width, height = animal["size"]
    parts = moved(animal["saddle"], 0, dy)
    forms.shade(picture, forms.polygon(width, height, parts["cloth"]), SADDLE_CLOTH, 2)
    forms.shade(picture, forms.polygon(width, height, parts["flap"]), SADDLE_LEATHER[:2] + SADDLE_LEATHER[1:2], 1)
    forms.paint(picture, forms.polygon(width, height, parts["girth"]), SADDLE_LEATHER[0])
    forms.shade(picture, forms.polygon(width, height, parts["seat"]), SADDLE_LEATHER, 2)
    if saddle == "on":
        forms.paint(picture, forms.limb(width, height, parts["leather"], [0.5, 0.5]), SADDLE_LEATHER[0])
        forms.dots(picture, rounded(parts["stirrup"]), "stone_light")
