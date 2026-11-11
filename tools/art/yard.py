"""The farm yard (task 122), drawn at 32 px per tile: the draw well with its sweep, the trough, the
hay rack and the chicken coop.

Each is drawn once, standing (its bottom row on the ground), the way the stations are (crafts.py):
generate.py puts the world objects into their cells of the object atlas on a ground shadow and the
coop into assets/buildings/, and the bodies of the icons of the items that place them are their
pictures. Each is rimmed in the darkest shade of its own colours, light from the top left.
"""

import math
import random

import forms
import items
from buildings import fieldstone_base, ground_shadow
from canvas import GAME_TILE, blank, outline_edge, rect

# The wet oak of posts, poles and planks, lit to dark.
OAK = ("soil_light", "soil_mid", "soil", "soil_dark")
OAK_FACES = ("soil_light", "soil_mid", "soil")


def _oak_beam(picture, x0, y0, x1, y1):
    """A square oak beam from (x0, y0) to (x1, y1), both ends included, lit on its left and top."""
    rect(picture, x0, y0, x1, y1, OAK[1])
    rect(picture, x0, y0, x0, y1, OAK[0])
    rect(picture, x0, y0, x1, y0, OAK[0])
    rect(picture, x1, y0 + 1, x1, y1, OAK[2])
    rect(picture, x0 + 1, y1, x1, y1, OAK[2])


def _pole(picture, start, end, thickness):
    """An oak pole from `start` to `end` (x, y), thickness px thick, lit along its top."""
    (x0, y0), (x1, y1) = start, end
    for x in range(min(x0, x1), max(x0, x1) + 1):
        top = round(y0 + (x - x0) * (y1 - y0) / (x1 - x0))
        for row in range(thickness):
            picture[top + row][x] = OAK[0] if row == 0 else OAK[2] if row == thickness - 1 else OAK[1]


WELL_WIDTH, WELL_HEIGHT = 60, 80
# The ring of the well: the middle of its top face, and how far it reaches across and down.
RING_X, RING_Y = 30, 61
RING_RX, RING_RY, RING_WALL = 15, 7, 11
# The ground shadow lies under the ring only, not the post: half its width.
WELL_SHADOW = 19


def draw_well():
    """The draw well, 60x80 px: a ring of fieldstones in courses under an oak coping, the dark
    water in its mouth; beside it a forked oak post, and on the fork the balanced sweep, its
    long end over the well with a rope and an oak bucket, a round weight stone hung from its
    short end. The ring stands in the middle of the picture, over the tile the well covers; the
    post and the weight reach out over the tile beside it."""
    picture = blank(WELL_WIDTH, WELL_HEIGHT)
    height = WELL_HEIGHT
    # The post behind the ring, forked at its head, with a few stones heaped at its foot.
    post_x = 49
    _oak_beam(picture, post_x, 14, post_x + 3, height - 3)
    for x0 in (post_x - 2, post_x + 4):
        _oak_beam(picture, x0, 9, x0 + 1, 18)
    rect(picture, post_x + 1, 12, post_x + 2, 14, OAK[3])
    for x0, y0, w, h in ((45, height - 7, 6, 5), (52, height - 6, 6, 4), (49, height - 9, 5, 4)):
        stone = forms.ellipse(WELL_WIDTH, height, x0 + w / 2, y0 + h / 2, w / 2, h / 2)
        forms.shade(picture, stone, ("stone_dark", "stone", "stone_light"), radius=2)
    # The sweep: a long pole through the fork, the long end lower and over the well. The short end
    # carries the weight stone on a rope; the rope of the bucket hangs from the long end.
    _pole(picture, (60 - 2, 5), (20, 28), 3)
    rect(picture, 55, 8, 55, 12, "sand")
    stone = forms.ellipse(WELL_WIDTH, height, 55.5, 17, 4.8, 4.5)
    forms.shade(picture, stone, ("stone_dark", "stone", "stone_light"), radius=3)
    rect(picture, 22, 30, 22, 43, "sand")
    # The oak bucket on its rope, narrower at the foot, hooped in iron, an iron bail over its mouth.
    for x, y in ((18, 44), (19, 43), (20, 42), (21, 42), (23, 42), (24, 42), (25, 43), (26, 44)):
        picture[y][x] = "stone"
    for row, y in enumerate(range(45, 54)):
        left, right = 18 + row // 5, 26 - row // 5
        rect(picture, left, y, right, y, OAK[1])
        picture[y][left] = OAK[0]
        picture[y][right] = OAK[2]
        if row in (2, 6):
            rect(picture, left, y, right, y, "stone")
    rect(picture, 19, 54, 25, 54, OAK[3])
    # The ring: its wall of fieldstones in three courses, the top face an oak coping round the
    # dark water.
    ring = forms.ellipse(WELL_WIDTH, height, RING_X, RING_Y, RING_RX, RING_RY)
    wall = ring.copy()
    for drop in range(1, RING_WALL + 1):
        wall[drop:] |= ring[:-drop]
    rng = random.Random(122)
    stones = {}
    for y in range(RING_Y, RING_Y + RING_RY + RING_WALL + 1):
        course = (y - RING_Y) // 4
        for x in range(RING_X - RING_RX, RING_X + RING_RX + 1):
            if not wall[y][x]:
                continue
            index = (x + (course % 2) * 3) // 6
            key = (course, index)
            stones.setdefault(key, rng.choice((0, 1, 1, 2)))
            lit = x < RING_X - RING_RX // 3
            shade = ("stone_dark", "stone", "stone_light")[min(2, max(0, stones[key] + (1 if lit else -1) + (1 if x < RING_X else 0)))]
            is_joint = (y - RING_Y) % 4 == 3 or (x + (course % 2) * 3) % 6 == 5
            picture[y][x] = "stone_dark" if is_joint else shade
    coping = ring
    rect_inner = forms.ellipse(WELL_WIDTH, height, RING_X, RING_Y, RING_RX - 4, RING_RY - 2.5)
    forms.paint(picture, coping & ~rect_inner, OAK[1])
    for x in range(RING_X - RING_RX, RING_X + RING_RX + 1):
        for y in range(height):
            if coping[y][x] and not rect_inner[y][x]:
                lit_edge = y == 0 or not coping[y - 1][x] or x < RING_X - RING_RX + 3
                picture[y][x] = OAK[0] if lit_edge else OAK[1] if (x + y) % 7 else OAK[2]
    forms.paint(picture, rect_inner, "water_deep")
    water_mask = rect_inner.copy()
    water_mask[: RING_Y - 1] = False
    forms.paint(picture, forms.shrunk(water_mask), "water")
    for x, y in ((RING_X - 5, RING_Y + 1), (RING_X - 4, RING_Y + 1), (RING_X + 2, RING_Y), (RING_X + 3, RING_Y)):
        picture[y][x] = "water_light"
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def egg_icon():
    """The body of the egg's icon: two hen's eggs, a brown one and a white one lying against each
    other, shaded from the top left."""
    body = blank(items.ICON)
    brown = items.ellipse(12, 19, 6.5, 8.5, 20)
    white = items.ellipse(20, 16, 6.5, 8.5, -15)
    items.shade(body, brown, ("sand", "straw", "sand_light"), radius=4)
    items.shade(body, white, ("stone_light", "lime", "snow_light"), radius=4)
    items.dots(body, [(10, 15), (11, 14), (18, 11), (19, 10)], "snow_light")
    return body


def icons():
    """The bodies of the icons of the yard's items, by item id: their pictures."""
    return {
        "draw_well": items.icon_of(draw_well()),
        "trough": items.icon_of(trough(3)),
        "feed_trough": items.icon_of(trough(3, "feed")),
        "hay_rack": items.icon_of(hay_rack(3)),
        "egg": egg_icon(),
    }


# What the trough and the hay rack look like at each of their four fills (see WorldObject
# `stock_look`): empty, low, half and full.
STOCK_LOOKS = 4
HAY = ("ochre_dark", "ochre", "straw", "gold")


def _hay(picture, mask, rng):
    """Hay in the mask of a picture: a mound lit from the top left, with wisps of straw and gold
    lying along it."""
    height, width = len(picture), len(picture[0])
    forms.shade(picture, mask, HAY, radius=5, top_light=0.3)
    for y, x in zip(*mask.nonzero()):
        if rng.random() < 0.18:
            dx = rng.choice((-1, 1))
            colour = rng.choice(("gold", "straw", "ochre_dark", "sand"))
            for step in range(rng.randrange(2, 5)):
                nx, ny = x + step * dx, y + step
                if 0 <= nx < width and 0 <= ny < height and mask[ny, nx]:
                    picture[ny][nx] = colour


# The feed in a feeding trough (task 165): a brown mash of acorns, beech mast and chopped turnip.
FEED = ("umber", "ochre_dark", "ochre", "straw")


def _feed(picture, x0, y0, x1, y1):
    """The feed lying in the trough from x0 to x1 and from y0 down to the floor at y1: a lumpy
    mash lit along its top, with acorns and bits of turnip in it."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if y == y0 and x % 6 in (0, 5):
                continue
            light = 2 if y == y0 or (y == y0 + 1 and x % 6 in (0, 5)) else 0 if y == y1 else 1
            colour = FEED[light]
            if (x * 7 + y * 3) % 11 == 0 and y > y0:
                colour = "soil"
            elif (x * 5 + y) % 9 == 0:
                colour = FEED[3]
            picture[y][x] = colour


def trough(level, fill="water"):
    """The trough, 64x26 px: a box of oak planks on two feet, seen from the front and a little
    above, its end boards lit on the left. Inside, `fill` ("water", or "feed" in a feeding trough)
    by `level` (0 empty, 1 low, 2 half, 3 full): none, a puddle or a heap in the middle, a pool
    or a layer along the floor, up to the rim."""
    width, height = 2 * GAME_TILE, 26
    picture = blank(width, height)
    # The feet, then the front of the box in planks with two seams and an iron band at each end.
    for x0 in (5, 53):
        rect(picture, x0, 22, x0 + 5, height - 1, OAK[2])
        rect(picture, x0, 22, x0, height - 1, OAK[1])
    rect(picture, 0, 11, width - 1, 21, OAK[1])
    rect(picture, 0, 11, width - 1, 11, "sand_light")
    rect(picture, 0, 12, width - 1, 12, OAK[0])
    for y in (15, 19):
        rect(picture, 0, y, width - 1, y, OAK[2])
        rect(picture, 0, y + 1, width - 1, y + 1, OAK[0])
    rect(picture, 0, 21, width - 1, 21, OAK[2])
    rng = random.Random(1220)
    for _ in range(14):
        x, y = rng.randrange(4, width - 12), rng.choice((13, 17))
        rect(picture, x, y, x + rng.randrange(3, 8), y, OAK[2])
    for x0 in (7, 54):
        rect(picture, x0, 11, x0 + 2, 21, "stone")
        rect(picture, x0, 11, x0, 21, "stone_light")
    # The inside: the back plank, then the floor, darker where it is wet, and the end boards.
    rect(picture, 0, 0, width - 1, 1, OAK[0])
    rect(picture, 0, 2, width - 1, 10, OAK[2])
    rect(picture, 3, 2, width - 4, 3, OAK[3])
    rect(picture, 0, 0, 2, 21, OAK[0])
    rect(picture, 3, 2, 3, 10, OAK[3])
    rect(picture, width - 3, 0, width - 1, 21, OAK[2])
    rect(picture, width - 3, 2, width - 3, 10, OAK[3])
    water = {
        1: (24, 6, 39, 9),
        2: (7, 5, 56, 9),
        3: (4, 3, 59, 9),
    }.get(level)
    if water and fill == "feed":
        _feed(picture, *water)
    elif water:
        x0, y0, x1, y1 = water
        rect(picture, x0, y0, x1, y1, "water_deep")
        rect(picture, x0 + 1, y0 + 1, x1 - 1, y1, "water")
        for x in range(x0 + 3, x1 - 3, 7):
            rect(picture, x, y0 + 1 + (x // 7) % 2, x + 2, y0 + 1 + (x // 7) % 2, "water_light")
        for x, y in ((x0 + 1, y0), (x1 - 1, y0), (x0, y1), (x1, y1)):
            picture[y][x] = OAK[2] if level == 1 else "water_deep"
        if level == 3:
            rect(picture, x0 + 2, y0 + 1, x0 + 6, y0 + 1, "foam")
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def trough_looks(fill="water"):
    return [trough(level, fill) for level in range(STOCK_LOOKS)]


def hay_rack(level):
    """The hay rack, 64x44 px: two oak posts joined by a rail at the top and a manger board at the
    foot, between them slats with the hay behind them, by `level` (0 empty, 1 low, 2 half,
    3 full): bare back boards, a heap at the foot, up to the middle, up to the rail. What has
    fallen lies on the ground in front."""
    width, height = 2 * GAME_TILE, 44
    picture = blank(width, height)
    rail_y, manger_y = 4, 30
    # The back boards, in the shade behind the slats, and the hay in front of them.
    rect(picture, 7, rail_y + 3, 56, manger_y, OAK[3])
    rect(picture, 7, rail_y + 3, 56, rail_y + 4, "soil_dark")
    rng = random.Random(1221)
    top = {0: manger_y, 1: 22, 2: 14, 3: rail_y}.get(level)
    if level:
        mound = forms.grid(width, height)
        xs, ys = mound
        sag = 3 * (1 - ((xs - 32) / 25) ** 2).clip(0)
        mask = (ys >= top + 4 - sag * (level < 3)) & (ys <= manger_y) & (xs > 7) & (xs < 57)
        _hay(picture, mask, rng)
    # The posts with caps, and the rail and the manger board across them.
    for x0 in (2, 57):
        _oak_beam(picture, x0, 0, x0 + 4, height - 3)
        rect(picture, x0 - 1, 0, x0 + 5, 1, OAK[0])
    _oak_beam(picture, 2, rail_y, 61, rail_y + 2)
    rect(picture, 2, manger_y, 61, manger_y + 5, OAK[1])
    rect(picture, 2, manger_y, 61, manger_y, "sand_light")
    rect(picture, 2, manger_y + 1, 61, manger_y + 1, OAK[0])
    rect(picture, 2, manger_y + 5, 61, manger_y + 5, OAK[2])
    rect(picture, 2, manger_y + 3, 61, manger_y + 3, OAK[2])
    # The slats (they lean out towards the foot, seen end on from the front), lit on their left.
    for x in range(10, 56, 6):
        rect(picture, x, rail_y + 3, x, manger_y - 1, OAK[0])
        rect(picture, x + 1, rail_y + 3, x + 1, manger_y - 1, OAK[1])
        rect(picture, x + 2, rail_y + 3, x + 2, manger_y - 1, OAK[2])
    # What has fallen lies on the ground.
    if level:
        for _ in range(8 + 4 * level):
            x, y = rng.randrange(8, 56), rng.randrange(manger_y + 6, height - 1)
            rect(picture, x, y, x + rng.randrange(1, 4), y, rng.choice(("straw", "gold", "ochre")))
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def hay_rack_looks():
    return [hay_rack(level) for level in range(STOCK_LOOKS)]


# The boards of the coop's walls: tarred oak, lit edge, face, joint.
TARRED = ("soil_mid", "soil", "soil_dark")
# The weathered grey boards of its roof: lit edge, face, joint.
ROOF_BOARDS = ("bare_light", "bare", "mud")
COOP_HEIGHT = 80


def _coop_roof(picture, snowy):
    """The shed roof, low and sloping to the front: boards laid down the slope, 5 px wide, each
    lit on its first pixel, a ridge board along the top, a drip edge with its shadow at the eaves."""
    width = len(picture[0])
    ridge, eaves = 6, 31
    for y in range(ridge, eaves + 1):
        # The left end is cut at a slant, so that the roof has an end to it.
        left = max(0, 6 - (y - ridge) // 4)
        for x in range(left, width - left):
            board = (x - left) % 5
            colour = ROOF_BOARDS[0] if board == 0 else ROOF_BOARDS[2] if board == 4 else ROOF_BOARDS[1]
            if (x * 7 + y * 3) % 23 == 0:
                colour = ROOF_BOARDS[2]
            picture[y][x] = colour
            snowy.add((x, y))
    rect(picture, 4, ridge - 1, width - 5, ridge, "sand_light")
    rect(picture, 4, ridge + 1, width - 5, ridge + 1, "bare")
    rect(picture, 0, eaves + 1, width - 1, eaves + 2, "mud_dark")
    rect(picture, 2, eaves + 3, width - 3, eaves + 4, "shadow")


def _coop_wall(picture, rng, left, right, top, bottom):
    """The wall of upright tarred boards, 4 px wide, each lit on its left edge, the grain in them."""
    for x in range(left, right + 1):
        board = (x - left) % 4
        colour = TARRED[0] if board == 0 else TARRED[2] if board == 3 else TARRED[1]
        rect(picture, x, top, x, bottom, colour)
    for _ in range(40):
        x, y = rng.randrange(left, right), rng.randrange(top + 2, bottom - 2)
        if (x - left) % 4 in (1, 2):
            rect(picture, x, y, x, y + rng.randrange(1, 4), TARRED[2])


def chicken_coop(is_lit):
    """The chicken coop on 2x2 tiles, low and boarded: tarred upright boards on a footing of field
    stones under a low shed roof of grey boards. On the left the plank door with its strap hinges
    and latch, the player's way in (the door tile of the building); in the middle the hen's hatch, a
    small dark opening, with a ramp up to it, a plank with cleats across it; on the right the nest
    box, boarded like the wall, its lid a hinged plank propped a little open. `is_lit` changes nothing: it has no windows."""
    rng = random.Random(1222)
    width, height = 2 * GAME_TILE, COOP_HEIGHT
    picture = blank(width, height)
    snowy = set()
    wall_top, foot_top = 34, 70
    _coop_wall(picture, rng, 1, width - 2, wall_top, foot_top - 1)
    rect(picture, 1, wall_top, width - 2, wall_top + 1, "soil_dark")
    fieldstone_base(picture, rng, 0, width - 1, foot_top, height - 3)
    # The hatch: a dark square opening in a lit frame, a little roost bar behind it.
    rect(picture, 36, 42, 47, 55, "bare_light")
    rect(picture, 38, 44, 45, 55, "ink")
    rect(picture, 38, 44, 45, 44, "soil_dark")
    rect(picture, 38, 53, 45, 53, "soil_mid")
    # The ramp up to it: a plank widening towards the ground, cleats across it every 4 px.
    for y in range(56, foot_top + 5):
        half = 4 + (y - 56) // 6
        rect(picture, 41 - half, y, 41 + half, y, "bare")
        picture[y][41 - half] = "bare_light"
        picture[y][41 + half] = "mud"
        if (y - 56) % 4 == 2:
            rect(picture, 41 - half, y, 41 + half, y, "soil_dark")
            rect(picture, 41 - half, y - 1, 41 + half, y - 1, "soil_light")
    # The door: planks 4 px wide, a Z of braces across, iron strap hinges, a latch.
    left, top, right = 8, 42, 23
    rect(picture, left - 2, top - 2, right + 2, foot_top - 1, "bare_light")
    rect(picture, right + 1, top - 2, right + 2, foot_top - 1, "mud")
    for x in range(left, right + 1):
        rect(picture, x, top, x, foot_top - 1, "soil_mid" if (x - left) % 4 else "soil_light")
        picture[top][x] = "soil_dark"
    for step in range(right - left + 1):
        picture[top + 4 + step * 18 // (right - left)][left + step] = "soil_dark"
        picture[top + 5 + step * 18 // (right - left)][left + step] = "soil_dark"
    for y in (top + 4, foot_top - 8):
        rect(picture, left, y, left + 8, y + 1, "stone")
        rect(picture, left, y, left + 8, y, "stone_light")
    rect(picture, right - 3, top + 14, right - 2, top + 17, "stone_light")
    rect(picture, right - 3, top + 17, right - 2, top + 17, "stone_dark")
    # The nest box: boarded like the wall, standing out a little from it, its lid propped open.
    rect(picture, 50, 52, 62, foot_top - 1, TARRED[1])
    rect(picture, 50, 52, 50, foot_top - 1, TARRED[0])
    rect(picture, 62, 52, 62, foot_top - 1, TARRED[2])
    rect(picture, 55, 58, 55, foot_top - 1, TARRED[2])
    rect(picture, 49, 48, 63, 51, "bare_light")
    rect(picture, 49, 51, 63, 51, "bare")
    rect(picture, 49, 47, 63, 47, "sand_light")
    rect(picture, 51, 52, 52, 53, "stone")
    rect(picture, 60, 52, 61, 53, "stone")
    _coop_roof(picture, snowy)
    outline_edge(picture, "soil_dark", keep_bottom=True, ignoring=("shadow",))
    ground_shadow(picture)
    return picture, snowy


PICTURES = {"chicken_coop": chicken_coop}
