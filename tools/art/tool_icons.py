"""The icons of the tools: hoe, axe, pickaxe, watering can, scythe, spade and hammer, at 32 px.

Each lies on the diagonal from the bottom left to the top right, the classic item-icon pose:
a round wooden handle 3 px thick (ash, lit on its upper left, the grain in streaks) with the
working end at the top right. As art-style.md has them, the tools are of wood with iron only
where they cut or strike: the iron is in the IRON ramp with its edge bright, so a better tool
later is the same icon with that ramp swapped. The pickaxe is the Geest's pick for grubbing
out the fieldstones of the till and splitting them, a point on one side and a broad chisel on
the other; the spade is wooden with an iron shoe. The watering can is all copper, as cans
were before tin-plate. Bodies by item id, outlined by items.icon.
"""

import math

import numpy as np

from items import COPPER, ICON, IRON, capsule, dots, edge_of, ellipse, limb, line, paint, polygon, shade
from canvas import blank

# Ash for the handles, lit to dark... as a ramp, dark to light.
ASH = ("soil_mid", "soil_light", "sand_light")


def handle(picture, start, end, radius=1.6):
    """A round handle from `start` to `end`, lit on its upper left, a streak of grain on it."""
    mask = capsule(start, end, radius)
    shade(picture, mask, ASH, radius=2)
    (x0, y0), (x1, y1) = start, end
    for t in (0.3, 0.62):
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        dots(picture, [(round(x), round(y)), (round(x + 1), round(y - 1))], "soil_mid")
    return mask


def along(start, end):
    """The pixels' distance along the line from `start` towards `end` and across it (positive
    to the left of the way), as arrays as big as the icon."""
    ys, xs = np.mgrid[0:ICON, 0:ICON]
    (x0, y0), (x1, y1) = start, end
    length = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / length, (y1 - y0) / length
    dx, dy = xs + 0.5 - x0, ys + 0.5 - y0
    return dx * ux + dy * uy, dx * uy - dy * ux


def iron(picture, mask):
    """Forged iron, flat but for its rims: lit along its top and left, dark along its bottom
    and right."""
    paint(picture, mask, IRON[1])
    paint(picture, edge_of(mask, "bottom") | edge_of(mask, "right"), IRON[0])
    paint(picture, edge_of(mask, "top") | edge_of(mask, "left"), IRON[2])


def bright_edge(picture, mask, side_mask):
    """Gives the pixels of `mask` in `side_mask` the bright edge of the iron."""
    paint(picture, mask & side_mask, IRON[3])


def hoe():
    """A long handle, a thin iron neck off its top to the right and a flat blade at the neck's
    end, hanging down, its edge bright."""
    picture = blank(ICON)
    handle(picture, (4, 29), (21, 8))
    iron(picture, capsule((20, 7), (26, 6), 1.3))
    blade = polygon([(23, 6), (30, 6), (30, 18), (22, 17)])
    iron(picture, blade)
    line(picture, 22, 17, 30, 18, IRON[3])
    line(picture, 25, 8, 25, 14, IRON[2])
    return picture


def axe():
    """An axe head on the left of the handle's top, fanning out to a curved edge, bright; the
    short poll on the right."""
    picture = blank(ICON)
    handle(picture, (5, 29), (21, 6))
    head = polygon([(24, 3), (24, 10), (17, 10), (10, 15), (5, 16), (3, 10), (5, 2), (10, 1), (17, 4)])
    iron(picture, head)
    edge = ellipse(17, 8.5, 13, 10) & ~ellipse(18.5, 8.5, 13, 10)
    bright_edge(picture, head, edge)
    line(picture, 8, 6, 15, 6, IRON[2])
    iron(picture, polygon([(24, 4), (27, 4), (27, 10), (24, 10)]))
    return picture


def pickaxe():
    """The pick of the Geest: a curved iron head across the top of the handle, pointed on one
    side and a broad chisel on the other."""
    picture = blank(ICON)
    handle(picture, (5, 29), (19, 11))
    centre = np.array((19.0, 11.0))
    way = np.array((0.707, 0.707))
    bow = np.array((0.707, -0.707))
    points = [tuple(centre + way * s + bow * 3.5 * (1 - (s / 13) ** 2)) for s in (-13, -7, 0, 7, 13)]
    iron(picture, limb(points, [2.8, 2.4, 2.8, 1.7, 0.6]))
    chisel = points[0]
    line(picture, round(chisel[0]) - 3, round(chisel[1]) + 1, round(chisel[0]) + 1, round(chisel[1]) - 3, IRON[3])
    dots(picture, [(round(points[-1][0]) - 1, round(points[-1][1]) - 1)], IRON[3])
    return picture


def scythe():
    """A long snath with a grip peg, and a long curved blade off its top to the left, its
    edge bright."""
    picture = blank(ICON)
    handle(picture, (5, 30), (24, 5), radius=1.4)
    peg = capsule((10, 19), (14, 22), 1.2)
    shade(picture, peg, ASH, radius=1)
    points = [(25, 4), (17, 2), (9, 4), (4, 8), (2, 13)]
    blade = limb(points, [2.6, 2.3, 1.8, 1.2, 0.5])
    iron(picture, blade)
    under = limb([(x + 0.7, y + 1.8) for x, y in points], [1.4, 1.2, 0.9, 0.6, 0.2])
    bright_edge(picture, blade, under)
    return picture


def shovel():
    """A wooden spade with an iron shoe: a T-grip at the top right, the square blade at the
    bottom left, its iron-shod edge bright."""
    picture = blank(ICON)
    handle(picture, (14, 18), (24, 8))
    shade(picture, capsule((21, 4), (28, 11), 1.5), ASH, radius=1)
    run, across = along((15, 17), (4, 28))
    half = np.minimum(1.8 + run * 1.6, 5.2)
    blade = (run >= 0) & (run < 15) & (np.abs(across) < half)
    shade(picture, blade, ASH, radius=2)
    paint(picture, blade & (np.abs(across) < 0.8) & (run > 3) & (run < 10), "soil_mid")
    iron(picture, blade & (run > 11))
    bright_edge(picture, blade, run > 13.8)
    return picture


def hammer():
    """A heavy iron head across the top of the handle, its striking faces bright, a wedge in
    its eye."""
    picture = blank(ICON)
    handle(picture, (5, 29), (20, 11))
    head = polygon([(27, 13), (23, 17), (13, 7), (17, 3)])
    iron(picture, head)
    line(picture, 13, 7, 17, 3, IRON[3])
    line(picture, 14, 7, 17, 4, IRON[3])
    dots(picture, [(20, 10), (21, 9)], "soil_light")
    return picture


def watering_can():
    """A copper can of the old kind: a tall round body with bands, a handle arching over the
    top, and a long spout from its foot to a big round rose, its face pricked with holes."""
    picture = blank(ICON)
    arch = limb([(4, 15), (6, 7), (12, 4), (18, 8), (19, 13)], [1.4] * 5)
    shade(picture, arch, COPPER[:3], radius=1)
    spout = capsule((18, 25), (26, 10), 1.7, 1.1)
    shade(picture, spout, COPPER[:3], radius=1)
    body = ellipse(11.5, 20, 8.5, 9.5)
    shade(picture, body, COPPER, radius=4)
    for y in (14, 26):
        line(picture, 4, y, 19, y, "ochre_dark")
    paint(picture, ellipse(11.5, 11.5, 4, 1.3), "umber")
    rose = ellipse(27, 7.5, 3.8, 4.8, angle=-35)
    shade(picture, rose, COPPER[1:], radius=1)
    dots(picture, [(26, 6), (28, 7), (27, 9), (26, 8), (28, 5)], "umber")
    return picture


ICONS = {
    "hoe": hoe,
    "axe": axe,
    "pickaxe": pickaxe,
    "watering_can": watering_can,
    "scythe": scythe,
    "shovel": shovel,
    "hammer": hammer,
}


def icons():
    """The bodies of the tools' icons, by item id."""
    return {item: draw() for item, draw in ICONS.items()}
