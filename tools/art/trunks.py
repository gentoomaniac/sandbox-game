"""Art for the trunks that felled trees leave (see `trunk` in game/state/world_object_types.gd).

Placeholder art, to be redrawn: everything about a trunk's look is in `log_picture` and `rows`.
A trunk lies horizontally. Its cell is an object cell of the atlas (48x80, see generate.py): the
long one (2x1 tiles) is centred on its 32 px wide footprint, the short one (1x1) on 16 px. The
ground row is the cell's bottom row. Pictures are lists of rows of palette colour names.
"""

import random

CELL_WIDTH = 48
CELL_HEIGHT = 80
CENTRE = CELL_WIDTH // 2
BOTTOM = CELL_HEIGHT - 1
# The log's rows, the outline included, ending two rows above the cell's bottom.
LOG_HEIGHT = 10
LOG_BOTTOM = BOTTOM - 2

# Length in pixels of the long and the short trunk.
LONG = 30
SHORT = 14

# Per tree, in the order of their atlas rows (see world_object_types.gd): light, middle and dark
# bark, and whether it has leaves left on its crown end.
SPECIES = {
    "oak": (("soil_light", "soil_mid", "soil"), True),
    "spruce": (("soil_mid", "soil", "soil_dark"), True),
    "pine": (("sand", "mud", "mud_dark"), True),
    "dead_tree": (("mud", "stone", "stone_dark"), False),
}
OUTLINE = {"soil": "soil_dark", "soil_dark": "ink", "mud_dark": "ink", "stone_dark": "ink"}
VARIANTS = 2


def log_picture(species, length, seed):
    """One trunk: a log lying with its cut face on the left, its crown end on the right with a
    twig or two and, on a living tree, some leaves."""
    rng = random.Random(seed)
    (light, middle, dark), has_leaves = SPECIES[species]
    canvas = [[None] * CELL_WIDTH for _ in range(CELL_HEIGHT)]
    left = CENTRE - length // 2
    right = left + length - 1
    top = LOG_BOTTOM - LOG_HEIGHT + 1
    # Ground shadow under the log.
    for x in range(left, right + 1):
        for y in (BOTTOM - 1, BOTTOM):
            canvas[y][x] = "shadow"
    for y in range(top, LOG_BOTTOM + 1):
        for x in range(left, right + 1):
            if x in (left, right) and y in (top, LOG_BOTTOM):
                continue
            row = y - top
            canvas[y][x] = light if row <= 2 else middle if row <= 6 else dark
    # Bark marks.
    for _ in range(length // 6):
        x, y = rng.randint(left + 5, right - 3), rng.randint(top + 3, LOG_BOTTOM - 2)
        canvas[y][x] = canvas[y][x + 1] = dark
    # The cut face with a ring.
    for y in range(top + 1, LOG_BOTTOM):
        for x in range(left + 1, left + 4):
            canvas[y][x] = "sand_light"
    for y in range(top + 2, LOG_BOTTOM - 1):
        canvas[y][left + 3] = "sand"
    canvas[top + 4][left + 2] = canvas[top + 5][left + 2] = "straw"
    # Twigs on the crown end.
    for index in range(2):
        y = top + 1 + index * 4
        for step in range(rng.randint(2, 3)):
            canvas[y - step // 2 - 1][right + 1 + step] = dark if index else middle
    if has_leaves:
        for x, y in ((right - 3, top - 1), (right - 2, top - 1), (right - 4, top), (right - 1, top - 2)):
            canvas[y][x] = "green"
        canvas[top - 1][right - 3] = "green_light"
    _outline(canvas, OUTLINE[dark])
    return canvas


def _outline(canvas, colour):
    """The edge pixels of everything but the ground shadow, in the outline colour."""
    marked = []
    for y in range(CELL_HEIGHT):
        for x in range(CELL_WIDTH):
            if canvas[y][x] in (None, "shadow"):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if canvas[y + dy][x + dx] in (None, "shadow"):
                    marked.append((x, y))
                    break
    for x, y in marked:
        canvas[y][x] = colour


def rows():
    """The trunk rows of assets/objects.png as (kind, variants): per tree the long trunk, then the
    short one."""
    result = []
    for species in SPECIES:
        for kind, length in (("trunk", LONG), ("short_trunk", SHORT)):
            seeds = (_seed(species, length, variant) for variant in range(VARIANTS))
            result.append((f"{species}_{kind}", [log_picture(species, length, seed) for seed in seeds]))
    return result


def _seed(species, length, variant):
    """A seed that is the same on every run (Python's hash() of a string is not)."""
    return sum(ord(letter) for letter in species) * 100 + length * 3 + variant
