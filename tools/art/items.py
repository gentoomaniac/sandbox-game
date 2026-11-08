"""Art for items and the slots that hold them: 32x32 icons and 20x20 slot frames.

The icons are drawn at 32 px per tile, like the world, in the style of the 32 px art: rounded
forms shaded from the top left (forms.py), wood with its grain, cloth with its folds, iron with
a bright edge. Each module draws its icons as a body without an outline, by item id;
generate.py writes `icon(body)` to assets/items/<item id>.png and `ground_item(body)`, the body
at half size, to assets/ground_items/<item id>.png, for the items lying on the ground. The UI
shows an icon at half size, 16 UI pixels (game/scenes/item_icon.gd), so an icon's pixel is as
big as a world pixel at the widest zoom. The slots are drawn for the UI's own pixels:
assets/ui/slot.png and slot_selected.png, and the faint hints of the equipment slots.

Pictures are lists of rows of palette colour names (None = clear), as in canvas.py; the shapes
are numpy masks of forms.py, as big as the icon. Tools are in tool_icons.py, the crops' seed sacks
and produce in crop_icons.py, the rest in the module of their topic (meadow.py, reeds.py,
crafts.py, church.py, landing.py); the items that place a world object are icons of its picture.
"""

import math

import chest
import forms
import numpy as np
from canvas import GAME_TILE, TILE, blank, outline, rect

ICON = GAME_TILE
SLOT = 20

# The darkest shade of each colour's ramp: an icon is outlined in it, next to a pixel of that
# colour, the rule of every 32 px picture (docs/art-style.md). A pixel already in the darkest
# shade of its ramp (DARKEST) gets no outline.
RIMS = {
    **dict.fromkeys(("green_bright", "green_light", "green", "green_dark", "olive", "meadow", "meadow_light"), "green_deep"),
    **dict.fromkeys(("spring_pale", "spring_light", "spring", "spring_dark", "dry", "dry_light", "frost"), "green_deep"),
    **dict.fromkeys(("soil_light", "soil_mid", "soil", "skin", "skin_shade"), "soil_dark"),
    **dict.fromkeys(("sand_light", "sand", "mud", "bare_light", "bare"), "mud_dark"),
    **dict.fromkeys(("straw", "reed", "autumn_light", "gold", "leaf_orange", "ochre", "ochre_dark"), "umber"),
    **dict.fromkeys(("red_light", "rust", "rust_dark", "flame", "ember"), "russet_deep"),
    **dict.fromkeys(("snow_light", "snow", "snow_shadow", "snow_deep", "stone_light", "stone", "lime"), "stone_dark"),
    **dict.fromkeys(("cream", "petal", "blossom", "heather"), "heather_dark"),
    **dict.fromkeys(("foam", "water_light", "water", "paint_teal", "spirit", "arcane"), "water_deep"),
}
DARKEST = {"soil_dark", "mud_dark", "umber", "russet_deep", "stone_dark", "heather_dark", "water_deep", "green_deep", "bog", "bog_dark", "ink"}

# Ramps, dark to light, for forms.shade.
OAK = ("soil", "soil_mid", "soil_light")
IRON = ("stone_dark", "stone", "stone_light", "snow_light")
LINEN = ("snow_shadow", "lime", "snow_light")
COPPER = ("umber", "ochre_dark", "ochre", "gold")


def rim_of(colour):
    return None if colour in DARKEST else RIMS.get(colour, "ink")


def icon(body):
    """The icon of a body: outlined all round in the darkest shade of what it surrounds."""
    return outline(body, rim_of)


def ground_item(body):
    """An item lying on the ground: the body at half size (`small`), outlined like the icon. Its
    shadow on the ground is drawn by the game (GroundItemView)."""
    return outline(small(body), rim_of)


def small(picture):
    """The picture at half size: each 2x2 block of pixels becomes the colour that most of its
    opaque pixels have (the first of them on a tie), or clear where fewer than two are opaque."""
    height, width = len(picture) // 2, len(picture[0]) // 2
    result = blank(width, height)
    for y in range(height):
        for x in range(width):
            block = [picture[2 * y + dy][2 * x + dx] for dy in (0, 1) for dx in (0, 1)]
            opaque = [colour for colour in block if colour is not None]
            if len(opaque) >= 2:
                result[y][x] = max(opaque, key=opaque.count)
    return result


def icon_of(picture):
    """The body of the icon of an item that places a world object: its picture, drawn at 32 px
    per tile, without its ground shadow and the clear rows round it, in the middle of the icon.
    A picture much bigger than the icon (the rowing boat, the cupboard) is halved first; then
    rows from its middle are left out until it fits. The picture has its edge already."""
    picture = [[None if name == "shadow" else name for name in row] for row in picture]
    picture = [row for row in picture if any(row)]
    if len(picture[0]) > ICON or len(picture) > ICON * 5 // 4:
        picture = small(picture)
    while len(picture) > ICON:
        middle = len(picture) // 2
        picture = picture[:middle] + picture[middle + 1 :]
    body = blank(ICON)
    top = (ICON - len(picture)) // 2
    left = (ICON - len(picture[0])) // 2
    for y, row in enumerate(picture):
        for x, name in enumerate(row):
            body[top + y][left + x] = name
    return body


# Masks as big as the icon (see forms.py).
def ellipse(cx, cy, rx, ry, angle=0.0):
    return forms.ellipse(ICON, ICON, cx, cy, rx, ry, angle)


def polygon(points):
    return forms.polygon(ICON, ICON, points)


def capsule(start, end, start_radius, end_radius=None):
    return forms.capsule(ICON, ICON, start, end, start_radius, end_radius)


def limb(points, radii):
    return forms.limb(ICON, ICON, points, radii)


def box(x0, y0, x1, y1):
    return forms.box(ICON, ICON, x0, y0, x1, y1)


def shade(picture, mask, ramp, radius=3, top_light=0.0):
    return forms.shade(picture, mask, ramp, radius, top_light)


def paint(picture, mask, colour):
    return forms.paint(picture, mask, colour)


def dots(picture, points, colour):
    return forms.dots(picture, points, colour)


def line(picture, x0, y0, x1, y1, colour):
    """A one pixel wide line with a pixel per step along the longer side, clipped."""
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    dots(picture, [(x0 + round((x1 - x0) * s / steps), y0 + round((y1 - y0) * s / steps)) for s in range(steps + 1)], colour)


def edge_of(mask, side):
    """The pixels of the mask's border facing `side`: "left", "right", "top" or "bottom"."""
    dx, dy = {"left": (-1, 0), "right": (1, 0), "top": (0, -1), "bottom": (0, 1)}[side]
    padded = np.pad(mask, 1)
    neighbour = padded[1 + dy : 1 + dy + mask.shape[0], 1 + dx : 1 + dx + mask.shape[1]]
    return mask & ~neighbour


def grain(picture, mask, colour, rows, seed=0):
    """Streaks of wood grain over the mask: short dashes along each of `rows`, offset by `seed`."""
    for index, y in enumerate(rows):
        start = (seed * 7 + index * 11) % 9
        for x in range(start, ICON, 9):
            dots(picture, [(px, y) for px in range(x, x + 4) if 0 <= px < ICON and mask[y, px]], colour)


def pixel(picture, x, y, colour):
    picture[y][x] = colour


def from_rows(rows, keys):
    """A picture from rows of characters, each mapped to a colour name by `keys` ("." is clear)."""
    return [[keys.get(character) for character in row] for row in rows]


def chest_icon():
    """The chest: its world picture."""
    return icon_of(chest.chest())


def logs():
    """Three split logs stacked, two below and one on them, their cut ends to the front with
    rings round a dark heart, the bark lit from the top."""
    picture = blank(ICON)
    for cx, cy in ((10, 21), (22, 21), (16, 12)):
        bark = ellipse(cx, cy, 7.5, 7)
        shade(picture, bark, ("soil", "soil_mid", "soil_light"), radius=3)
        face = ellipse(cx + 0.5, cy + 0.5, 5.5, 5)
        shade(picture, face, ("sand", "sand_light"), radius=2)
        paint(picture, ellipse(cx + 0.5, cy + 0.5, 5.5, 5) & ~ellipse(cx + 0.5, cy + 0.5, 4.5, 4), "sand")
        paint(picture, ellipse(cx + 0.5, cy + 0.5, 3, 2.6) & ~ellipse(cx + 0.5, cy + 0.5, 2, 1.7), "sand")
        paint(picture, ellipse(cx + 0.5, cy + 0.5, 1, 1), "soil_mid")
        # A split runs from the heart to the rim.
        line(picture, round(cx + 1), round(cy + 1), round(cx + 4), round(cy + 4), "mud")
    return picture


def stone():
    """A rounded fieldstone of the Geest, grey granite with a lit top, a crack and pale flecks."""
    picture = blank(ICON)
    body = polygon([(4, 18), (7, 10), (13, 6), (21, 6), (27, 11), (29, 19), (26, 26), (16, 28), (7, 26)])
    shade(picture, body, ("stone_dark", "stone", "stone_light"), radius=5, top_light=0.2)
    line(picture, 15, 9, 18, 15, "stone_dark")
    line(picture, 18, 15, 17, 20, "stone_dark")
    dots(picture, [(9, 15), (12, 21), (22, 12), (24, 20), (20, 24), (10, 11)], "snow_light")
    dots(picture, [(13, 17), (21, 18), (25, 15)], "stone_dark")
    return picture


def fibre():
    """A bundle of long plant fibres, green and straw, bound in the middle with a twist."""
    picture = blank(ICON)
    for index, (top, bottom) in enumerate(((4, 3), (8, 9), (12, 14), (16, 19), (20, 24), (24, 28), (27, 31))):
        colour = ("green_light", "straw", "green", "dry_light", "straw", "green_light", "reed")[index]
        line(picture, top, 2 + index % 2, 13 + index // 2, 15, colour)
        line(picture, 13 + index // 2, 16, bottom - 2, 29 - index % 2, colour)
        line(picture, top + 1, 2 + index % 2, 14 + index // 2, 15, "green_dark" if index % 2 else "dry")
    band = box(9, 14, 21, 17)
    shade(picture, band, ("mud", "sand", "sand_light"), radius=2)
    line(picture, 10, 17, 20, 14, "mud")
    return picture


def berries():
    """A sprig of three bilberries and a cranberry under two leaves, each berry glossy."""
    picture = blank(ICON)
    shade(picture, ellipse(13, 7, 6.5, 3.2, angle=20), ("green_dark", "green", "green_light"), radius=2)
    shade(picture, ellipse(22, 7, 5.5, 2.8, angle=-25), ("green_dark", "green", "green_light"), radius=2)
    line(picture, 9, 8, 18, 6, "green_dark")
    line(picture, 18, 6, 25, 8, "green_dark")
    for x0, y0, x1, y1 in ((17, 9, 10, 16), (17, 9, 18, 19), (18, 9, 25, 15)):
        line(picture, x0, y0, x1, y1, "green_dark")
    for cx, cy, ramp in (
        (9, 19, ("heather_dark", "heather", "petal")),
        (18, 23, ("heather_dark", "heather", "petal")),
        (25, 18, ("rust_dark", "ember", "red_light")),
        (12, 26, ("heather_dark", "heather", "petal")),
    ):
        shade(picture, ellipse(cx, cy, 4, 4), ramp, radius=2)
        dots(picture, [(cx - 2, cy - 2)], "cream")
    return picture


def acorn():
    """An acorn: a glossy nut in a scaly cap with a short stem."""
    picture = blank(ICON)
    shade(picture, ellipse(16, 19, 7.5, 9), ("umber", "ochre_dark", "ochre"), radius=4)
    dots(picture, [(12, 16), (12, 17), (13, 15)], "gold")
    dots(picture, [(16, 28)], "umber")
    cap = ellipse(16, 11, 10, 5.5) & ~box(0, 15, ICON - 1, ICON - 1)
    shade(picture, cap, ("soil", "soil_mid", "soil_light"), radius=2)
    for y in range(7, 15, 2):
        for x in range(7 + y % 4, 26, 4):
            if cap[y, x]:
                dots(picture, [(x, y)], "soil")
    rect(picture, 15, 2, 16, 6, "soil_mid")
    dots(picture, [(17, 2)], "soil_mid")
    return picture


def beechnut():
    """A beechnut: the woody husk split open in four lobes, two glossy three-sided nuts in it."""
    picture = blank(ICON)
    for angle in (200, 250, 290, 340):
        a = math.radians(angle)
        lobe = limb([(16, 24), (16 + 11 * math.cos(a), 22 + 11 * math.sin(a))], [4.5, 2.5])
        shade(picture, lobe, ("soil", "soil_mid", "soil_light"), radius=2)
    shade(picture, ellipse(16, 25, 7, 4), ("soil", "soil_mid", "soil_light"), radius=2)
    for x, y in ((8, 26), (11, 29), (16, 30), (21, 29), (24, 26), (5, 15), (27, 15)):
        dots(picture, [(x, y)], "soil_light")
    for points in (((9, 24), (12, 7), (16, 24)), ((16, 24), (20, 7), (23, 24))):
        nut = polygon(points)
        shade(picture, nut, ("umber", "ochre_dark", "ochre"), radius=2)
        line(picture, points[1][0], points[1][1] + 2, points[1][0], 22, "umber")
    return picture


def birch_catkin():
    """A birch's seed catkin: a slim cylinder of tight scales hanging from a twig."""
    picture = blank(ICON)
    line(picture, 15, 6, 22, 2, "soil")
    line(picture, 22, 2, 27, 3, "soil")
    line(picture, 14, 6, 15, 9, "soil_mid")
    body = capsule((15, 11), (16, 27), 3.2, 2.6)
    shade(picture, body, ("umber", "ochre_dark", "ochre"), radius=2)
    for y in range(11, 28, 2):
        for x in range(12, 20):
            if body[y, x] and (x + y // 2) % 3 == 0:
                dots(picture, [(x, y)], "umber")
    return picture


def alder_cone():
    """Three little black alder cones on a forked twig, their scales open."""
    picture = blank(ICON)
    for points in (((16, 2), (15, 10), (9, 14)), ((15, 10), (22, 13)), ((15, 10), (15, 19))):
        for start, end in zip(points, points[1:]):
            line(picture, *start, *end, "soil")
    for cx, cy in ((8, 18), (23, 17), (15, 24)):
        cone = ellipse(cx, cy, 4, 5.5)
        shade(picture, cone, ("bog_dark", "mud_dark", "mud"), radius=2)
        for y in range(cy - 4, cy + 5, 2):
            dots(picture, [(cx - 1 + (y // 2) % 2 * 2, y)], "soil_mid")
    return picture


def willow_cutting():
    """A willow rod cut at a slant at its foot, buds along it and young leaves at its tip."""
    picture = blank(ICON)
    rod = capsule((5, 28), (21, 8), 1.6, 1.1)
    shade(picture, rod, ("umber", "reed", "straw"), radius=1)
    dots(picture, [(4, 29), (5, 29)], "sand_light")
    for x, y in ((10, 22), (14, 17), (17, 13)):
        dots(picture, [(x + 1, y - 1), (x + 2, y - 1)], "ochre")
    shade(picture, ellipse(23, 6, 4.5, 2, angle=30), ("olive", "dry_light", "spring_pale"), radius=1)
    shade(picture, ellipse(25, 11, 4, 1.8, angle=-20), ("olive", "dry_light", "spring_pale"), radius=1)
    return picture


def cone(cx, top, bottom, widths, ramp):
    """A conifer cone hanging down from `top` to `bottom`: its half width at each row from
    `widths(t)` (t 0 to 1), its scales in a diamond lattice, each lit at its top, the right side
    in shade. `ramp` is seam, shade, body, tip."""
    picture = blank(ICON)
    seam, shadow, body, tip = ramp
    for y in range(top, bottom + 1):
        half = widths((y - top) / (bottom - top))
        for x in range(math.floor(cx - half), math.ceil(cx + half)):
            rising, falling = (x + y) % 5, (x - y) % 5
            if rising == 0 or falling == 0:
                colour = seam
            elif rising == 2 and falling == 2 or rising == 1 and falling == 1:
                colour = tip
            else:
                colour = body
            if x + 0.5 > cx + half * 0.5 and colour == body:
                colour = shadow
            picture[y][x] = colour
    return picture


def spruce_cone():
    """A long, narrow spruce cone hanging from a twig, its scales in a lattice."""
    picture = cone(16, 5, 30, lambda t: 2 + 4 * math.sin(math.pi * min(1, t * 1.2)) ** 0.6, ("soil_dark", "soil", "soil_mid", "soil_light"))
    line(picture, 16, 1, 16, 4, "soil")
    line(picture, 17, 1, 21, 1, "green")
    return picture


def pine_cone():
    """A fat, rounded pine cone with open, pale-tipped scales."""
    picture = cone(16, 6, 29, lambda t: 2.5 + 9 * math.sin(math.pi * (0.15 + 0.7 * t)) * (0.55 + 0.45 * t), ("mud_dark", "mud", "mud", "sand_light"))
    rect(picture, 15, 2, 16, 5, "soil")
    return picture


def garment(outline_points, ramp, folds=()):
    """A garment laid flat: its shape filled in `ramp`, lit from the top left, with folds as
    lines in its darkest shade."""
    picture = blank(ICON)
    shade(picture, polygon(outline_points), ramp, radius=4, top_light=0.15)
    for fold in folds:
        line(picture, *fold, ramp[0])
    return picture


# The linen shirt laid out: shoulders, long sleeves, the body, the open neck.
SHIRT = [(10, 4), (14, 4), (16, 7), (18, 4), (22, 4), (29, 10), (30, 22), (25, 22), (24, 13), (23, 28), (9, 28), (8, 13), (7, 22), (2, 22), (3, 10)]


def shirt():
    """A linen shirt with long sleeves, gathered at the cuffs, and an open neck."""
    picture = garment(SHIRT, LINEN, folds=((11, 14, 11, 26), (20, 15, 21, 26), (8, 13, 8, 17), (24, 13, 24, 17)))
    line(picture, 16, 7, 16, 13, "snow_shadow")
    rect(picture, 2, 21, 7, 22, "snow_shadow")
    rect(picture, 25, 21, 30, 22, "snow_shadow")
    return picture


def waistcoat():
    """A long red waistcoat with tin buttons, over the white sleeves of the shirt."""
    picture = garment(SHIRT, LINEN)
    rect(picture, 2, 21, 7, 22, "snow_shadow")
    rect(picture, 25, 21, 30, 22, "snow_shadow")
    vest = polygon([(10, 4), (14, 4), (16, 13), (18, 4), (22, 4), (24, 9), (24, 29), (8, 29), (8, 9)])
    shade(picture, vest, ("rust_dark", "rust", "red_light"), radius=3, top_light=0.15)
    line(picture, 16, 13, 16, 29, "rust_dark")
    for y in (15, 19, 23, 27):
        dots(picture, [(17, y)], "stone_light")
        dots(picture, [(18, y)], "stone")
    line(picture, 10, 21, 14, 21, "rust_dark")
    line(picture, 18, 21, 22, 21, "rust_dark")
    return picture


def jacket():
    """A short blue jacket with long sleeves and turned-back cuffs, open down the front."""
    picture = garment(
        [(10, 4), (22, 4), (29, 10), (30, 24), (25, 24), (24, 14), (24, 27), (8, 27), (8, 14), (7, 24), (2, 24), (3, 10)],
        ("water_deep", "water", "water_light"),
        folds=((8, 14, 8, 18), (24, 14, 24, 18), (11, 18, 11, 25)),
    )
    # The open front: the lining shows between the lapels.
    paint(picture, polygon([(14, 5), (18, 5), (18, 27), (14, 27)]), "soil_dark")
    shade(picture, polygon([(12, 4), (16, 4), (14, 13)]), ("water", "water_light", "foam"), radius=1)
    shade(picture, polygon([(16, 4), (20, 4), (18, 13)]), ("water_deep", "water", "water_light"), radius=1)
    for cuff in (box(2, 21, 7, 24), box(25, 21, 30, 24)):
        shade(picture, cuff, ("water", "water_light", "foam"), radius=1)
    dots(picture, [(13, 16), (13, 20), (13, 24)], "stone_light")
    return picture


def breeches():
    """Knee breeches of brown wool, banded at the knee, the white stockings below them."""
    picture = blank(ICON)
    shade(picture, polygon([(8, 4), (24, 4), (26, 17), (17, 17), (16, 10), (15, 17), (6, 17)]), OAK, radius=3)
    rect(picture, 8, 4, 24, 6, "soil_light")
    rect(picture, 8, 6, 24, 6, "soil")
    dots(picture, [(10, 5), (22, 5)], "stone_light")
    line(picture, 16, 7, 16, 10, "soil")
    for left in (6, 17):
        rect(picture, left, 17, left + 9, 18, "soil_dark")
        dots(picture, [(left + 7, 17)], "stone_light")
        shade(picture, box(left + 1, 19, left + 8, 28), LINEN, radius=2)
        rect(picture, left + 1, 28, left + 8, 29, "sand")
    return picture


def clogs():
    """A pair of pale wooden clogs from above, the toes pointed, the dark openings at the heels
    with the carved rim lit."""
    picture = blank(ICON)
    for cx, cy in ((9, 16), (23, 15)):
        clog = polygon([(cx, cy - 14), (cx + 4, cy - 10), (cx + 6, cy - 2), (cx + 6, cy + 9), (cx + 3, cy + 13), (cx - 3, cy + 13), (cx - 6, cy + 9), (cx - 6, cy - 2), (cx - 4, cy - 10)])
        shade(picture, clog, ("sand", "sand_light", "lime"), radius=3)
        opening = ellipse(cx + 0.5, cy + 5.5, 3.3, 6)
        paint(picture, opening, "soil_dark")
        paint(picture, opening & ~ellipse(cx + 0.5, cy + 7, 3.3, 6), "mud")
        line(picture, cx - 2, cy - 9, cx + 1, cy - 11, "lime")
    return picture


def straw_hat():
    """A low straw crown with a dark band, on a wide brim drooping at its ends, the straw
    plaited in rows."""
    picture = blank(ICON)
    brim = ellipse(16, 20, 15, 5)
    shade(picture, brim, ("reed", "straw", "sand_light"), radius=2)
    crown = ellipse(16, 13, 8, 7) & ~box(0, 19, ICON - 1, ICON - 1) | box(8, 13, 23, 18)
    shade(picture, crown, ("reed", "straw", "sand_light"), radius=3)
    rect(picture, 8, 15, 23, 17, "soil")
    rect(picture, 8, 15, 23, 15, "soil_mid")
    for y in (8, 11):
        for x in range(9 + y % 3, 24, 3):
            if crown[y, x]:
                dots(picture, [(x, y)], "reed")
    for x in range(3, 30, 3):
        dots(picture, [(x, 21 + (x % 2))], "reed")
    return picture


def knitted_cap():
    """A red wool stocking cap: a ribbed cuff, the long top flopping over to the right, a tassel
    at its tip."""
    picture = blank(ICON)
    top = limb([(12, 20), (12, 10), (16, 5), (22, 6), (26, 11), (27, 17)], [8.5, 7, 5, 3.6, 2.8, 2.2])
    shade(picture, top, ("rust_dark", "rust", "red_light"), radius=3)
    line(picture, 19, 9, 22, 13, "rust_dark")
    tassel = ellipse(27, 22, 3, 3.5)
    shade(picture, tassel, ("rust_dark", "ember", "red_light"), radius=1)
    dots(picture, [(26, 24), (28, 25), (27, 25)], "rust_dark")
    cuff = box(3, 19, 21, 26)
    shade(picture, cuff, ("rust_dark", "rust", "red_light"), radius=2)
    for x in range(4, 21, 2):
        line(picture, x, 20, x, 25, "rust_dark")
    return picture


def bone():
    """A meaty bone lying across, its knobbed ends pale and a shred of meat on the shaft."""
    picture = blank(ICON)
    shaft = capsule((8, 24), (24, 8), 2.6)
    knobs = ellipse(5, 24, 3, 3) | ellipse(8, 27, 3, 3) | ellipse(24, 5, 3, 3) | ellipse(27, 8, 3, 3)
    shade(picture, shaft | knobs, ("sand", "cream", "snow_light"), radius=2)
    meat = ellipse(15, 17, 5, 3, angle=45)
    shade(picture, meat, ("rust_dark", "rust", "red_light"), radius=2)
    dots(picture, [(13, 18), (16, 15)], "cream")
    return picture


def saddle():
    """A riding saddle from the side: the seat dipping between the high cantle at the back and
    the pommel at the front, the flap below it, a blue cloth under it and an iron stirrup."""
    picture = blank(ICON)
    shade(picture, polygon([(3, 12), (29, 12), (28, 22), (4, 22)]), ("water_deep", "water", "water_light"), radius=2)
    seat = polygon([(4, 5), (8, 4), (10, 10), (21, 10), (25, 6), (28, 7), (27, 13), (24, 18), (8, 18), (5, 12)])
    shade(picture, seat, ("rust_dark", "rust", "red_light"), radius=3)
    flap = polygon([(10, 13), (21, 13), (20, 23), (11, 23)])
    shade(picture, flap, ("russet_deep", "rust_dark", "rust"), radius=2)
    line(picture, 15, 18, 15, 25, "russet_deep")
    stirrup = ellipse(15.5, 27.5, 3.5, 3) & ~ellipse(15.5, 27, 2, 1.6)
    shade(picture, stirrup, IRON[:3], radius=1)
    return picture


ICONS = {
    "chest": chest_icon,
    "logs": logs,
    "stone": stone,
    "fibre": fibre,
    "berries": berries,
    "acorn": acorn,
    "spruce_cone": spruce_cone,
    "pine_cone": pine_cone,
    "beechnut": beechnut,
    "birch_catkin": birch_catkin,
    "alder_cone": alder_cone,
    "willow_cutting": willow_cutting,
    "waistcoat": waistcoat,
    "shirt": shirt,
    "breeches": breeches,
    "straw_hat": straw_hat,
    "knitted_cap": knitted_cap,
    "jacket": jacket,
    "clogs": clogs,
    "bone": bone,
    "saddle": saddle,
}


def icons():
    """The bodies of the icons drawn here, by item id."""
    return {item: draw() for item, draw in ICONS.items()}


def slot(frame):
    """A 20x20 slot: a frame round a soil panel lit from the upper left. The selected one has
    a gold frame."""
    picture = blank(SLOT)
    rect(picture, 0, 0, SLOT - 1, SLOT - 1, frame)
    rect(picture, 1, 1, SLOT - 2, SLOT - 2, "soil_dark")
    rect(picture, 2, 2, SLOT - 3, SLOT - 3, "soil")
    rect(picture, 2, 2, SLOT - 3, 2, "soil_mid")
    rect(picture, 2, 2, 2, SLOT - 3, "soil_mid")
    for x, y in ((0, 0), (SLOT - 1, 0), (0, SLOT - 1), (SLOT - 1, SLOT - 1)):
        picture[y][x] = None
    return picture


SLOTS = {"slot": slot("ink"), "slot_selected": slot("gold")}


# The faint outline an empty equipment slot shows for what fits it, as 16x16 icons in UI pixels,
# in a colour just lighter than the slot. Each is a list of closed paths, drawn as lines between
# points.
HINT_COLOUR = "soil_mid"
HINT_PATHS = {
    "head": [
        [(5, 8), (5, 5), (7, 3), (10, 3), (12, 5), (12, 8)],
        [(2, 8), (15, 8), (15, 10), (2, 10), (2, 8)],
    ],
    "body": [
        [(5, 3), (7, 3), (8, 5), (9, 3), (11, 3), (14, 6), (12, 8), (11, 7), (11, 13), (4, 13), (4, 7), (3, 8), (1, 6), (5, 3)]
    ],
    "coat": [
        [(5, 2), (11, 2), (14, 5), (14, 13), (12, 13), (12, 8), (11, 8), (11, 14), (5, 14), (5, 8), (4, 8), (4, 13), (2, 13), (2, 5), (5, 2)],
        [(7, 2), (8, 5), (9, 2)],
        [(8, 5), (8, 14)],
    ],
    "legs": [[(4, 2), (12, 2), (13, 14), (9, 14), (8, 7), (7, 14), (3, 14), (4, 2)]],
    "feet": [[(5, 2), (9, 2), (9, 8), (13, 10), (13, 13), (5, 13), (5, 2)]],
    "back": [
        [(4, 5), (11, 5), (12, 13), (3, 13), (4, 5)],
        [(5, 5), (5, 3), (10, 3), (10, 5)],
        [(6, 9), (9, 9), (9, 12), (6, 12), (6, 9)],
    ],
    "main_hand": [
        [(12, 2), (13, 3), (7, 9), (6, 8), (12, 2)],
        [(4, 8), (8, 12)],
        [(6, 10), (3, 13)],
    ],
    "off_hand": [
        [(3, 3), (12, 3), (12, 8), (8, 14), (3, 8), (3, 3)],
        [(7, 5), (7, 10)],
        [(5, 7), (10, 7)],
    ],
}


def hint(paths):
    picture = blank(TILE)
    for path in paths:
        for start, end in zip(path, path[1:]):
            line(picture, *start, *end, HINT_COLOUR)
    return picture


SLOT_HINTS = {f"equip_{slot}": hint(paths) for slot, paths in HINT_PATHS.items()}
