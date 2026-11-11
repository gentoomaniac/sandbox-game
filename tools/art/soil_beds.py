"""The brown of tilled soil as the moisture steps (see game/scenes/soil_wetness.gd): the ramps of
colour of each step, the overlay atlas that draws a step over the soil terrain, and the fade atlas
that softens the edge between a wetter tile and a drier one.

The terrain (terrain.py, classic/terrain.py) is the dry soil, the base. A moister tile gets an
overlay of its step on the plain tile grid, cut like the bed under it: its pixels are those of
the terrain that lie well inside the bed, so a bed's outer edge, with its rim, stays as it is and
the tiles inside it, wet or dry, show no seam of the plain grid against the dual grid the terrain
is drawn on. Which tiles around a tile are tilled decides the cut: BED_MASKS lists the 47 shapes
that can matter, and the overlay of step n is the row n - 1 of the atlas, one column per mask.
Where a tile is wetter than a tilled neighbour, a fade from the fade atlas lies over the
neighbour (see `fade_rows`).
"""

import math

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


def _inside_bed(size, mask, shapes):
    """Which pixels of a tile of a bed `mask` lie well inside the bed, as rows of booleans: where
    every variant of the terrain's edge shapes (see terrain.edge_shapes) covers the pixel and its
    neighbours, the terrain's rim excluded."""
    half = size // 2
    masks = _quadrant_masks(mask)
    inside = [[False] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            cell = (x + half) // size, (y + half) // size
            local_x, local_y = (x + half) % size, (y + half) % size
            inside[y][x] = masks[cell] == FULL or all(
                variant[masks[cell]](local_x + dx, local_y + dy)
                for variant in shapes
                for dx, dy in (*NEIGHBOURS, (0, 0))
            )
    return inside


def _soil_at(size, pixel, x, y):
    """The colour of the soil of `pixel(x, y)` (see terrain.soil_pixel_of) at a pixel of a tile
    of the plain grid: the terrain is drawn on the dual grid, half a tile off."""
    half = size // 2
    return pixel((x + half) % size, (y + half) % size)


def overlay_tile(size, mask, shapes, pixel):
    """One tile of the overlay for a bed `mask`: `pixel(x, y)` is the colour of the soil at a
    pixel of the terrain, and `shapes` its edge shapes. It is drawn where it lies well inside the
    bed."""
    inside = _inside_bed(size, mask, shapes)
    return [[_soil_at(size, pixel, x, y) if inside[y][x] else None for x in range(size)] for y in range(size)]


def overlay_rows(size, shapes, pixel_of_ramp):
    """The overlay atlas: a row for each step moister than the driest, a tile for each bed mask."""
    rows = []
    for ramp in RAMPS[1:]:
        pixel = pixel_of_ramp(ramp)
        rows.append([overlay_tile(size, mask, shapes, pixel) for mask in BED_MASKS])
    return rows


# The fades (task 167): where a tile is wetter than a tilled neighbour, its brown runs on into
# the neighbour and fades out there over a few pixels, through the browns of the steps between,
# in an ordered dither. A fade is drawn over the drier tile, on top of its own step, along the
# side or at the corner the wetter tile is at; on a side, it is cut to the bed at its two ends,
# where the bed may have its rim. A corner fades only when the tiles at both its sides are tilled
# (else the bed's rim lies there) and are not as wet; then it is a quarter round the corner that
# meets the fades of those sides.
# The order of the atlas and the ends of a fade are shared with game/scenes/soil_wetness.gd.
SIDES = (N, E, S, W)
CORNERS = (NE, SE, SW, NW)
# The two ends of a fade along each side: the side across it there and the corner between them.
_FADE_ENDS = {N: ((W, NW), (E, NE)), E: ((N, NE), (S, SE)), S: ((W, SW), (E, SE)), W: ((N, NW), (S, SW))}
# How an end of a fade along a side is cut: the side across is not tilled, it is but the corner is
# not, or both are; a fade along a side has a column for each of the 3 x 3 pairs, in this order.
END_CUTS = 3
# The pairs of steps a fade runs between, (wetter, drier): a row of the fade atlas each.
STEP_PAIRS = [(wetter, drier) for wetter in range(1, len(RAMPS)) for drier in range(wetter)]
# The thresholds of a 4 x 4 ordered dither: a tile is a multiple of 4 wide, so the pattern runs on
# from tile to tile.
_BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


def fade_masks(side):
    """The bed masks a fade along `side` is cut to, one for each pair of end cuts (see
    END_CUTS): the rest of the tile's neighbours tilled, as they don't reach the fade."""
    masks = []
    for first_cut in range(END_CUTS):
        for second_cut in range(END_CUTS):
            mask = 255
            for (across, corner), cut in zip(_FADE_ENDS[side], (first_cut, second_cut)):
                if cut == 0:
                    mask &= ~across
                if cut < 2:
                    mask &= ~corner
            masks.append(canonical(mask))
    return masks


def _distance_from(direction, size, x, y):
    """How far a pixel of a tile lies from the side or the corner `direction` of the tile."""
    far = size - 1
    return {
        N: y,
        E: far - x,
        S: far - y,
        W: x,
        NE: math.hypot(far - x, y),
        SE: math.hypot(far - x, far - y),
        SW: math.hypot(x, far - y),
        NW: math.hypot(x, y),
    }[direction]


def fade_tile(size, direction, inside, depth, steps, pixels):
    """The fade from a wetter tile at the side or corner `direction` into a drier one, `depth`
    pixels deep, between the `steps` (wetter, drier); `inside` are the pixels well inside the bed
    (see `_inside_bed`) and `pixels` the pixel functions of the steps. Where it has come down to
    the drier step, the tile is empty: that step is drawn under it."""
    wetter, drier = steps
    tile = [[None] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            distance = _distance_from(direction, size, x, y)
            if not inside[y][x] or distance >= depth:
                continue
            level = wetter - (wetter - drier) * (distance + 0.5) / depth
            threshold = (_BAYER[y % 4][x % 4] + 0.5) / 16
            step = math.ceil(level) if level % 1 > threshold else math.floor(level)
            if step > drier:
                tile[y][x] = _soil_at(size, pixels[step], x, y)
    return tile


def fade_rows(size, depth, shapes, pixel_of_ramp):
    """The fade atlas: a row for each pair of steps (STEP_PAIRS); in it the fades along each side
    (SIDES), a tile for each pair of end cuts (see `fade_masks`), then the fade at each corner
    (CORNERS)."""
    pixels = [pixel_of_ramp(ramp) for ramp in RAMPS]
    cuts = [(side, _inside_bed(size, mask, shapes)) for side in SIDES for mask in fade_masks(side)]
    whole_tile = _inside_bed(size, 255, shapes)
    cuts += [(corner, whole_tile) for corner in CORNERS]
    return [[fade_tile(size, direction, inside, depth, steps, pixels) for direction, inside in cuts] for steps in STEP_PAIRS]
