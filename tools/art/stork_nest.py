"""Art for the stork's nest on a roof ridge, drawn at 32 px per tile: two sheets at
assets/wildlife/<name>.png (see birds.py for the stork itself, docs/art-style.md, "Props and
animals").

`stork_nest` is the heap of sticks, one cell. `stork_chick` is a young stork over the rim, one
row per look and one column per frame, in the order of game/scenes/wildlife/wildlife_sprites.gd:
the head and neck of a hatchling (grey, downy), of a half-grown one and of a nearly grown one
(white, the bill red), then the grown young standing on the rim and flapping. A chick stands in
the bottom middle of its cell; the nest is drawn over its lower part, so that its head comes up
out of the sticks.
"""

import random

import forms
from bird_forms import flying, line, standing
from birds import STORK
from canvas import blank, outline

NEST_SIZE = (48, 14)
CHICK_SIZE = (40, 34)

# The sticks of the heap, from the dark ones low down to the pale ones on top.
STICKS = ["mud_dark", "soil_dark", "mud", "bare", "bare_light"]
HEAP = {"cx": 23.5, "cy": 15.0, "rx": 22.5, "ry": 13.0}


def nest():
    """A half ellipse of crossed sticks, some poking out of its rim."""
    rng = random.Random(152)
    width, height = NEST_SIZE
    picture = blank(width, height)
    heap = forms.ellipse(width, height, HEAP["cx"], HEAP["cy"], HEAP["rx"], HEAP["ry"])
    forms.paint(picture, heap, "mud_dark")
    for _ in range(80):
        x = rng.uniform(1, width - 4)
        y = rng.uniform(1, height - 1)
        level = min(len(STICKS) - 1, int((height - y) / height * len(STICKS)) + rng.randint(0, 1))
        stroke = blank(width, height)
        line(stroke, (x, y), (x + rng.uniform(3, 7), y + rng.uniform(-2.0, 2.0)), STICKS[level])
        for row in range(height):
            for col in range(width):
                if stroke[row][col] is not None and heap[row][col]:
                    picture[row][col] = stroke[row][col]
    picture = outline(picture, "ink")
    for x, y, dx, dy in ((6, 6, -3, -3), (14, 2, -2, -2), (31, 2, 3, -2), (41, 6, 4, -3), (24, 1, 2, -1)):
        line(picture, (x, y), (x + dx, y + dy), "soil_dark")
    return picture


DOWNY = ["stone", "stone_light", "bare_light"]
HALF_GROWN = ["stone_light", "bare_light", "snow_shadow"]
WHITE = ["snow_shadow", "snow", "lime"]
MIDDLE = CHICK_SIZE[0] // 2


def head_and_neck(head_at, head_radius, neck_radius, ramp, bill_length, bill_colours):
    """A head on a neck coming up from the bottom of the cell, its bill pointing up and forward
    (it begs)."""
    width, height = CHICK_SIZE
    picture = blank(width, height)
    hx, hy = head_at
    forms.shade(picture, forms.capsule(width, height, (MIDDLE, height), (hx, hy), neck_radius), ramp, radius=2)
    forms.shade(picture, forms.ellipse(width, height, hx, hy, head_radius, head_radius), ramp, radius=2)
    forms.dots(picture, [(int(hx), int(hy))], "ink")
    picture = outline(picture, "stone")
    root = hx + head_radius * 0.6
    line(picture, (root, hy - 1), (hx + head_radius + bill_length, hy - 1 - bill_length * 0.5), bill_colours[0])
    line(picture, (root, hy), (hx + head_radius + bill_length - 1, hy - bill_length * 0.5), bill_colours[1])
    return picture


# The grown young: a small stork, white all over but for its dark wing tips.
YOUNG = STORK._replace(
    body=(8.0, 4.5), neck=1.8, head=2.4, bill=(7.0, 1.2), legs=8, tail=2.5, span=19.0, chord=5.0, marks=None
)
YOUNG_AT = (16.0, 21.0)
YOUNG_STANDING = {"angle": 6, "head_at": (3.0, -8.0), "bill_angle": 45}


def chick_sheet():
    return [
        [head_and_neck((MIDDLE, 22), 3.2, 1.6, DOWNY, 3, ("ink", "stone_dark"))],
        [head_and_neck((MIDDLE, 17), 3.6, 2.0, HALF_GROWN, 5, ("stone_dark", "ember"))],
        [head_and_neck((MIDDLE, 11), 4.0, 2.2, WHITE, 8, ("red_light", "ember"))],
        [
            standing(CHICK_SIZE, YOUNG, YOUNG_AT, **YOUNG_STANDING)[0],
            standing(CHICK_SIZE, YOUNG, YOUNG_AT, **YOUNG_STANDING, look_round=True)[0],
        ],
        [flying(CHICK_SIZE, YOUNG, (20.0, 16.0), beat, legs_trailing=True)[0] for beat in ("up", "level", "down")],
    ]


def sheets():
    """(name, cell size, rows of cells) of every sheet."""
    return [("stork_nest", NEST_SIZE, [[nest()]]), ("stork_chick", CHICK_SIZE, chick_sheet())]
