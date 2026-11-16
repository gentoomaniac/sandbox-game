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

import random

import chest
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
    """The pieces of furniture that are not of a family of their own: by name, their picture and
    their footprint in tiles."""
    return {
        "chest": (chest.chest(), (1, 1)),
        "window": (window_picture(), (1, 2)),
        "stall_partition": (stall_partition(), (1, 2)),
        "hay_pile": (hay_pile(), (2, 1)),
        "barrel": (barrel(), (1, 1)),
        "sacks": (sacks(), (1, 1)),
        "crate": (crate(), (1, 1)),
    }


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
