"""The farm yard (task 122), drawn at 32 px per tile: the draw well with its sweep, the trough, the
hay rack and the chicken coop.

Each is drawn once, standing (its bottom row on the ground), the way the stations are (crafts.py):
generate.py puts the world objects into their cells of the object atlas on a ground shadow and the
coop into assets/buildings/, and the bodies of the icons of the items that place them are their
pictures. Each is rimmed in the darkest shade of its own colours, light from the top left.
"""

import math
import random

import forms
import items
from canvas import GAME_TILE, blank, outline_edge, rect

# The wet oak of posts, poles and planks, lit to dark.
OAK = ("soil_light", "soil_mid", "soil", "soil_dark")
OAK_FACES = ("soil_light", "soil_mid", "soil")


def _oak_beam(picture, x0, y0, x1, y1):
    """A square oak beam from (x0, y0) to (x1, y1), both ends included, lit on its left and top."""
    rect(picture, x0, y0, x1, y1, OAK[1])
    rect(picture, x0, y0, x0, y1, OAK[0])
    rect(picture, x0, y0, x1, y0, OAK[0])
    rect(picture, x1, y0 + 1, x1, y1, OAK[2])
    rect(picture, x0 + 1, y1, x1, y1, OAK[2])


def _pole(picture, start, end, thickness):
    """An oak pole from `start` to `end` (x, y), thickness px thick, lit along its top."""
    (x0, y0), (x1, y1) = start, end
    for x in range(min(x0, x1), max(x0, x1) + 1):
        top = round(y0 + (x - x0) * (y1 - y0) / (x1 - x0))
        for row in range(thickness):
            picture[top + row][x] = OAK[0] if row == 0 else OAK[2] if row == thickness - 1 else OAK[1]


WELL_WIDTH, WELL_HEIGHT = 60, 80
# The ring of the well: the middle of its top face, and how far it reaches across and down.
RING_X, RING_Y = 30, 61
RING_RX, RING_RY, RING_WALL = 15, 7, 11
# The ground shadow lies under the ring only, not the post: half its width.
WELL_SHADOW = 19


def draw_well():
    """The draw well, 60x80 px: a ring of fieldstones in courses under an oak coping, the dark
    water in its mouth; beside it a forked oak post, and on the fork the balanced sweep, its
    long end over the well with a rope and an oak bucket, a round weight stone hung from its
    short end. The ring stands in the middle of the picture, over the tile the well covers; the
    post and the weight reach out over the tile beside it."""
    picture = blank(WELL_WIDTH, WELL_HEIGHT)
    height = WELL_HEIGHT
    # The post behind the ring, forked at its head, with a few stones heaped at its foot.
    post_x = 49
    _oak_beam(picture, post_x, 14, post_x + 3, height - 3)
    for x0 in (post_x - 2, post_x + 4):
        _oak_beam(picture, x0, 9, x0 + 1, 18)
    rect(picture, post_x + 1, 12, post_x + 2, 14, OAK[3])
    for x0, y0, w, h in ((45, height - 7, 6, 5), (52, height - 6, 6, 4), (49, height - 9, 5, 4)):
        stone = forms.ellipse(WELL_WIDTH, height, x0 + w / 2, y0 + h / 2, w / 2, h / 2)
        forms.shade(picture, stone, ("stone_dark", "stone", "stone_light"), radius=2)
    # The sweep: a long pole through the fork, the long end lower and over the well. The short end
    # carries the weight stone on a rope; the rope of the bucket hangs from the long end.
    _pole(picture, (60 - 2, 5), (20, 28), 3)
    rect(picture, 55, 8, 55, 12, "sand")
    stone = forms.ellipse(WELL_WIDTH, height, 55.5, 17, 4.8, 4.5)
    forms.shade(picture, stone, ("stone_dark", "stone", "stone_light"), radius=3)
    rect(picture, 22, 30, 22, 43, "sand")
    # The oak bucket on its rope, narrower at the foot, hooped in iron, an iron bail over its mouth.
    for x, y in ((18, 44), (19, 43), (20, 42), (21, 42), (23, 42), (24, 42), (25, 43), (26, 44)):
        picture[y][x] = "stone"
    for row, y in enumerate(range(45, 54)):
        left, right = 18 + row // 5, 26 - row // 5
        rect(picture, left, y, right, y, OAK[1])
        picture[y][left] = OAK[0]
        picture[y][right] = OAK[2]
        if row in (2, 6):
            rect(picture, left, y, right, y, "stone")
    rect(picture, 19, 54, 25, 54, OAK[3])
    # The ring: its wall of fieldstones in three courses, the top face an oak coping round the
    # dark water.
    ring = forms.ellipse(WELL_WIDTH, height, RING_X, RING_Y, RING_RX, RING_RY)
    wall = ring.copy()
    for drop in range(1, RING_WALL + 1):
        wall[drop:] |= ring[:-drop]
    rng = random.Random(122)
    stones = {}
    for y in range(RING_Y, RING_Y + RING_RY + RING_WALL + 1):
        course = (y - RING_Y) // 4
        for x in range(RING_X - RING_RX, RING_X + RING_RX + 1):
            if not wall[y][x]:
                continue
            index = (x + (course % 2) * 3) // 6
            key = (course, index)
            stones.setdefault(key, rng.choice((0, 1, 1, 2)))
            lit = x < RING_X - RING_RX // 3
            shade = ("stone_dark", "stone", "stone_light")[min(2, max(0, stones[key] + (1 if lit else -1) + (1 if x < RING_X else 0)))]
            is_joint = (y - RING_Y) % 4 == 3 or (x + (course % 2) * 3) % 6 == 5
            picture[y][x] = "stone_dark" if is_joint else shade
    coping = ring
    rect_inner = forms.ellipse(WELL_WIDTH, height, RING_X, RING_Y, RING_RX - 4, RING_RY - 2.5)
    forms.paint(picture, coping & ~rect_inner, OAK[1])
    for x in range(RING_X - RING_RX, RING_X + RING_RX + 1):
        for y in range(height):
            if coping[y][x] and not rect_inner[y][x]:
                lit_edge = y == 0 or not coping[y - 1][x] or x < RING_X - RING_RX + 3
                picture[y][x] = OAK[0] if lit_edge else OAK[1] if (x + y) % 7 else OAK[2]
    forms.paint(picture, rect_inner, "water_deep")
    water_mask = rect_inner.copy()
    water_mask[: RING_Y - 1] = False
    forms.paint(picture, forms.shrunk(water_mask), "water")
    for x, y in ((RING_X - 5, RING_Y + 1), (RING_X - 4, RING_Y + 1), (RING_X + 2, RING_Y), (RING_X + 3, RING_Y)):
        picture[y][x] = "water_light"
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def icons():
    """The bodies of the icons of the yard's items, by item id: their pictures."""
    return {"draw_well": items.icon_of(draw_well())}
