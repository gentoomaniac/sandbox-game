"""The meadow flowers of the region: the flower row of assets/decorations.png (see terrain.py).

Each species of `SPECIES` has `VARIANTS` tiles side by side, in the order of the list, which
game/scenes/terrain_tileset.gd repeats (FLOWER_SPECIES): a lone small plant (just opened or
fading), a few plants, and two of the thick of a drift, whose plants are spread evenly over
the tile so neighbouring tiles run together into a carpet without a visible grid. Plants stand on a stem of their own, lit from the left; their
heads are 1 to 3 px, in the palette's flower accents. The seasons remap them like the other
decorations (autumn browns `cream`, `gold` and `petal`; `lime`, `blossom` and `heather` keep).
"""

import random

from canvas import TILE, blank

# The order of the atlas row, in the order they come into bloom over the year.
SPECIES = (
    "wood_anemone",
    "dandelion",
    "cuckooflower",
    "daisy",
    "buttercup",
    "red_campion",
    "red_clover",
    "white_clover",
    "yarrow",
    "knapweed",
    "meadowsweet",
    "heather",
)
VARIANTS = 4
SMALL, FEW = 0, 1
# A drift tile has a plant in most cells of a grid this many pixels wide, jittered.
DRIFT_CELL = 4
DRIFT_CHANCE = 0.85

STEM = "green_dark"
LEAF = "green_light"


def put(tile, x, y, colour):
    if 0 <= x < TILE and 0 <= y < TILE:
        tile[y][x] = colour


def stem(tile, x, foot, height, colour=STEM):
    """A stem from the foot up `height` px; returns the row of its top."""
    for step in range(height):
        put(tile, x, foot - step, colour)
    return foot - height + 1


def wood_anemone(tile, x, foot, rng, is_small):
    """A low white star with a pale yellow eye over a whorl of cut leaves: the beech woods in
    early spring."""
    top = stem(tile, x, foot, 2 if is_small else 3)
    put(tile, x - 1, top + 1, LEAF)
    put(tile, x + 1, top + 1, LEAF)
    put(tile, x, top - 1, "cream")
    if not is_small:
        put(tile, x - 1, top - 1, "lime")
        put(tile, x + 1, top - 1, "lime")
        put(tile, x, top - 2, "lime")


def dandelion(tile, x, foot, rng, is_small):
    """A flat rosette of jagged leaves and a round golden head on a short stalk."""
    put(tile, x - 1, foot, LEAF)
    put(tile, x + 1, foot, "green")
    put(tile, x - 2, foot, "green")
    top = stem(tile, x, foot - 1, 1 if is_small else 2)
    if is_small:
        put(tile, x, top - 1, "gold")
        return
    put(tile, x, top - 1, "gold")
    put(tile, x + 1, top - 1, "ochre")
    put(tile, x, top - 2, "gold")
    put(tile, x + 1, top - 2, "gold")


def cuckooflower(tile, x, foot, rng, is_small):
    """A thin, tall stem with a loose head of pale lilac flowers: wet meadows in spring."""
    top = stem(tile, x, foot, 3 if is_small else rng.randint(4, 6))
    put(tile, x - 1, foot, LEAF)
    put(tile, x, top - 1, "blossom")
    if not is_small:
        put(tile, x - 1, top, "blossom")
        put(tile, x + 1, top - 1, "petal")
        put(tile, x - 1, top - 2, "blossom")


def daisy(tile, x, foot, rng, is_small):
    """A white daisy with a golden eye, low over the grass."""
    put(tile, x - 1, foot, LEAF)
    top = stem(tile, x, foot, 1 if is_small else 2)
    if is_small:
        put(tile, x, top - 1, "lime")
        return
    put(tile, x, top - 2, "gold")
    put(tile, x - 1, top - 2, "lime")
    put(tile, x + 1, top - 2, "lime")
    put(tile, x, top - 3, "lime")
    put(tile, x, top - 1, "lime")


def buttercup(tile, x, foot, rng, is_small):
    """A tall branching stem with small glossy yellow cups."""
    top = stem(tile, x, foot, 3 if is_small else rng.randint(5, 7))
    put(tile, x, top - 1, "gold")
    if is_small:
        return
    put(tile, x + 1, top - 1, "gold")
    put(tile, x + 1, top, "ochre")
    # A side branch with a second cup.
    side = -1 if rng.random() < 0.5 else 1
    put(tile, x + side, top + 2, STEM)
    put(tile, x + 2 * side, top + 1, "gold")


def red_campion(tile, x, foot, rng, is_small):
    """A tall, slightly hairy stem with pink flowers: wood edges and hedges."""
    top = stem(tile, x, foot, 3 if is_small else rng.randint(5, 7), "green")
    put(tile, x - 1, foot - 1, LEAF)
    put(tile, x, top - 1, "petal")
    if is_small:
        return
    put(tile, x - 1, top - 1, "blossom")
    put(tile, x + 1, top - 1, "petal")
    put(tile, x, top - 2, "petal")
    put(tile, x, top - 1, "heather_dark")


def red_clover(tile, x, foot, rng, is_small):
    """A round pink-purple head over trefoil leaves, low in the grass."""
    put(tile, x - 1, foot, "green_bright")
    put(tile, x + 1, foot, "green_bright")
    put(tile, x, foot, LEAF)
    top = stem(tile, x, foot - 1, 1)
    put(tile, x, top - 1, "petal")
    if not is_small:
        put(tile, x + 1, top - 1, "heather")
        put(tile, x, top - 2, "blossom")
        put(tile, x + 1, top - 2, "petal")


def white_clover(tile, x, foot, rng, is_small):
    """A round white head over trefoil leaves, lowest of all: grazed pasture."""
    put(tile, x - 1, foot, "green_bright")
    put(tile, x + 1, foot, LEAF)
    put(tile, x, foot - 1, "lime")
    if not is_small:
        put(tile, x + 1, foot - 1, "cream")
        put(tile, x, foot - 2, "lime")
        put(tile, x + 1, foot - 2, "lime")


def yarrow(tile, x, foot, rng, is_small):
    """A stiff stem with a flat white umbel and feathery leaves: dry summer grass."""
    top = stem(tile, x, foot, 3 if is_small else rng.randint(4, 6))
    put(tile, x + 1, foot - 1, LEAF)
    put(tile, x - 1, foot - 2, LEAF)
    if is_small:
        put(tile, x, top - 1, "lime")
        return
    for dx in (-1, 0, 1):
        put(tile, x + dx, top - 1, "lime")
    put(tile, x + 2, top - 1, "cream")
    put(tile, x, top, "stone_light")


def knapweed(tile, x, foot, rng, is_small):
    """A wiry stem with a purple thistle-like tuft on a dark knob."""
    top = stem(tile, x, foot, 3 if is_small else rng.randint(4, 6))
    put(tile, x, top - 1, "heather_dark")
    put(tile, x, top - 2, "heather")
    if not is_small:
        put(tile, x - 1, top - 2, "heather")
        put(tile, x + 1, top - 2, "petal")
        put(tile, x + 1, top - 1, "heather_dark")


def meadowsweet(tile, x, foot, rng, is_small):
    """A tall reddish stem with a frothy creamy plume: ditches, banks and wet meadows."""
    top = stem(tile, x, foot, 4 if is_small else rng.randint(5, 8))
    put(tile, x + 1, foot - 2, LEAF)
    put(tile, x, top - 1, "cream")
    if is_small:
        return
    for dx, dy, colour in ((-1, -1, "lime"), (0, -2, "lime"), (1, -1, "cream"), (-1, -2, "lime"),
                           (1, -2, "cream"), (0, -3, "lime"), (-1, 0, "cream"), (1, 0, "stone_light")):
        put(tile, x + dx, top + dy, colour)


def heather(tile, x, foot, rng, is_small):
    """A low bush of woody twigs covered in tiny purple bells: the Geest heath in late summer."""
    width = 1 if is_small else rng.randint(2, 3)
    for dx in range(-width, width + 1):
        put(tile, x + dx, foot, "olive" if dx % 2 else "green_dark")
        height = 1 + (width - abs(dx) > 0) + (dx == 0 and not is_small)
        for step in range(1, height + 1):
            lit = dx < 0 or step == height
            put(tile, x + dx, foot - step, "heather" if lit and rng.random() < 0.8 else "heather_dark")


DRAW = {name: globals()[name] for name in SPECIES}


def flower_tile(name, variant):
    """One tile of a species: its plants over the tile, the back ones first."""
    rng = random.Random(f"{name}-{variant}")
    if variant == SMALL:
        feet = [(rng.randint(4, TILE - 5), rng.randint(10, 13))]
    elif variant == FEW:
        feet = [(rng.randint(2, 6), rng.randint(9, 12)), (rng.randint(9, 13), rng.randint(12, 15))]
    else:
        # Feet on a jittered grid, the top row low enough for the tallest stem.
        feet = [
            (cell_x + rng.randrange(DRIFT_CELL), cell_y + rng.randrange(DRIFT_CELL))
            for cell_y in range(DRIFT_CELL + 1, TILE, DRIFT_CELL)
            for cell_x in range(1, TILE - 2, DRIFT_CELL)
            if rng.random() < DRIFT_CHANCE
        ]
    tile = blank()
    for x, foot in sorted(feet, key=lambda f: f[1]):
        DRAW[name](tile, x, min(foot, TILE - 1), rng, variant == SMALL)
    return tile


def flower_row():
    """The flower row of the decoration atlas: every species' variants, in `SPECIES` order."""
    return [flower_tile(name, variant) for name in SPECIES for variant in range(VARIANTS)]
