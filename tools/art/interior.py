"""The interior (assets/interior.png and assets/interior/*.png), used by maps/interiors/*.tsx
and game/scenes/interior_view.gd, drawn at the game's tile (32 px, not doubled). The room is
seen in 3/4 view: the back wall as a face 2 tiles high, the side and front walls only as their
16 px thick tops. Light falls from the top left, as outdoors.

assets/interior.png is one row of 32x32 tiles, in the order of `atlas_tiles`, then
one marker tile per piece of furniture (the top left tile of its footprint, so Tiled shows
what is where). The game draws the furniture from assets/interior/<name>.png instead:
sprites of any size, centred on their footprint with their bottom edge on its bottom edge.
Wood is outlined in its darkest shade, and what stands free on the floor casts a dithered
shadow to the bottom right, which reads on the brick and on the clay alike.
"""

import math
import random

import chest
import fire
import forms
from canvas import GAME_TILE, TILE, blank, copy, outline_edge, rect
from terrain import patch_noise

T = GAME_TILE
# The thickness of the side and front walls' tops.
RIM = T // 2
# Oak, light to dark, and its outline.
OAK = ("soil", "soil_mid", "soil_light")


def dither(canvas, x0, y0, x1, y1, colour, phase=0):
    """Every other pixel of x0..x1, y0..y1 in `colour`, as a checkerboard: a soft shadow."""
    for y in range(max(0, y0), min(len(canvas) - 1, y1) + 1):
        for x in range(max(0, x0), min(len(canvas[0]) - 1, x1) + 1):
            if (x + y + phase) % 2 == 0:
                canvas[y][x] = colour


def floor_shadow(canvas, x0, y0, x1, y1):
    """The shadow a piece of furniture casts on the floor round x0..x1, y0..y1, to the bottom
    right of it: dithered on the clear pixels, after the outline."""
    for y in range(max(0, y0), min(len(canvas) - 1, y1) + 1):
        for x in range(max(0, x0), min(len(canvas[0]) - 1, x1) + 1):
            if canvas[y][x] is None and (x + y) % 2 == 0:
                canvas[y][x] = "soil_dark"
    return canvas


def grain(canvas, x0, y0, x1, y1, colour, seed, along_x=True, count=None):
    """Streaks of wood grain in `colour` over a board x0..x1, y0..y1, running along its length."""
    rng = random.Random(seed)
    length = (x1 - x0 + 1) if along_x else (y1 - y0 + 1)
    across = (y1 - y0 + 1) if along_x else (x1 - x0 + 1)
    for _ in range(count or max(1, length * across // 40)):
        start = rng.randrange(length)
        run = rng.randrange(3, 9)
        offset = rng.randrange(across)
        for step in range(run):
            if start + step >= length:
                break
            x, y = (x0 + start + step, y0 + offset) if along_x else (x0 + offset, y0 + start + step)
            canvas[y][x] = colour


# Floors ----------------------------------------------------------------------------------------

def brick_floor():
    """The floor of the living rooms: old red brick, 16x8, laid in a herringbone with joints
    one step darker. Kept calm, as the clay is: one colour of brick, as any second colour
    repeats with the tile into a pattern, and a worn spot on about every third brick. The
    pattern repeats every tile, and each brick is the same wherever the tile's edge cuts it."""
    canvas = blank(T)
    width = 8
    for band in range(-4, 5):
        for step in range(-8, 9):
            x, y = width * (step + 2 * band), width * (step - 2 * band)
            # A brick lying across, then one standing under its left half.
            for left, top, across, down in ((x, y, 2 * width, width), (x, y + width, width, 2 * width)):
                rng = random.Random(f"brick {left % T} {top % T} {across}")
                worn = (rng.randrange(1, across - 2), rng.randrange(1, down - 2)) if rng.random() < 0.3 else None
                for dy in range(down):
                    for dx in range(across):
                        if dx == across - 1 or dy == down - 1:
                            colour = "soil"
                        elif (dx, dy) == worn:
                            colour = "soil_mid"
                        else:
                            colour = "rust_dark"
                        canvas[(top + dy) % T][(left + dx) % T] = colour
    return canvas


def clay_floor():
    """The floor of the work rooms (the byre, the barn, the shack): beaten clay, trodden darker
    and greyer in patches, with a little sand, bits of straw and a pebble. Kept calm: whatever
    stands out repeats every tile."""
    rng = random.Random(134)
    trodden = patch_noise(135, 16)
    canvas = blank(T)
    for y in range(T):
        for x in range(T):
            level = trodden(x, y)
            if level < -0.35 and (x + y) % 2 == 0:
                canvas[y][x] = "mud_dark"
            elif level > 0.45 and (x + y) % 2 == 0:
                canvas[y][x] = "bare"
            else:
                canvas[y][x] = "mud"
    for colour, count, length in (("sand", 4, 1), ("mud_dark", 5, 2), ("straw", 2, 3), ("sand", 2, 2)):
        for _ in range(count):
            x, y = rng.randrange(T), rng.randrange(T)
            slope = rng.choice((0, 1))
            for step in range(length):
                canvas[(y + step * slope) % T][(x + step) % T] = colour
    for x, y in ((9, 21), (25, 6)):
        canvas[y][x] = "stone_light"
        canvas[y][x + 1] = "stone"
        canvas[y + 1][x] = canvas[y + 1][x + 1] = "mud_dark"
    return canvas


# Each floor colour one step darker, for the row along the back wall in its shadow.
FLOOR_SHADOW = {
    "ember": "rust_dark",
    "rust_dark": "russet_deep",
    "russet_deep": "soil_dark",
    "soil_dark": "soil_dark",
    "soil_light": "soil_mid",
    "soil_mid": "soil",
    "soil": "soil_dark",
    "mud": "mud_dark",
    "mud_dark": "soil_dark",
    "bare": "mud",
    "sand": "mud",
    "straw": "sand",
    "reed": "mud",
    "stone_light": "stone",
    "stone": "stone_dark",
}


def shaded_floor(floor):
    """The floor row along the back wall, in its shadow: one step darker, and darker still in a
    dithered band along the foot of the wall."""
    canvas = [[FLOOR_SHADOW[colour] for colour in row] for row in floor]
    rect(canvas, 0, 0, T - 1, 1, "soil_dark")
    for y in range(2, 6):
        for x in range(T):
            if (x + y) % 2 == 0 or y < 4:
                canvas[y][x] = FLOOR_SHADOW.get(canvas[y][x], "soil_dark")
    return canvas


# Walls -----------------------------------------------------------------------------------------

# The top of a side or front wall across its 16 px, from its outer edge to the room: an oak wall
# plate lit on its outer edge, its grain along the wall, shaded towards the room.
WALL_TOP_SHADES = (
    "soil_dark", "soil_light", "soil_light", "soil_mid", "soil_mid", "soil_mid", "soil_mid", "soil_mid",
    "soil_mid", "soil_mid", "soil_mid", "soil_mid", "soil", "soil", "soil_dark", "soil_dark",
)


def rim_left():
    """The top of the left wall: its 16 px next to the room are the right half of the tile."""
    canvas = blank(T)
    for x, colour in zip(range(RIM, T), WALL_TOP_SHADES):
        rect(canvas, x, 0, x, T - 1, colour)
    grain(canvas, RIM + 3, 0, T - 5, T - 1, "soil", 141, along_x=False, count=7)
    grain(canvas, RIM + 3, 0, T - 5, T - 1, "soil_light", 142, along_x=False, count=3)
    return canvas


def rim_front():
    """The top of the front wall: its 16 px next to the room are the top half of the tile."""
    canvas = blank(T)
    for y, colour in zip(range(RIM), WALL_TOP_SHADES[::-1]):
        rect(canvas, 0, y, T - 1, y, colour)
    grain(canvas, 0, 3, T - 1, RIM - 4, "soil", 143, count=7)
    grain(canvas, 0, 3, T - 1, RIM - 4, "soil_light", 144, count=3)
    return canvas


def mirrored_tile(canvas):
    return [row[::-1] for row in canvas]


def clear_columns(canvas, left, right):
    """Clears the columns left..right (both ends included)."""
    for row in canvas:
        for x in range(left, right + 1):
            row[x] = None
    return canvas


def interior_doormat():
    """The exit: a mat of plaited straw 32x16 across the gap in the front wall, its plaits in
    rows that turn every other one, with a darker binding."""
    canvas = blank(T)
    rect(canvas, 0, 0, T - 1, 15, "mud_dark")
    rect(canvas, 1, 1, T - 2, 14, "sand")
    for y in range(2, 14):
        for x in range(2, T - 2):
            row, down = divmod(y - 2, 3)
            across = (x + 2 * (row % 2)) % 4
            if down == 2:
                colour = "reed"
            elif across == 0:
                colour = "sand"
            elif down == 0 and across < 3:
                colour = "dry_light" if across == 1 else "straw"
            else:
                colour = "straw"
            canvas[y][x] = colour
    rect(canvas, 2, 2, T - 3, 2, "dry_light")
    return canvas


def plaster(canvas, x0, y0, x1, y1, seed):
    """Lime plaster gone warm with smoke, with flecks and a few fine cracks."""
    rng = random.Random(seed)
    rect(canvas, x0, y0, x1, y1, "sand_light")
    area = (x1 - x0 + 1) * (y1 - y0 + 1)
    for _ in range(area // 28):
        canvas[rng.randint(y0, y1)][rng.randint(x0, x1)] = "sand"
    for _ in range(area // 120):
        canvas[rng.randint(y0, y1)][rng.randint(x0, x1)] = "lime"
    for _ in range(area // 400):
        x, y = rng.randint(x0, x1 - 3), rng.randint(y0, y1 - 3)
        for step in range(3):
            canvas[y + step][x + (step + 1) // 2] = "mud"


def back_wall_top():
    """The upper tile of the back wall: an oak ceiling beam over plaster."""
    canvas = blank(T)
    plaster(canvas, 0, 0, T - 1, T - 1, 131)
    rect(canvas, 0, 0, T - 1, 0, "soil_light")
    rect(canvas, 0, 1, T - 1, 5, "soil_mid")
    grain(canvas, 0, 2, T - 1, 5, "soil", 145, count=5)
    rect(canvas, 0, 6, T - 1, 7, "soil")
    rect(canvas, 0, 8, T - 1, 8, "soil_dark")
    # The beam's shadow on the plaster.
    rect(canvas, 0, 9, T - 1, 9, "mud")
    dither(canvas, 0, 10, T - 1, 11, "sand")
    return canvas


def back_wall_bottom():
    """The lower tile of the back wall: plaster over a wainscot of raised oak panels, each lit
    on its top and left edges, and a dark skirting."""
    canvas = blank(T)
    plaster(canvas, 0, 0, T - 1, 9, 132)
    # The rail on top of the wainscot, and its shadow on the plaster.
    dither(canvas, 0, 8, T - 1, 9, "sand")
    rect(canvas, 0, 10, T - 1, 10, "soil_light")
    rect(canvas, 0, 11, T - 1, 12, "soil_mid")
    rect(canvas, 0, 13, T - 1, 13, "soil")
    rect(canvas, 0, 14, T - 1, 27, "soil")
    for left in (2, 18):
        right = left + 11
        rect(canvas, left, 15, right, 26, "soil_mid")
        rect(canvas, left, 15, right, 15, "soil_light")
        rect(canvas, left, 15, left, 26, "soil_light")
        rect(canvas, left, 26, right, 26, "soil_dark")
        rect(canvas, right, 16, right, 26, "soil_dark")
    rect(canvas, 0, 28, T - 1, 28, "soil_mid")
    rect(canvas, 0, 29, T - 1, 31, "soil_dark")
    return canvas


def back_wall_end(tile, is_left):
    """A back wall tile at a corner: only the 16 px next to the room, ending in a corner post
    lit on its left."""
    canvas = copy(tile)
    if is_left:
        clear_columns(canvas, 0, RIM - 1)
        post = range(RIM, RIM + 5)
    else:
        clear_columns(canvas, RIM, T - 1)
        post = range(RIM - 5, RIM)
    for x, colour in zip(post, ("soil_dark", "soil_light", "soil_mid", "soil", "soil_dark")):
        rect(canvas, x, 0, x, T - 1, colour)
    return canvas


def window_picture():
    """A window of 3x3 small panes, 32x64, drawn over the plaster of the back wall face: set
    deep in the wall, its reveal in the shade but for its lit sill, the daylight in the panes
    brightest at the top left, an oak frame and glazing bars."""
    canvas = blank(T, 2 * T)
    left, top, size = 7, 15, 19
    # The reveal: the wall's thickness round the window, lit along its bottom.
    rect(canvas, left - 4, top - 4, left + size + 3, top + size + 3, "sand")
    rect(canvas, left - 4, top - 4, left + size + 3, top - 3, "mud")
    rect(canvas, left - 4, top - 4, left - 3, top + size + 3, "mud")
    rect(canvas, left - 2, top + size + 2, left + size + 3, top + size + 3, "lime")
    rect(canvas, left - 1, top - 1, left + size, top + size, "soil")
    for y in range(top, top + size):
        for x in range(left, left + size):
            column, across = divmod(x - left, 6)
            row, down = divmod(y - top, 6)
            if across == 0 or down == 0:
                canvas[y][x] = "soil_mid"
            else:
                corner = across == 1 and down == 1
                light = (x - left + y - top) / (2 * size)
                canvas[y][x] = "snow_light" if corner else "foam" if light < 0.45 else "water_light"
    rect(canvas, left + size - 1, top, left + size - 1, top + size - 1, "soil")
    rect(canvas, left, top + size - 1, left + size - 1, top + size - 1, "soil")
    # The sill board, sticking out of the wall, and its shadow.
    rect(canvas, left - 6, top + size + 4, left + size + 5, top + size + 4, "soil_light")
    rect(canvas, left - 6, top + size + 5, left + size + 5, top + size + 6, "soil_mid")
    rect(canvas, left - 6, top + size + 7, left + size + 5, top + size + 7, "soil_dark")
    dither(canvas, left - 5, top + size + 8, left + size + 5, top + size + 9, "mud")
    return outline_edge(canvas, "soil_dark", ignoring=("sand", "mud", "lime"))


# Beds ------------------------------------------------------------------------------------------


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


# Tables, seats and the like --------------------------------------------------------------------


def turned_leg(canvas, x, top, bottom):
    """A turned oak leg 4 px wide from `top` to `bottom`, lit on its left, with two rings."""
    rect(canvas, x, top, x + 3, bottom, "soil_mid")
    rect(canvas, x, top, x, bottom, "soil_light")
    rect(canvas, x + 3, top, x + 3, bottom, "soil")
    for y in (top + 2, bottom - 3):
        if top < y < bottom:
            rect(canvas, x, y, x + 3, y, "soil_dark")


def planked_top(canvas, x0, y0, x1, y1, plank, seed):
    """A top of oak planks `plank` rows wide running across, lit, with their joints and grain."""
    rect(canvas, x0, y0, x1, y1, "soil_light")
    for y in range(y0 + plank, y1 + 1, plank):
        rect(canvas, x0, y, x1, y, "soil_mid")
    grain(canvas, x0, y0, x1, y1, "soil_mid", seed, count=(x1 - x0) * (y1 - y0) // 50)
    grain(canvas, x0, y0, x1, y1, "sand", seed + 1, count=(x1 - x0) * (y1 - y0) // 120)


def table():
    """A table 2x1 tiles: a plank top seen from above, its apron and two turned legs; on it a
    candle in a brass stick, a pewter plate with a spoon and a brown clay jug."""
    canvas = blank(2 * T, 48)
    planked_top(canvas, 0, 0, 63, 29, 6, 161)
    rect(canvas, 0, 0, 63, 0, "sand_light")
    rect(canvas, 0, 30, 63, 33, "soil_mid")
    rect(canvas, 0, 30, 63, 30, "soil_light")
    rect(canvas, 0, 34, 63, 35, "soil")
    for x in (3, 56):
        turned_leg(canvas, x, 36, 47)
    # The candle and its brass stick.
    rect(canvas, 47, 9, 52, 13, "ochre_dark")
    rect(canvas, 47, 9, 51, 11, "ochre")
    rect(canvas, 48, 3, 50, 9, "cream")
    rect(canvas, 50, 3, 50, 9, "sand_light")
    canvas[2][49] = "soil_dark"
    rect(canvas, 49, 0, 49, 1, "gold")
    # A pewter plate with a spoon.
    plate = forms.ellipse(2 * T, 48, 17, 14, 8, 6)
    forms.shade(canvas, plate, ("stone", "stone_light"), radius=1)
    forms.paint(canvas, forms.edge(plate), "stone_dark")
    rect(canvas, 14, 12, 19, 15, "stone")
    rect(canvas, 21, 18, 27, 18, "stone_light")
    rect(canvas, 26, 17, 27, 18, "stone_light")
    # A clay jug, its shadow on the table.
    dither(canvas, 36, 18, 41, 20, "soil_mid")
    jug = forms.ellipse(2 * T, 48, 35.5, 14.5, 4, 5)
    forms.shade(canvas, jug, ("rust_dark", "rust", "ochre"), radius=2)
    rect(canvas, 34, 7, 37, 9, "rust_dark")
    rect(canvas, 34, 8, 37, 8, "russet_deep")
    rect(canvas, 39, 11, 40, 15, "rust_dark")
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 8, 38, 63, 47)
    return canvas


def stool():
    """A stool, 20x20: a round seat of one board on three legs with a stretcher."""
    canvas = blank(20, 20)
    seat = forms.ellipse(20, 20, 10, 4.5, 9.5, 4.5)
    forms.shade(canvas, seat, OAK, radius=2)
    grain(canvas, 4, 3, 15, 7, "soil_mid", 162, count=3)
    rect(canvas, 1, 8, 18, 9, "soil")
    for x0, x1 in ((2, 3), (15, 16), (9, 10)):
        rect(canvas, x0, 10, x1, 19, "soil_mid")
        rect(canvas, x0, 10, x0, 19, "soil_light" if x0 < 10 else "soil_mid")
        rect(canvas, x1, 10, x1, 19, "soil")
    rect(canvas, 4, 14, 14, 14, "soil")
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 5, 13, 19, 19)
    return canvas


def bench():
    """A bench 2x1 tiles: a plank seat on two pairs of legs with a stretcher."""
    canvas = blank(2 * T, T)
    planked_top(canvas, 0, 5, 63, 14, 5, 163)
    rect(canvas, 0, 5, 63, 5, "sand_light")
    rect(canvas, 0, 15, 63, 17, "soil_mid")
    rect(canvas, 0, 15, 63, 15, "soil_light")
    rect(canvas, 0, 18, 63, 18, "soil")
    for x in (3, 56):
        turned_leg(canvas, x, 19, 31)
    rect(canvas, 7, 24, 55, 25, "soil")
    rect(canvas, 7, 24, 55, 24, "soil_mid")
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 6, 21, 63, 31)
    return canvas


def wall_bench():
    """A bench 2x1 tiles along the back wall: a back of turned spindles under a rail, standing
    on the wall above the footprint, and a plank seat on four legs."""
    canvas = blank(2 * T, T + 16)
    # The back: a rail and spindles, the wall showing between them in their shadow.
    rect(canvas, 0, 0, 63, 3, "soil_mid")
    rect(canvas, 0, 0, 63, 0, "soil_light")
    rect(canvas, 0, 3, 63, 3, "soil")
    for x in range(2, 62, 6):
        rect(canvas, x, 4, x + 2, 17, "soil_mid")
        rect(canvas, x, 4, x, 17, "soil_light")
        rect(canvas, x + 2, 4, x + 2, 17, "soil")
        rect(canvas, x, 10, x + 2, 10, "soil_dark")
    # The seat, seen from above, and its front edge.
    planked_top(canvas, 0, 18, 63, 29, 6, 164)
    rect(canvas, 0, 18, 63, 18, "soil_mid")
    rect(canvas, 0, 30, 63, 32, "soil_mid")
    rect(canvas, 0, 30, 63, 30, "soil_light")
    rect(canvas, 0, 33, 63, 33, "soil")
    for x in (3, 56):
        turned_leg(canvas, x, 34, 47)
    rect(canvas, 7, 40, 55, 41, "soil")
    rect(canvas, 7, 40, 55, 40, "soil_mid")
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 6, 37, 63, 47)
    return canvas


# The hearth --------------------------------------------------------------------------------------

# The hearth stands against the back wall: its footprint is the lower half of its picture, and
# the upper half, the smoke hood, is drawn over the back wall.
HEARTH_WIDTH, HEARTH_HEIGHT = 2 * T, 4 * T
# The box of the hearth's picture that its flame burns in (x, y, width, height; the flame stands
# on its bottom row, over the logs), and the flame's half width and height.
HEARTH_FLAME = ((16, 52, 32, 44), 10.0, 28)


def hearth_without_flame():
    """An open hearth 2x2 tiles under a smoke hood: a raised hearth of buff brick with two logs
    on it and an iron pot beside them, and over it, on the back wall, a lime-washed hood on an
    oak mantel beam that takes the smoke up into the chimney. The wall under the hood is laid
    with Delft tiles, black with soot behind the fire."""
    canvas = blank(HEARTH_WIDTH, HEARTH_HEIGHT)
    # The hood: a shaft up into the ceiling beam, flaring out to the mantel, lit from the top
    # left, its right flank in shade.
    for y in range(0, 32):
        half = 12 if y < 10 else 12 + round((y - 9) * 20 / 22)
        rect(canvas, 32 - half, y, 31 + half, y, "lime")
        rect(canvas, 32 - half, y, 32 - half + 1, y, "snow_light")
        shade = max(4, half // 3)
        rect(canvas, 31 + half - shade, y, 31 + half, y, "sand_light")
        rect(canvas, 31 + half - shade - 1, y, 31 + half - shade - 1, y, "snow_shadow" if y % 3 else "sand_light")
    rect(canvas, 20, 0, 20, 9, "snow_shadow")
    # Soot creeps up from the mantel.
    rng = random.Random(171)
    for y in range(24, 32):
        for x in range(4, 60):
            if rng.random() < (y - 22) / 12:
                canvas[y][x] = "bare_light" if canvas[y][x] in ("lime", "snow_light") else "bare"
    # The mantel beam, with a lit top edge and grain.
    rect(canvas, 0, 32, 63, 39, "soil")
    rect(canvas, 0, 32, 63, 32, "soil_light")
    rect(canvas, 0, 33, 63, 34, "soil_mid")
    grain(canvas, 0, 35, 63, 38, "soil_mid", 172, count=6)
    rect(canvas, 0, 39, 63, 39, "soil_dark")
    # The wall under the hood, tiled, in the mantel's shadow and black with soot where the fire
    # licks it.
    delft_tiles(canvas, 2, 40, 61, 79)
    dither(canvas, 2, 40, 61, 43, "soil_dark")
    rect(canvas, 2, 40, 61, 41, "soil_dark")
    soot(canvas)
    # The brackets that carry the mantel.
    for x in (2, 56):
        rect(canvas, x, 40, x + 5, 45, "soil")
        rect(canvas, x + 2, 46, x + 5, 50, "soil")
        rect(canvas, x, 40, x + 5, 40, "soil_mid")
        rect(canvas, x + 5, 40, x + 5, 50, "soil_dark")
    # The raised hearth: its top, bricks seen from above, and its front of buff brick.
    rect(canvas, 0, 80, 63, 103, "sand")
    for y in range(80, 104, 4):
        rect(canvas, 0, y + 3, 63, y + 3, "mud")
        for x in range(2 + (y // 4) % 2 * 6, 64, 12):
            rect(canvas, x, y, x, y + 2, "mud")
            rect(canvas, x + 1, y, x + 4, y, "sand_light")
    rect(canvas, 0, 80, 63, 80, "sand_light")
    rect(canvas, 0, 103, 63, 103, "sand_light")
    rect(canvas, 0, 104, 63, 126, "sand")
    for y in range(104, 127, 4):
        rect(canvas, 0, y + 3, 63, y + 3, "mud")
        for x in range(1 + (y // 4) % 2 * 4, 64, 8):
            rect(canvas, x, y, x, y + 2, "mud")
        for x in range(2 + (y // 4) % 2 * 4, 64, 8):
            rect(canvas, x, y, x + 2, y, "sand_light")
    rect(canvas, 0, 104, 63, 104, "mud_dark")
    rect(canvas, 0, 127, 63, 127, "mud_dark")
    # The ash bed and the logs, the flame stands on them (its box ends at row 95).
    ash = forms.ellipse(HEARTH_WIDTH, HEARTH_HEIGHT, 32, 94, 15, 5)
    forms.paint(canvas, ash, "stone")
    forms.paint(canvas, forms.shrunk(ash), "stone_dark")
    for (x0, y0), (x1, y1) in (((20, 95), (42, 91)), ((22, 90), (44, 95))):
        log = forms.capsule(HEARTH_WIDTH, HEARTH_HEIGHT, (x0, y0), (x1, y1), 2.5)
        forms.shade(canvas, log, ("soil_dark", "soil", "soil_mid"), radius=2)
    for x, y in ((19, 95), (44, 96)):
        rect(canvas, x, y - 1, x + 1, y, "ember")
        canvas[y - 1][x] = "flame"
    # A three-legged iron pot, a brass glint on its lid.
    pot = forms.ellipse(HEARTH_WIDTH, HEARTH_HEIGHT, 54, 89, 6, 6)
    forms.shade(canvas, pot, ("ink", "stone_dark", "stone"), radius=2)
    rect(canvas, 49, 82, 59, 83, "ink")
    rect(canvas, 50, 82, 58, 82, "stone_dark")
    canvas[81][53] = canvas[81][54] = "ochre"
    for x in (49, 58):
        rect(canvas, x, 95, x, 98, "ink")
    return outline_edge(canvas, "soil_dark", keep_bottom=True)


def delft_tiles(canvas, x0, y0, x1, y1):
    """Blue-and-white Delft tiles over x0..x1, y0..y1, 8 px square: white with a blue flower in
    the middle and blue corner ornaments where four tiles meet, in grey-blue joints."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            across, down = (x - x0) % 8, (y - y0) % 8
            middle = abs(across - 3.5) + abs(down - 3.5)
            if across == 7 or down == 7:
                colour = "snow_shadow"
            elif middle <= 1:
                colour = "water_deep"
            elif across in (0, 6) and down in (0, 6):
                colour = "water"
            elif middle <= 2 and (across == 3 or across == 4 or down == 3 or down == 4):
                colour = "water"
            else:
                colour = "lime"
            canvas[y][x] = colour


def soot(canvas):
    """The soot on the wall behind the fire: a black core that fades out upwards in ragged
    edges."""
    rng = random.Random(173)
    for y in range(44, 80):
        half = 4 + (y - 44) * 8 // 35
        for x in range(32 - half - 3, 32 + half + 3):
            inside = abs(x + 0.5 - 32) < half
            if inside and y >= 58:
                canvas[y][x] = "ink"
            elif inside or rng.random() < 0.5:
                canvas[y][x] = "stone_dark"


def hearth_layers():
    """The hearth without its flame: what is behind the flame and what is in front of it
    (nothing: the fire stands free on the hearth)."""
    return hearth_without_flame(), blank(HEARTH_WIDTH, HEARTH_HEIGHT)


def hearth():
    """The open hearth with a fire on it: the first frame of its flame (fire.strip)."""
    return fire.burning(*hearth_layers(), *HEARTH_FLAME, scale=GAME_TILE // TILE)


# The byre and the store ---------------------------------------------------------------------------


def stall_partition():
    """A stall partition 1x2 tiles: an oak post with two rails pegged to it that run on into the
    next stall, and a little straw at its foot."""
    canvas = blank(T, 2 * T)
    for top in (12, 32):
        rect(canvas, 0, top, 31, top + 6, "soil")
        rect(canvas, 0, top, 31, top + 1, "soil_mid")
        rect(canvas, 0, top, 31, top, "soil_light")
        rect(canvas, 0, top + 6, 31, top + 6, "soil_dark")
        grain(canvas, 0, top + 2, 31, top + 5, "soil_dark", 181 + top, count=3)
    rect(canvas, 11, 0, 20, 61, "soil_mid")
    rect(canvas, 11, 0, 13, 61, "soil_light")
    rect(canvas, 18, 0, 20, 61, "soil")
    rect(canvas, 11, 0, 20, 1, "sand")
    grain(canvas, 14, 2, 17, 58, "soil", 183, along_x=False, count=4)
    for top in (12, 32):
        rect(canvas, 15, top + 2, 16, top + 4, "soil_dark")
        canvas[top + 2][15] = "soil_light"
    rect(canvas, 6, 59, 25, 63, "soil_dark")
    rng = random.Random(184)
    for _ in range(14):
        x = rng.randrange(4, 28)
        rect(canvas, x, 60 + rng.randrange(2), x + 1, 63, rng.choice(("straw", "reed", "sand")))
    return outline_edge(canvas, "soil_dark", keep_bottom=True)


def hay_pile():
    """A pile of hay 2x1 tiles: a mound lit from the top left, shaggy along its top, in wisps
    of straw and gold, darker and trodden at its foot."""
    rng = random.Random(391)
    width, height = 2 * T, T
    mound = forms.grid(width, height)
    xs, ys = mound
    top = 4 + 13 * (1 - (1 - ((xs - 32) / 31) ** 2).clip(0) ** 0.6)
    mask = (ys >= top + rng.random()) & (xs > 0.5) & (xs < width - 0.5)
    for x in range(width):
        lift = rng.choice((0, 0, 1, 2))
        for y in range(height):
            if mask[y, x] and y > 0:
                mask[y - lift, x] = True
                break
    canvas = blank(width, height)
    forms.shade(canvas, mask, ("ochre_dark", "ochre", "straw", "gold"), radius=6, top_light=0.3)
    for _ in range(90):
        x, y = rng.randrange(2, width - 3), rng.randrange(4, height - 2)
        if mask[y, x]:
            colour = rng.choice(("gold", "straw", "ochre_dark", "sand"))
            dx = rng.choice((-1, 1))
            for step in range(rng.randrange(2, 5)):
                if 0 <= x + step * dx < width and 0 <= y + step < height and mask[y + step, x + step * dx]:
                    canvas[y + step][x + step * dx] = colour
    rect(canvas, 2, height - 3, width - 3, height - 1, "sand")
    dither(canvas, 2, height - 3, width - 3, height - 1, "mud")
    canvas = outline_edge(canvas, "mud_dark", keep_bottom=True)
    return canvas


def barrel():
    """A barrel, 1x1 tiles: oak staves bulging round, lit on the left, a lid, and two iron
    hoops with a glint."""
    canvas = blank(T, T)
    xs, ys = forms.grid(T, T)
    body = (abs(xs - 15.5) <= 11 - ((ys - 18) / 14) ** 2 * 3) & (ys > 6) & (ys < T)
    forms.shade(canvas, body, OAK, radius=7)
    for x in (9, 14, 19, 23):
        for y in range(8, T):
            if body[y, x]:
                canvas[y][x] = "soil" if canvas[y][x] != "soil" else "soil_dark"
    lid = forms.ellipse(T, T, 15.5, 7, 10, 4)
    forms.paint(canvas, lid, "soil")
    forms.paint(canvas, forms.shrunk(lid), "soil_mid")
    rect(canvas, 9, 5, 18, 5, "soil_light")
    rect(canvas, 8, 7, 22, 7, "soil")
    for y in (13, 25):
        for x in range(T):
            if body[y, x]:
                canvas[y][x] = "stone_dark"
                if body[y - 1, x]:
                    canvas[y - 1][x] = "stone" if x > 9 else "stone_light"
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 16, 22, 31, 31)
    return canvas


def sacks():
    """Two sacks of grain, 1x1 tiles, tied at the neck with cord, one of linen and one of
    coarse sacking, a few grains spilled."""
    canvas = blank(T, T)
    for cx, top, ramp, seed in ((10, 7, ("sand", "sand_light", "cream"), 191), (21, 13, ("mud", "sand", "straw"), 192)):
        width_half = 8 if cx == 10 else 7
        body = forms.ellipse(T, T, cx, (top + T) / 2 + 2, width_half, (T - top) / 2 - 1) & (forms.grid(T, T)[1] < T)
        body |= forms.box(T, T, cx - width_half + 1, (top + T) // 2 + 2, cx + width_half - 2, T - 1)
        forms.shade(canvas, body, ramp, radius=4)
        neck = forms.ellipse(T, T, cx - 0.5, top + 1, 2.5, 2.5)
        forms.shade(canvas, neck, ramp, radius=1)
        rect(canvas, cx - 3, top + 3, cx + 1, top + 3, "soil")
        rect(canvas, cx - 3, top + 4, cx + 1, top + 4, "soil_dark")
        rng = random.Random(seed)
        for _ in range(6):
            x, y = rng.randrange(cx - width_half + 2, cx + width_half - 2), rng.randrange(top + 8, T - 2)
            if body[y, x]:
                canvas[y][x] = ramp[0]
    for x, y in ((3, 30), (5, 31), (28, 31)):
        canvas[y][x] = "gold"
    canvas = outline_edge(canvas, "mud_dark", keep_bottom=True, ignoring=("gold",))
    floor_shadow(canvas, 8, 25, 31, 31)
    return canvas


def crate():
    """A wooden crate, 1x1 tiles: boards seen from a little above, braced with a cross, nailed
    at the corners."""
    canvas = blank(T, T)
    rect(canvas, 0, 6, 27, 9, "soil_light")
    rect(canvas, 0, 6, 27, 6, "sand_light")
    rect(canvas, 0, 10, 27, 31, "soil_mid")
    for y in (16, 23):
        rect(canvas, 0, y, 27, y, "soil")
    grain(canvas, 2, 11, 25, 30, "soil", 193, count=6)
    for i in range(18):
        for x0, x1 in ((3 + i, 4 + i), (24 - i, 23 - i)):
            canvas[11 + i][min(x0, x1)] = "soil_light"
            canvas[11 + i][max(x0, x1)] = "soil"
    rect(canvas, 0, 10, 2, 31, "soil_light")
    rect(canvas, 25, 10, 27, 31, "soil")
    rect(canvas, 0, 10, 27, 11, "soil_mid")
    rect(canvas, 0, 29, 27, 31, "soil")
    for x, y in ((1, 12), (26, 12), (1, 29), (26, 29)):
        canvas[y][x] = "stone_dark"
    canvas = [row[:28] + [None] * 4 for row in canvas]
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 24, 6, 31, 31)
    floor_shadow(canvas, 28, 8, 31, 31)
    return canvas


def plate(canvas, cx, cy, kind):
    """A plate 10 px across standing on its edge, its middle at (cx, cy): a blue-and-white Delft
    plate with a flower, or a pewter one with a glint."""
    width, height = len(canvas[0]), len(canvas)
    face = forms.ellipse(width, height, cx, cy, 5, 5.5)
    if kind == "delft":
        forms.paint(canvas, face, "lime")
        forms.paint(canvas, forms.edge(face), "water")
        rect(canvas, int(cx) - 1, int(cy) - 1, int(cx), int(cy), "water_deep")
        for dx, dy in ((-2, -2), (1, -2), (-2, 1), (1, 1)):
            canvas[int(cy) + dy][int(cx) + dx] = "water"
        rect(canvas, int(cx) + 3, int(cy) - 2, int(cx) + 3, int(cy) + 2, "snow_shadow")
    else:
        forms.shade(canvas, face, ("stone_dark", "stone", "stone_light"), radius=3)
        forms.paint(canvas, forms.edge(face), "stone_dark")
        canvas[int(cy) - 3][int(cx) - 2] = "snow_light"


def plate_rack():
    """A plate rack 1x2 tiles, hung on the back wall: an oak back with a carved crest and two
    shelves, each with a rail in front, holding a Delft plate and a pewter one."""
    canvas = blank(T, 2 * T)
    rect(canvas, 2, 8, 29, 52, "soil")
    for x in range(4, 28, 4):
        rect(canvas, x, 12, x, 50, "soil_dark")
    # The crest.
    for y in range(4, 9):
        half = 7 + (y - 4) * 2
        rect(canvas, 16 - half, y, 15 + half, y, "soil_mid")
    rect(canvas, 9, 4, 22, 4, "soil_light")
    canvas[6][15] = canvas[6][16] = "soil_dark"
    for top, plates in ((12, ("delft", "pewter")), (32, ("pewter", "delft"))):
        for cx, kind in zip((10, 21), plates):
            plate(canvas, cx, top + 6, kind)
        # The shelf the plates stand on and the rail that holds them.
        rect(canvas, 2, top + 12, 29, top + 14, "soil_mid")
        rect(canvas, 2, top + 12, 29, top + 12, "soil_light")
        rect(canvas, 2, top + 14, 29, top + 14, "soil")
        rect(canvas, 3, top + 8, 28, top + 9, "soil_mid")
        rect(canvas, 3, top + 8, 28, top + 8, "soil_light")
    for x0, x1 in ((2, 3), (28, 29)):
        rect(canvas, x0, 8, x1, 52, "soil_mid")
    rect(canvas, 2, 8, 2, 52, "soil_light")
    canvas = outline_edge(canvas, "soil_dark")
    dither(canvas, 4, 53, 30, 55, "sand")
    return canvas


def chest_picture():
    """The chest indoors is the chest of the object atlas (chest.py), still drawn at 16 px per
    tile (task 111), scaled up to the game's tile."""
    picture = chest.chest()
    factor = GAME_TILE // TILE
    return [[colour for colour in row for _ in range(factor)] for row in picture for _ in range(factor)]


def marker_tile(picture, footprint):
    """The top left tile of the footprint of a sprite that is centred on it."""
    width, height = len(picture[0]), len(picture)
    left = (width - footprint[0] * T) // 2
    top = height - footprint[1] * T
    tile = blank(T)
    for y in range(T):
        for x in range(T):
            if 0 <= top + y < height and 0 <= left + x < width:
                tile[y][x] = picture[top + y][left + x]
    return tile


def furniture():
    """The furniture by name: its picture and its footprint in tiles. The marker tiles of
    assets/interior.png and the files follow this order, and the tile ids of the tileset
    (maps/interiors/*.tsx) are counted in it, so new pieces go at the end."""
    return {
        "bed": (bed(), (1, 2)),
        "table": (table(), (2, 1)),
        "stool": (stool(), (1, 1)),
        "chest": (chest_picture(), (1, 1)),
        "hearth": (hearth(), (2, 2)),
        "window": (window_picture(), (1, 2)),
        "sleeping_mat": (sleeping_mat(), (1, 2)),
        "box_bed": (box_bed(), (2, 2)),
        "bench": (bench(), (2, 1)),
        "stall_partition": (stall_partition(), (1, 2)),
        "hay_pile": (hay_pile(), (2, 1)),
        "barrel": (barrel(), (1, 1)),
        "sacks": (sacks(), (1, 1)),
        "crate": (crate(), (1, 1)),
        "plate_rack": (plate_rack(), (1, 2)),
        "wall_bench": (wall_bench(), (2, 1)),
    }


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


def atlas_tiles(furniture):
    """The tiles of assets/interior.png: the ground tiles, then a marker tile per piece of
    `furniture`."""
    ground = {
        "floor": brick_floor(),
        "floor_shaded": shaded_floor(brick_floor()),
        "clay_floor": clay_floor(),
        "clay_floor_shaded": shaded_floor(clay_floor()),
        "rim_left": rim_left(),
        "rim_right": mirrored_tile(rim_left()),
        "rim_front": rim_front(),
        "front_left": clear_columns(rim_front(), 0, RIM - 1),
        "front_right": clear_columns(rim_front(), RIM, T - 1),
        "doormat": interior_doormat(),
        "back_top": back_wall_top(),
        "back_bottom": back_wall_bottom(),
        "back_left_top": back_wall_end(back_wall_top(), True),
        "back_left_bottom": back_wall_end(back_wall_bottom(), True),
        "back_right_top": back_wall_end(back_wall_top(), False),
        "back_right_bottom": back_wall_end(back_wall_bottom(), False),
    }
    return list(ground.values()) + [marker_tile(*furniture[name]) for name in furniture]
