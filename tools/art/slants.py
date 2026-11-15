"""The slanting pieces of a line across the land (the dyke), for both art sets.

A line is laid tile by tile and joins its neighbours on their sides (see boundaries.py), so where
it runs on the slant it is a stair of corners. A corner whose neighbour across one of its sides is
a corner turning the other way (a tile joined west and south, its neighbour to the south joined
north and east) is a step of such a stair: the line crosses that side on the slant, at 45 degrees,
through the side's middle (LineSlants in the game). A corner slanted on both sides is
a straight diagonal from the middle of one side to the middle of the other, so a stair of them is
one straight bank running corner to corner across the land; a corner slanted on one side only
bends from straight across its other side into the diagonal, the join between a straight and a
diagonal stretch.

The line is narrower across where it runs on the slant: its foot reaches out a half tile from the
skeleton across a straight side, but only half the tile's diagonal across a slanted one, which is
how far the corners of the stair's tiles are from the diagonal. So the bank comes down to the
ground in the notches of the stair and stays on the line's own tiles.
"""

import math

# The sides a line joins, as (bit, direction), in the order of the mask bits (as boundaries.py).
SIDES = ((1, (0, -1)), (2, (1, 0)), (4, (0, 1)), (8, (-1, 0)))
CORNERS = (0b0011, 0b0110, 0b1001, 0b1100)
# The pictures of a slanting line after its 16 of the connection masks, as (mask, slanted sides):
# each corner, slanted on its lower side, on its higher side, on both.
SLANTED = tuple(
    (mask, slants)
    for mask in CORNERS
    for slants in (mask & -mask, mask & ~(mask & -mask), mask)
)
# How far along its tangent a bend's control points lie, in tiles: from a straight side, and from
# a slanted side, which is longer so the bend runs out along the diagonal almost straight, as the
# step across it carries the diagonal on (it does not know whether this piece bends).
_BEND = 0.25
_SLANTED_BEND = 0.6
# Points along a bend.
_STEPS = 48


def _sides(mask):
    return [(bit, direction) for bit, direction in SIDES if mask & bit]


def _normal(x, y):
    length = math.hypot(x, y)
    return (x / length, y / length)


class Skeleton:
    """The skeleton of a slanted corner on a tile `tile` px wide: a curve from the middle of one
    side it joins to the middle of the other, running on straight into the neighbours past them.
    `foot` is how far the line reaches out from its skeleton across a straight side."""

    def __init__(self, mask, slants, tile, foot):
        assert mask in CORNERS and slants and not slants & ~mask
        centre = tile / 2
        (bit_a, side_a), (bit_b, side_b) = _sides(mask)
        diagonal = _normal(side_b[0] - side_a[0], side_b[1] - side_a[1])
        start = (centre + side_a[0] * centre, centre + side_a[1] * centre)
        end = (centre + side_b[0] * centre, centre + side_b[1] * centre)
        # Heading in across side a and out across side b.
        heading_in = diagonal if slants & bit_a else (-side_a[0], -side_a[1])
        heading_out = diagonal if slants & bit_b else side_b
        slanted_foot = foot / math.sqrt(2)
        foot_in = slanted_foot if slants & bit_a else foot
        foot_out = slanted_foot if slants & bit_b else foot
        # The inner corner of the turn, which the bank must not reach past its foot.
        inner = (centre + centre * (side_a[0] + side_b[0]), centre + centre * (side_a[1] + side_b[1]))
        bend_in = (_SLANTED_BEND if slants & bit_a else _BEND) * tile
        bend_out = (_SLANTED_BEND if slants & bit_b else _BEND) * tile
        controls = (
            start,
            (start[0] + heading_in[0] * bend_in, start[1] + heading_in[1] * bend_in),
            (end[0] - heading_out[0] * bend_out, end[1] - heading_out[1] * bend_out),
            end,
        )
        reach = 2 * tile
        points = [(start[0] - heading_in[0] * reach, start[1] - heading_in[1] * reach)]
        feet = [foot_in]
        for step in range(_STEPS + 1):
            t = step / _STEPS
            point = _bezier(controls, t)
            points.append(point)
            feet.append(min(foot_in + (foot_out - foot_in) * t, math.dist(point, inner)))
        points.append((end[0] + heading_out[0] * reach, end[1] + heading_out[1] * reach))
        feet.append(foot_out)
        self._points = points
        self._feet = feet

    def at(self, x, y):
        """(how far ground point (x, y) is from the skeleton, the line's foot at its nearest
        point)."""
        best = (math.inf, 0.0)
        for index in range(len(self._points) - 1):
            (ax, ay), (bx, by) = self._points[index], self._points[index + 1]
            dx, dy = bx - ax, by - ay
            along = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
            distance = math.hypot(x - ax - dx * along, y - ay - dy * along)
            if distance < best[0]:
                foot = self._feet[index] + (self._feet[index + 1] - self._feet[index]) * along
                best = (distance, foot)
        return best


def _bezier(controls, t):
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = controls
    u = 1 - t
    a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
    return (a * x0 + b * x1 + c * x2 + d * x3, a * y0 + b * y1 + c * y2 + d * y3)
