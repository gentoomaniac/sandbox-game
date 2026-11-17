"""The windmill of issue #26 in the classic art, drawn at 16 px per tile (see tools/art/windmill.py
for the same mill at 32 px): the post mill seen from behind, its body of tarred weatherboards on
the trestle with the ladder and tail pole down to the door tile, the tail wheel and the hood of
the sack hoist, and its sails (sails.py, shared
with the new art at half the size), which the game lays behind the body.
"""

import random

import sails as sail_drawing
from canvas import TILE, blank, outline_edge, rect

WIDTH, HEIGHT = 3 * TILE, 132
APEX, EAVES, ROOF_DEPTH = 20, 34, 18
WALL_LEFT, WALL_RIGHT = 9, 38
OVERHANG = 2
FLOOR = 76
GROUND = HEIGHT - 24
TARRED = ("soil_mid", "soil", "soil_dark")
BOARD = 3
OAK = ("soil_light", "soil_mid", "soil", "soil_dark")
GREY_OAK = ("bare_light", "bare", "mud")
GREEN = ("green_light", "green", "green_dark", "green_deep")
OUTLINE = "soil_dark"

# The sails at 16 px; the hub goes at SAILS_HUB of the body's picture (x 48, y 10 once the
# classic art is scaled up to the game's tile, as in the new art).
SAILS = sail_drawing.Sails(radius=55, inner=14, width=12, lead=2, bar_step=5, uplongs=0, stock=2, roll=2, hub=3)
SAILS_HUB = (24, 5)
# As many as the new art's (windmill.py), which the game steps through; see test_sails.py.
SAIL_FRAMES = 8
STILL_DEGREES = 45


def _near_rake(x):
    """The row of the near (back) gable's edge over column x."""
    return APEX + round(abs(x + 0.5 - WIDTH / 2) * (EAVES - APEX) / (WIDTH / 2 - WALL_LEFT + OVERHANG))


def _roof(picture, snowy):
    """The gabled roof of grey boards running back up the picture, the left slope lit."""
    for x in range(WALL_LEFT - OVERHANG, WALL_RIGHT + OVERHANG + 1):
        rake = _near_rake(x)
        lit = x < WIDTH // 2
        board, joint = ("bare_light", "bare") if lit else ("bare", "mud")
        for y in range(rake - ROOF_DEPTH, rake + 1):
            picture[y][x] = joint if (x - WALL_LEFT) % 3 == 2 else board
            snowy.add((x, y))
        picture[rake][x] = OAK[1]
        picture[rake + 1][x] = OAK[2]
    for y in range(APEX - ROOF_DEPTH, APEX):
        picture[y][WIDTH // 2 - 1] = "sand_light"


def _walls(picture):
    """The back wall and gable of tarred weatherboards, oak corner boards and the sill beam."""
    for y in range(APEX + 1, FLOOR):
        for x in range(WALL_LEFT, WALL_RIGHT + 1):
            if y > _near_rake(x) + 1:
                row = (y - FLOOR) % BOARD
                picture[y][x] = TARRED[0] if row == 0 else TARRED[2] if row == BOARD - 1 else TARRED[1]
    for y in range(EAVES, FLOOR):
        picture[y][WALL_LEFT] = OAK[0]
        picture[y][WALL_RIGHT] = OAK[2]
    rect(picture, WALL_LEFT - 1, FLOOR, WALL_RIGHT + 1, FLOOR + 2, OAK[1])
    rect(picture, WALL_LEFT - 1, FLOOR, WALL_RIGHT + 1, FLOOR, OAK[0])


def _window(picture, is_lit):
    """The small window high in the back wall: four panes in a white frame."""
    rect(picture, 21, 37, 26, 42, "lime")
    for x, y in ((22, 38), (24, 38), (22, 40), (24, 40)):
        glint = (x, y) == (22, 38)
        lit_colour = "cream" if glint else "gold"
        rect(picture, x, y, x + 1, y + 1, lit_colour if is_lit else "foam" if glint else "water")


def _hood(picture, snowy):
    """The sack hoist under the peak of the gable: a little hood of grey boards over the hatch's
    shut door, the end of the hoist beam under it and the hook."""
    apex, eaves = 24, 28
    for y in range(apex, eaves + 1):
        half = (y - apex) * 5 // (eaves - apex)
        for x in range(23 - half, 25 + half):
            picture[y][x] = "bare_light" if x < 24 else "bare"
            snowy.add((x, y))
        picture[y][23 - half] = picture[y][24 + half] = OAK[3]
    rect(picture, 18, eaves + 1, 29, eaves + 1, OAK[3])
    rect(picture, 20, eaves + 2, 27, eaves + 6, GREY_OAK[1])
    for x in (20, 23, 26):
        rect(picture, x, eaves + 2, x, eaves + 6, GREY_OAK[0])
    rect(picture, 20, eaves + 2, 27, eaves + 2, GREY_OAK[2])
    rect(picture, 23, eaves + 2, 24, eaves + 3, OAK[1])
    picture[eaves + 4][24] = "stone_dark"
    picture[eaves + 5][24] = "stone_dark"


def _door(picture):
    """The green door at the top of the ladder, in an oak frame, with a hinge and a latch."""
    left, top, right = 20, FLOOR - 20, 27
    rect(picture, left - 1, top - 1, right + 1, FLOOR - 1, OAK[0])
    rect(picture, right + 1, top - 1, right + 1, FLOOR - 1, OAK[2])
    for x in range(left, right + 1):
        rect(picture, x, top, x, FLOOR - 1, GREEN[0] if x == left else GREEN[2] if (x - left) % 3 == 2 else GREEN[1])
    rect(picture, left, top + 3, left + 4, top + 3, "stone")
    rect(picture, left, FLOOR - 4, left + 4, FLOOR - 4, "stone")
    picture[top + 10][right - 1] = "stone_light"


def _trestle(picture, rng):
    """The post, the quarter bars, the crosstree and its fieldstone piers."""
    for cx in (6, WIDTH - 7):
        rect(picture, cx - 3, GROUND - 4, cx + 3, GROUND, "stone")
        rect(picture, cx - 3, GROUND - 4, cx + 3, GROUND - 4, "stone_light")
        picture[GROUND - 2][cx + rng.choice((-1, 1))] = "stone_dark"
        rect(picture, cx - 3, GROUND + 1, cx + 4, GROUND + 1, "shadow")
    for step, y in enumerate(range(FLOOR + 3, GROUND - 6)):
        span = GROUND - 6 - FLOOR - 3
        left = 20 - step * 14 // span
        right = WIDTH - 23 + step * 14 // span
        rect(picture, left, y, left + 2, y, OAK[1])
        picture[y][left] = OAK[0]
        rect(picture, right, y, right + 2, y, OAK[2])
    rect(picture, 20, FLOOR + 3, 27, GROUND - 6, OAK[1])
    rect(picture, 20, FLOOR + 3, 20, GROUND - 6, OAK[0])
    rect(picture, 26, FLOOR + 3, 27, GROUND - 6, OAK[2])
    rect(picture, 20, FLOOR + 3, 27, FLOOR + 4, OAK[3])
    rect(picture, 2, GROUND - 7, WIDTH - 3, GROUND - 5, OAK[1])
    rect(picture, 2, GROUND - 7, WIDTH - 3, GROUND - 7, OAK[0])


def _tail_wheel(picture):
    """The wheel on the end of the tail pole, face on: an iron tyre, an oak felloe, four spokes."""
    cx, cy, radius = WIDTH / 2, HEIGHT - 6.5, 5.8
    for y in range(HEIGHT - 13, HEIGHT):
        for x in range(16, 32):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            distance = (dx * dx + dy * dy) ** 0.5
            lit = dx + dy < 0
            if distance > radius:
                continue
            if distance > radius - 1:
                picture[y][x] = "stone" if lit else "stone_dark"
            elif distance > radius - 2:
                picture[y][x] = OAK[0] if lit else OAK[2]
            elif abs(dx) < 0.6 or abs(dy) < 0.6:
                picture[y][x] = OAK[1] if lit else OAK[2]
    rect(picture, 23, HEIGHT - 8, 24, HEIGHT - 7, OAK[3])


def _ladder(picture):
    """The tarred tail pole ending in its wheel, and the grey oak ladder over it, its foot just
    behind the wheel, its handrails beside the door."""
    foot = HEIGHT - 14
    rect(picture, 22, FLOOR + 3, 25, HEIGHT - 7, TARRED[1])
    rect(picture, 22, FLOOR + 3, 22, HEIGHT - 7, TARRED[0])
    rect(picture, 25, FLOOR + 3, 25, HEIGHT - 7, TARRED[2])
    for y in range(FLOOR + 5, foot - 1, 4):
        rect(picture, 20, y, 27, y, GREY_OAK[0])
    for x in (18, 28):
        rect(picture, x, FLOOR - 11, x + 1, foot, GREY_OAK[1])
        rect(picture, x, FLOOR - 11, x, foot, GREY_OAK[0])
    _tail_wheel(picture)
    for x in range(17, 32):
        if picture[HEIGHT - 1][x] is None:
            picture[HEIGHT - 1][x] = "shadow"


def windmill(is_lit):
    """The post mill's body on its trestle with the ladder and tail pole, without its sails.
    `is_lit` lights the gable window."""
    rng = random.Random(2626)
    picture = blank(WIDTH, HEIGHT)
    snowy = set()
    _trestle(picture, rng)
    _walls(picture)
    _roof(picture, snowy)
    _window(picture, is_lit)
    _hood(picture, snowy)
    _door(picture)
    _ladder(picture)
    outline_edge(picture, OUTLINE, keep_bottom=True, ignoring=("shadow",))
    return picture, snowy


def sails():
    """The sails turning, cloth spread: SAIL_FRAMES frames side by side, a quarter turn."""
    return sail_drawing.strip(SAILS, SAIL_FRAMES)


def still_sails():
    """The sails at rest like X, the cloth furled."""
    return sail_drawing.frame(SAILS, STILL_DEGREES, spread=False)


PICTURES = {"windmill": windmill}
