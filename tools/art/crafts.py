"""The art of the professions (task 74): the stations they work at and what they make.

A station is drawn once, standing (its bottom row on the ground), like the chest: generate.py puts
that picture into its cell of the object atlas (outdoors), writes it as assets/interior/<type>.png
(inside a house, and the ghost while it is placed) and makes its item icon from it, outlined all
round. Item icons are 16x16 pictures, named after the item id of game/state/item_types.gd;
generate.py writes them with the other icons (and their 8x8 ground versions). Cooked food is warm
in colour; the meals in a bowl steam a little.
"""

import chest
from canvas import blank, outline_edge, rect
from items import ICON, LINEN, OAK, box, capsule, dots, ellipse, from_rows, grain, icon_of, line, paint, pixel, polygon, shade

# The workbench: a thick beech top on four legs with a stretcher, a vice screw at its left end
# and a saw lying on it.
WORKBENCH_ROWS = (
    ".TTTTTTTTTTTTTT.",
    "TTTTTTTTTTTTTTTT",
    "tttttttttttttttt",
    "FFFFFFFFFFFFFFFF",
    "FiiFFFFFFFFFFFFF",
    "fiiffffffffffffs",
    "LLl..........LLl",
    "LLl..........LLl",
    "LLlSSSSSSSSSSLLl",
    "LLl..........LLl",
    "LLl..........LLl",
)
WORKBENCH_KEYS = {
    "T": "sand_light",
    "t": "sand",
    "F": "soil_light",
    "f": "soil_mid",
    "s": "soil",
    "i": "stone_light",
    "L": "soil_light",
    "l": "soil_mid",
    "S": "soil_mid",
}

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


def workbench(is_standing=True):
    """The workbench, 16x11 px with its outline; standing, its bottom row has none."""
    picture = from_rows(WORKBENCH_ROWS, WORKBENCH_KEYS)
    # The saw on the top: its blade with teeth along the front and, at the right, its handle.
    rect(picture, 4, 1, 10, 1, "stone_light")
    for x in range(4, 11, 2):
        pixel(picture, x, 2, "stone")
    rect(picture, 11, 1, 12, 2, "soil")
    return outline_edge(picture, "soil_dark", keep_bottom=is_standing)


# The carved chest is the chest painted as the Frisian chests were: blue-green with a pale lid,
# flowers on its front.
PAINTED_CHEST = {"soil_light": "water_light", "soil_mid": "paint_teal", "soil": "water", "sand": "foam"}
CHEST_FLOWERS = ((4, 8), (11, 8), (4, 3), (11, 3))


def carved_chest(is_standing=True):
    """The chest, painted and with a flower on each side of its lock."""
    picture = [[PAINTED_CHEST.get(name, name) for name in row] for row in chest.chest(is_standing)]
    for x, y in CHEST_FLOWERS:
        pixel(picture, x, y, "petal")
        pixel(picture, x, y + 1, "cream")
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


KILN_WIDTH = 16
KILN_HEIGHT = 18


def kiln(is_standing=True):
    """A small beehive kiln of clay on a fieldstone footing, 16x18 px: the smoke hole at its top,
    courses of clay round its dome, and the arched mouth where the fire is laid."""
    picture = blank(KILN_WIDTH, KILN_HEIGHT)
    for y in range(2, KILN_HEIGHT):
        half = min(7, 3 + (y - 2) // 2)
        left, right = 8 - half - 1, 8 + half
        rect(picture, left, y, right, y, "mud")
        picture[y][left] = "sand"
        rect(picture, right - 1, y, right, y, "mud_dark")
        if y % 3 == 0:
            for x in range(left + 1 + y % 2, right - 1, 3):
                picture[y][x] = "mud_dark"
    # The rim and the smoke hole.
    rect(picture, 5, 0, 10, 1, "sand")
    rect(picture, 6, 1, 9, 2, "soil_dark")
    # The mouth, an arch over the ash.
    rect(picture, 6, 11, 9, 15, "soil_dark")
    rect(picture, 7, 10, 8, 10, "soil_dark")
    rect(picture, 6, 15, 9, 15, "stone_dark")
    # The footing of field stones.
    rect(picture, 0, 16, 15, 17, "stone")
    for x in (2, 6, 11, 14):
        picture[16][x] = "stone_light"
    for x in (4, 9, 13):
        picture[17][x] = "stone_dark"
    return outline_edge(picture, "soil_dark", keep_bottom=is_standing)


def oven(is_standing=True):
    """A bake oven of brick, 16x15 px: a dome with an arched mouth on a fieldstone base."""
    picture = blank(16, 15)
    for y in range(9):
        half = (4, 5, 6, 7, 7, 7, 7, 7, 7)[y]
        left, right = 8 - half - 1, 8 + half
        rect(picture, left, y, right, y, "rust")
        picture[y][left] = "red_light"
        rect(picture, right - 1, y, right, y, "rust_dark")
        # Courses of brick, the joints staggered.
        if y % 2 == 1:
            rect(picture, left + 1, y, right - 2, y, "rust_dark")
        elif y > 0:
            for x in range(left + 2 + y % 4, right - 1, 4):
                picture[y][x] = "rust_dark"
    # The mouth, with its iron door leaning aside.
    rect(picture, 6, 4, 9, 8, "soil_dark")
    rect(picture, 7, 3, 8, 3, "soil_dark")
    rect(picture, 11, 6, 12, 8, "stone_dark")
    # The base of field stones, with a hearth ledge in front of the mouth.
    rect(picture, 0, 9, 15, 14, "stone")
    rect(picture, 0, 9, 15, 9, "stone_light")
    for x, y in ((3, 11), (9, 12), (13, 11), (6, 13)):
        picture[y][x] = "stone_dark"
    return outline_edge(picture, "soil_dark", keep_bottom=is_standing)


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


def cupboard(is_standing=True):
    """A joined oak cupboard, 16x24 px: a cornice, two panelled doors with brass knobs over a
    drawer, on short feet. It stands in a house."""
    picture = blank(16, 24)
    rect(picture, 0, 0, 15, 2, "soil_light")
    rect(picture, 0, 2, 15, 2, "soil")
    rect(picture, 1, 3, 14, 21, "soil_mid")
    rect(picture, 1, 3, 1, 21, "soil_light")
    rect(picture, 14, 3, 14, 21, "soil")
    # The doors, each with two sunk panels, and the seam between them.
    for left in (2, 8):
        for top, bottom in ((4, 9), (11, 16)):
            rect(picture, left + 1, top, left + 4, bottom, "soil")
            rect(picture, left + 1, top, left + 4, top, "soil_dark")
    rect(picture, 7, 3, 8, 17, "soil")
    pixel(picture, 6, 10, "gold")
    pixel(picture, 9, 10, "gold")
    # The drawer under the doors, and the feet.
    rect(picture, 2, 18, 13, 20, "soil")
    rect(picture, 2, 18, 13, 18, "soil_light")
    pixel(picture, 7, 19, "gold")
    pixel(picture, 8, 19, "gold")
    rect(picture, 1, 22, 3, 23, "soil")
    rect(picture, 12, 22, 14, 23, "soil")
    return outline_edge(picture, "soil_dark", keep_bottom=is_standing)


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


def stations():
    """The pictures of the stations, standing, by world object type."""
    return {"workbench": workbench(), "carved_chest": carved_chest(), "kiln": kiln(), "oven": oven(), "cupboard": cupboard()}


def icons():
    """The bodies of the icons of the professions' items, by item id."""
    return {
        "workbench": icon_of(workbench(is_standing=False)),
        "kiln": icon_of(kiln(is_standing=False)),
        "oven": icon_of(oven(is_standing=False)),
        "planks": planks(),
        "cupboard": icon_of(cupboard(is_standing=False)),
        # Dried clay, grey-brown, and fired, red.
        "raw_brick": bricks("mud", "sand", "mud_dark"),
        "brick": bricks("rust", "red_light", "rust_dark"),
        "stool": stool(),
        "carved_chest": icon_of(carved_chest(is_standing=False)),
        "roast_turnip": roast_turnip(),
        # Cabbage, carrot and onion in a broth.
        "pottage": bowl(("olive", "dry_light", "green_light"), ("ochre", "flame", "cream")),
        # Yellow split peas, thick.
        "pea_soup": bowl(("reed", "straw", "dry_light"), ("straw", "gold")),
        "flour": flour(),
        "bread": bread(),
        "berry_tart": berry_tart(),
        "feast_cake": feast_cake(),
    }
