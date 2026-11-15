"""The ways the player lays tile by tile to walk on (issue #62): a plank walk and a stone path,
for both art sets (the classic generator imports this module too, with its 16 px tile).

Each is a full-tile piece of ground in the object atlas, drawn flat like the jetty's deck, so the
player walks over it: a picture as big as the tile, set at the bottom of its cell. It has no
connection masks; instead every variant meets every other at the seams, so a way of any shape
reads as one. Both are kept low in contrast, a step from the worn path and the grass beside them.

- The plank walk: weathered oak boards lying across the tile (east to west), with a dark gap
  between them, the top edge of each worn light in stretches, grain, a knot here and there and a
  nail at each end where it lies on the sleepers. The board ends stagger a pixel at the tile's
  sides, where the grass shows between them.
- The stone path: rounded fieldstones set in dark earth, cool and warm greys and a few brown
  ones, each lit on its top left and shaded on its lower right. The stones are the cells of a
  set of points that repeats every tile; the points near the tile's sides are the same in every
  variant (so the stones run on across the seams, with no straight line along them) and only the
  inner stones differ.

Light from the top left, as everywhere.
"""

import math
import random

from canvas import blank

# Weathered oak boards, as the jetty's deck: the worn top edge, the face and the gap.
BOARD_LIT, BOARD, BOARD_GAP = "bare_light", "bare", "mud_dark"
# A board of darker, browner oak, here and there among the grey ones, and its grain.
BOARD_DARK = "mud"
NAIL = "stone_dark"
# The rows of a board, from its top edge: (lit edge, face, gap). At 32 px a board is 4 px wide;
# at 16 px the boards are 3 px and one of 4, as 16 does not divide by 3.
BOARD_ROWS = {32: ("lit", "face", "face", "gap"), 16: ("lit", "face", "gap")}
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
PLANK_VARIANTS = 2
STONE_VARIANTS = 3


def _board_tops(tile):
    """The top rows of the boards of a tile, and the rows each has."""
    if tile == 32:
        return [(top, BOARD_ROWS[32]) for top in range(0, tile, 4)]
    tops = []
    top = 0
    while top < tile:
        rows = BOARD_ROWS[16] if top < 12 else ("lit", "face", "face", "gap")
        tops.append((top, rows))
        top += len(rows)
    return tops


def plank_walk(tile, variant, width=None):
    """One tile of the plank walk, `tile` px square: the boards across it, from the top. The
    boards are `width` px long, the tile's width unless given (for an icon)."""
    rng = random.Random(f"plank_walk-{tile}-{variant}")
    scale = tile // 16
    width = width or tile
    picture = blank(width, tile)
    boards = _board_tops(tile)
    dark_boards = set(rng.sample(range(len(boards)), 1 + variant))
    # A butt joint, where two boards meet on a sleeper, in a board or two.
    joints = {index: rng.randrange(tile // 4, tile * 3 // 4) for index in rng.sample(range(len(boards)), 1 + variant)}
    knots = rng.sample([index for index in range(len(boards)) if index not in joints], 1 + (variant + 1) % 2)
    for index, (top, rows) in enumerate(boards):
        # The ends stagger: some boards stop a pixel short of the tile's side.
        left = rng.choice((0, 0, 1))
        right = width - 1 - rng.choice((0, 0, 1))
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
            if part != "gap":
                # The right end of a board is in its own shade; its shadow falls on the grass.
                picture[y][right] = BOARD_GAP
                if right < width - 1:
                    picture[y][right + 1] = "shadow"
        face_row = top + 1
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
            picture[face_row][x] = NAIL
        if index in knots:
            # A knot: a dark eye in a ring of darker wood, drawn out along the grain.
            x = rng.randrange(4 * scale, width - 4 * scale)
            picture[face_row][x] = BOARD_GAP
            if tile == 32:
                ring = BOARD_GAP if is_dark else BOARD_DARK
                picture[face_row][x - 1] = picture[face_row][x + 1] = ring
                picture[face_row + 1][x] = ring
    return picture


# --- The stone path ---

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
    variant's (see `stone_path`)."""
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


def stone_path(tile, variant):
    """One tile of the stone path, `tile` px square."""
    picture = _stones(tile, variant)
    if variant:
        # An inner stone may reach a pixel or two into the edge: the edge is the first
        # variant's, so all variants meet at the seams.
        first = stone_path(tile, 0)
        for y in range(tile):
            for x in range(tile):
                if min(x, y, tile - 1 - x, tile - 1 - y) < SEAM_BAND:
                    picture[y][x] = first[y][x]
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
    return [in_cell(plank_walk(tile, variant), cell_width, cell_height) for variant in range(PLANK_VARIANTS)]


def stone_path_row(tile, cell_width, cell_height):
    return [in_cell(stone_path(tile, variant), cell_width, cell_height) for variant in range(STONE_VARIANTS)]


def plank_walk_piece(tile):
    """The picture of the plank walk's item: a few boards of its first variant, a little shorter
    than the tile, so the icon's outline fits round them."""
    boards = _board_tops(tile)
    first, last = (2, 7) if tile == 32 else (0, 4)
    return plank_walk(tile, 0, tile - 4)[boards[first][0] : boards[last][0]]


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
