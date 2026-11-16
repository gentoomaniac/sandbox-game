"""What shows a villager's friendship with the player (issue #48, step 14) in the classic 16 px art,
as tools/art/friendship.py draws it at 32 px, at about half the size: the heart that rises when a
villager's opinion of the player rises (two cells, a heartbeat), the grey cloud when it falls (two
cells, its drizzle falling on), both rimmed in ink; and the marks of the Neighbours tab, drawn for
the UI's own pixels as big as the new ones but flat, without the gleam, in the order of
`FriendshipMarks.Look` (not reached, cold, warm, gilded).
"""

from canvas import blank

HEART_COLOURS = {"k": "ink", "L": "red_light", "r": "ember", "d": "rust_dark", "g": "petal"}
HEART_FULL = (
    ".kkk.kkk.",
    "kLgLkLrrk",
    "kLLLLrrdk",
    "kLLrrrrdk",
    ".kLrrrdk.",
    "..krrdk..",
    "...krk...",
    "....k....",
)
HEART_SMALL = (
    ".kk.kk.",
    "kLgLrrk",
    "kLLrrdk",
    ".kLrdk.",
    "..krk..",
    "...k...",
)

CLOUD_COLOURS = {"k": "ink", "H": "stone_light", "s": "stone", "D": "stone_dark", "w": "foam"}
CLOUD = (
    "....kkk....",
    "..kkHHHkk..",
    ".kHHHHHsHk.",
    "kHHHHsssssk",
    "kHsssssssDk",
    ".kkDDDDDkk.",
    "...kkkkk...",
)
# The drops under the cloud in each cell: (x, the row under the cloud it is on).
DRIZZLE = (((3, 0), (7, 1)), ((3, 1), (7, 2)))
DRIZZLE_ROWS = 3

MARK_SIZE = (9, 8)
MARK = (
    ".kkk.kkk.",
    "kLLLkLrrk",
    "kLLrrrrdk",
    "kLrrrrrdk",
    ".krrrrdk.",
    "..krrdk..",
    "...kdk...",
    "....k....",
)
MARK_LOOKS = (
    {"k": "stone", "L": "stone_dark", "r": "stone_dark", "d": "stone_dark"},
    {"k": "ink", "L": "water_light", "r": "water_light", "d": "water"},
    {"k": "ink", "L": "red_light", "r": "red_light", "d": "ember"},
    {"k": "ink", "L": "gold", "r": "gold", "d": "ochre"},
)


def draw_map(picture, rows, colours, left, top):
    """Draws the letters of `rows` into the picture, its top left corner at left, top."""
    for y, row in enumerate(rows):
        for x, key in enumerate(row):
            if key != ".":
                picture[top + y][left + x] = colours[key]


def heart():
    """The heart's strip of two cells: the full heart, then the smaller one in the middle."""
    width, height = len(HEART_FULL[0]), len(HEART_FULL)
    picture = blank(2 * width, height)
    draw_map(picture, HEART_FULL, HEART_COLOURS, 0, 0)
    small_width, small_height = len(HEART_SMALL[0]), len(HEART_SMALL)
    draw_map(picture, HEART_SMALL, HEART_COLOURS, width + (width - small_width) // 2, (height - small_height) // 2)
    return picture


def cloud():
    """The cloud's strip of two cells, the drizzle under it falling on from the first to the second."""
    width, height = len(CLOUD[0]), len(CLOUD)
    picture = blank(2 * width, height + DRIZZLE_ROWS)
    for cell, drops in enumerate(DRIZZLE):
        draw_map(picture, CLOUD, CLOUD_COLOURS, cell * width, 0)
        for x, row in drops:
            picture[height + row][cell * width + x] = CLOUD_COLOURS["w"]
    return picture


def marks():
    """The strip of the marks of the tab, one cell of MARK_SIZE per look."""
    width, height = MARK_SIZE
    picture = blank(width * len(MARK_LOOKS), height)
    for index, colours in enumerate(MARK_LOOKS):
        draw_map(picture, MARK, colours, index * width, 0)
    return picture
