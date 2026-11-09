"""The brown of tilled soil as the moisture steps (see game/scenes/soil_wetness.gd): the ramps of
colour of each step, and the overlay atlas that draws a step over the soil terrain.

The terrain (terrain.py, classic/terrain.py) is the dry soil, the base. A moister tile gets an
overlay of its step on the plain tile grid, cut like the bed under it: its pixels are those of
the terrain that lie well inside the bed, so a bed's outer edge, with its rim, stays as it is and
the tiles inside it, wet or dry, show no seam of the plain grid against the dual grid the terrain
is drawn on. Which tiles around a tile are tilled decides the cut: BED_MASKS lists the 47 shapes
that can matter, and the overlay of step n is the row n - 1 of the atlas, one column per mask.
"""

from canvas import NEIGHBOURS

# Neighbour bits, shared with game/scenes/soil_wetness.gd.
N, E, S, W = 1, 2, 4, 8
NE, SE, SW, NW = 16, 32, 64, 128
_SIDES_OF_CORNER = {NE: N | E, SE: S | E, SW: S | W, NW: N | W}

# Dual-grid corner bits of a terrain cell, as in terrain.py.
TL, TR, BL, BR = 1, 2, 4, 8
FULL = TL | TR | BL | BR

# The colours (furrow, body, crest) of each moisture step, the driest first: from a light brown
# down to the darkest, a palette brown to a body, so no step turns grey or green.
RAMPS = [
    ("soil_mid", "soil_light", "sand_light"),
    ("soil", "soil_mid", "soil_light"),
    ("soil_dark", "soil", "soil_mid"),
    ("soil_dark", "soil_dark", "soil"),
]


def canonical(mask):
    """A mask of the 8 neighbours with the corners dropped whose two sides are not both tilled:
    a bed is cut the same whatever lies there."""
    for corner, sides in _SIDES_OF_CORNER.items():
        if mask & sides != sides:
            mask &= ~corner
    return mask


BED_MASKS = sorted({canonical(mask) for mask in range(256)})


def _quadrant_masks(mask):
    """The dual-grid cell mask under each quarter of a tile, as (cell x, cell y) of the tile
    corner it is at: the cell's corners are the tile, two sides and one corner of `mask`."""
    def bit(neighbour):
        return 1 if mask & neighbour else 0

    return {
        (0, 0): bit(NW) * TL | bit(N) * TR | bit(W) * BL | BR,
        (1, 0): bit(N) * TL | bit(NE) * TR | BL | bit(E) * BR,
        (0, 1): bit(W) * TL | TR | bit(SW) * BL | bit(S) * BR,
        (1, 1): TL | bit(E) * TR | bit(S) * BL | bit(SE) * BR,
    }


def overlay_tile(size, mask, shapes, pixel):
    """One tile of the overlay for a bed `mask`: `pixel(x, y)` is the colour of the soil at a
    pixel of the terrain, and `shapes` its edge shapes (see terrain.edge_shapes). A pixel is drawn
    where every variant of the shape covers it and its neighbours, the terrain's rim excluded."""
    half = size // 2
    masks = _quadrant_masks(mask)
    tile = [[None] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            cell = (x + half) // size, (y + half) // size
            local_x, local_y = (x + half) % size, (y + half) % size
            if masks[cell] == FULL or all(
                variant[masks[cell]](local_x + dx, local_y + dy)
                for variant in shapes
                for dx, dy in (*NEIGHBOURS, (0, 0))
            ):
                tile[y][x] = pixel(local_x, local_y)
    return tile


def overlay_rows(size, shapes, pixel_of_ramp):
    """The overlay atlas: a row for each step moister than the driest, a tile for each bed mask."""
    rows = []
    for ramp in RAMPS[1:]:
        pixel = pixel_of_ramp(ramp)
        rows.append([overlay_tile(size, mask, shapes, pixel) for mask in BED_MASKS])
    return rows
