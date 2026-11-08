"""Art for the trunks that felled trees leave (see `trunk` in game/state/world_object_types.gd).

A trunk is a felled log lying horizontally, seen in 3/4 view like everything else: its cut face
with year rings on the left, the bark of its top and front lit from the top left, a broken-off
branch stub or two, and a shadow on the ground. Its cell is an object cell of the atlas (48x80,
see canvas.py), drawn at 32 px per tile: the long one (2x1 tiles) is centred on its 64 px wide
footprint, the short one (1x1) on 32 px. The ground row is the cell's bottom row. Pictures are
lists of rows of palette colour names.
"""

import math
import random

from canvas import outline_edge
from trees import BOTTOM, CENTRE, cell

# The log's rows, its outline included, ending a row above the cell's bottom.
LOG_HEIGHT = 22
LOG_BOTTOM = BOTTOM - 2
# How far the cut face reaches into the log: it is an ellipse this wide, seen at a slant.
FACE_WIDTH = 14

# Length in pixels of the long and the short trunk.
LONG = 60
SHORT = 28

# Per tree: its bark lit to dark, the colour of the furrows in it, the outline (the darkest of its
# bark, never ink), and how furrowed it is (furrows per 10 px).
SPECIES = {
    "oak": (("soil_light", "soil_mid", "soil"), "soil_dark", "soil_dark", 3.0),
    "spruce": (("soil_mid", "soil", "soil_dark"), "russet_deep", "soil_dark", 1.2),
    "pine": (("sand", "mud", "mud_dark"), "rust_dark", "soil_dark", 2.0),
    "dead_tree": (("stone_light", "stone", "stone_dark"), "stone_dark", "stone_dark", 2.0),
    "willow": (("bare_light", "bare", "mud_dark"), "soil_dark", "soil_dark", 3.5),
    "beech": (("stone_light", "stone", "stone_dark"), "stone_dark", "stone_dark", 0.6),
    "birch": (("lime", "stone_light", "stone"), "ink", "stone_dark", 2.0),
    "alder": (("mud", "mud_dark", "soil_dark"), "ink", "soil_dark", 3.0),
}
# The cut face, from the rim of sapwood inwards: rings alternating, then the heart round the pith.
RINGS = ("straw", "sand_light", "sand", "sand_light", "straw", "sand_light", "sand")
VARIANTS = 2


def log_picture(species, length, seed):
    """One trunk: its cut face on the left, its other end rounded off where the crown was taken
    off, a branch stub on top."""
    rng = random.Random(seed)
    (light, middle, dark), furrow, outline, furrows = SPECIES[species]
    canvas = cell()
    left = CENTRE - length // 2
    right = left + length - 1
    top = LOG_BOTTOM - LOG_HEIGHT + 1
    centre_y = (top + LOG_BOTTOM) / 2
    radius_y = LOG_HEIGHT / 2

    # The ground shadow, a little wider than the log and offset to the lower right.
    for y, inset in ((BOTTOM - 4, 3), (BOTTOM - 3, 1), (BOTTOM - 2, 0), (BOTTOM - 1, 1), (BOTTOM, 4)):
        for x in range(left + inset, right + 5 - inset):
            canvas[y][x] = "shadow"

    # The bark: a cylinder, lit on its top, dark underneath. Its right end is rounded.
    face_x = left + FACE_WIDTH // 2
    for y in range(top, LOG_BOTTOM + 1):
        across = (y + 0.5 - centre_y) / radius_y
        end = right - round(5 * (1 - math.sqrt(max(0.0, 1 - across * across))))
        for x in range(face_x, end + 1):
            canvas[y][x] = light if across < -0.4 else middle if across < 0.45 else dark
    # Furrows along the bark, in runs of a few pixels, and a lit ridge here and there.
    for _ in range(round(furrows * length / 10)):
        y = rng.randint(top + 3, LOG_BOTTOM - 3)
        x = rng.randint(face_x + 6, right - 8)
        for step in range(rng.randint(5, 12)):
            if canvas[y][x + step] in (light, middle, dark):
                canvas[y][x + step] = furrow
        if canvas[y - 1][x + 1] in (light, middle):
            canvas[y - 1][x + 1] = light
    # A knot on the long trunks, and a broken-off branch stub on top.
    if length > SHORT:
        knot_x = rng.randint(face_x + 12, right - 16)
        for dx, dy, colour in ((0, 0, furrow), (1, 0, furrow), (2, 0, furrow), (0, 1, furrow), (1, 1, dark), (1, -1, light), (2, -1, light)):
            canvas[top + 12 + dy][knot_x + dx] = colour
    stub_x = right - rng.randint(8, 14) if length > SHORT else right - 8
    for y, x0, x1 in ((top - 6, 2, 4), (top - 5, 1, 5), (top - 4, 1, 5), (top - 3, 0, 5), (top - 2, 0, 5), (top - 1, 0, 6), (top, 0, 7)):
        for x in range(stub_x + x0, stub_x + x1 + 1):
            canvas[y][x] = light if x <= stub_x + x0 + 1 else middle if x < stub_x + x1 else dark
    for x in range(stub_x + 2, stub_x + 5):
        canvas[top - 6][x] = "sand_light"
    canvas[top - 5][stub_x + 3] = "sand"

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
    for dx, dy in ((0, 0), (1, 0), (0, 1)):
        canvas[math.floor(centre_y) + dy][math.floor(face_centre_x) + dx] = "soil_mid"
    outline_edge(canvas, outline, ignoring=("shadow",))
    return canvas


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
