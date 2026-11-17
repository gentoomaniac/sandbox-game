"""The windmill the player builds (issue #26): a wooden post mill, the region's mill until about
1800 (docs/art-style.md, Mills), on 3x3 tiles.

The whole body of a post mill turns on one oak post to face the wind, pushed round by the tail
pole; the miller climbs into it by the ladder at its back. The mill is drawn from behind, so
the ladder comes down to the player at the middle of the front row (the door tile) and the
sails turn behind the body:

- windmill.png: the body, drawn like the houses in buildings.py (as wide as the footprint, its
  bottom edge the footprint's): tarred weatherboards under a gabled roof of grey boards running
  back up the picture, a small window in the gable and a green door at the top of the ladder.
  It stands on the trestle: the post, two quarter bars from the crosstree up to it, the
  crosstree on two fieldstone piers. Down the middle come the ladder of grey weathered oak with
  its handrails and the tarred tail pole under it.
- windmill_sails.png and windmill_sails_still.png (`sails` and `still_sails`): the sails, which
  the game lays behind the body, their hub at SAILS_HUB of the body's picture. Turning, the cloth
  is spread (a strip of SAIL_FRAMES frames, a quarter turn); still, the cloth is furled along the
  stocks and the sails stand in a cross like X, as millers leave them at rest.
"""

import random

import sails as sail_drawing
from buildings import GREEN, SHADED, fieldstone_base, glass
from canvas import GAME_TILE, blank, outline_edge, rect

WIDTH, HEIGHT = 3 * GAME_TILE, 264
# The near apex of the gable, the eaves at the corners of the wall, how far up the picture the
# roof runs back, the wall's sides, the body's floor and the ground under the post.
APEX, EAVES, ROOF_DEPTH = 40, 68, 36
WALL_LEFT, WALL_RIGHT = 18, 77
OVERHANG = 3
FLOOR = 152
GROUND = HEIGHT - 48
# The tarred weatherboards, lit to dark, each board this many rows high.
TARRED = ("soil_mid", "soil", "soil_dark")
BOARD = 5
# The grey roof boards: the lit slope, the slope in shade, the joints of each.
ROOF_LIT = ("bare_light", "bare")
ROOF_SHADE = ("bare", "mud")
# The trestle's oak, lit to dark, and the ladder's weathered oak.
OAK = ("soil_light", "soil_mid", "soil", "soil_dark")
GREY_OAK = ("bare_light", "bare", "mud")
OUTLINE = "soil_dark"

# The sails at 32 px (see sails.py), and where their hub goes in the body's picture: the middle of
# each frame of the strip goes there.
SAILS = sail_drawing.Sails(radius=110, inner=28, width=24, lead=4, bar_step=8, uplongs=1, stock=3, roll=4, hub=7)
SAILS_HUB = (48, 10)
# The frames of the turning strip, a quarter turn; the still sails stand turned by this.
SAIL_FRAMES = 8
STILL_DEGREES = 45


def _near_rake(x):
    """The row of the near (back) gable's edge over column x."""
    return APEX + round(abs(x + 0.5 - WIDTH / 2) * (EAVES - APEX) / (WIDTH / 2 - WALL_LEFT + OVERHANG))


def _roof(picture, snowy):
    """The gabled roof seen from its back end: the gable's edge, and the two slopes running back up
    the picture ROOF_DEPTH rows, boarded along their length; the left slope lit, the right in
    shade, a ridge board between them and a barge board along the gable's edge."""
    for x in range(WALL_LEFT - OVERHANG, WALL_RIGHT + OVERHANG + 1):
        rake = _near_rake(x)
        lit = x < WIDTH // 2
        board, joint = ROOF_LIT if lit else ROOF_SHADE
        for y in range(rake - ROOF_DEPTH, rake + 1):
            colour = joint if (x - WALL_LEFT) % 4 == 3 else board
            # A few boards weathered darker along their length.
            if (x * 5 + y // 9) % 17 == 0:
                colour = joint
            picture[y][x] = colour
            snowy.add((x, y))
        # The barge board along the gable's edge, lit on top.
        picture[rake][x] = OAK[1]
        picture[rake + 1][x] = OAK[2]
        picture[rake - 1][x] = "sand_light" if lit else "bare_light"
    for y in range(APEX - ROOF_DEPTH - 1, APEX):
        picture[y][WIDTH // 2 - 1] = "sand_light"
        picture[y][WIDTH // 2] = "bare_light"
        snowy.update({(WIDTH // 2 - 1, y), (WIDTH // 2, y)})


def _walls(picture, rng):
    """The back wall and its gable of tarred weatherboards, each board lit along its top and dark
    at its lap; an oak corner board each side and the heavy sill beam under them."""
    for y in range(APEX + 1, FLOOR):
        for x in range(WALL_LEFT, WALL_RIGHT + 1):
            if y <= _near_rake(x) + 1:
                continue
            row = (y - FLOOR) % BOARD
            colour = TARRED[0] if row == 0 else TARRED[2] if row == BOARD - 1 else TARRED[1]
            picture[y][x] = colour
    # Knots and grain in the boards.
    for _ in range(70):
        x, y = rng.randrange(WALL_LEFT + 2, WALL_RIGHT - 1), rng.randrange(EAVES, FLOOR - 2)
        if picture[y][x] == TARRED[1]:
            rect(picture, x, y, min(WALL_RIGHT - 2, x + rng.randrange(1, 4)), y, TARRED[2])
    for x, colours in ((WALL_LEFT, (OAK[0], OAK[1])), (WALL_RIGHT - 1, (OAK[1], OAK[2]))):
        for y in range(_near_rake(x) + 2, FLOOR):
            picture[y][x] = colours[0]
            picture[y][x + 1] = colours[1]
    # The shadow under the barge board.
    for x in range(WALL_LEFT, WALL_RIGHT + 1):
        for below in (2, 3):
            y = _near_rake(x) + below
            if y < FLOOR and picture[y][x] in SHADED:
                picture[y][x] = SHADED[picture[y][x]]
    rect(picture, WALL_LEFT - 2, FLOOR, WALL_RIGHT + 2, FLOOR + 4, OAK[1])
    rect(picture, WALL_LEFT - 2, FLOOR, WALL_RIGHT + 2, FLOOR, OAK[0])
    rect(picture, WALL_LEFT - 2, FLOOR + 4, WALL_RIGHT + 2, FLOOR + 4, OAK[2])
    for x in range(WALL_LEFT + 4, WALL_RIGHT, 11):
        picture[FLOOR + 2][x] = OAK[3]


def _window(picture, is_lit):
    """The small window in the gable, four panes in a white frame."""
    left, top, size = 43, 50, 10
    rect(picture, left - 1, top - 1, left + size, top + size, "lime")
    rect(picture, left + size, top - 1, left + size, top + size, "sand_light")
    rect(picture, left - 1, top + size, left + size, top + size, "sand_light")
    for y in range(top, top + size):
        for x in range(left, left + size):
            picture[y][x] = glass((x - left) / size, (y - top) / size, is_lit)
    rect(picture, left + size // 2, top, left + size // 2, top + size - 1, "lime")
    rect(picture, left, top + size // 2, left + size - 1, top + size // 2, "lime")


def _door(picture):
    """The door at the top of the ladder: green planks lit on the left, a brace across, two iron
    strap hinges and a latch, in an oak frame."""
    left, top, right = 40, FLOOR - 42, 55
    rect(picture, left - 2, top - 2, right + 2, FLOOR - 1, OAK[0])
    rect(picture, right + 1, top - 2, right + 2, FLOOR - 1, OAK[2])
    rect(picture, left - 2, top - 2, right + 2, top - 2, OAK[1])
    light, middle, dark, deep = GREEN
    for x in range(left, right + 1):
        plank = (x - left) % 4
        colour = light if plank == 0 else dark if plank == 3 else middle
        rect(picture, x, top, x, FLOOR - 1, colour)
    rect(picture, left, top, right, top, deep)
    rect(picture, right, top, right, FLOOR - 1, dark)
    for step in range(right - left + 1):
        y = FLOOR - 9 - step * 22 // (right - left)
        picture[y][left + step] = deep
    for y in (top + 5, FLOOR - 8):
        rect(picture, left, y, left + 9, y + 1, "stone_dark")
        rect(picture, left, y, left + 9, y, "stone")
    rect(picture, right - 3, top + 19, right - 2, top + 21, "stone_light")
    picture[top + 21][right - 2] = "stone_dark"


def _pier(picture, rng, cx):
    """A fieldstone pier under an end of the crosstree, with its shadow on the ground."""
    fieldstone_base(picture, rng, cx - 6, cx + 6, GROUND - 9, GROUND)
    for x in range(cx - 6, cx + 9):
        for y in (GROUND + 1, GROUND + 2):
            picture[y][x] = "shadow"


def _beam(picture, start, end, thickness, colours):
    """An oak beam from `start` to `end` (x, y), `thickness` px across along the rows, its left
    column lit and its right column dark."""
    (x0, y0), (x1, y1) = start, end
    for y in range(min(y0, y1), max(y0, y1) + 1):
        x = round(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
        for i in range(thickness):
            colour = colours[0] if i == 0 else colours[2] if i == thickness - 1 else colours[1]
            picture[y][x + i] = colour


def _trestle(picture, rng):
    """The trestle: the post under the middle of the body, a quarter bar from each end of the
    crosstree up to it, the crosstree on its fieldstone piers."""
    for cx in (12, WIDTH - 13):
        _pier(picture, rng, cx)
    _beam(picture, (12, GROUND - 13), (39, FLOOR + 6), 6, OAK)
    _beam(picture, (WIDTH - 18, GROUND - 13), (WIDTH - 45, FLOOR + 6), 6, (OAK[1], OAK[2], OAK[3]))
    rect(picture, 41, FLOOR + 5, 54, GROUND - 12, OAK[1])
    rect(picture, 41, FLOOR + 5, 42, GROUND - 12, OAK[0])
    rect(picture, 52, FLOOR + 5, 54, GROUND - 12, OAK[2])
    # The shadow of the body on the top of the post.
    rect(picture, 41, FLOOR + 5, 54, FLOOR + 9, OAK[3])
    rect(picture, 5, GROUND - 15, WIDTH - 6, GROUND - 10, OAK[1])
    rect(picture, 5, GROUND - 15, WIDTH - 6, GROUND - 15, OAK[0])
    rect(picture, 5, GROUND - 10, WIDTH - 6, GROUND - 10, OAK[2])
    for x in (5, WIDTH - 6):
        rect(picture, x, GROUND - 15, x, GROUND - 10, OAK[0] if x == 5 else OAK[2])


def _ladder(picture):
    """The tail pole down to the ground at the front, tarred, and the ladder over it: two grey oak
    stringers, rungs lit along their top, and its handrails up beside the door."""
    rect(picture, 44, FLOOR + 5, 51, HEIGHT - 4, TARRED[1])
    rect(picture, 44, FLOOR + 5, 45, HEIGHT - 4, TARRED[0])
    rect(picture, 50, FLOOR + 5, 51, HEIGHT - 4, TARRED[2])
    rect(picture, 44, HEIGHT - 5, 51, HEIGHT - 4, "stone_dark")
    for y in range(FLOOR + 9, HEIGHT - 6, 7):
        rect(picture, 40, y, 55, y, GREY_OAK[0])
        rect(picture, 40, y + 1, 55, y + 1, GREY_OAK[2])
    for x in (37, 56):
        rect(picture, x, FLOOR - 22, x + 2, HEIGHT - 6, GREY_OAK[1])
        rect(picture, x, FLOOR - 22, x, HEIGHT - 6, GREY_OAK[0])
        rect(picture, x + 2, FLOOR - 22, x + 2, HEIGHT - 6, GREY_OAK[2])
        rect(picture, x, FLOOR - 23, x + 2, FLOOR - 23, GREY_OAK[0])
    for x in range(34, 62):
        for y in (HEIGHT - 3, HEIGHT - 2, HEIGHT - 1):
            if picture[y][x] is None:
                picture[y][x] = "shadow"


def windmill(is_lit):
    """The post mill's body on its trestle with the ladder and tail pole, without its sails (see
    the module's comment). `is_lit` lights the gable window."""
    rng = random.Random(2626)
    picture = blank(WIDTH, HEIGHT)
    snowy = set()
    _trestle(picture, rng)
    _walls(picture, rng)
    _roof(picture, snowy)
    _window(picture, is_lit)
    _door(picture)
    _ladder(picture)
    outline_edge(picture, OUTLINE, keep_bottom=True, ignoring=("shadow",))
    return picture, snowy


def sails():
    """The sails turning with their cloth spread: SAIL_FRAMES frames side by side, each SAILS.size
    square, a quarter turn clockwise, the first upright like +."""
    return sail_drawing.strip(SAILS, SAIL_FRAMES)


def still_sails():
    """The sails at rest, standing like X, the cloth furled and the lattice bare."""
    return sail_drawing.frame(SAILS, STILL_DEGREES, spread=False)


# How to draw the building, by its id in data/buildings.cfg.
PICTURES = {"windmill": windmill}
