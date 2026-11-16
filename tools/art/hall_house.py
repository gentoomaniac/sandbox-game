"""The hall house (assets/buildings/hall_house.png and hall_house_lit.png): it shows its
half-timbered gable and its big barn door to the front, its roof running back up the picture,
with horse heads on the bargeboards of the half-hipped thatch.

The thatch courses, walls, windows and the other drawing the houses share are in buildings.py.
"""

import math
import random

from buildings import COURSE, EAVES_ROLL, EAVES_ROWS, MOSS, OAK, RED_BRICKS, THATCH, brick_wall, eaves_shadow, fieldstone_base, ground_shadow, moss_patches, mossy, thatch_course, window
from canvas import GAME_TILE, blank, outline_edge, rect

# The ridge of a roof seen from its gable: how far short of the back of the roof it ends, and
# every how many rows it is bound, in px.
RIDGE_SHORT = 12
RIDGE_BINDING = 9


def gable_roof(picture, snowy, rng, left, right, eaves_y, foot_y, hip_half, depth, moss=7):
    """A half-hipped thatch roof seen from its gable end, over the columns left..right: the
    gable's rakes rise from the eaves at `eaves_y` on both sides to the foot of the little hip at
    `foot_y`, `hip_half` px either side of the middle, and the roof runs back `depth` px from
    them, up the picture. Its two long planes show from above, the left one lit and the right
    one in shade, with a reed ridge between them. As the eaves run back along the sides, the
    courses of reed run up the picture: 7 px wide, lit along their edge towards the ridge in
    broken runs, the reed ends hanging out towards the eaves over a shadow line, and the eaves
    are a thick rolled edge along both sides. At the front the reed is cut along the rakes; the
    hip faces the front in level courses over a rolled foot. White bargeboards lie along the
    rakes and cross over the hip, their ends carved into horse heads looking out. Moss grows in
    a few patches low on the shaded plane. Returns the top row of the gable wall in each column,
    below the boards and the hip."""
    centre = (left + right) / 2
    slope = (eaves_y - foot_y) / ((right - left) / 2 - hip_half)

    def rake(x):
        return round(eaves_y - min(x - left, right - x) * slope)

    # The courses, counted in from the eaves, each varying along the rows.
    courses = [thatch_course(rng, 0, len(picture) - 1) for _ in range(round((right - left) / 2) // COURSE + 2)]
    patches = moss_patches(rng, moss, (right - 48, right - 16), (eaves_y - depth, eaves_y - 20))
    face_top = {}
    for x in range(left, right + 1):
        from_eaves = min(x - left, right - x)
        plane = 1 if x < centre else 3
        bottom = rake(x)
        for y in range(bottom - depth, bottom + 1):
            if from_eaves < EAVES_ROWS:
                # The rolled eaves, one shade per column in from the side, darker on the
                # shaded plane.
                shade = EAVES_ROLL[from_eaves]
                if plane == 3 and from_eaves > 3:
                    shade += 1
                colour = THATCH[min(4, shade)]
            elif y > bottom - 4:
                # The cut ends of the reed along the rake.
                colour = THATCH[3] if plane == 1 and (x + y) % 3 else THATCH[4]
            else:
                along = from_eaves - EAVES_ROWS
                along += courses[along // COURSE][0][y]
                course, row = divmod(max(0, along), COURSE)
                _, lit, reed = courses[course]
                is_lit = row == COURSE - 1 and lit[y]
                hangs = COURSE - 2 - row < reed.get(y, 0)
                tone = plane - 1 if is_lit else plane
                if row == 0 and reed.get(y, 0) < 4:
                    tone = plane + 1
                elif not is_lit and hangs:
                    tone = plane + 1
                colour = THATCH[min(4, tone)]
                if mossy(rng, patches, x, y, (1.6, 1)):
                    colour = MOSS[min(3, tone)]
            picture[y][x] = colour
            snowy.add((x, y))
        face_top[x] = bottom + 1
    # The hip at the front, under the boards: level courses over a rolled foot, lit on the left.
    for x in range(left, right + 1):
        if abs(x - centre) >= hip_half:
            continue
        for y in range(rake(x) + 1, foot_y + 1):
            from_foot = foot_y - y
            if from_foot < 7:
                shade = (4, 4, 3, 3, 1, 0, 1)[from_foot]
            else:
                row = (from_foot - 7) % COURSE
                shade = 1 if row == COURSE - 1 and x % 9 else 3 if row == 0 or (row < 3 and x % 3 == 0) else 2
            picture[y][x] = THATCH[min(4, shade + (x > centre and shade < 4))]
            snowy.add((x, y))
        face_top[x] = foot_y + 1
    # The ridge: a roll of reed lying along the top of the roof, lit on its left, bound every few
    # rows. It narrows as it runs back into the picture and ends short of the back of the roof,
    # so it lies on the roof rather than standing up out of it.
    ridge_front, ridge_back = rake(centre), rake(centre) - depth + RIDGE_SHORT
    for y in range(ridge_back, ridge_front + 1):
        half_width = 2 + 4 * (y - ridge_back) / (ridge_front - ridge_back)
        is_binding = (ridge_front - y) % RIDGE_BINDING >= RIDGE_BINDING - 2
        for x in range(left, right + 1):
            offset = x - centre
            if abs(offset) > half_width:
                continue
            shade = 0 if offset < -half_width / 3 else 1 if offset < half_width / 3 else 3
            picture[y][x] = THATCH[min(4, shade + is_binding)]
            snowy.add((x, y))
    # The bargeboards: each runs from its eaves along the rake and on past the middle, so they
    # cross over the hip and end in horse heads.
    for side in (-1, 1):
        start = left if side < 0 else right
        reach = round((right - left) / 2) + 12
        for step in range(1, reach + 1):
            x = start - side * step
            line = round(eaves_y - step * slope)
            for row, colour in enumerate(BOARD):
                picture[line + 1 + row][x] = colour
                snowy.discard((x, line + 1 + row))
            below = line + 1 + len(BOARD)
            for shadow in (below, below + 1):
                if picture[shadow][x] not in BOARD:
                    picture[shadow][x] = "soil_dark"
                    snowy.discard((x, shadow))
            if abs(x - centre) >= hip_half:
                face_top[x] = max(face_top[x], below + 1)
        horse_head(picture, snowy, start - side * reach, round(eaves_y - reach * slope), -side)
    return face_top


# The white-painted bargeboards and their horse heads: lit, body, shade, from the top down.
BOARD = ("snow_light", "snow_light", "lime", "lime", "lime", "sand_light", "sand")
# A horse head carved on a board's end, looking right, from its top row down; the board comes in
# at the bottom left. "#" is the board's body, "o" its lit edge, "x" its shade, "e" the eye,
# "n" the nostril.
HORSE_HEAD = (
    "....oo...........",
    "....o#o..........",
    "....o##o.........",
    "...o####oo.......",
    "...o#ee####o.....",
    "..o#########o....",
    "..o##########oo..",
    ".o####xx#######o.",
    ".o###x..xx#####x.",
    "o###x.....xx#n#x.",
    "o###x.......xxxx.",
    "####x............",
    "###x.............",
    "##x..............",
    "#x...............",
)


def horse_head(picture, snowy, x, y, facing):
    """A horse head carved on the end of a bargeboard whose top edge ends at (x, y), looking
    right with `facing` 1 and left with -1, outlined in dark oak so it shows against the thatch
    and kept clear of snow."""
    colours = {"o": BOARD[0], "#": BOARD[2], "x": BOARD[6], "e": "soil_dark", "n": "sand"}
    head = {}
    for row, line in enumerate(HORSE_HEAD):
        for column, mark in enumerate(line):
            if mark in colours:
                head[x + facing * column, y - len(HORSE_HEAD) + 4 + row] = colours[mark]
    for hx, hy in head:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (hx + dx, hy + dy) not in head and picture[hy + dy][hx + dx] not in BOARD:
                picture[hy + dy][hx + dx] = "soil_dark"
                snowy.discard((hx + dx, hy + dy))
    for (hx, hy), colour in head.items():
        picture[hy][hx] = colour
        snowy.discard((hx, hy))


def herringbone(picture, rng, pixels, bricks, mortar):
    """Bricks laid slanting in columns 8 px wide, leaning one way in one column and the other way
    in the next, so their joints zigzag: the herringbone of a decorated gable."""
    colours = {}
    for x, y in pixels:
        band, offset = divmod(x, 8)
        if offset == 7:
            picture[y][x] = mortar
            continue
        diagonal = y + offset if band % 2 else y - offset
        if diagonal % 4 == 0:
            picture[y][x] = mortar
        else:
            picture[y][x] = colours.setdefault((band, diagonal // 4), rng.choice(bricks))


def diagonal_bricks(picture, rng, pixels, bricks, mortar, rising):
    """Bricks laid slanting all one way, parallel to a rake: rising to the right, or to the left
    with `rising` -1; a joint every 9 px along each course."""
    colours = {}
    for x, y in pixels:
        course = y + rising * x
        along = x + course // 3 * 4
        if course % 3 == 0 or along % 9 == 0:
            picture[y][x] = mortar
        else:
            picture[y][x] = colours.setdefault((course // 3, along // 9), rng.choice(bricks))


def grote_door(picture, left, right, top, spring, bottom):
    """The Grote Door of a hall house: two tall leaves of upright planks painted green, under a
    flat arch rising from `spring` at the sides to `top` in the middle, in a white frame, each
    leaf held by ledges with iron hinges; a stone threshold below."""
    centre = (left + right) / 2
    half = (right - left + 1) / 2
    right_leaf = (left + right + 1) // 2
    for x in range(left, right + 1):
        arch = spring - round((spring - top) * math.sqrt(max(0.0, 1 - ((x - centre) / half) ** 2)))
        rect(picture, x, arch - 2, x, arch - 1, "snow_light")
        leaf_left = left if x < right_leaf else right_leaf
        if x in (left, left + 1, right - 1, right):
            colour = "green_dark"
        elif x in (right_leaf - 1, right_leaf) or (x - leaf_left) % 7 == 6:
            colour = "green_deep"
        else:
            colour = "green_light" if (x - leaf_left) % 7 == 0 else "green"
        rect(picture, x, arch, x, bottom, colour)
    for y in (spring + 8, (spring + bottom) // 2 + 6, bottom - 10):
        rect(picture, left + 2, y, right - 2, y + 2, "green")
        rect(picture, left + 2, y, right - 2, y, "green_light")
        rect(picture, left + 2, y + 3, right - 2, y + 3, "green_deep")
        rect(picture, left + 2, y + 1, left + 9, y + 1, "stone_dark")
        rect(picture, right - 9, y + 1, right - 2, y + 1, "stone_dark")
    rect(picture, left - 3, top - 2, left - 1, bottom, "snow_light")
    rect(picture, right + 1, top - 2, right + 3, bottom, "lime")
    rect(picture, right_leaf - 6, (spring + bottom) // 2, right_leaf - 4, (spring + bottom) // 2 + 1, "gold")
    rect(picture, left - 4, bottom + 1, right + 4, bottom + 2, "stone_light")
    rect(picture, left - 4, bottom + 3, right + 4, bottom + 4, "stone")


def hall_house(is_lit):
    """The Low German hall house (Niedersachsenhaus) on 7x5 tiles, its gable end to the front:
    the big arched barn door (Grote Door) in the middle under a carved oak beam, oak framing
    with red brick in it, laid in herringbone and slanting courses in the gable, and the top of
    the gable boarded, with the owl hole (Uhlenloch) under the little hip. A huge half-hipped
    thatch runs back from it, with a reed ridge, and white bargeboards cross over the hip in a
    pair of horse heads. Small stable windows to either side of the door."""
    rng = random.Random(385)
    width, height = 7 * GAME_TILE, 272
    picture = blank(width, height)
    snowy = set()
    # The rows of the gable, top down: the foot of the hip, where the gable starts; the beam
    # across the gable, with the boarded top above it; the beam over the door; the rail of the
    # side bays; the fieldstone base.
    gable_top = 108
    gable_beam = (128, 133)
    door_beam = (164, 171)
    rail = 208
    base_top = height - 14
    wall_left, wall_right = 6, width - 7
    # The posts of the oak frame, the stout posts either side of the door, and the door between.
    posts = (wall_left, 40, 110, 180, wall_right - 3)
    door_posts = (74, 144)
    door_left, door_right = 84, 139
    face_top = gable_roof(picture, snowy, rng, 0, width - 1, 212, gable_top, 26, 68)
    # The gable is drawn whole on a picture of its own, and shows below the roof and the boards.
    gable = blank(width, height)
    brick_wall(gable, rng, wall_left, wall_right, gable_top, base_top - 1, RED_BRICKS, "sand")
    # The upper gable, between its beams: brick in herringbone between the door posts, slanting
    # with the rakes in the bays beside them.
    panel_rows = range(gable_beam[1], door_beam[0])
    herringbone(gable, rng, [(x, y) for x in range(80, 144) for y in panel_rows], RED_BRICKS, "sand")
    for x0, x1, rising in ((44, 74, 1), (148, 178, -1)):
        diagonal_bricks(gable, rng, [(x, y) for x in range(x0, x1 + 1) for y in panel_rows], RED_BRICKS, "sand", rising)
    # The top of the gable boarded in oak, with the owl hole in it.
    for x in range(wall_left, wall_right + 1):
        board = (x - wall_left) % 8
        colour = "soil_light" if board == 0 else "soil" if board == 7 else "soil_mid"
        rect(gable, x, gable_top, x, gable_beam[0] - 1, colour)
    for row in range(10):
        rect(gable, 111 - row, gable_top + 5 + row, 112 + row, gable_top + 5 + row, "ink")
    rect(gable, 101, gable_top + 15, 122, gable_top + 15, "soil_light")
    # The oak frame: the sill, the posts, a rail in the side bays, short braces in the corner
    # bays, the beam over the door (carved) and the gable's beam.
    rect(gable, wall_left, base_top - 4, wall_right, base_top - 1, OAK[1])
    rect(gable, wall_left, base_top - 4, wall_right, base_top - 4, OAK[0])
    rect(gable, wall_left, base_top - 1, wall_right, base_top - 1, OAK[2])
    for x in posts:
        rect(gable, x, gable_beam[0], x + 3, base_top - 1, OAK[1])
        rect(gable, x, gable_beam[0], x, base_top - 1, OAK[0])
        rect(gable, x + 3, gable_beam[0], x + 3, base_top - 1, OAK[2])
    for x in door_posts:
        rect(gable, x, gable_beam[0], x + 5, base_top - 1, OAK[1])
        rect(gable, x, gable_beam[0], x + 1, base_top - 1, OAK[0])
        rect(gable, x + 5, gable_beam[0], x + 5, base_top - 1, OAK[2])
    for x0, x1 in ((wall_left, door_posts[0]), (door_posts[1], wall_right)):
        rect(gable, x0, rail, x1, rail + 3, OAK[1])
        rect(gable, x0, rail, x1, rail, OAK[0])
        rect(gable, x0, rail + 3, x1, rail + 3, OAK[2])
    for x0, direction in ((10, -1), (184, 1)):
        for step in range(28):
            bx = x0 + step if direction > 0 else x0 + 27 - step
            for dx, colour in enumerate((OAK[0], OAK[1], OAK[1], OAK[2])):
                gable[base_top - 6 - step][bx + dx] = colour
    for top, bottom in (gable_beam, door_beam):
        rect(gable, wall_left, top, wall_right, bottom, OAK[1])
        rect(gable, wall_left, top, wall_right, top, OAK[0])
        rect(gable, wall_left, bottom, wall_right, bottom, OAK[2])
    # A line cut into the door beam, as the farmer and his wife had their names and the year
    # carved there.
    x = door_left + 2
    while x < door_right - 2:
        letter = rng.randint(2, 4)
        rect(gable, x, door_beam[1] - 3, x + letter - 1, door_beam[1] - 3, "soil_light")
        if rng.random() < 0.6:
            rect(gable, x, door_beam[1] - 5, x, door_beam[1] - 4, "soil_light")
        if rng.random() < 0.3:
            gable[door_beam[1] - 5][x + letter - 1] = "soil_light"
        x += letter + rng.choice((1, 2, 2, 4))
    fieldstone_base(gable, rng, wall_left, wall_right, base_top, height - 3)
    for left in (48, 156):
        window(gable, left, 180, 3, 3, is_lit, frame="green_dark")
    grote_door(gable, door_left, door_right, door_beam[1] + 4, door_beam[1] + 18, height - 6)
    for x, top in face_top.items():
        for y in range(top, height):
            if gable[y][x] is not None:
                picture[y][x] = gable[y][x]
    eaves_shadow(picture, {x: y - 1 for x, y in face_top.items()}, wall_left, wall_right)
    outline_edge(picture, THATCH[4], keep_bottom=True)
    ground_shadow(picture)
    return picture, snowy


# How to draw the hall house (is_lit to the picture and the pixels snow covers), by its id in
# data/buildings.cfg.
PICTURES = {"hall_house": hall_house}
