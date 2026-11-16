"""Art for the horses: the horse's sheets (wildlife/horse_<look>.png), saddled and ridden (wildlife/horse_<look>_saddled.png, _ridden.png and _ridden_over.png).

The shared drawing and the saddle are in livestock.py.
"""

import forms
import numpy as np
from canvas import blank, outline
from livestock import SADDLE_CLOTH, SADDLE_LEATHER, TOP_LIGHT, WALK_STEPS, draw_leg, moved, quadruped_frame, quadruped_sheet, rounded, scaled, shapes_mask, strands

# A heavy marsh horse of the Oldenburg kind, 88 px from the tail to the nose and 57 px to the
# withers (a person is 61 px tall), and a small pony drawn in the same cell. The legs have a
# forearm, knee, cannon, fetlock and hoof, the hind leg a gaskin and a hock pointing back; the
# neck and head rise ahead of the back, so that the back between the withers and the croup stays
# free for a saddle and a rider (task 81).

HORSE_SIZE = (88, 76)
HORSE_TORSO = [
    (20, 22), (24, 19), (30, 18), (37, 20), (44, 22), (50, 21), (55, 19), (60, 19), (64, 23),
    (67, 30), (66, 37), (63, 43), (58, 45), (46, 47), (38, 45), (32, 43), (27, 44), (22, 45),
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
            (52, 22), (55, 19), (60, 21), (65, 26), (69, 33), (72, 40), (74, 46), (75, 51), (77, 56),
            (78, 62), (78, 68), (78, 71), (77, 73), (73, 73), (70, 71), (68, 66), (66, 60), (65, 55),
            (65, 50), (64, 45), (62, 40), (59, 34),
        ]],
        "crest": [(52, 23), (56, 19), (61, 22), (66, 27), (70, 34), (73, 40), (75, 46), (75, 51), (72, 51), (70, 44), (67, 38), (63, 32), (58, 28), (55, 27)],
        "locks": [(58, 25), (62, 28), (66, 32), (69, 37)],
        "forelock": [(77, 53), (78, 54), (78, 56), (77, 56)],
        "ears": [[(73, 51), (74, 46), (77, 50)], [(75, 52), (78, 48), (79, 52)]],
        "eye": (73, 57),
        "nostril": [(76, 70), (77, 70), (77, 69)],
        "mouth": [(73, 72), (74, 72)],
        "jaw": [(67, 60), (69, 65), (72, 70)],
        "blaze": [(77, 54), (78, 55), (78, 69), (77, 71), (75, 62)],
    },
}
# The legs through their joints, standing, and the joint the lower leg folds at and from which
# it is in the colour of the points (a bay's black from the knee and the hock down).
HORSE_LEGS = {
    "near_front": {"joints": [(62, 36), (62, 47), (62, 57), (62, 67), (63, 71)], "radii": [5.6, 4.6, 2.4, 1.6, 1.9], "bend": 2, "points": 2, "front": True},
    "far_front": {"joints": [(56, 38), (57, 47), (57, 57), (57, 67), (58, 71)], "radii": [4.6, 3.8, 2.2, 1.5, 1.8], "bend": 2, "points": 2, "front": True},
    "near_hind": {"joints": [(24, 38), (28, 47), (26, 53), (22, 58), (24, 67), (24, 71)], "radii": [6.4, 5.4, 4.0, 2.4, 1.6, 1.9], "bend": 3, "points": 3, "front": False},
    "far_hind": {"joints": [(30, 40), (31, 47), (29, 53), (28, 58), (30, 67), (30, 71)], "radii": [5.0, 4.4, 3.4, 2.2, 1.5, 1.8], "bend": 3, "points": 3, "front": False},
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
    # The near legs whose forearm and thigh (their first joints) are shaded with the body.
    "upper_legs": {"near_front": 2, "near_hind": 3},
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


def horse_sheet(look, saddle=None):
    style = horse_look(look)
    return quadruped_sheet(style.get("animal", HORSE), style, saddle)


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


def sheets():
    """Every sheet of the horses as (file name, cell size, rows of cells for palette.save)."""
    for look in HORSE_LOOKS:
        yield f"horse_{look}", HORSE_SIZE, horse_sheet(look)
    for look in HORSE_LOOKS:
        yield f"horse_{look}_saddled", HORSE_SIZE, horse_sheet(look, "on")
        behind, in_front = ridden_sheets(look)
        yield f"horse_{look}_ridden", HORSE_SIZE, behind
        yield f"horse_{look}_ridden_over", HORSE_SIZE, in_front
