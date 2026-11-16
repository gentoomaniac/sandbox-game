"""Art for the sheep (wildlife/sheep_<look>.png), put together by livestock.quadruped_frame."""

import forms
import numpy as np
from livestock import moved, quadruped_sheet, rounded

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


def sheets():
    """Every sheet of the sheep as (file name, cell size, rows of cells for palette.save)."""
    for look in SHEEP_LOOKS:
        yield f"sheep_{look}", SHEEP_SIZE, sheep_sheet(look)
