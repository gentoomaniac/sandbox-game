"""Art for the trunks that felled trees leave (see `trunk` in game/state/world_object_types.gd).

A trunk is a felled log lying horizontally, seen in 3/4 view like everything else: its cut face
with year rings on the left, the bark of its top and front lit from the top left, a broken-off
branch stub or two, and a shadow on the ground. Its cell is an object cell of the atlas (48x80,
see canvas.py): the long one (2x1 tiles) is centred on its 32 px wide footprint, the short one
(1x1) on 16 px. The ground row is the cell's bottom row. Pictures are lists of rows of palette
colour names.
"""

import math
import random

from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank

# The log's rows, its outline included, ending a row above the cell's bottom.
LOG_HEIGHT = 11
LOG_BOTTOM = OBJECT_BOTTOM - 1
# How far the cut face reaches into the log: it is an ellipse this wide, seen at a slant.
FACE_WIDTH = 7

# Length in pixels of the long and the short trunk.
LONG = 30
SHORT = 14

# Per tree: its bark lit to dark, the colour of the furrows in it, the outline, and how furrowed
# it is (furrows per 10 px).
SPECIES = {
    "oak": (("soil_light", "soil_mid", "soil"), "soil_dark", "soil_dark", 3.0),
    "spruce": (("soil_mid", "soil", "soil_dark"), "russet_deep", "ink", 1.2),
    "pine": (("sand", "mud", "mud_dark"), "rust_dark", "ink", 2.0),
    "dead_tree": (("stone_light", "stone", "stone_dark"), "stone_dark", "ink", 2.0),
    "willow": (("bare_light", "bare", "mud_dark"), "soil_dark", "soil_dark", 3.5),
    "beech": (("stone_light", "stone", "stone_dark"), "stone_dark", "stone_dark", 0.6),
    "birch": (("lime", "stone_light", "stone"), "ink", "stone_dark", 2.0),
}
# The cut face, from the rim of sapwood inwards: rings alternating, then the heart round the pith.
RINGS = ("straw", "sand_light", "sand", "sand_light")
VARIANTS = 2


def log_picture(species, length, seed):
    """One trunk: its cut face on the left, its other end rounded off where the crown was taken
    off, a branch stub on top."""
    rng = random.Random(seed)
    (light, middle, dark), furrow, outline, furrows = SPECIES[species]
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    left = OBJECT_CENTRE - length // 2
    right = left + length - 1
    top = LOG_BOTTOM - LOG_HEIGHT + 1
    centre_y = (top + LOG_BOTTOM) / 2
    radius_y = LOG_HEIGHT / 2

    # The ground shadow, a little wider than the log and offset to the lower right.
    for y, inset in ((OBJECT_BOTTOM - 2, 1), (OBJECT_BOTTOM - 1, 0), (OBJECT_BOTTOM, 2)):
        for x in range(left + inset, right + 3 - inset):
            canvas[y][x] = "shadow"

    # The bark: a cylinder, lit on its top, dark underneath. Its right end is rounded.
    face_x = left + FACE_WIDTH // 2
    for y in range(top, LOG_BOTTOM + 1):
        across = (y + 0.5 - centre_y) / radius_y
        end = right - round(2.5 * (1 - math.sqrt(max(0.0, 1 - across * across))))
        for x in range(face_x, end + 1):
            canvas[y][x] = light if across < -0.4 else middle if across < 0.45 else dark
    # Furrows along the bark, in runs of a few pixels, and a lit ridge here and there.
    for _ in range(round(furrows * length / 10)):
        y = rng.randint(top + 2, LOG_BOTTOM - 2)
        x = rng.randint(face_x + 4, right - 4)
        for step in range(rng.randint(3, 6)):
            if canvas[y][x + step] in (light, middle, dark):
                canvas[y][x + step] = furrow
        if canvas[y - 1][x + 1] in (light, middle):
            canvas[y - 1][x + 1] = light
    # A knot on the long trunks, and a broken-off branch stub on top.
    if length > SHORT:
        knot_x = rng.randint(face_x + 6, right - 8)
        canvas[top + 6][knot_x] = canvas[top + 6][knot_x + 1] = furrow
        canvas[top + 5][knot_x] = light
    stub_x = right - rng.randint(4, 7) if length > SHORT else right - 4
    for y, x0, x1 in ((top - 3, 1, 2), (top - 2, 0, 2), (top - 1, 0, 2), (top, 0, 3)):
        for x in range(stub_x + x0, stub_x + x1 + 1):
            canvas[y][x] = light if x == stub_x + x0 else middle
    canvas[top - 3][stub_x + 1] = "sand_light"

    # The cut face: rings around the pith, the rim of bark round it in the darkest bark.
    face_centre_x = left + FACE_WIDTH / 2
    for y in range(top, LOG_BOTTOM + 1):
        for x in range(left, left + FACE_WIDTH):
            distance = math.hypot((x + 0.5 - face_centre_x) / (FACE_WIDTH / 2), (y + 0.5 - centre_y) / radius_y)
            if distance > 1:
                continue
            if distance > 0.82:
                canvas[y][x] = dark
            else:
                canvas[y][x] = RINGS[min(len(RINGS) - 1, int((0.82 - distance) / 0.82 * len(RINGS)))]
    canvas[math.floor(centre_y)][math.floor(face_centre_x)] = "soil_mid"
    _outline(canvas, outline)
    return canvas


def _outline(canvas, colour):
    """The edge pixels of everything but the ground shadow, in the outline colour."""
    marked = []
    for y in range(OBJECT_CELL_HEIGHT):
        for x in range(OBJECT_CELL_WIDTH):
            if canvas[y][x] in (None, "shadow"):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if canvas[y + dy][x + dx] in (None, "shadow"):
                    marked.append((x, y))
                    break
    for x, y in marked:
        canvas[y][x] = colour


def rows(species):
    """The two trunk rows of a tree in assets/objects.png as (kind, variants): the long trunk, then
    the short one."""
    result = []
    for kind, length in (("trunk", LONG), ("short_trunk", SHORT)):
        seeds = (_seed(species, length, variant) for variant in range(VARIANTS))
        result.append((f"{species}_{kind}", [log_picture(species, length, seed) for seed in seeds]))
    return result


def _seed(species, length, variant):
    """A seed that is the same on every run (Python's hash() of a string is not)."""
    return sum(ord(letter) for letter in species) * 100 + length * 3 + variant
