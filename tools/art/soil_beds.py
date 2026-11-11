"""The brown of tilled soil as the moisture steps (see game/scenes/soil_wetness.gd): the ramps of
colour of each step, the overlay atlas that draws a step over the soil terrain, and the atlas of
the pieces that draw the edge between a wetter tile and a drier one as the edge of a wet patch.

The terrain (terrain.py, classic/terrain.py) is the dry soil, the base. A moister tile gets an
overlay of its step on the plain tile grid, cut like the bed under it: its pixels are those of
the terrain that lie well inside the bed, so a bed's outer edge, with its rim, stays as it is and
the tiles inside it, wet or dry, show no seam of the plain grid against the dual grid the terrain
is drawn on. Which tiles around a tile are tilled decides the cut: BED_MASKS lists the 47 shapes
that can matter, and the overlay of step n is the row n - 1 of the atlas, one column per mask.
Where a tile is wetter than a tilled neighbour, the edge between their browns wanders across the
tile edge like the edge of a wet patch (see `edge_rows`).
"""

import math
import random

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


def inside_bed(size, mask, shapes):
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


def spot_on_bed(rng, inside, drawn):
    """A random spot (the top left corner) for a small picture on a tile, where all its `drawn`
    pixels ((x, y) in the picture) lie on `inside`: the weeds of fallow soil stay on the bed even
    of a tile tilled alone (see inside_bed with the mask 0)."""
    size = len(inside)
    width = max(x for x, _ in drawn) + 1
    height = max(y for _, y in drawn) + 1
    while True:
        x, y = rng.randrange(size - width + 1), rng.randrange(size - height + 1)
        if all(inside[y + dy][x + dx] for dx, dy in drawn):
            return x, y


def _soil_at(size, pixel, x, y):
    """The colour of the soil of `pixel(x, y)` (see terrain.soil_pixel_of) at a pixel of a tile
    of the plain grid: the terrain is drawn on the dual grid, half a tile off."""
    half = size // 2
    return pixel((x + half) % size, (y + half) % size)


def overlay_tile(size, mask, shapes, pixel):
    """One tile of the overlay for a bed `mask`: `pixel(x, y)` is the colour of the soil at a
    pixel of the terrain, and `shapes` its edge shapes. It is drawn where it lies well inside the
    bed."""
    inside = inside_bed(size, mask, shapes)
    return [[_soil_at(size, pixel, x, y) if inside[y][x] else None for x in range(size)] for y in range(size)]


def overlay_rows(size, shapes, pixel_of_ramp):
    """The overlay atlas: a row for each step moister than the driest, a tile for each bed mask."""
    rows = []
    for ramp in RAMPS[1:]:
        pixel = pixel_of_ramp(ramp)
        rows.append([overlay_tile(size, mask, shapes, pixel) for mask in BED_MASKS])
    return rows


# The edges of wet patches (task 175): where a tile is wetter than a tilled neighbour, the line
# between their browns wanders across the tile edge, in and out, blotchy along its length, and
# steps through the browns between in bands a few pixels apart. Each line of the tile grid has a
# long wavy line PHASES tiles long that repeats along it; a tile's edge is the part of it at the
# tile's place along the line (its phase), so the line runs on from tile to tile as far as the
# patch's edge does. Where it doesn't (the patch's edge turns there, or the bed ends), the line
# comes to the tile's corner, and a corner piece rounds the patch off there over its wetter tile,
# or fills in a hollow of the patch over its drier tile.
# A side's edge is drawn in pieces over its two tiles: over the drier tile a bulge for each wetter
# step, where the line lies beyond the tile edge, and over the wetter tile a bite for each drier
# step, where it lies short of it. A piece is one step in its brown; the game stacks those of an
# edge (the wettest bulge and the driest bite on top), so each pixel shows its step of the line.
# The order of the atlas and the ends of a side are shared with game/scenes/soil_wetness.gd.
SIDES = (N, E, S, W)
CORNERS = (NE, SE, SW, NW)
# The two ends of each side: the side across it there and the corner between them.
_SIDE_ENDS = {N: ((W, NW), (E, NE)), E: ((N, NE), (S, SE)), S: ((W, SW), (E, SE)), W: ((N, NW), (S, SW))}
# How a side's edge ends, in this order: at the bed's rim (the tile across is not tilled: the line
# runs into the rim, cut to the bed), running on into the next tiles (as wet as these two), or
# turning (the line comes to the corner). The tile beyond, across the edge from the one across,
# never cuts a tile: the bed's notch where it is not tilled lies in it.
END_KINDS = 3
END_RIM, END_RUNS_ON, END_TURNS = range(END_KINDS)
PHASES = 4
# What the rows of the atlas draw, a row for each phase: the bites of the steps 0 to 2 and the
# bulges of the steps 1 to 3, as (is a bulge, step).
PIECES = [(False, 0), (False, 1), (False, 2), (True, 1), (True, 2), (True, 3)]


def _smooth(t):
    return t * t * (3 - 2 * t)


def _value_noise(seed, cell, period, reach):
    """A smooth noise of blobs `cell` pixels across, -1..1, that repeats every `period` pixels
    along x (a multiple of `cell`), for y within `reach` of 0."""
    rng = random.Random(seed)
    columns = period // cell
    rows = range(-(reach // cell) - 1, reach // cell + 2)
    values = {(i, j): rng.uniform(-1, 1) for j in rows for i in range(columns)}

    def noise(x, y):
        fx, fy = x / cell, y / cell
        ix, iy = math.floor(fx), math.floor(fy)
        tx, ty = _smooth(fx - ix), _smooth(fy - iy)

        def value(i, j):
            return values[i % columns, j]

        top = value(ix, iy) * (1 - tx) + value(ix + 1, iy) * tx
        bottom = value(ix, iy + 1) * (1 - tx) + value(ix + 1, iy + 1) * tx
        return top * (1 - ty) + bottom * ty

    return noise


def _wavy_line(seed, period):
    """A smooth line, -1..1 at its farthest, that repeats every `period` pixels."""
    rng = random.Random(seed)
    waves = [(cycles, weight, rng.uniform(0, math.tau)) for cycles, weight in ((1, 1.0), (2, 0.8), (3, 0.5), (5, 0.3))]

    def raw(t):
        return sum(weight * math.sin(math.tau * cycles * t / period + phase) for cycles, weight, phase in waves)

    farthest = max(abs(raw(t)) for t in range(period))
    return lambda t: raw(t) / farthest


class PatchEdge:
    """How the edge of a wet patch is drawn at a tile `size`: its line wanders up to `amplitude`
    pixels across the tile edge and blotches by up to `blotch` pixels in blobs `blotch_cell`
    across; the browns between step down from it into the wetter tile `gap` pixels apart; a
    patch's corner is rounded off with a radius of `convex` and a hollow filled in with one of
    `concave`, and towards a corner the line comes to the tile's corner over `taper` pixels
    before it."""

    def __init__(self, size, amplitude, blotch, blotch_cell, gap, convex, concave, taper):
        self.size = size
        self.amplitude = amplitude
        self.blotch = blotch
        self.gap = gap
        self.convex = convex
        self.concave = concave
        self.taper = taper
        self.line = _wavy_line(91, PHASES * size)
        self.line_blotch = _value_noise(92, blotch_cell, PHASES * size, size)
        self.corner_blotches = [_value_noise(93 + variant, blotch_cell, size, size) for variant in range(PHASES)]

    def wet_steps(self, line_offset, distance):
        """How many steps of the wetter tile (0 to 3) reach a pixel `distance` pixels beyond the
        tile edge (towards the drier tile), where the line lies `line_offset` pixels beyond it."""
        return sum(1 for step in (1, 2, 3) if distance < line_offset - (step - 1) * self.gap)

    def reach(self, along, ends):
        """How far the line may stray from the tile edge `along` a side whose ends are `ends`,
        0 to 1: near an end where the patch turns it lies on the tile edge, where a corner piece
        may round it, and it comes away over `taper` pixels; at the bed's rim it runs into the
        rim as it is."""
        factor = 1.0
        corner_size = max(self.convex, self.concave)
        for kind, distance in zip(ends, (along + 0.5, self.size - along - 0.5)):
            if kind == END_TURNS:
                factor *= _smooth(min(1.0, max(0.0, (distance - corner_size) / self.taper)))
        return factor


def _is_drawn(piece, wet_steps):
    """Whether a piece (see PIECES) draws a pixel that `wet_steps` steps reach."""
    is_bulge, step = piece
    return wet_steps >= step if is_bulge else wet_steps <= step


def _from_side(side, size, x, y):
    """Where a pixel of a tile lies from its `side`: how far along it (from its north or west
    end) and how far in, both to the pixel's middle."""
    far = size - 0.5
    return {N: (x, y + 0.5), S: (x, far - y), W: (y, x + 0.5), E: (y, far - x)}[side]


def side_masks(side):
    """The bed masks a side's pieces are cut to, one for each pair of end kinds (see END_KINDS):
    at the bed's rim the tile across is not tilled, else all are."""
    masks = []
    for first in range(END_KINDS):
        for second in range(END_KINDS):
            mask = 255
            for (across, _), kind in zip(_SIDE_ENDS[side], (first, second)):
                if kind == END_RIM:
                    mask &= ~across
            masks.append(canonical(mask))
    return masks


def side_piece(edge, side, ends, phase, piece, inside, pixel):
    """A piece (see PIECES) of the edge along `side` of a tile, whose ends are `ends` (see
    END_KINDS), at `phase` of its line, in the colours `pixel(x, y)` of its step; `inside` are
    the pixels well inside the bed."""
    size = edge.size
    tile = [[None] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            along, depth = _from_side(side, size, x, y)
            distance = depth if piece[0] else -depth
            place = phase * size + along
            wander = edge.amplitude * edge.line(place) + edge.blotch * edge.line_blotch(place, distance)
            line_offset = edge.reach(along, ends) * wander
            if inside[y][x] and _is_drawn(piece, edge.wet_steps(line_offset, distance)):
                tile[y][x] = _soil_at(size, pixel, x, y)
    return tile


def corner_piece(edge, corner, variant, piece, inside, pixel):
    """A piece (see `side_piece`) at `corner` of a tile: a bite rounds off a patch's corner over
    its wetter tile, a bulge fills in a hollow of a patch over its drier tile. Within its radius
    of the corner it draws every pixel of its step, over the pieces of the sides there."""
    is_bulge, _ = piece
    size = edge.size
    radius = edge.concave if is_bulge else edge.convex
    first, second = (side for side in SIDES if side & _SIDES_OF_CORNER[corner])
    tile = [[None] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            _, a = _from_side(first, size, x, y)
            _, b = _from_side(second, size, x, y)
            if not inside[y][x] or a >= radius or b >= radius:
                continue
            # How far the pixel lies inside the patch: beyond the arc round the patch's corner,
            # or short of the arc that fills in its hollow.
            rounded = radius - math.hypot(radius - a, radius - b)
            distance = rounded if is_bulge else -rounded
            # The blotches fade out towards the sides, where the sides' line lies on the tile edge.
            fade = min(1.0, (radius - max(a, b)) / edge.taper)
            line_offset = fade * edge.blotch * edge.corner_blotches[variant](a, b)
            if _is_drawn(piece, edge.wet_steps(line_offset, distance)):
                tile[y][x] = _soil_at(size, pixel, x, y)
    return tile


def edge_rows(edge, shapes, pixel_of_ramp):
    """The atlas of the edges of wet patches: a row for each phase of each piece (see PIECES); in
    it a tile for each side (SIDES) and pair of end kinds (see `side_masks`), then for each corner
    (CORNERS), where both sides are tilled."""
    pixels = [pixel_of_ramp(ramp) for ramp in RAMPS]
    sides = [
        (side, divmod(index, END_KINDS), inside_bed(edge.size, mask, shapes))
        for side in SIDES
        for index, mask in enumerate(side_masks(side))
    ]
    whole_tile = inside_bed(edge.size, 255, shapes)
    rows = []
    for piece in PIECES:
        pixel = pixels[piece[1]]
        for phase in range(PHASES):
            rows.append(
                [side_piece(edge, side, ends, phase, piece, inside, pixel) for side, ends, inside in sides]
                + [corner_piece(edge, corner, phase, piece, whole_tile, pixel) for corner in CORNERS]
            )
    return rows
