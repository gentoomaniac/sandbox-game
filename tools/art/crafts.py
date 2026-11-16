"""The art of the professions (task 74): the stations they work at and what they make.

A station is drawn once at 32 px per tile, standing (its bottom row on the ground), like the
chest: generate.py puts that picture into its cell of the object atlas (outdoors) and writes it as
assets/interior/<type>.png (inside a house, and the ghost while it is placed). Each is rimmed in
the darkest shade of its own colours, light from the top left. Its item icon's body is that
picture (items.icon_of). The items made at the stations are drawn as icon bodies, named after the
item id of game/state/item_types.gd, which generate.py outlines and writes with the other icons.
Cooked food is warm in colour; the meals in a bowl steam a little.
"""

import random

import camp
import chest
import forms
from canvas import blank, outline_edge, rect
from items import ICON, LINEN, OAK, box, capsule, dots, ellipse, grain, icon_of, line, paint, polygon, shade

def bowl(broth, bits):
    """A wooden bowl of a meal from the side and a little above: `broth` is its ramp, dark to
    light, `bits` the colours of what floats in it."""
    picture = blank(ICON)
    wood = ellipse(16, 18, 14, 10) & ~box(0, 0, ICON - 1, 16)
    shade(picture, wood, OAK, radius=4)
    grain(picture, wood & ~box(0, 0, ICON - 1, 20), "soil", (23, 26))
    paint(picture, ellipse(16, 16, 14, 5), "soil_light")
    shade(picture, ellipse(16, 16.5, 12, 3.8), broth, radius=2)
    for index, (x, y) in enumerate(((9, 16), (13, 15), (18, 17), (22, 15), (15, 18), (11, 18), (20, 14))):
        dots(picture, [(x, y), (x + 1, y)], bits[index % len(bits)])
    rect(picture, 11, 28, 21, 29, "soil")
    return picture


def roast_turnip():
    """A turnip roasted golden brown in the embers, its leaves burnt off, dark marks of the fire
    on it."""
    picture = blank(ICON)
    body = ellipse(16, 18, 11, 9)
    shade(picture, body, ("ochre_dark", "ochre", "leaf_orange"), radius=4)
    shade(picture, body & ellipse(16, 11, 13, 6), ("rust_dark", "rust", "flame"), radius=2)
    rect(picture, 15, 6, 17, 9, "umber")
    line(picture, 16, 27, 17, 30, "ochre_dark")
    for x, y in ((10, 17), (19, 13), (14, 22), (22, 19), (12, 13)):
        dots(picture, [(x, y), (x + 1, y)], "umber")
    return picture


def _grain(picture, x0, y0, x1, y1, colour, seed, count):
    """Short streaks of grain in `colour` along a board x0..x1, y0..y1."""
    rng = random.Random(seed)
    for _ in range(count):
        x, y = rng.randint(x0, x1), rng.randint(y0, y1)
        rect(picture, x, y, min(x1, x + rng.randint(2, 6)), y, colour)


def workbench():
    """The workbench, 32x22 px: a thick beech top on four oak legs joined by a stretcher, a vice
    at its left end with a wooden screw and its bar, and a saw and a few shavings lying on it."""
    picture = blank(32, 22)
    # The back legs, in the shade under the top, then the stretcher between the front ones.
    for x in (7, 23):
        rect(picture, x, 6, x + 1, 19, "soil")
    rect(picture, 4, 14, 27, 16, "soil_mid")
    rect(picture, 4, 14, 27, 14, "soil_light")
    rect(picture, 4, 16, 27, 16, "soil")
    for x in (2, 26):
        rect(picture, x, 6, x + 3, 21, "soil_mid")
        rect(picture, x, 6, x, 21, "soil_light")
        rect(picture, x + 3, 6, x + 3, 21, "soil")
    # The top: its face seen from above, lit, and its thick front edge, the end grain at the right.
    rect(picture, 1, 0, 30, 2, "sand_light")
    rect(picture, 0, 1, 31, 2, "sand_light")
    rect(picture, 0, 2, 31, 2, "sand")
    _grain(picture, 2, 0, 29, 1, "sand", 41, 4)
    rect(picture, 0, 3, 31, 6, "soil_light")
    rect(picture, 0, 6, 31, 6, "soil_mid")
    _grain(picture, 1, 4, 28, 5, "soil_mid", 42, 5)
    rect(picture, 29, 3, 31, 6, "sand")
    picture[4][30] = picture[5][30] = "soil_mid"
    # The vice: a jaw of oak under the left end, its screw through it and the bar through the
    # screw's head.
    rect(picture, 0, 7, 4, 12, "soil_mid")
    rect(picture, 0, 7, 0, 12, "soil_light")
    rect(picture, 0, 9, 7, 10, "sand")
    rect(picture, 0, 9, 7, 9, "sand_light")
    rect(picture, 5, 7, 5, 13, "stone")
    # The saw lying on the top: its blade, teeth to the front, and its handle at the right.
    rect(picture, 8, 1, 19, 1, "stone_light")
    rect(picture, 8, 2, 19, 2, "stone")
    for x in range(8, 20, 2):
        picture[3][x] = "stone_dark"
    rect(picture, 20, 0, 23, 2, "soil")
    rect(picture, 20, 0, 23, 0, "soil_mid")
    picture[1][22] = "soil_dark"
    # Curled shavings.
    for x, y in ((25, 1), (26, 0), (27, 1), (12, 0)):
        picture[y][x] = "cream"
    return outline_edge(picture, "soil_dark", keep_bottom=True)


# The carved chest is the chest painted as the Frisian chests were: blue-green with a pale lid,
# tulips on its front.
PAINTED_CHEST = {
    "sand_light": "foam", "sand": "water_light", "soil_light": "water_light", "soil_mid": "paint_teal", "soil": "water",
}
# Where the tulips stand, by the foot of their stems, either side of the lock.
CHEST_TULIPS = ((8, 9), (23, 9), (8, 20), (23, 20))


def carved_chest():
    """The chest, painted, a tulip on each side of its lock on the lid and on the box."""
    picture = [[PAINTED_CHEST.get(name, name) for name in row] for row in chest.chest()]
    for x, y in CHEST_TULIPS:
        rect(picture, x, y - 2, x, y, "green_light")
        picture[y - 1][x - 1] = picture[y - 1][x + 1] = "green"
        rect(picture, x - 1, y - 4, x + 1, y - 3, "red_light")
        picture[y - 5][x - 1] = picture[y - 5][x + 1] = "red_light"
        picture[y - 4][x] = "petal"
        picture[y - 4][x - 1] = "cream"
    return picture


def planks():
    """Three sawn boards stacked, their ends to the front right, the grain along them."""
    picture = blank(ICON)
    for top in (19, 12, 5):
        face = polygon([(2, top + 4), (22, top + 4), (22, top + 8), (2, top + 8)])
        shade(picture, face, ("sand", "sand_light", "lime"), radius=1)
        grain(picture, face, "sand", (top + 6,), seed=top)
        end = polygon([(22, top + 4), (29, top), (29, top + 4), (22, top + 8)])
        shade(picture, end, ("soil_mid", "soil_light", "sand"), radius=1)
        top_face = polygon([(2, top + 4), (9, top), (29, top), (22, top + 4)])
        shade(picture, top_face, ("sand_light", "lime", "snow_light"), radius=1)
    return picture


# Clay and fired clay, lit to dark; field stones; brick.
CLAY = ("mud_dark", "mud", "sand", "sand_light")
STONES = ("stone_dark", "stone", "stone_light")
BRICK = ("rust_dark", "rust", "red_light")


def _footing(picture, top, bottom, seed):
    """A footing of rounded field stones, rows top..bottom, the width of the picture."""
    rng = random.Random(seed)
    width = len(picture[0])
    rect(picture, 0, top, width - 1, bottom, "stone_dark")
    x = 1
    while x < width - 1:
        half = rng.uniform(2.6, 3.8)
        stone = forms.ellipse(width, len(picture), x + half, (top + bottom) / 2 + rng.uniform(-0.5, 0.5), half, (bottom - top) / 2 + 0.4)
        forms.shade(picture, stone, STONES, radius=2)
        x += 2 * half + 0.6


def kiln():
    """A small beehive kiln of clay on a fieldstone footing, 32x36 px: the smoke hole at its top,
    courses of clay round its dome, and the arched mouth where the fire is laid, glowing low."""
    width, height = 32, 36
    picture = blank(width, height)
    xs, ys = forms.grid(width, height)
    half = 4.5 + 11 * ((ys - 2).clip(0) / 28) ** 0.5
    dome = (abs(xs - 16) <= half) & (ys >= 2) & (ys < 31)
    level = forms.light_level(dome, 6, top_light=0.25)
    # The courses of clay: a darker joint every 5 rows, the clay bulging lit under it.
    for y in range(6, 31, 5):
        level[y] -= 0.5
        level[y + 1] += 0.2
    forms.shade_by_level(picture, dome, CLAY, level)
    # The rim round the smoke hole, and the hole.
    rect(picture, 11, 0, 20, 3, "sand")
    rect(picture, 11, 0, 20, 0, "sand_light")
    rect(picture, 13, 1, 18, 3, "soil_dark")
    rect(picture, 14, 2, 17, 3, "ink")
    # The mouth, an arch over the ash and the embers.
    mouth = forms.ellipse(width, height, 16, 25, 5, 6) | forms.box(width, height, 11, 25, 20, 30)
    forms.paint(picture, mouth, "ink")
    forms.paint(picture, forms.shrunk(mouth), "soil_dark")
    rect(picture, 12, 29, 19, 30, "stone_dark")
    for x in (13, 16, 18):
        picture[29][x] = "ember"
    picture[28][15] = "flame"
    _footing(picture, 31, 35, 151)
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def oven():
    """A bake oven of brick, 32x30 px: a dome of bricks in staggered courses with an arched
    mouth, its iron door leaning aside, on a base of field stones with a hearth ledge in front."""
    width, height = 32, 30
    picture = blank(width, height)
    xs, ys = forms.grid(width, height)
    dome = forms.ellipse(width, height, 16, 18, 15, 17) & (ys < 18)
    level = forms.light_level(dome, 6, top_light=0.2)
    forms.shade_by_level(picture, dome, BRICK, level)
    # Courses of brick 4 rows high, the joints staggered.
    for y in range(3, 18, 4):
        for x in range(32):
            if dome[y, x]:
                picture[y][x] = "rust_dark"
        for x in range(2 + (y // 4) % 2 * 4, 32, 8):
            for dy in (1, 2, 3):
                if y + dy < 18 and dome[y + dy, x]:
                    picture[y + dy][x] = "rust_dark"
    # The mouth: a dark arch, the iron door leaning beside it.
    mouth = forms.ellipse(width, height, 15, 13, 5, 5) | forms.box(width, height, 10, 13, 19, 17)
    forms.paint(picture, mouth, "soil_dark")
    forms.paint(picture, forms.shrunk(mouth), "ink")
    rect(picture, 22, 9, 25, 17, "stone_dark")
    rect(picture, 22, 9, 22, 17, "stone")
    picture[13][24] = "stone_light"
    # The base of field stones and the hearth ledge in front of the mouth.
    _footing(picture, 18, 29, 161)
    rect(picture, 8, 18, 22, 19, "stone_light")
    rect(picture, 8, 20, 22, 20, "stone")
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def flour():
    """A small linen sack of flour, open at the top, with flour spilt in front."""
    picture = blank(ICON)
    body = ellipse(16, 19, 10, 9) | box(6, 19, 26, 27)
    shade(picture, body, LINEN, radius=4)
    paint(picture, ellipse(16, 10, 8, 3), "lime")
    paint(picture, ellipse(16, 10.5, 6, 2), "snow_light")
    for x, y in ((9, 15), (12, 23), (22, 21)):
        line(picture, x, y, x + 2, y - 3, "snow_shadow")
    shade(picture, ellipse(9, 29, 5, 1.6) | ellipse(22, 29.5, 3, 1.2), LINEN, radius=1)
    return picture


def bread():
    """A round rye loaf with a floured crust and cuts across it."""
    picture = blank(ICON)
    loaf = ellipse(16, 18, 14, 10)
    shade(picture, loaf, ("umber", "ochre_dark", "ochre"), radius=5, top_light=0.1)
    for x in (9, 15, 21):
        line(picture, x, 12, x + 4, 18, "sand_light")
        line(picture, x + 1, 12, x + 5, 18, "umber")
    dots(picture, [(8, 20), (13, 22), (24, 15), (19, 23), (6, 15)], "sand_light")
    return picture


def berry_tart():
    """A round tart in its pastry crust, full of berries."""
    picture = blank(ICON)
    shade(picture, ellipse(16, 19, 14, 8), ("ochre_dark", "ochre", "gold"), radius=3)
    shade(picture, ellipse(16, 17.5, 11, 5), ("heather_dark", "heather", "petal"), radius=2)
    for x, y in ((9, 17), (13, 15), (18, 16), (22, 18), (15, 19), (11, 19), (20, 14)):
        shade(picture, ellipse(x, y, 1.8, 1.6), ("heather_dark", "heather", "petal"), radius=1)
        dots(picture, [(x - 1, y - 1)], "cream")
    rect(picture, 4, 22, 28, 22, "ochre")
    for x in range(5, 28, 3):
        dots(picture, [(x, 24)], "umber")
    return picture


def cupboard():
    """A joined oak cupboard, 32x48 px: a moulded cornice, two doors with two raised panels each
    and brass knobs, a drawer under them, on bun feet. It stands in a house."""
    picture = blank(32, 48)
    # The cornice, lit on top, its moulding in shadow below.
    rect(picture, 0, 0, 31, 4, "soil_light")
    rect(picture, 0, 0, 31, 1, "sand")
    rect(picture, 1, 3, 30, 3, "soil_mid")
    rect(picture, 1, 4, 30, 5, "soil")
    # The carcass: lit down its left stile, dark down its right.
    rect(picture, 1, 6, 30, 43, "soil_mid")
    rect(picture, 1, 6, 2, 43, "soil_light")
    rect(picture, 29, 6, 30, 43, "soil")
    _grain(picture, 3, 6, 28, 42, "soil", 225, 10)
    # The doors, each with two raised panels: lit on their top and left, shaded on their bottom
    # and right; the seam between the doors.
    for left in (4, 16):
        for top, bottom in ((8, 18), (21, 32)):
            rect(picture, left + 1, top, left + 10, bottom, "soil_mid")
            rect(picture, left + 1, top, left + 10, top, "soil_light")
            rect(picture, left + 1, top, left + 1, bottom, "soil_light")
            rect(picture, left + 10, top + 1, left + 10, bottom, "soil")
            rect(picture, left + 2, bottom, left + 10, bottom, "soil_dark")
    rect(picture, 15, 6, 16, 34, "soil")
    rect(picture, 15, 6, 15, 34, "soil_dark")
    for x in (13, 18):
        rect(picture, x, 19, x + 1, 20, "gold")
        picture[19][x] = "cream"
    # The drawer under the doors, its two knobs.
    rect(picture, 4, 36, 27, 41, "soil")
    rect(picture, 4, 36, 27, 36, "soil_light")
    rect(picture, 4, 41, 27, 41, "soil_dark")
    for x in (10, 21):
        rect(picture, x, 38, x + 1, 39, "gold")
        picture[38][x] = "cream"
    # The bun feet.
    for x in (2, 25):
        rect(picture, x, 44, x + 4, 47, "soil")
        rect(picture, x, 44, x + 1, 45, "soil_mid")
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def feast_cake():
    """A tall round cake for a feast, iced, with a band of jam, strawberries and berries on
    top."""
    picture = blank(ICON)
    side = ellipse(16, 24, 12, 4) | box(4, 12, 27, 24)
    shade(picture, side, ("ochre_dark", "ochre", "leaf_orange"), radius=3)
    rect(picture, 4, 18, 27, 19, "rust")
    shade(picture, ellipse(16, 12, 12, 4), ("lime", "cream", "snow_light"), radius=2)
    for x in range(5, 28, 4):
        rect(picture, x, 14, x + 1, 15 + x % 3, "cream")
    strawberry, berry = ("rust_dark", "ember", "red_light"), ("heather_dark", "heather", "petal")
    for x, y, ramp in ((10, 10, strawberry), (16, 8, strawberry), (22, 10, strawberry), (13, 12, berry), (19, 12, berry)):
        shade(picture, ellipse(x, y, 2.2, 2), ramp, radius=1)
    dots(picture, [(16, 5), (17, 5)], "green")
    return picture


def bricks(face, top, end):
    """Two bricks, one on the other and set back: `face` is their front, `top` their lit top
    and `end` the dark end, with a few pits in the clay."""
    picture = blank(ICON)
    for left, bottom in ((7, 15), (3, 26)):
        rect(picture, left, bottom - 8, left + 20, bottom, face)
        rect(picture, left + 2, bottom - 10, left + 22, bottom - 9, top)
        rect(picture, left + 21, bottom - 8, left + 22, bottom - 1, end)
        for x, y in ((4, 3), (11, 5), (16, 2), (8, 6)):
            dots(picture, [(left + x, bottom - 8 + y)], end)
    return picture


def stool():
    """A three-legged milking stool of oak: a round seat lit on its top, the legs splayed."""
    picture = blank(ICON)
    for start, end in (((11, 14), (6, 29)), ((21, 14), (26, 29)), ((16, 15), (16, 27))):
        shade(picture, capsule(start, end, 1.6), OAK, radius=1)
    seat = ellipse(16, 12, 12, 4.5) | box(4, 12, 27, 15) | ellipse(16, 15, 12, 4.5)
    shade(picture, seat, OAK, radius=2)
    top = ellipse(16, 11.5, 11, 3.5)
    shade(picture, top, ("soil_mid", "soil_light", "sand"), radius=1)
    grain(picture, top, "soil_mid", (10, 12))
    return picture


def pancakes():
    """Buckwheat pancakes, a stack of three on a wooden plate, dark and lacy at their rims, a
    pat of butter on top."""
    picture = blank(ICON)
    shade(picture, ellipse(16, 24, 15, 5), OAK, radius=2)
    for y in (21, 18, 15):
        cake = ellipse(16, y, 12, 4) | ellipse(16, y + 1.5, 12, 4)
        shade(picture, cake, ("soil", "soil_mid", "soil_light"), radius=2)
        paint(picture, ellipse(16, y, 10, 3), "ochre_dark")
        dots(picture, [(10, y), (14, y + 1), (20, y), (22, y + 1), (17, y - 1)], "soil_mid")
    shade(picture, box(14, 11, 19, 14), ("ochre", "gold", "cream"), radius=1)
    return picture


def stations():
    """The pictures of the stations, standing, by world object type."""
    return {"workbench": workbench(), "carved_chest": carved_chest(), "kiln": kiln(), "oven": oven(), "cupboard": cupboard()}


def _without_clear_columns(picture):
    """The picture of a camp object, drawn on a cell as wide as a tree's, cut to what is drawn."""
    drawn = [x for x in range(len(picture[0])) if any(row[x] not in (None, "shadow") for row in picture)]
    return [row[drawn[0] : drawn[-1] + 1] for row in picture]


def icons():
    """The bodies of the icons of the professions' items, by item id."""
    return {
        "workbench": icon_of(workbench()),
        "kiln": icon_of(kiln()),
        "oven": icon_of(oven()),
        "fireplace": icon_of(_without_clear_columns(camp.fireplace())),
        "sleeping_bag": icon_of(_without_clear_columns(camp.bedroll())),
        "planks": planks(),
        "cupboard": icon_of(cupboard()),
        # Dried clay, grey-brown, and fired, red.
        "raw_brick": bricks("mud", "sand", "mud_dark"),
        "brick": bricks("rust", "red_light", "rust_dark"),
        "stool": stool(),
        "carved_chest": icon_of(carved_chest()),
        "roast_turnip": roast_turnip(),
        # Cabbage, carrot and onion in a broth.
        "pottage": bowl(("olive", "dry_light", "green_light"), ("ochre", "flame", "cream")),
        # Yellow split peas, thick.
        "pea_soup": bowl(("reed", "straw", "dry_light"), ("straw", "gold")),
        "buckwheat_pancakes": pancakes(),
        "flour": flour(),
        "bread": bread(),
        "berry_tart": berry_tart(),
        "feast_cake": feast_cake(),
    }
