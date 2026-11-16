"""The beds of the interiors (assets/interior/<bed>.png): the bed with its curtain, the sleeping mat
and the box bed, and the part of each that lies over the player when they wake in it.

The room, and the drawing all furniture shares (the grain of wood, the dithered shadow), are in
interior.py.
"""

import forms
from canvas import blank, outline_edge, rect
from interior import T, grain


def checked_blanket(canvas, x0, y0, x1, y1):
    """A blanket of indigo linen woven in a check over x0..x1, y0..y1, lit along its top and
    left, with the white sheet turned down over its top edge."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            stripe = (x - x0) % 6 in (3, 4) or (y - y0) % 6 in (3, 4)
            both = (x - x0) % 6 in (3, 4) and (y - y0) % 6 in (3, 4)
            canvas[y][x] = "water_light" if both else "water" if stripe else "water_deep"
    rect(canvas, x0, y0, x1, y0 + 2, "lime")
    rect(canvas, x0, y0, x1, y0, "snow_light")
    rect(canvas, x0, y0 + 3, x1, y0 + 3, "snow_shadow")


def pillow(canvas, x0, y0, x1, y1):
    """A plump linen pillow over x0..x1, y0..y1, shaded as a cushion lit from the top left."""
    width, height = len(canvas[0]), len(canvas)
    mask = forms.rounded_box(width, height, x0, y0, x1, y1)
    forms.shade(canvas, mask, ("sand_light", "cream", "lime"), radius=3)
    forms.paint(canvas, forms.edge(mask), "sand")


def curtain(canvas, x0, y0, x1, y1, tie):
    """A red curtain of madder wool gathered over x0..x1, y0..y1: folds running down, lit on
    their left, drawn together at the row `tie` by a band."""
    for x in range(x0, x1 + 1):
        fold = (x - x0) % 3
        rect(canvas, x, y0, x, y1, ("red_light", "rust", "rust_dark")[fold])
    rect(canvas, x0, tie, x1, tie + 1, "ochre")
    rect(canvas, x0, tie + 1, x1, tie + 1, "ochre_dark")
    rect(canvas, x0, y1, x1, y1, "rust_dark")


def bed():
    """A bed 1x2 tiles, head to the north, boxed in like a Durk: high side boards, a pillow and a
    checked blanket down to the foot board, and over its head a canopy on the wall with red
    curtains drawn aside. The figure lying in it (PlayerView.LYING_POSES) has its head on the
    pillow at rows 38 to 56 and its feet at the bottom row, under the foot board."""
    canvas = blank(T, 3 * T)
    # The canopy on the wall: a cornice, and the dark hollow behind the curtains.
    rect(canvas, 0, 3, 31, 31, "soil_dark")
    rect(canvas, 0, 3, 31, 9, "soil_mid")
    rect(canvas, 0, 3, 31, 3, "soil_light")
    rect(canvas, 0, 6, 31, 6, "soil_light")
    rect(canvas, 0, 9, 31, 10, "soil")
    for x in range(1, 31, 4):
        rect(canvas, x, 11, x + 1, 12, "soil")
    rect(canvas, 4, 13, 27, 31, "russet_deep")
    for x in (2, 23):
        curtain(canvas, x, 11, x + 6, 39, 24)
    # The bed seen from above: side boards, the head board, the straw tick, the pillow, the
    # blanket and the foot board.
    rect(canvas, 0, 32, 31, 95, "soil_mid")
    rect(canvas, 0, 32, 2, 95, "soil_light")
    rect(canvas, 29, 32, 31, 95, "soil")
    grain(canvas, 0, 32, 2, 95, "soil_mid", 151, along_x=False, count=4)
    rect(canvas, 0, 32, 31, 35, "soil_mid")
    rect(canvas, 0, 32, 31, 32, "soil_light")
    rect(canvas, 3, 36, 28, 91, "straw")
    rect(canvas, 3, 36, 28, 37, "reed")
    pillow(canvas, 5, 37, 26, 56)
    checked_blanket(canvas, 3, 55, 28, 91)
    rect(canvas, 0, 92, 31, 95, "soil")
    rect(canvas, 0, 92, 31, 92, "soil_light")
    rect(canvas, 0, 93, 31, 93, "soil_mid")
    return outline_edge(canvas, "soil_dark", keep_bottom=True)


def sleeping_mat():
    """A straw sleeping mat 1x2 tiles, head to the north: a tick of linen quilted across, a
    cream pillow and a grey wool blanket with a dark stripe down to its foot. The figure lying on
    it has its head at rows 6 to 24 and its feet at the bottom row."""
    canvas = blank(T, 2 * T)
    mask = forms.rounded_box(T, 2 * T, 2, 1, 29, 63)
    forms.shade(canvas, mask, ("sand", "straw", "dry_light"), radius=3)
    for y in range(6, 63, 6):
        rect(canvas, 3, y, 28, y, "sand")
    # Straw poking out at the seams.
    for x, y in ((1, 14), (1, 15), (30, 30), (30, 31), (1, 44)):
        canvas[y][x] = "straw"
    pillow(canvas, 5, 4, 26, 24)
    # The blanket, its top folded back, a dark stripe across.
    blanket = forms.rounded_box(T, 2 * T, 3, 23, 28, 63)
    forms.shade(canvas, blanket, ("stone_dark", "stone", "stone_light"), radius=2)
    rect(canvas, 3, 23, 28, 25, "stone_light")
    rect(canvas, 3, 26, 28, 26, "stone_dark")
    rect(canvas, 3, 44, 28, 45, "stone_dark")
    rect(canvas, 3, 47, 28, 47, "stone_dark")
    rect(canvas, 3, 63, 28, 63, "stone_dark")
    return outline_edge(canvas, "mud_dark")


def box_bed():
    """A box bed 2x2 tiles built against the back wall (an Alkoven): a panelled oak cupboard
    whose front stands up the wall to just under a window's sill, open in the middle onto the
    bed inside (a pillow at the left end, a checked blanket to the right end), red curtains
    drawn aside, and a front board down to the floor. The figure lying in it (head to the left,
    PlayerView.LYING_POSES) is at rows 45 to 64, above the front board, its head at x 4 to 22
    on the pillow and its feet under the blanket at the post on the right."""
    canvas = blank(2 * T, 2 * T + 24)
    # The cupboard: a cornice, the posts at the sides and the dark alcove between them.
    rect(canvas, 0, 0, 63, 87, "soil_mid")
    rect(canvas, 0, 0, 63, 5, "soil")
    rect(canvas, 0, 0, 63, 0, "soil_light")
    rect(canvas, 0, 3, 63, 3, "soil_light")
    for x in (0, 60):
        rect(canvas, x + 1, 6, x + 1, 66, "soil_light")
        rect(canvas, x + 3, 6, x + 3, 66, "soil")
    rect(canvas, 4, 6, 59, 66, "soil_dark")
    rect(canvas, 4, 6, 59, 8, "russet_deep")
    # The bed inside, lengthwise along the wall: the straw tick, the pillow at the head end.
    rect(canvas, 4, 46, 59, 66, "straw")
    rect(canvas, 4, 46, 59, 47, "reed")
    pillow(canvas, 5, 42, 25, 66)
    checked_blanket(canvas, 24, 47, 59, 66)
    # The curtains, gathered to the sides.
    for x in (4, 53):
        curtain(canvas, x, 6, x + 6, 41, 26)
    rect(canvas, 4, 6, 59, 7, "soil")
    # The front board, lit along its top, with two raised panels.
    rect(canvas, 0, 67, 63, 67, "soil_light")
    rect(canvas, 0, 68, 63, 68, "soil_mid")
    for x in (4, 34):
        rect(canvas, x, 70, x + 25, 82, "soil")
        rect(canvas, x + 1, 71, x + 24, 81, "soil_mid")
        rect(canvas, x + 1, 71, x + 24, 71, "soil_light")
        rect(canvas, x + 1, 71, x + 1, 81, "soil_light")
        rect(canvas, x, 82, x + 25, 82, "soil_dark")
        grain(canvas, x + 3, 73, x + 22, 80, "soil", 152 + x, count=4)
    rect(canvas, 0, 84, 63, 87, "soil")
    rect(canvas, 0, 84, 63, 84, "soil_mid")
    return outline_edge(canvas, "soil_dark", keep_bottom=True)


# The part of each bed that lies over the player when they wake in it (the blanket, and what
# is below it down to the foot of the bed), as rectangles (x0, y0, x1, y1) of the finished
# picture. The pillow stays under them, so the head shows on it.
BED_COVERS = {
    "bed": [(0, 55, 31, 95)],
    "sleeping_mat": [(0, 23, 31, 63)],
    "box_bed": [(24, 45, 63, 66), (0, 67, 63, 87)],
}


def covers(furniture):
    """The pictures assets/interior/<bed>_cover.png: the same size as the bed's, with only the
    pixels inside BED_COVERS left. The game draws one over the player lying in the bed."""
    result = {}
    for name, rects in BED_COVERS.items():
        picture = furniture[name][0]
        cover = blank(len(picture[0]), len(picture))
        for x0, y0, x1, y1 in rects:
            for y in range(y0, y1 + 1):
                cover[y][x0 : x1 + 1] = picture[y][x0 : x1 + 1]
        result[f"{name}_cover"] = cover
    return result


def pieces():
    """The beds by name: their picture and their footprint in tiles."""
    return {
        "bed": (bed(), (1, 2)),
        "sleeping_mat": (sleeping_mat(), (1, 2)),
        "box_bed": (box_bed(), (2, 2)),
    }
