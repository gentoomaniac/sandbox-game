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

This module has the room (floors, walls, the window) and what all the furniture shares; the
furniture itself is in beds.py, byre_and_store.py, kitchen.py and tables_and_seats.py, and
furnishings.py collects it.
"""

import random

import forms
from canvas import GAME_TILE, blank, copy, outline_edge, rect
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


def pieces():
    """The furniture that belongs to the room: by name, its picture and its footprint in tiles."""
    return {"window": (window_picture(), (1, 2))}


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
