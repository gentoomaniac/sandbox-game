"""The notice board of the village square (issue #12) and the quest mark over it, drawn at 32 px
per tile.

The board is a plank board in an oak frame on two posts, 1x1 tiles, under a little gable of
weathered oak boards with a knob on its peak, as such boards stood by a church door or a Krug.
Four notes are pinned to it, each with its nail: a big one with a heading, an older yellowed one,
one sealed in red wax and a small one. Light from the top left: the barge boards are lit on the
left slope, the frame on its top and left, each note shaded on its right and bottom edge and
casting a shadow of a pixel on the planks; the eave shades the top of the board. It is rimmed
in the darkest shade of each part (`soil_dark` for the oak, `mud_dark` for the weathered boards).
`notice_board()` is the picture (and the body of its item's icon), set into its atlas cell by
`generate.standing_outdoors`.

The quest mark is a warm "!" of gold, lit cream on its upper left, shaded ochre on its right and
rimmed in ink like the other marks over figures (character.sleep_z, pet_heart), bold enough to
read at the widest zoom. `quest_mark()` is its strip of BOB_FRAMES cells, the mark at the top of
the first and BOB px lower in the second, for a slow bob.
"""

from canvas import blank, rect

WIDTH, HEIGHT = 36, 56
# The roof: the knob on its peak, then the barge boards from the peak to the eaves.
KNOB_ROWS = 3
EAVE = 14
BARGE = 3
# The board in its frame, and the posts under it.
BOARD_LEFT, BOARD_RIGHT = 2, 33
BOARD_TOP, BOARD_BOTTOM = 13, 39
FRAME = 2
POSTS = (5, 27)
POST_WIDTH = 4
PLANK = 6
# The oak of the frame and the posts, lit to dark, and the weathered boards of the roof.
OAK = ("soil_light", "soil_mid", "soil", "soil_dark")
WEATHERED = ("bare_light", "bare", "mud_dark")

# The notes, each (left, top, rows) in the letters of NOTE_COLOURS: P paper, p its shade (the
# right and bottom edge), n the nail and its head N, w writing, h a heading, r the red seal, R its
# shade, f a folded corner. Old notes are yellowed (Y, y).
NOTES = (
    (
        6,
        16,
        (
            "PPPPNPPPPp",
            "PPPPnPPPPp",
            "PhhhPhhPPp",
            "PPPPPPPPPp",
            "PwwPwwwPwp",
            "PPPPPPPPPp",
            "PwwwPwwPPp",
            "PPPPPPPPPp",
            "PwPwwwPwwp",
            "PPPPPPPPPp",
            "PwwwPwwPff",
            "PPPPPPPPf.",
            "ppppppppp.",
        ),
    ),
    (
        19,
        16,
        (
            "YYYYNYYYy",
            "YYYYnYYYy",
            "YwwYwwwYy",
            "YYYYYYYYy",
            "YwwwYwwYy",
            "YYYYYYYYy",
            "yyyyyyyyy",
        ),
    ),
    (
        18,
        26,
        (
            "PPPPPNPPPPp",
            "PPPPPnPPPPp",
            "PwwwPwwPwwp",
            "PPPPPPPPPPp",
            "PwwPwwwPPPp",
            "PwwwPPPrrPp",
            "PPPPPPrrrrp",
            "PPPPPPrrRRp",
            "PPPPPPPRRPp",
            "ppppppppppp",
        ),
    ),
    (
        6,
        31,
        (
            "PPPNPPPp",
            "PPPnPPPp",
            "PwwPwwPp",
            "PPPPPPPp",
            "PwwwPwPp",
            "pppppppp",
        ),
    ),
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
    "N": "stone_light",
    "r": "ember",
    "R": "rust_dark",
}

# The quest mark: k ink, c cream, g gold, o ochre, d ochre dark.
QUEST_MARK = (
    "..kkkkkk..",
    ".kccgggok.",
    ".kcggggok.",
    ".kcggggok.",
    ".kcggggok.",
    "..kcggok..",
    "..kcggok..",
    "..kcggok..",
    "..kcggok..",
    "..kgggok..",
    "...kgok...",
    "...kgok...",
    "...kkkk...",
    "..........",
    "...kkkk...",
    "..kccgok..",
    "..kcggok..",
    "..kggodk..",
    "...kkkk...",
)
QUEST_MARK_COLOURS = {"k": "ink", "c": "cream", "g": "gold", "o": "ochre", "d": "ochre_dark"}
BOB_FRAMES = 2
BOB = 2


def _roof_left(y):
    """The left end of the roof's upper edge on row `y` (counted from the top of the barge boards):
    from the peak down to the eaves at the picture's edge, stepping 1 and 2 px in turn."""
    return 15 - (3 * y) // 2


def _roof(picture):
    """The gable: barge boards of weathered oak along the two slopes (the left lit, the right in
    the shade, both dark on their underside), the gable's boards under them in the shade of the
    roof, and the knob on the peak."""
    rect(picture, 16, 0, 19, KNOB_ROWS - 1, OAK[1])
    rect(picture, 16, 0, 16, KNOB_ROWS - 1, OAK[0])
    rect(picture, 19, 0, 19, KNOB_ROWS - 1, OAK[2])
    rows = EAVE - KNOB_ROWS + 1
    for y in range(rows):
        left = max(0, _roof_left(y))
        right = WIDTH - 1 - left
        top = KNOB_ROWS + y
        # The gable boards, the shaded triangle under the barge boards.
        for x in range(left, right + 1):
            colour = OAK[3] if (x - 2) % 4 == 0 else OAK[2]
            picture[top][x] = colour
        # The barge boards: each column's three rows from its upper edge.
        for x in range(left, right + 1):
            first = _first_row_of(x)
            depth = top - first
            if depth < BARGE:
                is_left = x < WIDTH // 2
                lit, face, under = WEATHERED
                picture[top][x] = (lit if is_left else face) if depth == 0 else face if depth == 1 else under
    # The eave casts its shadow over the top of the board.


def _first_row_of(x):
    """The row of the roof's upper edge over column `x`."""
    column = x if x < WIDTH // 2 else WIDTH - 1 - x
    for y in range(EAVE - KNOB_ROWS + 1):
        if max(0, _roof_left(y)) <= column:
            return KNOB_ROWS + y
    return EAVE


def _posts(picture):
    for left in POSTS:
        for dx, colour in enumerate(OAK[: POST_WIDTH - 1] + (OAK[2],)):
            rect(picture, left + dx, BOARD_BOTTOM + 1, left + dx, HEIGHT - 1, colour)


def _board(picture):
    """Upright planks of oak in a frame lit on its top and left; the eave shades the top."""
    inside_left, inside_right = BOARD_LEFT + FRAME, BOARD_RIGHT - FRAME
    inside_top, inside_bottom = BOARD_TOP + FRAME, BOARD_BOTTOM - FRAME
    for x in range(inside_left, inside_right + 1):
        along = x - inside_left
        colour = OAK[2] if along % PLANK == PLANK - 1 else OAK[1]
        rect(picture, x, inside_top, x, inside_bottom, colour)
    # A few streaks of grain, 2-3 px long.
    for x, y, length in ((6, 34, 3), (13, 30, 2), (25, 22, 3), (30, 34, 2), (17, 19, 2)):
        rect(picture, x, y, x, y + length - 1, OAK[2])
    rect(picture, inside_left, inside_top, inside_right, inside_top, OAK[2])
    # The frame: top and left lit, bottom and right in the shade.
    rect(picture, BOARD_LEFT, BOARD_TOP, BOARD_RIGHT, BOARD_TOP + FRAME - 1, OAK[1])
    rect(picture, BOARD_LEFT, BOARD_TOP + 1, BOARD_RIGHT - 1, BOARD_TOP + 1, OAK[0])
    rect(picture, BOARD_LEFT, BOARD_TOP, BOARD_LEFT + FRAME - 1, BOARD_BOTTOM, OAK[1])
    rect(picture, BOARD_LEFT + 1, BOARD_TOP + 1, BOARD_LEFT + 1, BOARD_BOTTOM - 1, OAK[0])
    rect(picture, BOARD_RIGHT - FRAME + 1, BOARD_TOP + FRAME, BOARD_RIGHT, BOARD_BOTTOM, OAK[2])
    rect(picture, BOARD_LEFT + FRAME, BOARD_BOTTOM - FRAME + 1, BOARD_RIGHT, BOARD_BOTTOM, OAK[2])
    rect(picture, BOARD_LEFT, BOARD_BOTTOM, BOARD_RIGHT, BOARD_BOTTOM, OAK[3])


def _notes(picture):
    """The notes pinned to the board, each casting a shadow of a pixel to its bottom right."""
    for left, top, rows in NOTES:
        for y, row in enumerate(rows):
            for x, key in enumerate(row):
                if key == ".":
                    continue
                for dx, dy in ((1, 0), (0, 1), (1, 1)):
                    beside = rows[y + dy][x + dx] if y + dy < len(rows) and x + dx < len(row) else "."
                    if beside == "." and picture[top + y + dy][left + x + dx] in OAK[1:3]:
                        picture[top + y + dy][left + x + dx] = OAK[3]
        for y, row in enumerate(rows):
            for x, key in enumerate(row):
                if key != ".":
                    picture[top + y][left + x] = NOTE_COLOURS[key]


def _rim(picture):
    """Rims the picture's edge in the darkest shade of each part, but the bottom row (it stands
    on the ground): the weathered boards in `mud_dark`, the rest in `soil_dark`."""
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
    """The notice board, 36x56 px, standing (its bottom row on the ground)."""
    picture = blank(WIDTH, HEIGHT)
    _posts(picture)
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
