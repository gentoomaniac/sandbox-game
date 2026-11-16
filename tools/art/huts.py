"""The huts of the marsh: the shack and the fisherman's hut, small boarded buildings in tarred
boards under turf or reed thatch (assets/buildings/shack.png and fisher_hut.png, and their _lit ones).

The roofs, windows, doors and the other drawing the houses share are in buildings.py.
"""

import math
import random

from buildings import OX_BLOOD, TEAL, THATCH, eaves_shadow, fieldstone_base, ground_shadow, thatch_roof, turf_ridge, window
from canvas import GAME_TILE, blank, outline_edge, rect

# The grass of a turf roof, lit to dark, and where it has dried out.
TURF = ("green_bright", "green_light", "green", "green_dark", "green_deep")
DRY_TURF = ("dry_light", "dry", "olive", "green_dark", "green_deep")


def tarred_boards(picture, rng, left, right, top, bottom):
    """A wall of upright boards 10 px wide tarred near-black, a batten over each joint: its
    raised edge catching the light in the blue-grey sheen of the tar, with a dark line where it
    shades the board to its right. Streaks of the sheen and of darker grain run down the
    boards."""
    for x in range(left, right + 1):
        board = (x - left) % 10
        colour = ("mud_dark", "stone_dark", "soil_dark", "ink")[board] if board < 4 else "ink"
        rect(picture, x, top, x, bottom, colour)
        if board < 4:
            continue
        y = top + rng.randrange(10)
        while y <= bottom:
            run = rng.randint(5, 14)
            if board in (4, 7) and rng.random() < 0.4:
                rect(picture, x, y, x, min(bottom, y + run - 1), "stone_dark")
            elif board in (5, 8) and rng.random() < 0.3:
                rect(picture, x, y, x, min(bottom, y + run - 1), "soil_dark")
            y += run + rng.randint(5, 14)


def ledged_door(picture, left, top, bottom, width, colours):
    """A door of upright planks painted in `colours` (light, middle, dark, deep), held by two
    ledges and a brace between them, in a dark frame, with an iron latch and a stone step."""
    light, middle, dark, deep = colours
    rect(picture, left - 2, top - 2, left + width + 1, bottom, "ink")
    for x in range(left, left + width):
        plank = (x - left) % 7
        colour = dark if plank == 6 else light if plank == 0 else middle
        rect(picture, x, top, x, bottom, colour)
    rect(picture, left + width - 2, top, left + width - 1, bottom, dark)
    ledges = (top + 4, bottom - 8)
    for y in ledges:
        rect(picture, left, y, left + width - 1, y + 2, middle)
        rect(picture, left, y, left + width - 1, y, light)
        rect(picture, left, y + 3, left + width - 1, y + 3, deep)
    span = ledges[1] - ledges[0] - 4
    for step in range(span):
        bx = left + 1 + step * (width - 5) // span
        y = ledges[1] - 1 - step
        rect(picture, bx, y, bx + 2, y, middle)
        picture[y][bx] = light
        picture[y][bx + 3] = deep
    latch_y = (top + bottom) // 2
    rect(picture, left + width - 6, latch_y, left + width - 3, latch_y + 1, "stone_light")
    picture[latch_y + 1][left + width - 3] = "stone_dark"
    rect(picture, left - 4, bottom + 1, left + width + 3, bottom + 2, "stone_light")
    rect(picture, left - 4, bottom + 3, left + width + 3, bottom + 4, "stone")


def boarded_hut(picture, rng, wall_left, wall_right, wall_top, base_top, bottom):
    """The walls of a hut of tarred boards on a low fieldstone base: the corner posts, the right
    one in shade, and the sill beam they stand on."""
    tarred_boards(picture, rng, wall_left, wall_right, wall_top, base_top - 1)
    rect(picture, wall_left, wall_top, wall_left + 3, base_top - 1, "stone_dark")
    rect(picture, wall_left + 2, wall_top, wall_left + 3, base_top - 1, "soil_dark")
    rect(picture, wall_left, wall_top, wall_left, base_top - 1, "stone")
    rect(picture, wall_right - 3, wall_top, wall_right, base_top - 1, "ink")
    rect(picture, wall_left, base_top - 4, wall_right, base_top - 3, "stone_dark")
    rect(picture, wall_left, base_top - 2, wall_right, base_top - 1, "ink")
    fieldstone_base(picture, rng, wall_left, wall_right, base_top, bottom)


def shack(is_lit):
    """A small hut on 3x2 tiles, a fisherman's or herdsman's: tarred boards with battens on a
    low fieldstone base, a low ox-blood door on the middle tile and a small white window with an
    ox-blood shutter on the right, under a turf roof."""
    rng = random.Random(384)
    width, height = 3 * GAME_TILE, 128
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 4, width - 5, 54, height - 11
    boarded_hut(picture, rng, wall_left, wall_right, wall_top, base_top, height - 3)
    window(picture, 72, 70, 2, 3, is_lit)
    # The shutter, folded back to the left of the window.
    rect(picture, 62, 68, 68, 90, "rust_dark")
    rect(picture, 62, 68, 62, 90, "rust")
    rect(picture, 68, 68, 68, 90, "russet_deep")
    rect(picture, 62, 73, 68, 73, "russet_deep")
    rect(picture, 62, 84, 68, 84, "russet_deep")
    rect(picture, 61, 68, 61, 90, "ink")
    ledged_door(picture, 37, 62, height - 6, 22, OX_BLOOD)
    eaves = turf_roof(picture, snowy, rng, 0, width - 1, 12, 52)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


def fisher_hut(is_lit):
    """The fisherman's hut (Fischerkate) on 4x2 tiles, the shack's kin at the landing: low walls
    of tarred boards on fieldstones, a hipped reed thatch with a turf ridge, a low door in faded
    teal on the second tile, one small window and an oar leant against the wall between them."""
    rng = random.Random(386)
    width, height = 4 * GAME_TILE, 128
    picture = blank(width, height)
    snowy = set()
    wall_left, wall_right, wall_top, base_top = 4, width - 5, 52, height - 11
    boarded_hut(picture, rng, wall_left, wall_right, wall_top, base_top, height - 3)
    window(picture, 90, 68, 2, 3, is_lit)
    ledged_door(picture, 37, 60, height - 6, 22, TEAL)
    # The oar, its blade up under the eaves: a pale shaft lit on the left, a dark edge on the right.
    for y in range(58, 116):
        x = 70 + (115 - y) // 9
        is_blade = y < 74
        picture[y][x] = "sand" if is_blade else "soil_light"
        picture[y][x + 1] = "sand" if is_blade else "soil_mid"
        picture[y][x + 2] = "mud" if is_blade else "soil"
        if is_blade:
            picture[y][x - 1] = "sand_light"
            picture[y][x + 3] = "mud"
    eaves = thatch_roof(picture, snowy, rng, 0, width - 1, 10, 58, 32, moss=4)
    turf_ridge(picture, snowy, 32, width - 33, 10)
    eaves_shadow(picture, eaves, wall_left, wall_right)
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


def turf_roof(picture, snowy, rng, left, right, ridge_y, eaves_y):
    """A turf roof over the columns left..right, the grass growing on birch bark: a slope of
    grass in clumps, lit on top and on the left and darker towards the eaves and the right end,
    with a few patches of dry grass and a few flowers; a ragged crest of tufts on the ridge, and
    at the eaves a thick rounded lip of turf with blades hanging over the pale edge of the bark.
    Returns the lowest roof row of each column."""
    height = eaves_y - ridge_y
    # The ridge, a pixel or two higher in a few short runs, rounded off at the ends.
    crest = {}
    x = left
    while x <= right:
        lift = rng.choice((0, 0, 1, 2))
        for column in range(x, min(right, x + rng.randint(1, 4)) + 1):
            crest[column] = ridge_y + max(0, 6 - min(column - left, right - column)) - lift
        x = column + 1
    dry = [
        (rng.uniform(left + 12, right - 12), rng.uniform(ridge_y + 8, eaves_y - 12), rng.uniform(5, 8))
        for _ in range(2)
    ]
    # The gaps between the clumps, in shade; darker towards the eaves.
    for x in range(left, right + 1):
        for y in range(crest[x], eaves_y + 1):
            picture[y][x] = TURF[3] if (y - ridge_y) / height < 0.6 else TURF[4]
            snowy.add((x, y))
    # The clumps lie in rows 3 px apart, each a pixel or two up or down, so they overlap in
    # scallops rather than stripes: a rounded lit top over a body that is darker on its right,
    # one step darker on the lower slope and at the right end, with a blade or two standing up.
    for y in range(ridge_y, eaves_y - 4, 3):
        x = left + rng.randrange(-5, 1)
        while x <= right:
            clump = rng.randint(5, 10)
            top = y + rng.choice((-1, 0, 0, 1, 2))
            is_dry = any(math.hypot((x - dx) / 1.5, top - dy) < radius for dx, dy, radius in dry)
            ramp = DRY_TURF if is_dry else TURF
            step = (top - ridge_y > height * 0.55) + (x > right - 12)
            for cx in range(max(left, x), min(right, x + clump - 1) + 1):
                # The clump's rounded top: its ends a row or two lower.
                rounding = 2 if cx in (x, x + clump - 1) else 1 if cx in (x + 1, x + clump - 2) else 0
                for cy in range(max(crest[cx], top + rounding), top + 5):
                    lit = 0 if cy <= top + rounding and cx < x + clump - 2 else 1
                    if cx >= x + clump - 2 or cy >= top + 4:
                        lit = 2
                    picture[cy][cx] = ramp[min(len(ramp) - 1, lit + step)]
            blade = max(left, min(right, x + rng.randrange(1, clump)))
            if top - 2 >= crest[blade]:
                rect(picture, blade, top - 2, blade, top - 1, ramp[min(4, 1 + step)])
            # A flower on a few clumps: daisies, buttercups, a pink campion.
            flower = max(left, min(right - 1, x + 2))
            if rng.random() < 0.08 and not is_dry and top >= crest[flower]:
                rect(picture, flower, top, flower + 1, top, rng.choice(("cream", "cream", "gold", "petal")))
            x += clump - rng.choice((0, 1, 2))
    # The lip of the turf at the eaves, thicker in some runs: a dark line where it stands out
    # from the slope, then rounded and lit along its top. Under it the edge of the birch bark
    # sticks out, pale with a few black marks and shaded below, and blades of grass hang over it.
    eaves = {}
    x = left
    while x <= right:
        lip_top = eaves_y - rng.choice((4, 4, 5, 6))
        for column in range(x, min(right, x + rng.randint(5, 10)) + 1):
            shade = column > right - 8
            picture[lip_top - 1][column] = TURF[4]
            for y in range(lip_top, eaves_y + 1):
                picture[y][column] = TURF[min(4, 1 + (y - lip_top) // 2 + shade)]
            is_mark = rng.random() < 0.15
            picture[eaves_y + 1][column] = "ink" if is_mark else "stone" if shade else "stone_light"
            picture[eaves_y + 2][column] = "ink" if is_mark else "stone" if shade else "stone_light"
            picture[eaves_y + 3][column] = "stone_dark" if shade else "stone"
            snowy.update(((column, eaves_y + 1), (column, eaves_y + 2), (column, eaves_y + 3)))
            eaves[column] = eaves_y + 3
        x = column + 1
    x = left + rng.randrange(3)
    while x <= right:
        for y in range(eaves_y + 1, eaves_y + 1 + rng.choice((2, 3, 4, 5))):
            picture[y][x] = TURF[3] if y < eaves_y + 3 else TURF[4]
            eaves[x] = max(eaves[x], y)
        x += rng.choice((2, 3, 3, 4, 5))
    return eaves


# How to draw each hut (is_lit to the picture and the pixels snow covers), by its id in
# data/buildings.cfg.
PICTURES = {
    "shack": shack,
    "fisher_hut": fisher_hut,
}
