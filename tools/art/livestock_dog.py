"""Art for the dogs (wildlife/dog_<look>.png), put together by livestock.quadruped_frame."""

import forms
from livestock import moved, quadruped_sheet, rounded, shapes_mask

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


def sheets():
    """Every sheet of the dogs as (file name, cell size, rows of cells for palette.save)."""
    for look in DOG_LOOKS:
        yield f"dog_{look}", DOG_SIZE, dog_sheet(look)
