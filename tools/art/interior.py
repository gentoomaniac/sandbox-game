"""The interior (assets/interior.png and assets/interior/*.png), used by maps/interiors/*.tsx
and game/scenes/interior_view.gd. The room is seen in 3/4 view: the back wall as a face 2
tiles high, the side and front walls only as their 8 px thick tops.

assets/interior.png is one row of 16x16 tiles, in the order of `atlas_tiles`, then
one marker tile per piece of furniture (the top left tile of its footprint, so Tiled shows
what is where). The game draws the furniture from assets/interior/<name>.png instead:
sprites of any size, centred on their footprint with their bottom edge on its bottom edge.
"""

import math
import random

import chest
import fire
from canvas import NEIGHBOURS, TILE, blank, copy, filled, rect

RIM = 8


def outline(canvas, colour, keep_bottom=False):
    """Gives the picture's border (pixels next to clear ones or the image edge) `colour`.
    keep_bottom leaves the bottom edge alone: the picture stands on the ground there."""
    height, width = len(canvas), len(canvas[0])
    border = []
    for y in range(height):
        for x in range(width):
            if canvas[y][x] is None or (keep_bottom and y == height - 1):
                continue
            for dx, dy in NEIGHBOURS:
                nx, ny = x + dx, y + dy
                if not (0 <= nx < width and 0 <= ny < height) or canvas[ny][nx] is None:
                    border.append((x, y))
                    break
    for x, y in border:
        canvas[y][x] = colour
    return canvas


def herringbone_floor(tones, joint):
    """Floor bricks 8x4 laid in a herringbone, one of `tones` each, a `joint` on their bottom
    and right edges. The bricks step down to the right in bands; the pattern repeats every
    tile, and the tones are picked once per brick so a tile reads as a warm texture."""
    rng = random.Random(133)
    canvas = blank()
    width = 4
    for band in range(-4, 5):
        for step in range(-8, 9):
            x, y = width * (step + 2 * band), width * (step - 2 * band)
            # A brick lying across, then one standing under its left half.
            for left, top, across, down in ((x, y, 2 * width, width), (x, y + width, width, 2 * width)):
                tone = rng.choice(tones)
                for dy in range(down):
                    for dx in range(across):
                        if 0 <= left + dx < TILE and 0 <= top + dy < TILE:
                            is_joint = dx == across - 1 or dy == down - 1
                            canvas[top + dy][left + dx] = joint if is_joint else tone
    return canvas


def brick_floor():
    """The floor of the living rooms: old red brick in a herringbone, half of the bricks browner."""
    return herringbone_floor(("rust_dark", "rust_dark", "soil_mid", "soil_mid"), "soil")


def clay_floor():
    """The floor of the work rooms (the byre, the barn, the shack): beaten clay, with greyer and
    darker trodden patches and a little sand. Kept calm: whatever stands out repeats every tile."""
    rng = random.Random(134)
    canvas = filled("mud")
    for colour, count, length in (("bare", 6, 3), ("mud_dark", 3, 2), ("sand", 3, 2)):
        for _ in range(count):
            x, y = rng.randrange(TILE), rng.randrange(TILE)
            for dx in range(length):
                canvas[y][(x + dx) % TILE] = colour
    return canvas


# Each floor colour one step darker, for the row along the back wall in its shadow.
FLOOR_SHADOW = {
    "rust_dark": "russet_deep",
    "soil_mid": "soil",
    "soil": "soil_dark",
    "mud": "mud_dark",
    "mud_dark": "soil_dark",
    "sand": "mud",
    "bare": "mud_dark",
}


def shaded_floor(floor):
    """The floor row along the back wall, in its shadow."""
    canvas = [[FLOOR_SHADOW[colour] for colour in row] for row in floor]
    rect(canvas, 0, 0, TILE - 1, 1, "soil_dark")
    return canvas


def clear_columns(canvas, left, right):
    """Clears the columns left..right (both ends included)."""
    for row in canvas:
        for x in range(left, right + 1):
            row[x] = None
    return canvas


WALL_TOP_SHADES = ("soil_dark", "soil_light", "soil_mid", "soil_mid", "soil_mid", "soil_mid", "soil", "soil_dark")


def rim_left():
    """The top of the left wall: its 8 px next to the room are the right half of the tile."""
    canvas = blank()
    for x, colour in zip(range(RIM, TILE), WALL_TOP_SHADES):
        rect(canvas, x, 0, x, TILE - 1, colour)
    return canvas


def rim_front():
    """The top of the front wall: its 8 px next to the room are the top half of the tile."""
    canvas = blank()
    for y, colour in zip(range(RIM), WALL_TOP_SHADES[::-1]):
        rect(canvas, 0, y, TILE - 1, y, colour)
    return canvas


def mirrored_tile(canvas):
    return [row[::-1] for row in canvas]


def interior_doormat():
    """The exit: a woven mat 16x8 across the gap in the front wall."""
    canvas = blank()
    rect(canvas, 0, 0, TILE - 1, 7, "soil_dark")
    rect(canvas, 1, 1, TILE - 2, 6, "straw")
    for y in (2, 4):
        rect(canvas, 1, y, TILE - 2, y, "dry_light")
    rect(canvas, 1, 6, TILE - 2, 6, "reed")
    return canvas


def back_wall_top():
    """The upper tile of the back wall: a beam over plaster."""
    canvas = filled("sand_light")
    rng = random.Random(131)
    for _ in range(9):
        canvas[rng.randrange(5, TILE)][rng.randrange(TILE)] = "sand"
    rect(canvas, 0, 0, TILE - 1, 0, "soil_mid")
    rect(canvas, 0, 1, TILE - 1, 2, "soil")
    rect(canvas, 0, 2, TILE - 1, 2, "soil_dark")
    rect(canvas, 0, 3, TILE - 1, 3, "mud")
    return canvas


def back_wall_bottom():
    """The lower tile of the back wall: plaster over a wainscot of panels."""
    canvas = filled("sand_light")
    rng = random.Random(132)
    for _ in range(5):
        canvas[rng.randrange(0, 5)][rng.randrange(TILE)] = "sand"
    rect(canvas, 0, 5, TILE - 1, 5, "soil_light")
    rect(canvas, 0, 6, TILE - 1, 6, "soil")
    rect(canvas, 0, 7, TILE - 1, 13, "soil_mid")
    rect(canvas, 0, 14, TILE - 1, 15, "soil_dark")
    for x in (0, 7, 8, 15):
        rect(canvas, x, 7, x, 13, "soil")
    return canvas


def back_wall_end(tile, is_left):
    """A back wall tile at a corner: only the 8 px next to the room, ending in a post."""
    canvas = copy(tile)
    if is_left:
        clear_columns(canvas, 0, RIM - 1)
        post = (RIM, RIM + 1)
    else:
        clear_columns(canvas, RIM, TILE - 1)
        post = (RIM - 1, RIM - 2)
    for y in range(TILE):
        canvas[y][post[0]] = "soil_dark"
        canvas[y][post[1]] = "soil_mid"
    return canvas


def window_picture():
    """A 10x10 window with a sill, 16x32: drawn over the plaster of the back wall face. Nine
    small panes of daylight in wooden glazing bars."""
    canvas = blank(TILE, 2 * TILE)
    rect(canvas, 3, 7, 12, 16, "soil_dark")
    rect(canvas, 4, 8, 11, 15, "water_light")
    rect(canvas, 4, 8, 8, 9, "foam")
    rect(canvas, 4, 8, 5, 12, "foam")
    rect(canvas, 4, 14, 11, 15, "water")
    for offset in (3, 6):
        rect(canvas, 3 + offset, 8, 3 + offset, 15, "soil_mid")
        rect(canvas, 4, 7 + offset, 11, 7 + offset, "soil_mid")
    rect(canvas, 2, 17, 13, 17, "soil_light")
    rect(canvas, 2, 18, 13, 18, "soil_mid")
    rect(canvas, 3, 19, 12, 19, "mud")
    return canvas


def bed():
    """A bed 1x2 tiles, head to the north: frame, pillow and a blanket with a folded edge."""
    canvas = blank(TILE, 2 * TILE)
    rect(canvas, 0, 0, 15, 31, "soil_mid")
    rect(canvas, 0, 0, 15, 5, "soil")
    rect(canvas, 1, 1, 14, 1, "soil_light")
    rect(canvas, 2, 6, 13, 12, "cream")
    rect(canvas, 2, 12, 13, 12, "sand_light")
    rect(canvas, 2, 13, 13, 28, "ember")
    rect(canvas, 2, 13, 13, 15, "flame")
    rect(canvas, 2, 15, 13, 15, "ember")
    rect(canvas, 11, 16, 13, 28, "soil")
    rect(canvas, 5, 20, 7, 21, "soil")
    rect(canvas, 2, 29, 13, 31, "soil")
    rect(canvas, 0, 29, 15, 29, "soil_light")
    outline(canvas, "soil_dark")
    return canvas


def table():
    """A table 2x1 tiles: a plank top, an apron and two legs; a candle and a bowl on it."""
    canvas = blank(2 * TILE, 24)
    rect(canvas, 0, 0, 31, 15, "soil_light")
    for y in (4, 9, 14):
        rect(canvas, 0, y, 31, y, "soil_mid")
    rect(canvas, 0, 16, 31, 17, "soil_mid")
    rect(canvas, 0, 18, 31, 18, "soil_dark")
    for x in (2, 27):
        rect(canvas, x, 19, x + 2, 23, "soil")
        rect(canvas, x, 19, x, 23, "soil_mid")
    rect(canvas, 23, 5, 24, 9, "cream")
    rect(canvas, 23, 3, 24, 4, "gold")
    rect(canvas, 7, 6, 12, 9, "stone_light")
    rect(canvas, 8, 7, 11, 8, "stone_dark")
    return outline(canvas, "soil_dark", keep_bottom=True)


def stool():
    """A stool, 10x10 on its 16x16 tile."""
    canvas = blank(10, 10)
    rect(canvas, 0, 0, 9, 4, "soil_light")
    rect(canvas, 0, 4, 9, 4, "soil_mid")
    for x in (1, 7):
        rect(canvas, x, 5, x + 1, 9, "soil")
    rect(canvas, 4, 5, 5, 8, "soil_dark")
    return outline(canvas, "soil_dark", keep_bottom=True)


# The box of the hearth's picture that its flame burns in (x, y, width, height; the flame stands
# on its bottom row, over the logs), and the flame's half width and height.
HEARTH_FLAME = ((8, 10, 16, 16), 5.0, 12)


def hearth_without_flame():
    """A stone hearth 2x2 tiles with two logs in its firebox."""
    canvas = blank(2 * TILE, 2 * TILE)
    rect(canvas, 0, 0, 31, 29, "stone")
    for y in range(4, 30, 4):
        rect(canvas, 0, y, 31, y, "stone_dark")
        for x in range(2 + (y // 4 % 2) * 4, 32, 8):
            rect(canvas, x, y - 3, x, y - 1, "stone_dark")
    rect(canvas, 0, 0, 31, 2, "stone_light")
    rect(canvas, 0, 3, 31, 3, "stone_dark")
    rect(canvas, 7, 9, 24, 28, "stone_dark")
    rect(canvas, 8, 10, 23, 28, "soil_dark")
    rect(canvas, 9, 25, 22, 27, "soil")
    rect(canvas, 9, 25, 22, 25, "soil_mid")
    # Hearthstone in front.
    rect(canvas, 2, 29, 29, 31, "stone_light")
    rect(canvas, 2, 31, 29, 31, "stone")
    return outline(canvas, "soil_dark", keep_bottom=True)


def hearth():
    """A stone hearth 2x2 tiles with a fire in it."""
    return fire.burning(hearth_without_flame(), blank(2 * TILE, 2 * TILE), *HEARTH_FLAME)


def sleeping_mat():
    """A straw sleeping mat 1x2 tiles, head to the north, with a cream pillow."""
    canvas = blank(TILE, 2 * TILE)
    rect(canvas, 1, 1, 14, 30, "straw")
    for y in range(4, 30, 3):
        rect(canvas, 1, y, 14, y, "sand")
    rect(canvas, 1, 1, 1, 30, "sand_light")
    rect(canvas, 3, 2, 12, 8, "cream")
    rect(canvas, 3, 8, 12, 8, "sand_light")
    return outline(canvas, "soil_dark")


def box_bed():
    """A box bed 2x2 tiles, head to the north: a timber box with a straw mattress, a pillow
    and a red blanket, a front board in front."""
    canvas = blank(2 * TILE, 2 * TILE)
    rect(canvas, 0, 0, 31, 31, "soil_mid")
    rect(canvas, 1, 1, 30, 1, "soil_light")
    rect(canvas, 2, 5, 29, 24, "soil_dark")
    rect(canvas, 3, 6, 28, 24, "straw")
    rect(canvas, 4, 7, 14, 12, "cream")
    rect(canvas, 4, 12, 14, 12, "sand_light")
    rect(canvas, 4, 13, 28, 24, "ember")
    rect(canvas, 4, 13, 28, 15, "flame")
    rect(canvas, 4, 15, 28, 15, "ember")
    rect(canvas, 0, 25, 31, 31, "soil")
    rect(canvas, 0, 25, 31, 25, "soil_light")
    rect(canvas, 0, 28, 31, 28, "soil_mid")
    return outline(canvas, "soil_dark")


def bench():
    """A bench 2x1 tiles: a plank seat on two legs."""
    canvas = blank(2 * TILE, TILE)
    rect(canvas, 0, 3, 31, 7, "soil_light")
    rect(canvas, 0, 5, 31, 5, "soil_mid")
    rect(canvas, 0, 8, 31, 9, "soil_mid")
    rect(canvas, 0, 10, 31, 10, "soil_dark")
    for x in (2, 27):
        rect(canvas, x, 11, x + 2, 15, "soil")
        rect(canvas, x, 11, x, 15, "soil_mid")
    return outline(canvas, "soil_dark", keep_bottom=True)


def stall_partition():
    """A stall partition 1x2 tiles: a post with two rails that run on into the next stall."""
    canvas = blank(TILE, 2 * TILE)
    for top in (6, 16):
        rect(canvas, 0, top, 15, top + 3, "soil")
        rect(canvas, 0, top, 15, top, "soil_light")
        rect(canvas, 0, top + 3, 15, top + 3, "soil_dark")
    rect(canvas, 5, 0, 10, 31, "soil_mid")
    rect(canvas, 5, 0, 6, 31, "soil_light")
    rect(canvas, 5, 28, 10, 31, "soil_dark")
    return outline(canvas, "soil_dark", keep_bottom=True)


def hay_pile():
    """A pile of hay 2x1 tiles: a mound of straw with gold and darker wisps."""
    rng = random.Random(391)
    canvas = blank(2 * TILE, TILE)
    for x in range(2 * TILE):
        top = 2 + round(6 * (1 - math.sin(math.pi * (x + 0.5) / (2 * TILE))))
        for y in range(top, TILE):
            colour = rng.choice(("straw", "straw", "gold", "dry_light"))
            if y >= TILE - 3:
                colour = rng.choice(("sand", "sand_light", "sand"))
            canvas[y][x] = colour
    return outline(canvas, "soil_dark", keep_bottom=True)


def barrel():
    """A barrel, 1x1 tiles: staves, a lid and two iron hoops."""
    canvas = blank(TILE, TILE)
    rect(canvas, 2, 3, 13, 15, "soil_mid")
    rect(canvas, 3, 0, 12, 3, "soil_light")
    for x in (5, 9):
        rect(canvas, x, 4, x, 15, "soil")
    rect(canvas, 12, 4, 13, 15, "soil")
    for y in (5, 12):
        rect(canvas, 2, y, 13, y, "stone")
        rect(canvas, 2, y, 6, y, "stone_light")
    return outline(canvas, "soil_dark", keep_bottom=True)


def sacks():
    """Two sacks of grain, 1x1 tiles, tied at the neck."""
    canvas = blank(TILE, TILE)
    rect(canvas, 1, 5, 8, 15, "sand_light")
    rect(canvas, 7, 5, 8, 15, "sand")
    rect(canvas, 3, 3, 6, 4, "sand_light")
    rect(canvas, 3, 5, 6, 5, "mud")
    rect(canvas, 8, 8, 14, 15, "straw")
    rect(canvas, 13, 8, 14, 15, "sand")
    rect(canvas, 10, 6, 12, 7, "straw")
    rect(canvas, 10, 8, 12, 8, "mud")
    return outline(canvas, "soil_dark", keep_bottom=True)


def crate():
    """A wooden crate, 1x1 tiles, with a cross of boards."""
    canvas = blank(TILE, TILE)
    rect(canvas, 0, 1, 15, 15, "soil_light")
    for i in range(2, 14):
        canvas[1 + i][i] = "soil_mid"
        canvas[1 + i][15 - i] = "soil_mid"
    rect(canvas, 0, 1, 15, 2, "soil_mid")
    rect(canvas, 0, 14, 15, 15, "soil_mid")
    rect(canvas, 0, 1, 1, 15, "soil_mid")
    rect(canvas, 14, 1, 15, 15, "soil_mid")
    return outline(canvas, "soil_dark", keep_bottom=True)


def marker_tile(picture, footprint):
    """The top left tile of the footprint of a sprite that is centred on it."""
    width, height = len(picture[0]), len(picture)
    left = (width - footprint[0] * TILE) // 2
    top = height - footprint[1] * TILE
    tile = blank()
    for y in range(TILE):
        for x in range(TILE):
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
        "chest": (chest.chest(), (1, 1)),
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
        "front_right": clear_columns(rim_front(), RIM, TILE - 1),
        "doormat": interior_doormat(),
        "back_top": back_wall_top(),
        "back_bottom": back_wall_bottom(),
        "back_left_top": back_wall_end(back_wall_top(), True),
        "back_left_bottom": back_wall_end(back_wall_bottom(), True),
        "back_right_top": back_wall_end(back_wall_top(), False),
        "back_right_bottom": back_wall_end(back_wall_bottom(), False),
    }
    return list(ground.values()) + [marker_tile(*furniture[name]) for name in furniture]
