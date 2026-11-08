"""The parish church of a marsh village, its bell frame and the graves of its churchyard.

The church (assets/buildings/church.png) is drawn like the houses in buildings.py, at 32 px per
tile, from the south in 3/4 view: a nave of grey-brown tuff ashlar with the lower chancel to the
east, under steep roofs of red pantiles, small round-arched windows of leaded glass in brick
arches, and a low porch on the south side whose gable faces the front, with the round-arched
church door in it. An iron cross stands on the west gable and on the porch. The small marsh
parishes had no tower: the bells hung in a free-standing wooden frame (Glockenstapel,
bell_frame.png), an open oak frame on a brick base under a pyramid of oak shingles, the bell in
it. The churchyard wall is the fieldstone wall of boundaries.py; the graves (an oak cross, a
sandstone headstone and a fieldstone slab) are world objects, a row of the object atlas.
"""

import math
import random

import forms
import items
from buildings import OAK, RED_BRICKS, SHADED, brick_wall, door, eaves_shadow, fieldstone_base, glass, ground_shadow, lime_wall
from canvas import GAME_TILE, blank, outline_edge, rect

# Tuff ashlar: the blocks, mostly grey, some browner, each lit along its top, and the joints
# between them.
TUFF = ("stone", "stone", "sand")
TUFF_LIT = {"stone": "stone_light", "sand": "sand_light"}
TUFF_JOINT = "stone_dark"
# The shade of each colour of a pantile in the shadow of the course above.
PANTILE_SHADED = {"red_light": "rust", "rust": "rust_dark", "rust_dark": "russet_deep", "russet_deep": "russet_deep"}
# Across a pantile, 10 px wide: the roll lit on its left, the trough dark on its right.
PANTILE_COLUMNS = ("red_light", "red_light", "rust", "rust", "rust", "rust", "rust_dark", "rust_dark", "russet_deep", "rust_dark")
# The height of a course of pantiles, in px.
PANTILE_COURSE = 10
# Weathered oak shingles, silver-grey: lit, in shade, and the gaps between them.
SHINGLE = ("stone_light", "stone", "stone_dark")
# A bronze bell: its lit edge, its body, its shade, its deep shade.
BRONZE = ("gold", "ochre", "ochre_dark", "soil")
# The colour of everything's outline, as on the houses.
OUTLINE = "soil_dark"


def ashlar(picture, rng, left, right, top, bottom):
    """A wall of cut tuff blocks 15 px long and 6 high in thin dark joints, each course offset
    from the one below and each block lit along its top, a few with a weathered pit; the
    rightmost columns, round the corner, in shade."""
    rect(picture, left, top, right, bottom, TUFF_JOINT)
    for row, y in enumerate(range(bottom - 5, top - 7, -7)):
        for x in range(left - (row % 2) * 8, right + 1, 16):
            colour = rng.choice(TUFF)
            rect(picture, max(left, x), max(top, y), min(right, x + 14), y + 5, colour)
            rect(picture, max(left, x), max(top, y), min(right, x + 13), y, TUFF_LIT[colour])
            rect(picture, max(left, x), max(top, y), max(left, x), y + 4, TUFF_LIT[colour])
            if rng.random() < 0.3:
                px, py = rng.randint(x + 3, x + 11), rng.randint(y + 2, y + 4)
                if left <= px <= right and top <= py:
                    picture[py][px] = TUFF_JOINT
    for y in range(top, bottom + 1):
        for x in (right - 3, right - 2, right - 1, right):
            picture[y][x] = SHADED.get(picture[y][x], picture[y][x])


def pantile_roof(picture, snowy, rng, left, right, ridge_y, eaves_y):
    """A roof of red pantiles seen from its eaves side, over the columns left..right from the
    ridge down to the eaves. The S-shaped tiles lie in columns 10 px wide, each roll lit on its
    left and the trough dark on its right, in courses 10 px high: the lip at the foot of each
    course catches the light over the shadow it casts on the course below. Over the years a
    tile here and there was replaced by a darker one, a few have yellow lichen, and moss grows
    on the lips low on the roof. Half-round ridge tiles along the top, the verges lit on the
    left and shaded on the right."""
    first = ridge_y + 6
    for y in range(first, eaves_y + 1):
        for x in range(left, right + 1):
            column, row = (x - left) % 10, (y - first) % PANTILE_COURSE
            colour = PANTILE_COLUMNS[column]
            if row < 2:
                colour = PANTILE_SHADED[colour]
            elif row >= PANTILE_COURSE - 2 and column < 7:
                colour = "red_light" if column < 4 else "rust"
            picture[y][x] = colour
            snowy.add((x, y))
    for course_top in range(first, eaves_y + 1, PANTILE_COURSE):
        low = (course_top - first) / (eaves_y - first)
        for tile_left in range(left, right + 1, 10):
            if rng.random() < 0.12:
                for y in range(course_top + 2, min(eaves_y, course_top + 7) + 1):
                    for x in range(tile_left, min(right, tile_left + 8) + 1):
                        picture[y][x] = PANTILE_SHADED[picture[y][x]]
            if rng.random() < 0.08:
                lx, ly = tile_left + rng.randint(1, 5), course_top + rng.randint(3, 5)
                rect(picture, lx, ly, min(right, lx + 1), ly, "ochre")
                picture[ly + 1][lx] = "ochre"
            # Moss on the lips, more of it low on the roof, where it stays damp.
            lip = course_top + PANTILE_COURSE - 1
            if lip <= eaves_y and rng.random() < 0.35 * low:
                rect(picture, tile_left + 1, lip, min(right, tile_left + rng.randint(2, 6)), lip, "olive")
                picture[lip - 1][tile_left + 2] = "dry"
    # The ridge tiles, joined every 14 px, and the verges.
    for y, colour in zip(range(ridge_y, first), ("red_light", "red_light", "rust", "rust", "rust_dark", "russet_deep")):
        rect(picture, left, y, right, y, colour)
        for x in range(left, right + 1):
            snowy.add((x, y))
    for x in range(left + 6, right, 14):
        rect(picture, x, ridge_y + 1, x, ridge_y + 4, "russet_deep")
        rect(picture, x + 1, ridge_y + 1, x + 1, ridge_y + 2, "red_light")
    rect(picture, left + 1, ridge_y, left + 2, eaves_y, "red_light")
    rect(picture, right - 2, ridge_y, right - 1, eaves_y, "rust_dark")
    rect(picture, left, eaves_y - 1, right, eaves_y, "russet_deep")


def church_window(picture, cx, top, bottom, is_lit):
    """A small round-arched window 14 px wide in a brick arch: glass in diamond panes of lead,
    in a dark reveal, over a stone sill."""
    half = 7
    spring = top + half

    def inside(x, y, grow):
        if y >= spring:
            return abs(x + 0.5 - cx) <= half + grow
        return math.hypot(x + 0.5 - cx, y + 0.5 - spring) <= half + grow

    for y in range(top - 6, bottom + 1):
        for x in range(cx - 13, cx + 14):
            if inside(x, y, 0):
                if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                    picture[y][x] = "stone_dark"
                else:
                    picture[y][x] = glass((x - cx + half) / (2 * half), (y - top) / (bottom - top), is_lit)
            elif inside(x, y, 2):
                picture[y][x] = "stone_dark"
            elif y < spring and inside(x, y, 6):
                # The voussoirs of the arch, in alternating reds, lit on the left.
                angle = math.atan2(y + 0.5 - spring, x + 0.5 - cx)
                picture[y][x] = ("red_light" if x < cx else "rust") if round(angle * 6) % 2 else "rust_dark"
    rect(picture, cx - 9, bottom + 1, cx + 9, bottom + 2, "stone_light")
    rect(picture, cx - 9, bottom + 3, cx + 9, bottom + 4, "stone")


def iron_cross(picture, cx, top):
    """A small iron cross 11 px wide and 18 high, lit on the left, its foot at top + 17."""
    rect(picture, cx - 1, top, cx + 1, top + 17, "stone_dark")
    rect(picture, cx - 5, top + 4, cx + 5, top + 6, "stone_dark")
    rect(picture, cx - 1, top, cx - 1, top + 17, "stone")
    rect(picture, cx - 5, top + 4, cx + 5, top + 4, "stone")


def church(is_lit):
    """A small church on 6x4 tiles, from the south: the tall nave with the lower chancel at its
    east end, both of tuff on a fieldstone base under red pantiles; three small arched windows;
    the low porch on the third tile, its gable to the front, with the round-arched oak door."""
    rng = random.Random(386)
    width, height = 6 * GAME_TILE, 256
    picture = blank(width, height)
    snowy = set()
    base_top = height - 14
    nave_left, nave_right, nave_top = 6, 139, 148
    chancel_right, chancel_top = width - 7, 176
    ashlar(picture, rng, nave_right + 1, chancel_right, chancel_top, base_top - 1)
    ashlar(picture, rng, nave_left, nave_right, nave_top, base_top - 1)
    fieldstone_base(picture, rng, nave_left, chancel_right, base_top, height - 3)
    church_window(picture, 26, 172, 204, is_lit)
    church_window(picture, 122, 172, 204, is_lit)
    church_window(picture, 163, 196, 222, is_lit)
    # The chancel's roof first, as the nave's gable end rises over it.
    pantile_roof(picture, snowy, rng, nave_right - 5, width - 1, 88, 180)
    pantile_roof(picture, snowy, rng, 0, nave_right + 6, 32, 156)
    eaves = {x: 156 if x <= nave_right + 6 else 180 for x in range(width)}
    eaves_shadow(picture, eaves, nave_left, chancel_right)
    iron_cross(picture, 9, 14)
    porch(picture, snowy, rng, 54, 106, 150, base_top, height)
    outline_edge(picture, OUTLINE, keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


def brick_arch(picture, cx, spring, radius):
    """An arch of red bricks 4 px deep over an opening of `radius` round (cx, spring), the
    bricks lit on the left."""
    for y in range(spring - radius - 6, spring):
        for x in range(cx - radius - 6, cx + radius + 7):
            distance = math.hypot(x + 0.5 - cx, y + 0.5 - spring)
            if radius + 1 < distance <= radius + 5:
                angle = math.atan2(y + 0.5 - spring, x + 0.5 - cx)
                if round(angle * 7) % 2:
                    picture[y][x] = "red_light" if x < cx else "rust"
                else:
                    picture[y][x] = "rust_dark"


def porch(picture, snowy, rng, left, right, apex, base_top, height):
    """The porch, its gable to the front between the columns left..right with its peak at
    `apex`: lime-washed on a fieldstone base, so that it stands out from the tuff of the nave,
    the wash flaking near the foot; the pantiles of its roof showing above the rakes, an iron
    cross on the peak and the oak door in a stone surround under a brick arch. It casts a
    shadow on the wall to its right, and a dark edge parts it from the wall on either side."""
    cx = (left + right) // 2

    def rake(x):
        return apex + abs(x - cx)

    porch_picture = blank(len(picture[0]), height)
    lime_wall(porch_picture, rng, left, right, apex, base_top - 1)
    fieldstone_base(porch_picture, rng, left, right, base_top, height - 3)
    door_left, door_top, door_width = cx - 11, 190, 22
    door(porch_picture, door_left, door_top, height - 6, door_width, ("soil_light", "soil_mid", "soil", "soil_dark"),
         frame=("stone_light", "stone"), arched=True, split=False)
    brick_arch(porch_picture, cx, door_top + door_width // 2, door_width // 2 + 2)
    # The roof over the rakes, 12 rows deep: the tiles, lit on the left slope, with a lit edge
    # and a shaded one, and a joint between the tiles every 5 px.
    depths = ("red_light", "red_light", "red_light", "rust", "rust", "rust", "rust", "rust_dark", "rust_dark", "rust_dark", "russet_deep", "russet_deep")
    for x in range(left - 2, right + 3):
        top = rake(x)
        for y in range(top - len(depths) + 1, height):
            if y <= top:
                depth = y - (top - len(depths) + 1)
                colour = depths[depth]
                if x > cx and colour in ("red_light", "rust"):
                    colour = PANTILE_SHADED[colour]
                if (x - cx) % 5 == 0 and 2 <= depth <= 8:
                    colour = "rust_dark"
                picture[y][x] = colour
                if depth < 5:
                    snowy.add((x, y))
            elif porch_picture[y][x] is not None:
                picture[y][x] = porch_picture[y][x]
    rect(picture, cx - 1, apex - 13, cx + 1, apex - 10, "red_light")
    iron_cross(picture, cx, apex - 29)
    for x in range(right + 3, right + 9):
        for y in range(rake(right) - 4, base_top):
            if picture[y][x] in SHADED:
                picture[y][x] = SHADED[picture[y][x]]
    for x in (left - 2, right + 2):
        rect(picture, x, rake(x) + 1, x, height - 3, OUTLINE)


def bell_frame(is_lit):
    """The free-standing bell frame (Glockenstapel) on 2x2 tiles: an open oak frame on a brick
    base, its two front posts leaning in under a pyramid roof of oak shingles with an iron
    finial, braced crosswise below the rail; the bronze bell hangs from the head beam, the back
    posts showing behind it. `is_lit` changes nothing: it has no windows."""
    rng = random.Random(387)
    width, height = 2 * GAME_TILE, 168
    picture = blank(width, height)
    snowy = set()
    apex, eaves_y, sill, base_top = 10, 56, 128, 136
    # The back posts, in shade, and the cross braces between the front posts below the rail.
    for x in (22, 39):
        rect(picture, x, eaves_y, x + 3, sill, OAK[1])
        rect(picture, x + 3, eaves_y, x + 3, sill, OAK[2])
    for step in range(26):
        for x, colour in ((14 + step, OAK[0]), (47 - step, OAK[1])):
            rect(picture, x, 101 + step, x + 2, 101 + step, colour)
            picture[101 + step][x + 3] = OAK[2]
    # The front posts, leaning in, lit on the left; the head beam, the rail and the sill.
    for step, y in enumerate(range(eaves_y, sill + 1)):
        lean = 8 - step * 8 // (sill - eaves_y)
        for x0 in (6 + lean, 52 - lean):
            rect(picture, x0, y, x0 + 5, y, OAK[0])
            picture[y][x0] = "soil_light"
            rect(picture, x0 + 4, y, x0 + 5, y, OAK[1])
    for y in (eaves_y + 2, 96):
        rect(picture, 12, y, 51, y + 4, OAK[0])
        rect(picture, 12, y, 51, y, "soil_light")
        rect(picture, 12, y + 4, 51, y + 4, OAK[2])
    rect(picture, 4, sill, 59, sill + 5, OAK[0])
    rect(picture, 4, sill, 59, sill, "soil_light")
    rect(picture, 4, sill + 5, 59, sill + 5, OAK[2])
    # The bell, hung from the head beam, its mouth dark with the clapper in it; lit on the left
    # and shaded round to the right, with a ring round its waist and a lip at its mouth.
    rect(picture, 29, eaves_y + 7, 34, eaves_y + 8, "stone_dark")
    rect(picture, 30, eaves_y + 9, 33, eaves_y + 11, "stone_dark")
    halves = (5, 6, 6, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 10, 10, 11, 12, 13, 13)
    for row, half in enumerate(halves):
        y = eaves_y + 12 + row
        for x in range(32 - half, 32 + half):
            across = (x - 32 + half) / (2 * half)
            shade = 0 if across < 0.18 else 1 if across < 0.5 else 2 if across < 0.82 else 3
            if row in (8, len(halves) - 3):
                shade = min(3, shade + 1)
            if row == len(halves) - 1:
                shade = 2
            picture[y][x] = BRONZE[shade]
    mouth = eaves_y + 12 + len(halves)
    rect(picture, 21, mouth, 42, mouth + 1, "soil_dark")
    rect(picture, 30, mouth, 33, mouth + 3, "stone_dark")
    rect(picture, 30, mouth, 30, mouth + 2, "stone")
    # The brick base, capped with a course of headers.
    brick_wall(picture, rng, 4, 59, base_top, height - 3, RED_BRICKS, "sand")
    rect(picture, 2, base_top - 2, 61, base_top - 1, "red_light")
    rect(picture, 2, base_top, 61, base_top + 1, "rust_dark")
    for x in range(4, 60, 5):
        rect(picture, x, base_top - 2, x, base_top - 1, "rust")
    # The pyramid of shingles: courses of 5 rows, the shingles 6 px wide and staggered, the
    # left face lit, each shingle's foot in shade; a drip edge at the eaves and an iron finial.
    for y in range(apex, eaves_y + 1):
        half = (y - apex) * 30 // (eaves_y - apex) + 2
        course, row = divmod(y - apex, 5)
        for x in range(32 - half, 32 + half):
            lit = x < 32
            if row == 4 or (x + course * 3) % 6 == 0:
                colour = SHINGLE[1] if lit else SHINGLE[2]
            else:
                colour = SHINGLE[0] if lit else SHINGLE[1]
            picture[y][x] = colour
            snowy.add((x, y))
    rect(picture, 0, eaves_y + 1, width - 1, eaves_y + 2, SHINGLE[2])
    rect(picture, 31, 0, 32, apex - 1, "stone_dark")
    rect(picture, 31, 0, 31, apex - 1, "stone")
    rect(picture, 28, 3, 35, 4, "stone_dark")
    outline_edge(picture, OUTLINE, keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


def oak_cross():
    """An oak cross, 22x32 px, its arms a little below the top: square-sawn beams lit on their
    left and top faces, grain along them, weathered grey on top and green with lichen at the
    foot, a little turf round it."""
    picture = blank(22, 32)
    for x0, y0, x1, y1 in ((8, 0, 13, 31), (0, 8, 21, 13)):
        rect(picture, x0, y0, x1, y1, "soil_mid")
        rect(picture, x0, y0, x1, y0 + 1, "soil_light")
        rect(picture, x0, y0, x0 + 1, y1, "soil_light")
        rect(picture, x1, y0 + 2, x1, y1, "soil")
        rect(picture, x0 + 2, y1, x1, y1, "soil")
    rng = random.Random(313)
    for _ in range(9):
        x, y = rng.randint(10, 12), rng.randint(2, 29)
        rect(picture, x, y, x, min(30, y + rng.randint(1, 3)), "soil")
    for _ in range(5):
        x, y = rng.randint(2, 19), rng.randint(10, 11)
        rect(picture, x, y, min(20, x + rng.randint(1, 3)), y, "soil")
    # The end grain of the post's top and of the arms, weathered grey.
    rect(picture, 8, 0, 13, 0, "bare_light")
    rect(picture, 0, 8, 0, 13, "bare_light")
    picture[9][21] = picture[10][21] = "bare"
    for x, y in ((9, 28), (10, 29), (12, 27), (9, 30)):
        picture[y][x] = "olive"
    outline_edge(picture, "soil_dark", keep_bottom=True)
    for x, height in ((5, 2), (6, 3), (7, 1), (14, 2), (15, 3), (16, 1)):
        rect(picture, x, 31 - height + 1, x, 31, "green_dark" if height > 1 else "green")
    return picture


def headstone():
    """A headstone of sandstone, 22x28 px, its top round: a dome lit on its upper left, a cross
    cut into it over three lines of letters, lichen and moss on its foot."""
    width, height = 22, 28
    picture = blank(width, height)
    xs, ys = forms.grid(width, height)
    stone = (ys >= 10) | (((xs - 11) / 10.5) ** 2 + ((ys - 10.5) / 10.5) ** 2 <= 1)
    stone &= (xs > 0.5) & (xs < width - 0.5)
    forms.shade(picture, stone, ("mud", "sand", "sand_light"), radius=4)
    # The cross and the letters cut in, dark on their upper edge where the cut is in shade.
    rect(picture, 10, 4, 11, 12, "mud_dark")
    rect(picture, 7, 6, 14, 7, "mud_dark")
    rect(picture, 10, 4, 11, 4, "mud")
    for y, (left, right) in zip((16, 19, 22), ((4, 17), (5, 16), (7, 14))):
        for x in range(left, right + 1, 2):
            picture[y][x] = "mud_dark"
    rect(picture, 2, 25, 7, 27, "olive")
    rect(picture, 3, 24, 5, 24, "dry")
    picture[26][15] = picture[27][16] = "olive"
    return outline_edge(picture, "mud_dark", keep_bottom=True)


def fieldstone_slab():
    """A low slab of grey granite, 26x18 px, rough on top, lit on its upper left, a cross cut into
    it, a patch of lichen."""
    width, height = 26, 18
    picture = blank(width, height)
    rng = random.Random(343)
    tops = [round(6 - 6 * math.sin(math.pi * (x + 0.5) / width) ** 0.6 + rng.uniform(-0.6, 0.6)) for x in range(width)]
    stone = forms.box(width, height, 0, 0, width - 1, height - 1)
    for x, top in enumerate(tops):
        stone[: max(0, top), x] = False
    forms.shade(picture, stone, ("stone_dark", "stone", "stone_light"), radius=4, top_light=0.3)
    for _ in range(14):
        x, y = rng.randrange(1, width - 1), rng.randrange(4, height - 1)
        if stone[y, x]:
            picture[y][x] = rng.choice(("stone_light", "stone_dark"))
    rect(picture, 12, 4, 13, 13, "stone_dark")
    rect(picture, 8, 7, 17, 8, "stone_dark")
    for x, y in ((4, 12), (5, 13), (4, 14), (20, 6), (21, 7)):
        picture[y][x] = "olive"
    return outline_edge(picture, "stone_dark", keep_bottom=True)


def graves():
    """The looks of a grave, standing: the variants of the world object `grave`."""
    return [oak_cross(), headstone(), fieldstone_slab()]


def icons():
    """The body of the icon of the grave marker, the item that places a grave: the oak cross."""
    return {"grave_marker": items.icon_of(oak_cross())}


# How to draw each building, by its id in data/buildings.cfg (generate.py adds them to those of
# buildings.py).
PICTURES = {"church": church, "bell_frame": bell_frame}
