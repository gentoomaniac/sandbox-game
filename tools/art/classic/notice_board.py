"""The notice board of the village square (issue #12) and the quest mark over it in the classic
16 px art, as tools/art/notice_board.py draws them at 32 px, at half the size: a plank board in an
oak frame on two posts, 1x1 tiles, under a little gable of weathered oak boards with a knob on its
peak, four notes pinned to it (one yellowed, one with a red seal); and a warm "!" of gold, rimmed
in ink, in a strip of BOB_FRAMES cells for a slow bob.
"""

from canvas import blank, rect

WIDTH, HEIGHT = 18, 28
KNOB_ROWS = 2
EAVE = 8
BARGE = 3
BOARD_LEFT, BOARD_RIGHT = 1, 16
BOARD_TOP, BOARD_BOTTOM = 8, 20
POSTS = (3, 13)
OAK = ("soil_light", "soil_mid", "soil", "soil_dark")
WEATHERED = ("bare_light", "bare", "mud_dark")

# The notes, each (left, top, rows), in the letters of NOTE_COLOURS (see the 32 px module).
NOTES = (
    (3, 9, ("PPnPp", "PhhPp", "PPPPp", "PwwPp", "PPPPp", "Pwwff", "pppf.")),
    (10, 9, ("YnYy", "YwwY", "yyyy")),
    (9, 14, ("PPnPPp", "PwwPPp", "PPPrrp", "PwPrRp", "pppppp")),
)
NOTE_COLOURS = {
    "P": "cream",
    "p": "sand_light",
    "Y": "sand_light",
    "y": "sand",
    "f": "sand_light",
    "w": "mud",
    "h": "stone_dark",
    "n": "stone_dark",
    "r": "ember",
    "R": "rust_dark",
}

QUEST_MARK = (
    ".kkkk.",
    "kccgok",
    "kcggok",
    ".kcgk.",
    ".kcgk.",
    ".kcgk.",
    ".kgok.",
    "..kk..",
    "......",
    ".kkkk.",
    ".kcok.",
    ".kkkk.",
)
QUEST_MARK_COLOURS = {"k": "ink", "c": "cream", "g": "gold", "o": "ochre"}
BOB_FRAMES = 2
BOB = 1


def _roof(picture):
    rect(picture, 8, 0, 9, KNOB_ROWS - 1, OAK[1])
    for y in range(EAVE - KNOB_ROWS + 1):
        left = max(0, 7 - y)
        top = KNOB_ROWS + y
        for x in range(left, WIDTH - left):
            column = min(x, WIDTH - 1 - x)
            depth = top - (KNOB_ROWS + max(0, 7 - column))
            if depth < BARGE:
                lit = WEATHERED[0] if x < WIDTH // 2 else WEATHERED[1]
                picture[top][x] = lit if depth <= 1 else WEATHERED[2]
            else:
                picture[top][x] = OAK[3] if x % 3 == 0 else OAK[2]


def _board(picture):
    for x in range(BOARD_LEFT + 1, BOARD_RIGHT):
        colour = OAK[2] if (x - BOARD_LEFT - 1) % 4 == 3 else OAK[1]
        rect(picture, x, BOARD_TOP + 1, x, BOARD_BOTTOM - 1, colour)
    rect(picture, BOARD_LEFT, BOARD_TOP, BOARD_RIGHT, BOARD_TOP, OAK[0])
    rect(picture, BOARD_LEFT, BOARD_TOP, BOARD_LEFT, BOARD_BOTTOM, OAK[0])
    rect(picture, BOARD_RIGHT, BOARD_TOP + 1, BOARD_RIGHT, BOARD_BOTTOM, OAK[2])
    rect(picture, BOARD_LEFT + 1, BOARD_BOTTOM, BOARD_RIGHT, BOARD_BOTTOM, OAK[2])
    for left in POSTS:
        rect(picture, left, BOARD_BOTTOM + 1, left, HEIGHT - 1, OAK[0])
        rect(picture, left + 1, BOARD_BOTTOM + 1, left + 1, HEIGHT - 1, OAK[2])


def _notes(picture):
    """The notes pinned to the board, each casting a shadow of a pixel to its right and below."""
    for left, top, rows in NOTES:
        for y, row in enumerate(rows):
            for x, key in enumerate(row):
                for dx, dy in ((1, 0), (0, 1)):
                    beside = rows[y + dy][x + dx] if y + dy < len(rows) and x + dx < len(row) else "."
                    if key != "." and beside == "." and picture[top + y + dy][left + x + dx] in OAK[1:3]:
                        picture[top + y + dy][left + x + dx] = OAK[3]
    for left, top, rows in NOTES:
        for y, row in enumerate(rows):
            for x, key in enumerate(row):
                if key != ".":
                    picture[top + y][left + x] = NOTE_COLOURS[key]


def _rim(picture):
    rims = []
    for y in range(HEIGHT - 1):
        for x in range(WIDTH):
            if picture[y][x] is None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < WIDTH and 0 <= ny < HEIGHT) or picture[ny][nx] is None:
                    rims.append((x, y, WEATHERED[2] if picture[y][x] in WEATHERED else OAK[3]))
                    break
    for x, y, colour in rims:
        picture[y][x] = colour


def notice_board():
    """The notice board, 18x28 px, standing (its bottom row on the ground)."""
    picture = blank(WIDTH, HEIGHT)
    _board(picture)
    _roof(picture)
    _notes(picture)
    _rim(picture)
    return picture


def quest_mark():
    """The quest mark's strip: BOB_FRAMES cells side by side, the mark BOB px lower in each."""
    width, height = len(QUEST_MARK[0]), len(QUEST_MARK) + BOB * (BOB_FRAMES - 1)
    picture = blank(width * BOB_FRAMES, height)
    for frame in range(BOB_FRAMES):
        for y, row in enumerate(QUEST_MARK):
            for x, key in enumerate(row):
                if key != ".":
                    picture[frame * BOB + y][frame * width + x] = QUEST_MARK_COLOURS[key]
    return picture
