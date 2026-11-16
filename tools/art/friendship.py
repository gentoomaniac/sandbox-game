"""What shows a villager's friendship with the player (issue #48, step 14), drawn at 32 px per tile.

- `heart()`: the heart that rises over a villager's head when their opinion of the player rises
  (assets/effects/friendship_heart.png). Ember red, lit `red_light` on its upper left with a cream
  gleam, shaded `rust_dark` on its lower right, rimmed in ink like the other marks over figures
  (character.pet_heart, notice_board.quest_mark). Two cells side by side for a heartbeat: the
  heart full, then a size smaller.
- `cloud()`: the small grey cloud that rises when it falls (assets/effects/friendship_cloud.png):
  three puffs of `stone_light` lit on top, `stone` and a flat `stone_dark` underside, rimmed in
  ink, with a drizzle of two drops under it that falls on in the second cell.
- `marks()`: the marks of the Neighbours tab (assets/ui/friendship_marks.png), drawn for the UI's
  own pixels: a small heart per level in a strip of MARK_LOOKS cells, the order of
  `FriendshipMarks.Look`: a level not reached (grey and hollow), the two cold levels (water blue),
  the warm ones (ember red) and the tenth (gilded).

All are maps of letters drawn by hand, one letter per region; light from the top left.
"""

from canvas import blank

# The heart's letters: its rim, the lit side, the body, the shaded side and the gleam.
HEART_COLOURS = {"k": "ink", "L": "red_light", "r": "ember", "d": "rust_dark", "g": "cream"}
HEART_FULL = (
    "...kkk..kkk...",
    "..kLLLkkLrrk..",
    ".kLggLLLLrrrk.",
    "kLLgLLLLrrrrdk",
    "kLLLLLrrrrrrdk",
    "kLLLrrrrrrrddk",
    ".kLrrrrrrrrdk.",
    "..krrrrrrrdk..",
    "...krrrrrdk...",
    "....krrrdk....",
    ".....krdk.....",
    "......kk......",
)
# The heart between two beats: a size smaller, in the middle of the cell.
HEART_SMALL = (
    "..kkk..kkk..",
    ".kLLLkkLrrk.",
    "kLggLLLLrrdk",
    "kLgLLLrrrrdk",
    "kLLLrrrrrrdk",
    ".kLrrrrrrdk.",
    "..krrrrrdk..",
    "...krrrdk...",
    "....krdk....",
    ".....kk.....",
)

# The cloud's letters: its rim, the lit tops of the puffs, the body, the underside and the rain.
CLOUD_COLOURS = {"k": "ink", "H": "stone_light", "s": "stone", "D": "stone_dark", "w": "foam", "W": "water_light"}
CLOUD = (
    ".......kkkk.......",
    ".....kkHHHHkk.....",
    "..kkkHHHHHHHHkk...",
    ".kHHHkHHHHHHsHHk..",
    "kHHHHHsHHHHsssHsk.",
    "kHHHHsssssssssssk.",
    "kHsssssssssssssDk.",
    ".kDssssssssssDDk..",
    "..kkDDDDDDDDDkk...",
    "....kkkkkkkkk.....",
)
# The drops under the cloud in each cell: (x, the row under the cloud they start on).
DRIZZLE = (((5, 0), (9, 1), (12, 0)), ((5, 2), (9, 3), (12, 2)))
# A drop is two pixels, one under the other: foam over water_light.
DROP_ROWS = ("w", "W")
DRIZZLE_ROWS = 5

# The marks of the tab, each a heart of MARK_SIZE in the letters of the heart.
MARK_SIZE = (9, 8)
MARK = (
    ".kkk.kkk.",
    "kLgLkLrrk",
    "kLLLLrrdk",
    "kLLrrrrdk",
    ".kLrrrdk.",
    "..krrdk..",
    "...krk...",
    "....k....",
)
# The colours of each look of a mark, in the order of FriendshipMarks.Look: empty, cold, warm,
# gilded. A mark not reached is hollow: a grey rim round its dark inside.
MARK_LOOKS = (
    {"k": "stone", "L": "stone_dark", "r": "stone_dark", "d": "stone_dark", "g": "stone_dark"},
    {"k": "ink", "L": "water_light", "r": "water", "d": "water_deep", "g": "foam"},
    {"k": "ink", "L": "red_light", "r": "ember", "d": "rust_dark", "g": "blossom"},
    {"k": "ink", "L": "gold", "r": "ochre", "d": "ochre_dark", "g": "cream"},
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
            draw_map(picture, DROP_ROWS, CLOUD_COLOURS, cell * width + x, height + row)
    return picture


def marks():
    """The strip of the marks of the tab, one cell of MARK_SIZE per look."""
    width, height = MARK_SIZE
    picture = blank(width * len(MARK_LOOKS), height)
    for index, colours in enumerate(MARK_LOOKS):
        draw_map(picture, MARK, colours, index * width, 0)
    return picture
