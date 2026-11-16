"""The farmhouses: Kate (the cottage, with its brick and Geest walls as kate_brick and kate_geest),
the longhouse and the barn (assets/buildings/<id>.png and <id>_lit.png): hipped reed thatch with
eyebrow dormers, chimneys and crossed ridges, on lime-washed or brick walls.

The thatch, walls, windows, doors and the other drawing the houses share are in buildings.py.
"""

import math
import random

from buildings import BUFF_BRICKS, GREEN, KATE_BRICKS, OAK, RED_BRICKS, TEAL, THATCH, brick_wall, door, eaves_shadow, fieldstone_base, glass, ground_shadow, lime_wall, thatch_roof, turf_ridge, window
from canvas import GAME_TILE, blank, outline_edge, rect


def crossed_ridge(picture, snowy, left, right, y):
    """A ridge capped with straw and held down by crossed split-oak sticks every 12 px: the
    crossings lie on the cap and the tips stand out above it, so the row of X's shows against
    the sky; a stick is lit where it lies on the cap."""
    rect(picture, left, y, right, y + 4, "umber")
    rect(picture, left, y, right, y, "ochre_dark")
    rect(picture, left, y + 5, right, y + 6, "soil_dark")
    for x in range(left, right + 1):
        snowy.update(((x, y), (x, y + 1), (x, y + 2)))
    for x in range(left + 2, right - 9, 12):
        for step in range(10):
            on_cap = step >= 5
            for dx in (0, 1):
                picture[y - 5 + step][x + step + dx] = "soil_light" if on_cap else "soil_mid"
                picture[y - 5 + step][x + 9 - step + dx] = "soil_mid" if on_cap else "soil"
        rect(picture, x + 4, y - 1, x + 5, y - 1, "soil_dark")


def chimney(picture, snowy, left, top, bottom, colours, bricks=None):
    """A square chimney 12 px wide from `top` down into the roof at `bottom`, lit on the left,
    with a cap of two courses and soot at the top: lime-washed in `colours` (light, middle,
    dark), or of `bricks` in courses."""
    light, middle, dark = colours
    rect(picture, left, top, left + 11, bottom, middle)
    if bricks:
        brick_wall(picture, random.Random(left), left, left + 11, top, bottom, bricks, "sand")
    rect(picture, left, top, left + 1, bottom, light)
    rect(picture, left + 10, top, left + 11, bottom, dark)
    rect(picture, left - 2, top, left + 13, top + 3, light)
    rect(picture, left - 2, top + 2, left + 13, top + 3, dark)
    rect(picture, left + 1, top - 2, left + 10, top - 1, "stone_dark")
    rect(picture, left + 3, top - 2, left + 8, top - 2, "ink")
    for x in range(left - 2, left + 14):
        snowy.add((x, top))


def eyebrow(picture, snowy, cx, bottom, width, is_lit):
    """An eyebrow dormer: the thatch swells up in a smooth wave over a half-round window in the
    roof. The swell is lit along its crest and shades the top of the window."""
    half = width // 2
    arch = half * 2 // 3
    crest_rows = (THATCH[1], THATCH[0], THATCH[0], THATCH[1], THATCH[1], THATCH[2], THATCH[3], THATCH[3])
    for x in range(cx - half - 12, cx + half + 12):
        offset = min(1.0, abs(x + 0.5 - cx) / (half + 12))
        crest = bottom - arch - 4 - round(8 * math.cos(offset * math.pi / 2) ** 2)
        for row, colour in enumerate(crest_rows):
            y = crest + row
            if (x, y) in snowy and y < bottom:
                picture[y][x] = colour if x < cx + half else THATCH[min(4, THATCH.index(colour) + 1)]
    # The window: flat at the bottom, arched on top, in a white frame with glazing bars round
    # small panes.
    for y in range(bottom - arch - 1, bottom + 1):
        for x in range(cx - half, cx + half):
            distance = math.hypot(x + 0.5 - cx, (bottom - y) * half / (arch + 1))
            if distance > half:
                continue
            snowy.discard((x, y))
            if distance > half - 2 or y >= bottom - 1 or (x - cx) % 5 == 2 or (bottom - y) % 5 == 4:
                picture[y][x] = "snow_light"
            else:
                picture[y][x] = glass((x - cx + half) / width, (y - bottom + arch) / arch, is_lit)
            # The shade the swell casts over the top of the frame.
            if half - 3 < distance <= half - 2 and y < bottom - arch // 2:
                picture[y][x] = "stone"
    rect(picture, cx - half - 1, bottom + 1, cx + half, bottom + 2, THATCH[4])


def tarred_foot(picture, rng, left, right, top, bottom):
    """The foot of a wall tarred black against the splash, as on the Geest instead of
    fieldstones: a lit lip along its top, and runs of the tar's blue-grey sheen and of thinner,
    browner tar across it."""
    rect(picture, left, top, right, bottom, "ink")
    rect(picture, left, top, right, top, "stone_dark")
    rect(picture, left, top + 1, right, top + 1, "mud_dark")
    for y in range(top + 3, bottom + 1, 2):
        x = left + rng.randrange(8)
        while x <= right:
            run = rng.randint(4, 12)
            colour = "stone_dark" if rng.random() < 0.5 else "soil_dark"
            rect(picture, x, y, min(right, x + run - 1), y, colour)
            x += run + rng.randint(8, 20)


def kate(is_lit, walls="fieldstone"):
    """A small cottage on 5x3 tiles, a big eyebrow dormer in the middle of the roof, the thatch
    swelling up over the door. `walls` gives its look: "fieldstone", white lime walls on
    fieldstones, a teal split door and braced teal shutters, a small white chimney and crossed
    sticks on the ridge; "brick", red brick in sand joints on the fieldstones with white frames,
    green door and shutters and a brick chimney; "geest", the lime wash over a black tarred foot
    under a turf ridge."""
    rng = random.Random(381)
    width, height = 5 * GAME_TILE, 192
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 6, width - 7, 102, height - 14
    if walls == "brick":
        bottom = base_top - 1
        brick_wall(picture, rng, wall_left, wall_right, wall_top, bottom, KATE_BRICKS, "sand")
    else:
        lime_wall(picture, rng, wall_left, wall_right, wall_top, base_top - 1)
    if walls == "geest":
        tarred_foot(picture, rng, wall_left, wall_right, base_top, height - 3)
    else:
        fieldstone_base(picture, rng, wall_left, wall_right, base_top, height - 3)
    paint = GREEN if walls == "brick" else TEAL
    for left in (25, 116):
        window(picture, left, 140, 3, 3, is_lit, shutters=paint)
    door(picture, 67, 126, height - 6, 26, paint)
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 22, 122, 44, swells=((80, 26, 12),))
    if walls == "geest":
        turf_ridge(picture, snowy, 44, width - 45, 22)
    else:
        crossed_ridge(picture, snowy, 44, width - 45, 22)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    eyebrow(picture, snowy, 80, 86, 32, is_lit)
    if walls == "brick":
        brick_chimney = ("red_light", "rust", "rust_dark")
        chimney(picture, snowy, 104, 6, 30, brick_chimney, bricks=KATE_BRICKS)
    else:
        chimney(picture, snowy, 104, 6, 30, ("snow_light", "lime", "sand_light"))
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


def climbing_rose(picture, rng, x, top, bottom):
    """A climbing rose up the wall: a column of dark leaves, lit in places, with red flowers."""
    for y in range(top, bottom + 1):
        reach = 2 if y < top + 6 else 4
        wobble = round(math.sin(y / 5))
        for dx in range(-reach + wobble + (y % 2), reach + wobble + 1):
            picture[y][x + dx] = "green" if (dx + y) % 4 == 0 else "green_dark" if (dx * 3 + y) % 5 else "green_deep"
    for _ in range((bottom - top) // 4):
        fx, fy = x + rng.randint(-3, 2), rng.randint(top + 2, bottom - 2)
        rect(picture, fx, fy, fx + 1, fy, "red_light")
        rect(picture, fx, fy + 1, fx + 1, fy + 1, "ember")


def longhouse(is_lit):
    """A long, low North German farmhouse on 7x3 tiles (a Geesthardenhaus, entered on the eaves
    side): buff brick on a fieldstone base, a huge thatch with crossed sticks on its ridge, two
    brick chimneys and two eyebrow dormers. The big arched door of green planks is in the middle
    of the long side, the thatch sweeping up over it; white windows in dark green frames to
    either side, roses climbing the wall."""
    rng = random.Random(382)
    width, height = 7 * GAME_TILE, 192
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 6, width - 7, 104, height - 14
    brick_wall(picture, rng, wall_left, wall_right, wall_top, base_top - 1, BUFF_BRICKS, "sand")
    rect(picture, wall_right - 2, wall_top, wall_right, base_top - 1, "sand")
    fieldstone_base(picture, rng, wall_left, wall_right, base_top, height - 3)
    for left in (14, 50, 155, 191):
        window(picture, left, 142, 3, 3, is_lit, frame="green_dark")
    climbing_rose(picture, rng, 80, 134, base_top - 1)
    climbing_rose(picture, rng, 144, 138, base_top - 1)
    door(picture, 90, 120, height - 6, 44, GREEN, arched=True, split=False)
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 26, 130, 60, swells=((112, 44, 22),), moss=9)
    crossed_ridge(picture, snowy, 60, width - 61, 26)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    for cx in (52, 172):
        eyebrow(picture, snowy, cx, 90, 28, is_lit)
    for left in (72, 140):
        chimney(picture, snowy, left, 8, 34, ("red_light", "rust", "rust_dark"), RED_BRICKS)
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


def half_timbering(picture, left, right, top, bottom, posts, braces):
    """Dark oak beams 4 px thick, lit on their top or left edge: a sill and a head beam, upright
    posts at `posts`, and a diagonal brace in each panel of `braces` (left edge, width, and +1
    to rise to the right or -1 to the left)."""
    for y0 in (top, bottom - 3):
        rect(picture, left, y0, right, y0 + 3, OAK[1])
        rect(picture, left, y0, right, y0, OAK[0])
        rect(picture, left, y0 + 3, right, y0 + 3, OAK[2])
    for x in posts:
        rect(picture, x, top, x + 3, bottom, OAK[1])
        rect(picture, x, top + 1, x, bottom - 4, OAK[0])
        rect(picture, x + 3, top + 4, x + 3, bottom - 4, OAK[2])
    for x, panel_width, direction in braces:
        rise = bottom - top - 7
        for step in range(rise):
            offset = step * panel_width // rise
            bx = x + offset if direction > 0 else x + panel_width - 3 - offset
            y = bottom - 4 - step
            picture[y][bx] = OAK[0]
            picture[y][bx + 1] = OAK[1]
            picture[y][bx + 2] = OAK[1]
            picture[y][bx + 3] = OAK[2]


def barn(is_lit):
    """A barn on 6x3 tiles: half-timbered with red brick in dark oak beams, big plank double
    doors with braces on the third tile, a thatch roof with a turf ridge, no windows. `is_lit`
    changes nothing: a barn has no windows to light."""
    rng = random.Random(383)
    width, height = 6 * GAME_TILE, 192
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 6, width - 7, 104, height - 14
    brick_wall(picture, rng, wall_left, wall_right, wall_top, base_top - 1, RED_BRICKS, "sand")
    half_timbering(
        picture, wall_left, wall_right, wall_top, base_top - 1,
        (wall_left, 42, 116, 150, wall_right - 3), ((10, 32, -1), (120, 30, 1), (154, 30, 1)),
    )
    fieldstone_base(picture, rng, wall_left, wall_right, base_top, height - 3)
    # The doors: two leaves of planks with a Z of braces each and iron hinges, in an oak frame.
    door_left, door_right, door_top = 52, 107, 120
    rect(picture, door_left - 4, door_top - 4, door_right + 4, height - 5, OAK[2])
    rect(picture, door_left - 4, door_top - 4, door_left - 3, height - 5, OAK[0])
    leaf_width = (door_right - door_left + 1) // 2
    for leaf_left in (door_left, door_left + leaf_width):
        leaf_right = leaf_left + leaf_width - 1
        for x in range(leaf_left, leaf_right + 1):
            plank = (x - leaf_left) % 7
            colour = "soil_dark" if plank == 6 else "soil_light" if plank == 0 else "soil_mid"
            rect(picture, x, door_top, x, height - 7, colour)
        bars = (door_top + 4, height - 14)
        for y in bars:
            rect(picture, leaf_left, y, leaf_right, y + 2, "soil_mid")
            rect(picture, leaf_left, y, leaf_right, y, "soil_light")
            rect(picture, leaf_left, y + 3, leaf_right, y + 3, "soil")
            hinge = (leaf_left, leaf_left + 7) if leaf_left == door_left else (leaf_right - 7, leaf_right)
            rect(picture, hinge[0], y + 1, hinge[1], y + 1, "stone_dark")
        span = bars[1] - bars[0] - 4
        for step in range(span):
            bx = leaf_left + 1 + step * (leaf_width - 5) // span
            y = bars[1] - 1 - step
            rect(picture, bx, y, bx + 2, y, "soil_mid")
            picture[y][bx] = "soil_light"
            picture[y][bx + 3] = "soil"
    rect(picture, door_left + leaf_width - 1, door_top, door_left + leaf_width, height - 7, "soil_dark")
    rect(picture, door_left - 4, height - 6, door_right + 4, height - 5, "stone_light")
    rect(picture, door_left - 4, height - 4, door_right + 4, height - 3, "stone")
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 26, 128, 52, swells=((80, 40, 20),))
    turf_ridge(picture, snowy, 52, width - 53, 26)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


# How to draw each farmhouse (is_lit to the picture and the pixels snow covers), by its id in
# data/buildings.cfg; a style's as <building>_<style>.
PICTURES = {
    "kate": kate,
    "kate_brick": lambda is_lit: kate(is_lit, walls="brick"),
    "kate_geest": lambda is_lit: kate(is_lit, walls="geest"),
    "longhouse": longhouse,
    "barn": barn,
}
