"""The ways the player lays tile by tile to walk on (issue #62, #84): a plank walk and a stone
path, for both art sets (the classic generator imports this module too, with its 16 px tile).

Each is a full-tile piece of ground in the object atlas, drawn flat like the jetty's deck, so the
player walks over it: a picture as big as the tile, set at the bottom of its cell. A piece has a
picture per connection mask (bit 0 north, 1 east, 2 south, 3 west: which neighbours are ways,
whatever their kind). Where a way has a neighbour it runs on flush across the seam, so a road can
be made as wide as wanted and has no edge inside it; where it has none its outer edge is irregular,
and the stone path has a kerb of edging stones there.

- The plank walk: weathered oak boards lying across the way, each a little different in width and
  length and cut at the ends, a dark gap between them, the top edge of each worn light in
  stretches, grain, a knot here and there and a nail at each end where it lies on the sleepers.
  Where the way ends the boards stop short by a pixel or three, so its edge is ragged and the grass
  shows between them. The boards lie east to west unless the way runs east to west
  (`boards_lie_east_west`).
- The stone path: rounded fieldstones set in dark earth, cool and warm greys and a few brown
  ones, each lit on its top left and shaded on its lower right. The stones are the cells of a
  set of points that repeats every tile; the points near the tile's sides are the same in every
  variant (so the stones run on across the seams, with no straight line along them) and only the
  inner stones differ. A side with no way beside it has a kerb: edging stones set in a row, each
  at its own distance from the edge, which hold the cobbles together.
- The road edge (`way_edge`): what a free tile beside a way gets on its side next to the way,
  trodden earth that thins out into the grass. It is no object: the game draws it over the ground
  where a way lies beside a free tile and takes it off when a way is laid there, so a road made
  wider has no rim inside it.

Light from the top left, as everywhere.
"""

import functools
import math
import random

from canvas import blank

# The sides of a way's neighbours as the bits of a connection mask (see World `connections`).
NORTH, EAST, SOUTH, WEST = 1, 2, 4, 8
ALL_SIDES = NORTH | EAST | SOUTH | WEST
# The pictures of a variant: one per connection mask.
CONNECTION_LOOKS = 16

# Weathered oak boards, as the jetty's deck: the worn top edge, the face and the gap.
BOARD_LIT, BOARD, BOARD_GAP = "bare_light", "bare", "mud_dark"
# A board of darker, browner oak, here and there among the grey ones, and its grain.
BOARD_DARK = "mud"
NAIL = "stone_dark"
# How wide the boards of a variant are down its tile, in px. A board is its width in rows: the lit
# edge, the face and the gap. Every variant's add up to the tile, so a board starts at the tile's
# top and the boards of the tile below go on from the gap at its bottom.
BOARD_WIDTHS = {
    32: ((4, 5, 3, 4, 4, 4, 5, 3), (5, 3, 4, 4, 5, 3, 4, 4), (3, 4, 4, 5, 4, 3, 5, 4), (4, 4, 5, 3, 4, 5, 3, 4)),
    16: ((3, 4, 3, 3, 3), (4, 3, 3, 3, 3), (3, 3, 4, 3, 3), (3, 3, 3, 4, 3)),
}
# How many knots (the eyes of branches) a variant has: some tiles have one, some none.
KNOTS = (1, 0, 1, 0)
# How far, in px, an end of a board with no way beyond it stops short of the tile's side: picked
# from these, so the boards differ in length.
END_INSETS = {32: (0, 1, 1, 2, 3, 4), 16: (0, 0, 1, 1, 2)}
# How an end of a board is cut: square, or with its top or its bottom corner sawn off.
END_CUTS = ("square", "square", "top", "bottom")
PLANK_VARIANTS = 4
STONE_VARIANTS = 3


def boards_lie_east_west(mask):
    """Whether the boards of a plank walk with this connection mask lie east to west (across a
    way that runs north to south) and not north to south (across one that runs east to west).
    The way runs along the axis with more neighbours on it; with as many on both (a corner, a
    crossing, a tile alone) the boards lie east to west."""
    along_north_south = bool(mask & NORTH) + bool(mask & SOUTH)
    along_east_west = bool(mask & EAST) + bool(mask & WEST)
    return along_east_west <= along_north_south


def _transposed_mask(mask):
    """The mask of the same tile turned over its diagonal: north and west swap, east and south."""
    return (
        (WEST if mask & NORTH else 0)
        | (SOUTH if mask & EAST else 0)
        | (EAST if mask & SOUTH else 0)
        | (NORTH if mask & WEST else 0)
    )


def _board_tops(tile, variant=0):
    """The top rows of the boards of a variant of a tile, and the rows each has."""
    tops = []
    top = 0
    for width in BOARD_WIDTHS[tile][variant]:
        tops.append((top, ["lit", *["face"] * (width - 2), "gap"]))
        top += width
    return tops


def _cast_shadows(picture):
    """A shadow, a pixel wide, to the right of and below whatever lies on the ground: the light is
    from the top left."""
    standing = [[colour not in (None, "shadow") for colour in row] for row in picture]
    for y, row in enumerate(picture):
        for x, colour in enumerate(row):
            if colour is None and ((x and standing[y][x - 1]) or (y and standing[y - 1][x])):
                row[x] = "shadow"
    return picture


def plank_walk(tile, variant, mask=ALL_SIDES, width=None):
    """One tile of the plank walk with a connection mask, `tile` px square: the boards across the
    way (see `boards_lie_east_west`). The boards are `width` px long, the tile's width unless
    given (for an icon, whose boards lie east to west)."""
    if boards_lie_east_west(mask):
        return _cast_shadows(_boards_east_west(tile, variant, mask, width or tile))
    boards = _boards_east_west(tile, variant, _transposed_mask(mask), tile)
    return _cast_shadows([list(column) for column in zip(*boards)])


def _boards_east_west(tile, variant, mask, width):
    """The boards of a tile lying east to west, their shadows not drawn yet. Everything random is
    drawn for every mask alike, so a variant's boards are the same boards in each of its masks."""
    rng = random.Random(f"plank_walk-{tile}-{variant}")
    scale = tile // 16
    picture = blank(width, tile)
    boards = _board_tops(tile, variant)
    dark_boards = set(rng.sample(range(len(boards)), 1 + variant % 2))
    # A butt joint, where two boards meet on a sleeper, in a board or two.
    joints = {index: rng.randrange(tile // 4, tile * 3 // 4) for index in rng.sample(range(len(boards)), 1 + variant % 2)}
    knots = rng.sample([index for index in range(len(boards)) if index not in joints], KNOTS[variant])
    for index, (top, rows) in enumerate(boards):
        left_inset, right_inset = rng.choice(END_INSETS[tile]), rng.choice(END_INSETS[tile])
        left_cut, right_cut = rng.choice(END_CUTS), rng.choice(END_CUTS)
        is_joint_at_seam = rng.random() < 0.4
        knot_x = rng.randrange(4 * scale, width - 4 * scale)
        # A board runs on to the tile's side where a way is beside it. Where none is it stops
        # short, the right end one pixel more: its shadow falls there.
        left = 0 if mask & WEST else left_inset
        right = width - 1 - (0 if mask & EAST else right_inset + 1)
        is_dark = index in dark_boards
        face = BOARD_DARK if is_dark else BOARD
        for row, part in enumerate(rows):
            y = top + row
            for x in range(left, right + 1):
                if part == "gap":
                    colour = BOARD_GAP
                elif part == "lit":
                    # The top edge is worn light in long stretches, never on a dark board.
                    is_worn = not is_dark and (x // (3 * scale) * 5 + index * 3 + variant) % 7 < 4
                    colour = BOARD_LIT if is_worn else face
                else:
                    colour = face
                    # Grain: short dark streaks along the board (too fine for 16 px).
                    if tile == 32 and (x // 4 * 5 + y * 3 + variant) % 13 == 0:
                        colour = BOARD_GAP if is_dark else BOARD_DARK
                picture[y][x] = colour
            # A board that stops has its end grain in shade.
            if part != "gap" and not mask & EAST:
                picture[y][right] = BOARD_GAP
        for is_open, x, cut in ((not mask & WEST, left, left_cut), (not mask & EAST, right, right_cut)):
            if is_open and cut != "square":
                picture[top if cut == "top" else top + len(rows) - 2][x] = None
        # A board that runs on from the tile to the west may be two, meeting on a sleeper.
        if mask & WEST and is_joint_at_seam:
            for row, part in enumerate(rows):
                if part != "gap":
                    picture[top + row][0] = BOARD_GAP
        # A nail at each end, where the board lies on a sleeper (at 32 px: at 16 they would
        # stand in dotted lines down the tile's sides).
        nails = [left + 2, right - 3]
        if index in joints:
            joint = joints[index]
            for row, part in enumerate(rows):
                if part != "gap":
                    picture[top + row][joint] = BOARD_GAP
            nails += [joint - 2, joint + 2]
        for x in nails if tile == 32 else ():
            picture[top + 1][x] = NAIL
        if index in knots:
            # A knot: a dark eye in a ring of darker wood, drawn out along the grain.
            eye_row = top + 1 + (len(rows) - 3) // 2
            picture[eye_row][knot_x] = BOARD_GAP
            if tile == 32:
                ring = BOARD_GAP if is_dark else BOARD_DARK
                picture[eye_row][knot_x - 1] = picture[eye_row][knot_x + 1] = ring
                if len(rows) > 3:
                    picture[eye_row + 1][knot_x] = ring
    _chip_long_sides(picture, mask, rng, tile)
    return picture


def _chip_long_sides(picture, mask, rng, tile):
    """Where no way lies beside the first or the last board, that board's outer edge is chipped, a
    pixel or two gone here and there; the last one loses its gap row, where its shadow falls."""
    width = len(picture[0])
    for side, y in ((NORTH, 0), (SOUTH, tile - 1)):
        chips = [(rng.randrange(width), rng.choice((1, 1, 2))) for _ in range(width // 8)]
        if mask & side:
            continue
        for x, length in chips:
            for chipped in range(x, min(x + length, width)):
                picture[y][chipped] = None
        if side == SOUTH:
            picture[y] = [None] * width


# The earth of the road edge, as it thins out from the way: the share of the pixels at each
# distance from the way that are earth, so the edge is trodden bare close to the way and breaks up
# into specks of earth in the grass further out.
EDGE_DENSITY = {32: (0.7, 0.85, 0.8, 0.6, 0.4, 0.2, 0.1), 16: (0.75, 0.8, 0.45, 0.2)}

# --- The stone path ---

# The stones' ramps, lit, face, shaded: cool grey granite, warm grey and brown fieldstone, and how
# often each comes.
STONE_RAMPS = (
    (("stone_light", "stone", "stone_dark"), 0.35),
    (("bare_light", "bare", "mud_dark"), 0.4),
    (("sand", "mud", "mud_dark"), 0.25),
)
# The earth between the stones.
JOINT = "mud_dark"
# The light from the top left, in the ground's plane.
LIGHT = (-0.6, -0.8)
# The stones of a tile at each size: how many, and how far in from the tile's sides a point must
# lie to be an inner one, which may move in a variant.
STONES = {32: 13, 16: 6}
INNER = {32: 8.0, 16: 5.0}
# How often the stones are evened out (`_relax`): fully they would lie in rows, which the few
# stones of a 16 px tile show most.
RELAX_STEPS = {32: 12, 16: 2}
# The joint between two stones, in px: where a pixel is this much nearer the one than the other.
JOINT_WIDTH = {32: 1.2, 16: 0.6}
# A stone is round: it reaches no further from its middle than this many times the radius of a
# circle of its share of the tile, so earth shows where three stones meet.
ROUNDNESS = {32: 1.12, 16: 1.3}
# The edge of a tile, in px, that is the same in every variant of the stone path.
SEAM_BAND = 2
# The kerb along a side that has no way beside it: the lengths of its stones along it (they add up
# to the tile, so a stone starts at the tile's corner and the next tile's go on), how far in from
# the tile's side a stone's outer face lies (never 0: its shadow falls there on the right and at the
# bottom) and how deep a stone is.
KERB_LENGTHS = {32: ((7, 6, 8, 5, 6), (6, 8, 5, 7, 6), (8, 5, 7, 6, 6)), 16: ((5, 4, 4, 3), (4, 5, 3, 4), (3, 4, 5, 4))}
KERB_OUTSETS = {32: (1, 2, 3), 16: (1, 2)}
KERB_DEPTHS = {32: (4, 5), 16: (2,)}


def _torus_offset(a, b, tile):
    """The shortest offset from `b` to `a` on a tile that repeats."""
    d = a - b
    return d - tile * round(d / tile)


def _relax(points, tile, is_movable, steps):
    """Lloyd's relaxation on the repeating tile: each movable point moves to the middle of the
    pixels nearest it, so the stones come out even in size."""
    points = list(points)
    for _ in range(steps):
        sums = [[0.0, 0.0, 0] for _ in points]
        for y in range(tile):
            for x in range(tile):
                px, py = x + 0.5, y + 0.5
                nearest = min(range(len(points)), key=lambda i: math.hypot(_torus_offset(px, points[i][0], tile), _torus_offset(py, points[i][1], tile)))
                sums[nearest][0] += _torus_offset(px, points[nearest][0], tile)
                sums[nearest][1] += _torus_offset(py, points[nearest][1], tile)
                sums[nearest][2] += 1
        points = [
            ((x + sx / n) % tile, (y + sy / n) % tile) if n and is_movable(i) else (x, y)
            for i, ((x, y), (sx, sy, n)) in enumerate(zip(points, sums))
        ]
    return points


def _is_inner(point, tile):
    x, y = point
    return min(x, y, tile - x, tile - y) >= INNER[tile]


def stone_points(tile, variant):
    """The middles of the stones of a variant: the same near the tile's sides in every variant,
    inner ones of their own."""
    rng = random.Random(f"stone_path-{tile}")
    points = [(rng.uniform(0, tile), rng.uniform(0, tile)) for _ in range(STONES[tile])]
    points = _relax(points, tile, lambda i: True, RELAX_STEPS[tile])
    if variant == 0:
        return points
    rng = random.Random(f"stone_path-{tile}-{variant}")
    inner = [i for i, point in enumerate(points) if _is_inner(point, tile)]
    margin = INNER[tile]
    moved = list(points)
    for i in inner:
        moved[i] = (rng.uniform(margin, tile - margin), rng.uniform(margin, tile - margin))
    # One stone more or fewer inside, for variety.
    if variant == 2 and inner:
        moved.append((rng.uniform(margin, tile - margin), rng.uniform(margin, tile - margin)))
        inner.append(len(moved) - 1)
    inner_set = set(inner)
    return _relax(moved, tile, lambda i: i in inner_set, 4)


def _pick_ramps(points, tile, ramps):
    """Gives each stone without a ramp in `ramps` (a list as long as `points`, None where there
    is none yet) the ramp its neighbours have least, then the one furthest below its share, so
    the greys and browns mix evenly and no two alike lie in a line."""
    spacing = tile / math.sqrt(len(points))
    used = {ramp: 0.0 for ramp, _ in STONE_RAMPS}
    for ramp in ramps:
        if ramp is not None:
            used[ramp] += 1
    for i, (x, y) in enumerate(points):
        if ramps[i] is not None:
            continue
        near = [
            ramps[j]
            for j, (ox, oy) in enumerate(points)
            if j != i and math.hypot(_torus_offset(x, ox, tile), _torus_offset(y, oy, tile)) < 1.5 * spacing
        ]
        ramps[i] = min(STONE_RAMPS, key=lambda entry: (near.count(entry[0]), used[entry[0]] / entry[1]))[0]
        used[ramps[i]] += 1
    return ramps


def _stones(tile, variant):
    """A tile of the stone path as its variant's stones lie, before its edge is made the first
    variant's (see `_field`)."""
    base = stone_points(tile, 0)
    points = stone_points(tile, variant)
    # The outer stones keep the ramps of the first variant, as they run on across the seams.
    base_ramps = _pick_ramps(base, tile, [None] * len(base))
    ramps = _pick_ramps(points, tile, [base_ramps[i] if i < len(base) and point == base[i] else None for i, point in enumerate(points)])
    light_x, light_y = LIGHT
    reach = ROUNDNESS[tile] * math.sqrt(tile * tile / len(points) / math.pi)
    picture = blank(tile)
    owners = {}
    for y in range(tile):
        for x in range(tile):
            px, py = x + 0.5, y + 0.5
            offsets = sorted(
                (math.hypot(dx, dy), dx, dy, i)
                for i, (dx, dy) in enumerate((_torus_offset(px, ox, tile), _torus_offset(py, oy, tile)) for ox, oy in points)
            )
            (d1, dx, dy, owner), (d2, *_) = offsets[0], offsets[1]
            to_edge = (d2 - d1) / 2
            if to_edge < JOINT_WIDTH[tile] / 2 or d1 > reach:
                picture[y][x] = JOINT
                continue
            lit, face, shaded = ramps[owner]
            # How far out on the stone's dome, 0 at its middle and 1 at its edge, and which way
            # it faces there.
            out = d1 / (d1 + to_edge)
            facing = (dx * light_x + dy * light_y) / d1 if d1 else 0.0
            light = facing * out**1.5
            if light > 0.6:
                colour = lit
            elif light < -0.3 or (to_edge < JOINT_WIDTH[tile] / 2 + 1 and facing < -0.2):
                colour = shaded
            else:
                colour = face
            picture[y][x] = colour
            owners[(x, y)] = owner
    if tile == 16:
        # A 16 px stone is too small for a dome: it is lit along its top and left edge and
        # shaded along its bottom and right one, where it meets the earth (the tile repeats).
        for (x, y), owner in owners.items():
            lit, face, shaded = ramps[owner]
            earth = {(dx, dy) for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)) if owners.get(((x + dx) % tile, (y + dy) % tile)) != owner}
            if earth & {(1, 0), (0, 1)}:
                picture[y][x] = shaded
            elif earth:
                picture[y][x] = lit
            else:
                picture[y][x] = face
    return picture


@functools.cache
def _field(tile, variant):
    """The cobbles of a tile, without a kerb: an inner stone may reach a pixel or two into the
    edge, but the edge is the first variant's, so all variants meet at the seams."""
    picture = _stones(tile, variant)
    if variant:
        first = _field(tile, 0)
        for y in range(tile):
            for x in range(tile):
                if min(x, y, tile - 1 - x, tile - 1 - y) < SEAM_BAND:
                    picture[y][x] = first[y][x]
    return tuple(tuple(row) for row in picture)


def _kerb_stones(tile, variant, side):
    """The edging stones along one side, in order, each (first row or column along the side, length,
    outset, depth, ramp)."""
    rng = random.Random(f"stone_path_kerb-{tile}-{variant}-{side}")
    stones = []
    start = 0
    ramp = None
    for length in KERB_LENGTHS[tile][variant]:
        ramp = rng.choice([other for other, _ in STONE_RAMPS if other != ramp])
        stones.append((start, length, rng.choice(KERB_OUTSETS[tile]), rng.choice(KERB_DEPTHS[tile]), ramp))
        start += length
    return stones


def _tile_place(side, along, depth, tile):
    """The (x, y) of the pixel `along` the kerb of `side` and `depth` in from the tile's side."""
    return {WEST: (depth, along), EAST: (tile - 1 - depth, along), NORTH: (along, depth), SOUTH: (along, tile - 1 - depth)}[side]


def _add_kerb(picture, tile, variant, mask):
    """Sets the edging stones along every side of the tile that has no way beside it, over the
    cobbles: each stone with its outer face its own distance from the side, so the edge is not
    straight, its outer corners rounded off, lit on its top and left and shaded on its bottom
    and right; the earth lies in the joints and between the kerb and the cobbles."""
    stones_of = {}
    # The kerb of the north and south sides runs to the corners; the west and east kerbs begin where
    # it ends.
    for side in (WEST, EAST, NORTH, SOUTH):
        if not mask & side:
            stones_of[side] = _kerb_stones(tile, variant, side)
    owners = {}
    for side, stones in stones_of.items():
        corner = max(outset + depth + 1 for _, _, outset, depth, _ in stones)
        low = corner if side in (WEST, EAST) and not mask & NORTH else 0
        high = tile - corner if side in (WEST, EAST) and not mask & SOUTH else tile
        for number, (first, length, outset, depth, ramp) in enumerate(stones):
            first, end = max(first, low), min(first + length, high)
            if end - first < 3:
                continue
            for along in range(first, end):
                for inward in range(outset + depth + 1):
                    x, y = _tile_place(side, along, inward, tile)
                    owners.pop((x, y), None)
                    if inward < outset:
                        picture[y][x] = None
                    elif inward == outset + depth or along == first:
                        picture[y][x] = JOINT
                    elif inward == outset and along in (first + 1, end - 1):
                        picture[y][x] = None
                    else:
                        owners[(x, y)] = ((side, number), ramp)
    for (x, y), (stone, (lit, face, shaded)) in owners.items():
        def is_beyond(dx, dy):
            return owners.get((x + dx, y + dy), (None,))[0] != stone

        if is_beyond(1, 0) or is_beyond(0, 1):
            picture[y][x] = shaded
        elif is_beyond(-1, 0) or is_beyond(0, -1):
            picture[y][x] = lit
        else:
            picture[y][x] = face


def stone_path(tile, variant, mask=ALL_SIDES):
    """One tile of the stone path with a connection mask, `tile` px square."""
    picture = [list(row) for row in _field(tile, variant)]
    _add_kerb(picture, tile, variant, mask)
    return _cast_shadows(picture)


def way_edge(tile, mask):
    """What a free tile gets whose neighbours on the sides of `mask` are ways, `tile` px square:
    along each of those sides the earth the way's edge is trodden into, thinning out into specks
    of earth in the grass, so it has no line of its own along the way's ragged edge."""
    picture = blank(tile)
    for side in (NORTH, EAST, SOUTH, WEST):
        if not mask & side:
            continue
        rng = random.Random(f"way_edge-{tile}-{side}")
        for along in range(tile):
            for depth, density in enumerate(EDGE_DENSITY[tile]):
                is_earth, roll = rng.random() < density, rng.random()
                x, y = _tile_place(side, along, depth, tile)
                if is_earth and picture[y][x] is None:
                    picture[y][x] = "mud" if roll < 0.5 else "sand" if roll < 0.8 else "mud_dark"
    return picture


def in_cell(picture, cell_width, cell_height):
    """A tile's picture at the bottom middle of its object cell, where its tile is."""
    canvas = blank(cell_width, cell_height)
    left = (cell_width - len(picture[0])) // 2
    top = cell_height - len(picture)
    for y, row in enumerate(picture):
        canvas[top + y][left : left + len(row)] = row
    return canvas


def plank_walk_row(tile, cell_width, cell_height):
    """The atlas row of the plank walk: each variant's pictures, one per connection mask."""
    return [in_cell(plank_walk(tile, variant, mask), cell_width, cell_height) for variant in range(PLANK_VARIANTS) for mask in range(CONNECTION_LOOKS)]


def stone_path_row(tile, cell_width, cell_height):
    return [in_cell(stone_path(tile, variant, mask), cell_width, cell_height) for variant in range(STONE_VARIANTS) for mask in range(CONNECTION_LOOKS)]


def way_edge_row(tile, cell_width, cell_height):
    """The atlas row of the road edge: one picture per mask of the sides that have a way beside them."""
    return [in_cell(way_edge(tile, mask), cell_width, cell_height) for mask in range(CONNECTION_LOOKS)]


def plank_walk_piece(tile):
    """The picture of the plank walk's item: a few boards of its first variant, a little shorter
    than the tile, so the icon's outline fits round them."""
    boards = _board_tops(tile)
    first, last = (2, 7) if tile == 32 else (0, 4)
    return plank_walk(tile, 0, NORTH | SOUTH, tile - 4)[boards[first][0] : boards[last][0]]


def stone_path_piece(tile):
    """The picture of the stone path's item: a slab of its first variant, as the plank walk's is
    a few boards, a little smaller than the tile so the icon's outline fits round it, its
    corners rounded off."""
    inset = tile // 16
    picture = [row[inset : tile - inset] for row in stone_path(tile, 0)[2 * inset : tile - 2 * inset]]
    width, height = len(picture[0]), len(picture)
    for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        picture[y][x] = None
    return picture


def icons(tile, icon_of):
    """The icons of the items that lay the ways, by item id, made by the art set's `icon_of`."""
    return {"plank_walk": icon_of(plank_walk_piece(tile)), "stone_path": icon_of(stone_path_piece(tile))}
