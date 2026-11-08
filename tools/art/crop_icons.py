"""The icons of what crops give and need besides their sheets (see crops.py), at 32 px: the
produce, and a seed sack per crop.

The produce is drawn like the crops in the field: rounded forms shaded from the top left. A seed
sack is the same linen sack for every crop, told apart at a glance by the string it is tied with
(in the crop's colour), the crop itself painted on its front (its produce at half size) and a
few of its seeds spilled in front of it. Bodies by item id, outlined by items.icon.
"""

import math

from canvas import blank
from items import ICON, box, icon, capsule, dots, ellipse, limb, line, paint, polygon, shade, small

LEAF = ("green_dark", "green", "green_light")


def leaf(picture, start, end, width, ramp=LEAF):
    """A leaf from its stalk at `start` to its tip at `end`, `width` px at its widest, its
    midrib in the darkest shade."""
    (x0, y0), (x1, y1) = start, end
    mask = limb([start, ((x0 + x1) / 2, (y0 + y1) / 2), end], [0.6, width / 2, 0.4])
    shade(picture, mask, ramp, radius=2)
    line(picture, round(x0), round(y0), round(x1), round(y1), ramp[0])


def turnip():
    """A white turnip, purple at the shoulder, with its leaf stalks cut short and a long root."""
    picture = blank(ICON)
    for start, end in (((15, 11), (10, 2)), ((16, 11), (17, 1)), ((17, 11), (24, 3))):
        leaf(picture, start, end, 4, ("green_dark", "green_light", "green_bright"))
    body = ellipse(16, 18, 10, 8)
    shade(picture, body, ("snow_shadow", "cream", "snow_light"), radius=4)
    shade(picture, body & ellipse(16, 12, 12, 6), ("heather_dark", "heather", "petal"), radius=2)
    line(picture, 16, 26, 17, 30, "sand_light")
    dots(picture, [(17, 31)], "sand")
    return picture


def potato():
    """Two potatoes, one before the other, their skins with eyes."""
    picture = blank(ICON)
    for cx, cy, rx, ry, angle in ((20, 14, 9, 6.5, 15), (12, 20, 10, 7, -10)):
        shade(picture, ellipse(cx, cy, rx, ry, angle), ("mud", "sand", "sand_light"), radius=3)
        for dx, dy in ((-4, -1), (2, 2), (4, -2), (-1, 3)):
            dots(picture, [(cx + dx, cy + dy)], "mud")
    return picture


def carrot():
    """A carrot lying on the diagonal, its leaves at the top right."""
    picture = blank(ICON)
    for end in ((26, 2), (30, 5), (22, 3)):
        leaf(picture, (20, 11), end, 3, ("green_dark", "green_light", "green_bright"))
    root = capsule((19, 12), (4, 28), 4.5, 0.6)
    shade(picture, root, ("ember", "flame", "leaf_orange"), radius=3)
    for t in (0.25, 0.45, 0.65):
        x, y = 19 - 15 * t, 12 + 16 * t
        line(picture, round(x), round(y), round(x + 2), round(y + 2), "ember")
    return picture


def cabbage():
    """A head of cabbage, round and tight, its outer leaves folded round it with pale veins."""
    picture = blank(ICON)
    for cx, cy, rx, ry, angle in ((7, 21, 6, 8, 30), (25, 21, 6, 8, -30), (16, 25, 10, 5, 0)):
        shade(picture, ellipse(cx, cy, rx, ry, angle), ("green_dark", "green", "green_light"), radius=2)
    head = ellipse(16, 15, 10, 10)
    shade(picture, head, ("green", "green_light", "green_bright"), radius=4)
    for start, end in (((16, 6), (16, 22)), ((10, 9), (15, 21)), ((22, 9), (17, 21))):
        line(picture, *start, *end, "green")
    dots(picture, [(11, 11), (12, 10)], "spring_pale")
    return picture


def onion():
    """A golden onion, its papery skin streaked, the dry neck on top and roots below."""
    picture = blank(ICON)
    body = ellipse(16, 19, 10, 9)
    neck = polygon([(13, 11), (19, 11), (17, 4), (15, 4)])
    shade(picture, body | neck, ("reed", "straw", "gold"), radius=4)
    for x0 in (10, 14, 19, 22):
        line(picture, 16, 11, x0, 26, "reed")
    line(picture, 16, 3, 18, 1, "straw")
    for x in (13, 16, 19):
        line(picture, x, 28, x + (x - 16) // 2, 30, "sand_light")
    return picture


def sheaf(picture, ear):
    """A sheaf of corn: stalks fanning up from a straw band, `ear(picture, x, y)` drawing each
    ear at its stalk's top."""
    tops = ((6, 7), (10, 5), (14, 4), (18, 4), (22, 5), (26, 7))
    for index, (x, y) in enumerate(tops):
        line(picture, x + 1, y + 4, 15 + index // 3, 29, "straw" if index % 2 else "reed")
        line(picture, x + 2, y + 4, 16 + index // 3, 29, "reed" if index % 2 else "straw")
    for x, y in tops:
        ear(picture, x, y)
    band = box(11, 20, 21, 22)
    shade(picture, band, ("umber", "ochre_dark", "ochre"), radius=1)


def wheat():
    """A sheaf of wheat: golden ears of paired grains with long awns."""
    picture = blank(ICON)

    def ear(picture, x, y):
        shade(picture, ellipse(x + 1.5, y + 2, 2, 4), ("ochre_dark", "ochre", "gold"), radius=1)
        for dy in (0, 2):
            dots(picture, [(x, y + dy), (x + 2, y + dy + 1)], "ochre_dark")
        line(picture, x + 1, y - 2, x, y - 5, "straw")

    sheaf(picture, ear)
    return picture


def rye():
    """A sheaf of rye: pale, slim ears nodding over to the right."""
    picture = blank(ICON)

    def ear(picture, x, y):
        shade(picture, capsule((x + 1, y), (x + 4, y + 6), 1.3), ("sand", "sand_light", "lime"), radius=1)
        dots(picture, [(x + 2, y + 2), (x + 3, y + 4)], "sand")
        line(picture, x + 1, y, x - 1, y - 3, "sand_light")

    sheaf(picture, ear)
    return picture


def buckwheat():
    """A heap of buckwheat: small brown three-cornered grains, each lit on its upper face."""
    picture = blank(ICON)
    heap = [(16, 9), (11, 12), (21, 12), (7, 16), (16, 15), (25, 16), (11, 19), (21, 19), (5, 22), (15, 22), (26, 22), (9, 25), (20, 25)]
    for x, y in heap:
        grain = polygon([(x, y - 3), (x + 4, y + 3), (x - 4, y + 3)])
        shade(picture, grain, ("soil_dark", "soil", "soil_light"), radius=2)
        line(picture, x, y - 2, x, y + 2, "soil_mid")
    return picture


def peas():
    """A pea pod split open on the diagonal, its round peas in a row."""
    picture = blank(ICON)
    pod = limb([(3, 25), (12, 18), (22, 10), (28, 4)], [1.5, 4.5, 4.5, 1.2])
    shade(picture, pod, ("green_dark", "green", "green_light"), radius=2)
    for t in (0.2, 0.37, 0.54, 0.71):
        x, y = 4 + 23 * t, 24 - 20 * t
        shade(picture, ellipse(x, y, 2.6, 2.6), ("green_light", "green_bright", "spring_pale"), radius=1)
    line(picture, 28, 4, 30, 1, "green_dark")
    return picture


def beans():
    """Three broad bean pods, long and lumpy over their beans, side by side."""
    picture = blank(ICON)
    for x, lean in ((8, -2), (16, 0), (24, 2)):
        points = [(x + lean * y / 29, y) for y in (3, 7, 11, 15, 19, 23, 28)]
        pod = limb(points, [1.6, 3.4, 2.7, 3.4, 2.7, 3.4, 1.8])
        shade(picture, pod, ("green", "green_light", "green_bright"), radius=2)
        for y in (7, 15, 23):
            dots(picture, [(round(x + lean * y / 29) - 1, y - 1)], "spring_pale")
        line(picture, x, 2, x - 1, 0, "green_dark")
    return picture


def flax():
    """A bundle of flax stalks, tied, with blue flowers and seed bolls at the top."""
    picture = blank(ICON)
    for index, x in enumerate((5, 9, 13, 17, 21, 25)):
        line(picture, x, 7, 13 + index, 29, "straw" if index % 2 else "dry_light")
    for x, y in ((5, 5), (13, 3), (21, 5)):
        shade(picture, ellipse(x, y, 3, 3), ("water", "water_light", "foam"), radius=1)
        dots(picture, [(x, y)], "cream")
    for x, y in ((9, 5), (17, 4), (25, 6)):
        shade(picture, ellipse(x, y, 1.5, 2), ("reed", "straw", "sand_light"), radius=1)
    shade(picture, box(10, 18, 22, 20), ("soil", "soil_mid", "soil_light"), radius=1)
    return picture


def strawberries():
    """Three small wild strawberries on their stalks, under a three-lobed leaf."""
    picture = blank(ICON)
    for end in ((9, 4), (16, 2), (23, 4)):
        leaf(picture, (16, 10), end, 6)
    for x0, y0, x1, y1 in ((15, 10, 9, 17), (16, 10, 17, 21), (17, 10, 24, 16)):
        line(picture, x0, y0, x1, y1, "green_dark")
    for x, y in ((8, 21), (17, 25), (24, 20)):
        berry = polygon([(x - 4, y - 3), (x + 4, y - 3), (x + 3, y + 2), (x, y + 5), (x - 3, y + 2)])
        shade(picture, berry, ("rust_dark", "ember", "red_light"), radius=2)
        dots(picture, [(x - 2, y - 1), (x + 1, y), (x - 1, y + 2), (x + 2, y - 2)], "gold")
        line(picture, x - 3, y - 4, x + 3, y - 4, "green")
    return picture


def pumpkin():
    """A small green garden squash, ribbed and mottled (the item id stays pumpkin)."""
    picture = blank(ICON)
    body = ellipse(16, 19, 13, 9.5)
    shade(picture, body, ("green_deep", "olive", "dry_light"), radius=4)
    for x, bulge in ((9, -1), (16, 0), (23, 1)):
        rib = [(round(x + bulge * 2 * math.sin(math.pi * (y - 10) / 18)), y) for y in range(11, 28)]
        dots(picture, [(rx, y) for rx, y in rib if body[y, rx]], "green_deep")
    dots(picture, [(7, 16), (12, 22), (19, 15), (24, 21), (13, 14)], "straw")
    shade(picture, capsule((16, 10), (18, 4), 1.6), ("soil", "soil_mid", "soil_light"), radius=1)
    return picture


PRODUCE = {
    "turnip": turnip,
    "potato": potato,
    "carrot": carrot,
    "cabbage": cabbage,
    "onion": onion,
    "wheat": wheat,
    "rye": rye,
    "buckwheat": buckwheat,
    "peas": peas,
    "beans": beans,
    "flax": flax,
    "strawberries": strawberries,
    "pumpkin": pumpkin,
}

# What tells each crop's seed sack apart besides its produce painted on it: the colour of the
# string it is tied with, and the ramp of its seeds, dark to light.
SACKS = {
    "turnip": ("heather", ("soil_dark", "soil", "soil_mid")),
    "potato": ("soil_light", ("mud", "sand", "sand_light")),
    "carrot": ("flame", ("soil", "soil_mid", "soil_light")),
    "cabbage": ("green_light", ("soil_dark", "soil", "soil_mid")),
    "onion": ("gold", ("ink", "stone_dark", "stone")),
    "wheat": ("ochre", ("ochre_dark", "ochre", "gold")),
    "rye": ("straw", ("mud", "sand", "sand_light")),
    "buckwheat": ("petal", ("soil_dark", "soil", "soil_light")),
    "peas": ("green_bright", ("green", "green_light", "green_bright")),
    "beans": ("green_dark", ("soil", "soil_mid", "soil_light")),
    "flax": ("water_light", ("umber", "ochre_dark", "ochre")),
    "strawberries": ("ember", ("rust_dark", "ember", "red_light")),
    "pumpkin": ("olive", ("sand", "sand_light", "cream")),
}


def seed_sack(produce, tie, seeds):
    """A linen sack tied at the neck with a string of the crop's colour, its produce painted
    on the front at half size, and three of its seeds spilled in front."""
    picture = blank(ICON)
    body = ellipse(16, 18, 10.5, 9) | box(6, 18, 26, 26)
    neck = polygon([(11, 4), (21, 4), (19, 9), (13, 9)])
    shade(picture, body | neck, ("sand", "sand_light", "lime"), radius=4, top_light=0.1)
    dots(picture, [(12, 4), (15, 3), (18, 4), (20, 3)], "lime")
    paint(picture, box(12, 8, 20, 9), tie)
    line(picture, 20, 9, 24, 12, tie)
    line(picture, 21, 9, 23, 13, tie)
    for x, y in ((7, 13), (11, 25), (25, 23)):
        line(picture, x, y, x + 2, y - 3, "sand")
    emblem = icon(small(produce))
    for y, row in enumerate(emblem):
        for x, colour in enumerate(row):
            if colour is not None:
                picture[10 + y][8 + x] = colour
    for x, y in ((4, 29), (16, 30), (28, 29)):
        shade(picture, ellipse(x, y, 1.8, 1.4), seeds, radius=1)
    return picture


def icons():
    """The bodies of the produce's and the seed sacks' icons, by item id."""
    pictures = {crop: draw() for crop, draw in PRODUCE.items()}
    for crop, (tie, seeds) in SACKS.items():
        pictures[f"{crop}_seeds"] = seed_sack(pictures[crop], tie, seeds)
    return pictures
