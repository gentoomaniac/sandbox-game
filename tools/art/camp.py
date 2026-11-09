"""The camp site objects of assets/objects.png, drawn at 32 px per tile: the fireplace and the
bedroll (the sleeping_bag object). Light from the top left; each is rimmed in the darkest shade of
its own colours and lies on a ground shadow."""

import math
import random

import fire
import forms
from canvas import GAME_OBJECT_BOTTOM, GAME_OBJECT_CELL_HEIGHT, GAME_OBJECT_CELL_WIDTH, GAME_OBJECT_CENTRE, blank, outline, rect
from palette import darkest_of
from trees import ground_shadow

WIDTH, HEIGHT = GAME_OBJECT_CELL_WIDTH, GAME_OBJECT_CELL_HEIGHT
CENTRE, BOTTOM = GAME_OBJECT_CENTRE, GAME_OBJECT_BOTTOM

# Field stones round the fire, lit to dark, and split oak logs: bark and the pale cut ends.
STONES = ("stone_dark", "stone", "stone_light")
BARK = ("soil_dark", "soil", "soil_mid")
CUT_END = ("soil_mid", "sand", "sand_light")

# The box of the fireplace's cell that its flame burns in (x, y, width, height; the flame stands
# on its bottom row), and the flame's half width and height. The same box as the 16 px art's,
# doubled, so AmbientMotion.FIRE_PROFILES fits both art sets.
FIREPLACE_FLAME = ((CENTRE - 16, 102, 32, 40), 11, 30)
# The middle of the fire on the ground, and the ring of stones round it (half width, half depth).
_FIRE_GROUND = 142
_RING = (21, 8)


def _fire_stone(canvas, rng, x, y):
    """A field stone of the ring, a rounded lump lit on its upper left."""
    half_width, half_height = rng.uniform(3.2, 4.2), rng.uniform(2.6, 3.2)
    stone = forms.ellipse(WIDTH, HEIGHT, x, y, half_width, half_height)
    forms.shade(canvas, stone, STONES, radius=2)
    for py, px in zip(*forms.edge(stone).nonzero()):
        if py >= y or px >= x + half_width - 1.5:
            canvas[py][px] = "ink" if py > y + half_height - 1.2 else "stone_dark"


def _log(canvas, start, end):
    """A split log lying from `start` to `end` (its cut end), barked, lit on top, with its pale
    cut face at the end with rings and a dark rim."""
    log = forms.capsule(WIDTH, HEIGHT, start, end, 2.6)
    forms.shade(canvas, log, BARK, radius=2)
    (x0, y0), (x1, y1) = start, end
    length = math.hypot(x1 - x0, y1 - y0)
    for step in range(3, int(length) - 2, 4):
        x, y = round(x0 + (x1 - x0) * step / length), round(y0 + (y1 - y0) * step / length)
        canvas[y][x] = "soil_dark"
    cut = forms.ellipse(WIDTH, HEIGHT, x1, y1, 2.2, 2.2)
    forms.shade(canvas, cut, CUT_END, radius=1)
    canvas[round(y1)][round(x1)] = "soil_mid"
    for py, px in zip(*forms.edge(cut).nonzero()):
        canvas[py][px] = "soil"


def fireplace_layers():
    """The fireplace without its flame: what is behind the flame (the far half of the ring of
    stones, the bed of ash and embers and three logs on it, laid like the spokes of a wheel with
    their charred ends in the middle) and what is in front of it (the near half of the ring)."""
    behind, front = blank(WIDTH, HEIGHT), blank(WIDTH, HEIGHT)
    rng = random.Random(71)
    centre, ground = CENTRE, _FIRE_GROUND
    ground_shadow(behind, 26, rows=8)
    stones = []
    for step in range(16):
        angle = step / 16 * 2 * math.pi
        stones.append((centre + _RING[0] * math.cos(angle), ground + 5 + _RING[1] * math.sin(angle)))
    for x, y in sorted(stones, key=lambda stone: stone[1]):
        if y < ground + 5:
            _fire_stone(behind, rng, x, y)
    # The bed of ash, grey with soot at its rim, and the embers glowing in it.
    ash = forms.ellipse(WIDTH, HEIGHT, centre, ground + 1, 18, 7)
    forms.paint(behind, ash, "stone_dark")
    forms.paint(behind, forms.shrunk(forms.shrunk(ash)), "stone")
    for _ in range(26):
        x, y = rng.randint(centre - 14, centre + 14), rng.randint(ground - 3, ground + 5)
        if ash[y, x]:
            behind[y][x] = rng.choice(("stone_light", "stone_dark", "ember", "stone_light"))
    for (x0, y0), (x1, y1) in (((centre - 2, ground - 1), (centre - 15, ground - 6)), ((centre + 2, ground - 1), (centre + 15, ground - 6)), ((centre, ground + 1), (centre + 1, ground + 9))):
        _log(behind, (x0, y0), (x1, y1))
        # The charred end in the fire.
        for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 0)):
            behind[y0 + dy][x0 + dx] = "ink" if (dx + dy) % 2 else "ember"
    for x, y in sorted(stones, key=lambda stone: stone[1]):
        if y >= ground + 5:
            _fire_stone(front, rng, x, y)
    return behind, front


def fireplace():
    """The fireplace with the first frame of its flame, for where the fire does not move."""
    return fire.burning(*fireplace_layers(), *FIREPLACE_FLAME)


def ghost(picture, width, height):
    """The picture of an object as the ghost of placing it shows it: without its shadow, in a
    picture of `width` x `height` px, its drawing in the middle and its bottom rows on the
    bottom, so that the bottom edge is the footprint's, like the other pictures of
    assets/interior/. The sizes are the same in both looks (see test_art_set.gd)."""
    picture = [[None if colour == "shadow" else colour for colour in row] for row in picture]
    rows = [y for y, row in enumerate(picture) if any(row)]
    columns = [x for x in range(len(picture[0])) if any(row[x] for row in picture)]
    drawn = [row[columns[0] : columns[-1] + 1] for row in picture[rows[0] :]]
    left = (width - len(drawn[0])) // 2
    result = [[None] * width for _ in range(height)]
    for y, row in enumerate(drawn):
        for x, colour in enumerate(row):
            result[height - len(drawn) + y][left + x] = colour
    return result


# The bedroll: 28x56 px on its 1x2 tiles (the cell's bottom edge is the footprint's), as long as a
# person lying on it, so its foot hides their clogs (see BEDROLL_COVER_FROM_ROW).
_BEDROLL_LEFT, _BEDROLL_TOP, _BEDROLL_BOTTOM = CENTRE - 14, 102, 156
_BEDROLL_RIGHT = _BEDROLL_LEFT + 27
# The linen ticking of the straw sack, lit to dark, its stripes, and the grey wool blanket.
TICKING = ("mud", "sand", "sand_light")
WOOL = ("stone_dark", "stone", "stone_light")


def bedroll():
    """The bedroll lying on 1x2 tiles: a sack of linen ticking with faint stripes, stuffed with
    straw so it bulges between the rows it is quilted in, straw poking out at its seams, and a
    grey wool blanket rolled up and tied at its head end. The object's id stays sleeping_bag."""
    canvas = blank(WIDTH, HEIGHT)
    left, top, bottom, right = _BEDROLL_LEFT, _BEDROLL_TOP, _BEDROLL_BOTTOM, _BEDROLL_RIGHT
    # The straw sack: a long cushion, its quilted rows each a bulge lit on its top.
    sack = forms.rounded_box(WIDTH, HEIGHT, left, top + 6, right, bottom)
    level = forms.light_level(sack, 5)
    rows = range(top + 15, bottom - 2, 8)
    for row in rows:
        level[row] -= 0.45
        level[row + 1 : row + 3] += 0.3
    forms.shade_by_level(canvas, sack, TICKING, level)
    # Faint stripes woven into the ticking, and the quilting's ties.
    for x in range(left + 4, right - 2, 6):
        for y in range(top + 8, bottom - 1):
            if sack[y, x] and canvas[y][x] == "sand_light":
                canvas[y][x] = "stone_light"
    for row in rows:
        for x in (left + 7, left + 14, left + 21):
            canvas[row][x] = "mud_dark"
    # The rolled blanket across the head end: a roll lit on top, its ends showing the spiral.
    roll = forms.rounded_box(WIDTH, HEIGHT, left - 2, top, right + 2, top + 15)
    forms.shade(canvas, roll, WOOL, radius=5)
    for x in (left - 1, right + 1):
        end = forms.ellipse(WIDTH, HEIGHT, x + 0.5, top + 8, 2.5, 6.5)
        forms.paint(canvas, end, "stone")
        forms.paint(canvas, forms.ellipse(WIDTH, HEIGHT, x + 0.5, top + 8, 1.2, 3.6), "stone_dark")
        canvas[top + 8][x] = "stone_light"
    # Two cords round the roll.
    for x in (left + 6, right - 6):
        rect(canvas, x, top, x + 1, top + 15, "soil")
        rect(canvas, x, top + 1, x, top + 6, "soil_light")
    canvas = outline(canvas, darkest_of)
    # Straw sticking out of the seams.
    rng = random.Random(53)
    for _ in range(9):
        side = rng.choice((left - 1, right + 1))
        y = rng.randint(top + 16, bottom - 6)
        direction = -1 if side < CENTRE else 1
        for step in range(rng.randint(2, 4)):
            canvas[y - step // 2][side + direction * step] = rng.choice(("straw", "gold", "straw"))
    for x in range(left + 5, right - 4, 4):
        canvas[bottom + 1][x] = "straw"
        canvas[bottom + 1][x + 1] = "gold"
    # Its shadow on the ground, to the lower right.
    for y in range(top + 12, bottom + 3):
        for x in range(left + 3, right + 4):
            if canvas[y][x] is None:
                canvas[y][x] = "shadow"
    return canvas


# The rows of the bedroll cell from which the bedroll covers a player lying in it: below the
# rolled blanket at the head end, so only the head shows.
BEDROLL_COVER_FROM_ROW = 124


def bedroll_cover():
    """The part of the bedroll drawn over the player lying on it (assets/bedroll_cover.png): the
    cell of `bedroll` with everything above BEDROLL_COVER_FROM_ROW cleared, and its ground
    shadow, which the atlas draws on its own."""
    canvas = bedroll()
    for y in range(BEDROLL_COVER_FROM_ROW):
        canvas[y] = [None] * WIDTH
    return [[None if colour == "shadow" else colour for colour in row] for row in canvas]
