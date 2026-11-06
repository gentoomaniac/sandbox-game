"""The camp site objects of assets/objects.png: the fireplace and the bedroll (the
sleeping_bag object)."""

import math

import fire
from canvas import OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank, rect

def fire_stone(canvas, x, y):
    rect(canvas, x - 1, y - 1, x + 1, y, "stone")
    rect(canvas, x - 1, y - 1, x, y - 1, "stone_light")
    rect(canvas, x + 1, y, x + 1, y, "stone_dark")


# The box of the fireplace's cell that its flame burns in (x, y, width, height; the flame stands
# on its bottom row), and the flame's half width and height.
FIREPLACE_FLAME = ((OBJECT_CENTRE - 8, 51, 16, 20), 5.5, 15)


def fireplace_layers():
    """The fireplace without its flame: what is behind the flame (the ash bed and three logs on
    it, laid like the spokes of a wheel) and what is in front of it (the ring of stones)."""
    behind, front = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT), blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    centre, ground = OBJECT_CENTRE, 71
    for y in range(ground - 4, ground + 5):
        for x in range(centre - 10, centre + 10):
            if ((x - centre) / 9.5) ** 2 + ((y - ground) / 4.2) ** 2 <= 1:
                behind[y][x] = "soil_dark"
    for dx, dy, shades in ((-7, -2, ("soil_mid", "soil")), (7, -2, ("soil", "soil_dark")), (0, 3, ("soil_mid", "soil"))):
        for i in range(9):
            x, y = round(centre + dx * i / 8), round(ground + dy * i / 8)
            behind[y][x] = behind[y + 1][x] = shades[0]
            behind[y + 2][x] = shades[1]
    ring = [
        (round(centre + 10.5 * math.cos(step / 14 * 2 * math.pi)), round(ground + 3 + 4 * math.sin(step / 14 * 2 * math.pi)), math.sin(step / 14 * 2 * math.pi))
        for step in range(14)
    ]
    for x, y, depth in sorted(ring, key=lambda stone: stone[2]):
        fire_stone(front, x, y)
    return behind, front


def fireplace():
    return fire.burning(*fireplace_layers(), *FIREPLACE_FLAME)


def bedroll():
    """14x26 px, lying vertically on 1x2 tiles (the cell's bottom edge is the footprint's): a
    sack of linen ticking stuffed with straw, quilted across, straw poking out at its seams, and
    a grey wool blanket rolled up and tied at its head end. The object's id stays sleeping_bag."""
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    left, top, bottom = OBJECT_CENTRE - 7, 51, 76
    right = left + 13
    # The straw sack: lit linen, shaded down its right side, quilted in rows.
    rect(canvas, left, top + 3, right, bottom, "mud_dark")
    rect(canvas, left + 1, top + 4, right - 1, bottom - 1, "sand_light")
    rect(canvas, right - 3, top + 4, right - 1, bottom - 1, "sand")
    rect(canvas, left + 1, bottom - 1, right - 1, bottom - 1, "sand")
    for y in range(top + 12, bottom - 2, 5):
        rect(canvas, left + 1, y, right - 1, y, "sand")
        rect(canvas, right - 3, y, right - 1, y, "mud")
    for x, y in ((left, bottom), (right, bottom), (left, top + 3), (right, top + 3)):
        canvas[y][x] = None
    rect(canvas, left + 2, bottom + 1, right, bottom + 2, "shadow")
    # Straw sticking out of the seams.
    for x, y, colour in ((left - 1, top + 13, "straw"), (left - 1, top + 14, "gold"), (left - 2, top + 14, "straw"),
                         (right + 1, top + 20, "straw"), (right + 1, top + 21, "straw"), (right + 2, top + 20, "gold"),
                         (left + 3, bottom + 1, "straw"), (left + 4, bottom + 1, "gold"), (left + 4, bottom + 2, "straw")):
        canvas[y][x] = colour
    # The rolled blanket across the head end: lit on top, its rolled-up ends showing a spiral.
    rect(canvas, left - 1, top, right + 1, top + 8, "stone_dark")
    rect(canvas, left, top + 1, right, top + 7, "stone")
    rect(canvas, left, top + 1, right, top + 3, "stone_light")
    rect(canvas, left, top + 7, right, top + 7, "stone_dark")
    for x in (left - 1, right + 1):
        canvas[top][x] = canvas[top + 8][x] = None
    for x in (left, right):
        rect(canvas, x, top + 3, x, top + 5, "stone_dark")
    canvas[top + 4][left + 1] = "stone_dark"
    canvas[top + 4][right - 1] = "stone_dark"
    # Two cords round the roll.
    for x in (left + 3, right - 3):
        rect(canvas, x, top + 1, x, top + 7, "soil")
        canvas[top + 1][x] = "soil_light"
    return canvas
