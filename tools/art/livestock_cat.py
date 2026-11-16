"""Art for the cats (wildlife/cat_<look>.png), put together by livestock.quadruped_frame, with the hunting rows."""

import forms
import numpy as np
from livestock import WALK_STEPS, moved, quadruped_frame, quadruped_sheet, rounded, shapes_mask

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
    "ginger": {"coat": ("rust", "flame", "flame", "leaf_orange"), "stripe": "rust", "eye": "olive", "outline": "russet_deep"},
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


def sheets():
    """Every sheet of the cats as (file name, cell size, rows of cells for palette.save)."""
    for look in CAT_LOOKS:
        yield f"cat_{look}", CAT_SIZE, cat_sheet(look)
