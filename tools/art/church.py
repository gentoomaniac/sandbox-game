"""The parish church of a marsh village, its bell frame and the graves of its churchyard.

The church (assets/buildings/church.png) is drawn like the houses in buildings.py, from the
south in 3/4 view: a nave of grey-brown tuff ashlar with the lower chancel to the east, under
steep roofs of red pantiles, small round-arched windows of leaded glass in brick arches, and a
low porch on the south side whose gable faces the front, with the round-arched church door in
it. An iron cross stands on the west gable and on the porch. The small marsh parishes had no
tower: the bells hung in a free-standing wooden frame (Glockenstapel, bell_frame.png), an open
oak frame on a brick base under a pyramid of oak shingles, the bell in it. The churchyard wall
is the fieldstone wall of boundaries.py; the graves (an oak cross, a sandstone headstone and a
fieldstone slab) are world objects, a row of the object atlas.
"""

import math
import random

import crafts
import interior
from buildings import LIME, OAK, SHADED, eaves_shadow, fieldstone_base, brick_wall, glass, ground_shadow, outline, plank_door
from canvas import TILE, blank, rect

# Tuff ashlar: the blocks, mostly grey, some browner, each lit along its top, and the joints
# between them.
TUFF = ("stone", "stone", "sand")
TUFF_LIT = {"stone": "stone_light", "sand": "sand_light"}
TUFF_JOINT = "stone_dark"
# Weathered oak shingles, silver-grey: lit, in shade, and the gaps between them.
SHINGLE = ("stone_light", "stone", "stone_dark")
# A bronze bell: its lit edge, its body, its shade.
BRONZE = ("gold", "ochre", "ochre_dark")
# The colour of everything's outline, as on the houses.
OUTLINE = "soil_dark"


def ashlar(picture, rng, left, right, top, bottom):
    """A wall of cut tuff blocks 7 px long and 3 high in thin dark joints, each course offset
    from the one below and each block lit along its top; the rightmost columns, round the
    corner, in shade."""
    rect(picture, left, top, right, bottom, TUFF_JOINT)
    for row, y in enumerate(range(bottom - 2, top - 4, -4)):
        for x in range(left - (row % 2) * 4, right + 1, 8):
            colour = rng.choice(TUFF)
            rect(picture, max(left, x), max(top, y), min(right, x + 6), y + 2, colour)
            rect(picture, max(left, x), max(top, y), min(right, x + 5), y, TUFF_LIT[colour])
    for y in range(top, bottom + 1):
        for x in (right - 1, right):
            picture[y][x] = SHADED.get(picture[y][x], picture[y][x])


def pantile_roof(picture, snowy, rng, left, right, ridge_y, eaves_y):
    """A roof of red pantiles seen from its eaves side, over the columns left..right from the
    ridge down to the eaves. The S-shaped tiles lie in columns 5 px wide, each roll lit on its
    left and the trough dark on its right, in courses 5 px high: the lip at the foot of each
    course catches the light over the shadow it casts on the course below. Over the years a
    tile here and there was replaced by a darker one, a few have yellow lichen, and moss grows
    on the lips low on the roof. Half-round
    ridge tiles along the top, the verges lit on the left and shaded on the right."""
    shades = {"red_light": "rust", "rust": "rust_dark", "rust_dark": "russet_deep", "russet_deep": "russet_deep"}
    first = ridge_y + 3
    for y in range(first, eaves_y + 1):
        for x in range(left, right + 1):
            column, row = (x - left) % 5, (y - first) % 5
            colour = ("red_light", "rust", "rust", "rust_dark", "rust_dark")[column]
            if row == 0:
                colour = shades[colour]
            elif row == 4 and column < 4:
                colour = "red_light" if column < 2 else "rust"
            picture[y][x] = colour
            snowy.add((x, y))
    for course_top in range(first, eaves_y + 1, 5):
        for tile_left in range(left, right + 1, 5):
            if rng.random() < 0.12:
                for y in range(course_top + 1, min(eaves_y, course_top + 4) + 1):
                    for x in range(tile_left, min(right, tile_left + 4) + 1):
                        picture[y][x] = shades[picture[y][x]]
            if rng.random() < 0.06:
                picture[course_top + 2][tile_left + 1] = "ochre"
            # Moss on the lips, more of it low on the roof, where it stays damp.
            if course_top + 4 <= eaves_y and rng.random() < 0.3 * (course_top - first) / (eaves_y - first):
                rect(picture, tile_left, course_top + 4, min(right, tile_left + rng.randint(1, 3)), course_top + 4, "olive")
                picture[course_top + 3][tile_left + 1] = "dry"
    # The ridge tiles, joined every 7 px, and the verges.
    for y, colour in zip(range(ridge_y, first), ("red_light", "rust", "rust_dark")):
        rect(picture, left, y, right, y, colour)
        for x in range(left, right + 1):
            snowy.add((x, y))
    for x in range(left + 3, right, 7):
        rect(picture, x, ridge_y + 1, x, ridge_y + 2, "russet_deep")
    rect(picture, left + 1, ridge_y, left + 1, eaves_y, "red_light")
    rect(picture, right - 1, ridge_y, right - 1, eaves_y, "rust_dark")
    rect(picture, left, eaves_y, right, eaves_y, "russet_deep")


def church_window(picture, cx, top, bottom, is_lit):
    """A small round-arched window 7 px wide in a brick arch: glass in diamond panes of lead,
    in a dark reveal, over a stone sill."""
    half = 3.5
    spring = top + 4

    def inside(x, y, grow):
        if y >= spring:
            return abs(x + 0.5 - cx - 0.5) <= half + grow
        return math.hypot(x + 0.5 - cx - 0.5, y + 0.5 - spring) <= half + grow

    for y in range(top - 3, bottom + 1):
        for x in range(cx - 6, cx + 7):
            if inside(x, y, 0):
                if (x + y) % 3 == 0 or (x - y) % 3 == 0:
                    picture[y][x] = "stone_dark"
                else:
                    picture[y][x] = glass(x, y, cx, (top + bottom) // 2, is_lit)
            elif inside(x, y, 1):
                picture[y][x] = "stone_dark"
            elif y < spring and inside(x, y, 3):
                # The voussoirs of the arch, in alternating reds.
                angle = math.atan2(y + 0.5 - spring, x - cx)
                picture[y][x] = "red_light" if round(angle * 4) % 2 else "rust"
    rect(picture, cx - 4, bottom + 1, cx + 4, bottom + 1, "stone_light")
    rect(picture, cx - 4, bottom + 2, cx + 4, bottom + 2, "stone")


def iron_cross(picture, cx, top):
    """A small iron cross 5 px wide and 9 high, its foot at top + 8."""
    rect(picture, cx, top, cx, top + 8, "stone_dark")
    rect(picture, cx - 2, top + 2, cx + 2, top + 2, "stone_dark")


def church(is_lit):
    """A small church on 6x4 tiles, from the south: the tall nave with the lower chancel at its
    east end, both of tuff on a fieldstone base under red pantiles; three small arched windows;
    the low porch on the third tile, its gable to the front, with the round-arched oak door."""
    rng = random.Random(386)
    width, height = 6 * TILE, 128
    picture = blank(width, height)
    snowy = set()
    base_top = height - 7
    nave_left, nave_right, nave_top = 3, 69, 74
    chancel_right, chancel_top = width - 4, 88
    ashlar(picture, rng, nave_right + 1, chancel_right, chancel_top, base_top - 1)
    ashlar(picture, rng, nave_left, nave_right, nave_top, base_top - 1)
    fieldstone_base(picture, rng, nave_left, chancel_right, base_top, height - 2)
    church_window(picture, 13, 86, 101, is_lit)
    church_window(picture, 61, 86, 101, is_lit)
    church_window(picture, 81, 98, 110, is_lit)
    # The chancel's roof first, as the nave's gable end rises over it.
    pantile_roof(picture, snowy, rng, nave_right - 2, width - 1, 44, 90)
    pantile_roof(picture, snowy, rng, 0, nave_right + 3, 16, 78)
    eaves = {x: 78 if x <= nave_right + 3 else 90 for x in range(width)}
    eaves_shadow(picture, eaves, nave_left, chancel_right)
    iron_cross(picture, 4, 7)
    porch(picture, snowy, rng, 27, 53, 86, base_top, height)
    outline(picture, OUTLINE)
    ground_shadow(picture)
    return picture, snowy


def brick_arch(picture, cx, spring, radius):
    """An arch of red bricks 2 px deep over an opening of `radius` round (cx, spring)."""
    for y in range(spring - radius - 3, spring):
        for x in range(cx - radius - 3, cx + radius + 4):
            distance = math.hypot(x - cx, y + 0.5 - spring)
            if radius + 0.5 < distance <= radius + 2.5:
                angle = math.atan2(y + 0.5 - spring, x - cx)
                picture[y][x] = "red_light" if round(angle * 5) % 2 else "rust"


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
    rect(porch_picture, left, apex, right, base_top - 1, LIME[0])
    rect(porch_picture, right - 1, apex, right, base_top - 1, LIME[1])
    for _ in range(6):
        porch_picture[base_top - rng.randint(1, 4)][rng.randint(left, right - 2)] = "sand"
    fieldstone_base(porch_picture, rng, left, right, base_top, height - 2)
    door_left, door_top, door_width = cx - 5, 104, 11
    plank_door(porch_picture, door_left, door_top, height - 4, door_width, ("soil_light", "soil_mid", "soil"), arched=True)
    for y in range(door_top - 1, height - 3):
        for x in range(door_left - 1, door_left + door_width + 1):
            if porch_picture[y][x] == "snow_light":
                porch_picture[y][x] = "stone_light"
    brick_arch(porch_picture, cx, door_top + door_width // 2, door_width // 2 + 2)
    for x in range(left - 1, right + 2):
        top = rake(x)
        for y in range(top - 5, height):
            if y <= top:
                # The tiles, lit on the left slope, with a lit edge and a shaded one.
                depth = y - (top - 5)
                colour = ("red_light", "red_light", "rust", "rust", "rust_dark", "russet_deep")[depth]
                if x > cx and colour in ("red_light", "rust"):
                    colour = {"red_light": "rust", "rust": "rust_dark"}[colour]
                if (x - cx) % 3 == 0 and 1 <= depth <= 3:
                    colour = "rust_dark"
                picture[y][x] = colour
                if depth < 3:
                    snowy.add((x, y))
            elif porch_picture[y][x] is not None:
                picture[y][x] = porch_picture[y][x]
    rect(picture, cx, apex - 6, cx, apex - 4, "red_light")
    iron_cross(picture, cx, apex - 14)
    for x in range(right + 2, right + 5):
        for y in range(rake(right) - 2, base_top):
            if picture[y][x] in SHADED:
                picture[y][x] = SHADED[picture[y][x]]
    for x in (left - 1, right + 1):
        rect(picture, x, rake(x) + 1, x, height - 2, OUTLINE)


def bell_frame(is_lit):
    """The free-standing bell frame (Glockenstapel) on 2x2 tiles: an open oak frame on a brick
    base, its two front posts leaning in under a pyramid roof of oak shingles with an iron
    finial, braced crosswise below the rail; the bronze bell hangs from the head beam, the back
    posts showing behind it. `is_lit` changes nothing: it has no windows."""
    rng = random.Random(387)
    width, height = 2 * TILE, 84
    picture = blank(width, height)
    snowy = set()
    apex, eaves_y, sill, base_top = 5, 28, 64, 68
    # The back posts, in shade, and the cross braces between the front posts below the rail.
    for x in (11, 20):
        rect(picture, x, eaves_y, x + 1, sill, "soil")
        rect(picture, x + 1, eaves_y, x + 1, sill, OAK[1])
    for step in range(13):
        for x, colour in ((7 + step, "soil_mid"), (24 - step, "soil")):
            rect(picture, x, 51 + step, x + 1, 51 + step, colour)
    # The front posts, leaning in, lit on the left; the head beam, the rail and the sill.
    for step, y in enumerate(range(eaves_y, sill + 1)):
        lean = 4 - step * 4 // (sill - eaves_y)
        for x0 in (3 + lean, 26 - lean):
            rect(picture, x0, y, x0 + 2, y, "soil_mid")
            picture[y][x0] = "soil_light"
            picture[y][x0 + 2] = "soil"
    for y in (eaves_y + 1, 48):
        rect(picture, 6, y, 25, y + 1, "soil_mid")
        rect(picture, 6, y, 25, y, "soil_light")
        rect(picture, 6, y + 2, 25, y + 2, "soil")
    rect(picture, 2, sill, 29, sill + 2, "soil_mid")
    rect(picture, 2, sill, 29, sill, "soil_light")
    # The bell, hung from the head beam, its mouth dark with the clapper in it.
    rect(picture, 15, eaves_y + 4, 16, eaves_y + 5, "stone_dark")
    halves = (2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 6)
    for row, half in enumerate(halves):
        y = eaves_y + 6 + row
        for x in range(16 - half, 16 + half):
            third = (x - 16 + half) * 3 // (2 * half)
            picture[y][x] = BRONZE[2] if row == len(halves) - 1 else BRONZE[min(2, third)]
        picture[y][16 - half] = BRONZE[0] if row < len(halves) - 1 else BRONZE[1]
    mouth = eaves_y + 6 + len(halves)
    rect(picture, 12, mouth, 19, mouth, "soil_dark")
    rect(picture, 15, mouth, 16, mouth + 1, "stone_dark")
    # The brick base, capped with a course of headers.
    brick_wall(picture, rng, 2, 29, base_top, height - 2, ("rust", "rust", "red_light", "rust_dark"), "sand")
    rect(picture, 1, base_top - 1, 30, base_top - 1, "red_light")
    rect(picture, 1, base_top, 30, base_top, "rust_dark")
    # The pyramid of shingles: courses of 3 rows, the shingles 3 px wide and staggered, the
    # left face lit; a drip edge at the eaves and an iron finial on top.
    for y in range(apex, eaves_y + 1):
        half = (y - apex) * 15 // (eaves_y - apex) + 1
        course = (y - apex) // 3
        for x in range(16 - half, 16 + half):
            lit = x < 16
            if (y - apex) % 3 == 2 or (x + course * 2) % 4 == 0:
                colour = SHINGLE[1] if lit else SHINGLE[2]
            else:
                colour = SHINGLE[0] if lit else SHINGLE[1]
            picture[y][x] = colour
            snowy.add((x, y))
    rect(picture, 0, eaves_y + 1, width - 1, eaves_y + 1, SHINGLE[2])
    rect(picture, 16, 0, 16, apex - 1, "stone_dark")
    rect(picture, 14, 2, 18, 2, "stone_dark")
    outline(picture, OUTLINE)
    ground_shadow(picture)
    return picture, snowy


def oak_cross():
    """An oak cross, 11x16 px, lit on the left, its arms a little below the top."""
    picture = blank(11, 16)
    rect(picture, 4, 0, 6, 15, "soil_mid")
    rect(picture, 0, 4, 10, 6, "soil_mid")
    rect(picture, 4, 0, 4, 15, "soil_light")
    rect(picture, 0, 4, 10, 4, "soil_light")
    rect(picture, 6, 7, 6, 15, "soil")
    rect(picture, 0, 6, 10, 6, "soil")
    return interior.outline(picture, "soil_dark", keep_bottom=True)


def headstone():
    """A headstone of sandstone, 11x14 px, its top round, a cross cut into it over three lines
    of letters; lichen on its foot."""
    picture = blank(11, 14)
    for y in range(14):
        for x in range(11):
            if y >= 5 or math.hypot(x - 5, y - 5) <= 5.5:
                picture[y][x] = "sand_light" if x < 3 or y < 2 else "sand" if x < 9 else "mud"
    rect(picture, 5, 2, 5, 6, "mud")
    rect(picture, 3, 3, 7, 3, "mud")
    for y, (left, right) in zip((8, 10), ((2, 8), (3, 7))):
        for x in range(left, right + 1, 2):
            picture[y][x] = "mud"
    rect(picture, 1, 12, 3, 12, "olive")
    picture[11][2] = "dry"
    return interior.outline(picture, "mud_dark", keep_bottom=True)


def fieldstone_slab():
    """A low slab of grey granite, 13x9 px, rough on top, a cross cut into it."""
    picture = blank(13, 9)
    tops = (3, 2, 1, 1, 0, 0, 0, 1, 1, 1, 2, 2, 3)
    for x, top in enumerate(tops):
        for y in range(top, 9):
            picture[y][x] = "stone_light" if y <= top + 1 or x < 2 else "stone" if x < 11 else "stone_dark"
    rect(picture, 6, 2, 6, 6, "stone_dark")
    rect(picture, 4, 3, 8, 3, "stone_dark")
    return interior.outline(picture, "stone_dark", keep_bottom=True)


def graves():
    """The looks of a grave, standing: the variants of the world object `grave`."""
    return [oak_cross(), headstone(), fieldstone_slab()]


def icons():
    """The icon of the grave marker, the item that places a grave: the oak cross."""
    return {"grave_marker": crafts.icon_of(oak_cross())}


# How to draw each building, by its id in data/buildings.cfg (generate.py adds them to those of
# buildings.py).
PICTURES = {"church": church, "bell_frame": bell_frame}
