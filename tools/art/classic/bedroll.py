"""The bedroll of the camp and its cover, as camp.py drew them before task 112 made the bedroll
as long as a person lying on it: the classic object atlas has this bedroll, so its cover must
match it. Copied from camp.py of commit 6dbc5f5 unchanged."""

from canvas import OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, blank, rect


def bedroll():
    """14x26 px, lying vertically on 1x2 tiles (the cell's bottom edge is the footprint's): a
    sack of linen ticking stuffed with straw, quilted across, straw poking out at its seams, and
    a grey wool blanket rolled up and tied at its head end. The object's id stays sleeping_bag."""
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    left, top, bottom = OBJECT_CENTRE - 7, 51, 76
    right = left + 13
    # The straw sack: lit linen, shaded down its right side, quilted in rows.
    rect(canvas, left, top + 3, right, bottom, "mud_dark")
    rect(canvas, left + 1, top + 4, right - 1, bottom - 1, "sand_light")
    rect(canvas, right - 3, top + 4, right - 1, bottom - 1, "sand")
    rect(canvas, left + 1, bottom - 1, right - 1, bottom - 1, "sand")
    for y in range(top + 12, bottom - 2, 5):
        rect(canvas, left + 1, y, right - 1, y, "sand")
        rect(canvas, right - 3, y, right - 1, y, "mud")
    for x, y in ((left, bottom), (right, bottom), (left, top + 3), (right, top + 3)):
        canvas[y][x] = None
    rect(canvas, left + 2, bottom + 1, right, bottom + 2, "shadow")
    # Straw sticking out of the seams.
    for x, y, colour in ((left - 1, top + 13, "straw"), (left - 1, top + 14, "gold"), (left - 2, top + 14, "straw"),
                         (right + 1, top + 20, "straw"), (right + 1, top + 21, "straw"), (right + 2, top + 20, "gold"),
                         (left + 3, bottom + 1, "straw"), (left + 4, bottom + 1, "gold"), (left + 4, bottom + 2, "straw")):
        canvas[y][x] = colour
    # The rolled blanket across the head end: lit on top, its rolled-up ends showing a spiral.
    rect(canvas, left - 1, top, right + 1, top + 8, "stone_dark")
    rect(canvas, left, top + 1, right, top + 7, "stone")
    rect(canvas, left, top + 1, right, top + 3, "stone_light")
    rect(canvas, left, top + 7, right, top + 7, "stone_dark")
    for x in (left - 1, right + 1):
        canvas[top][x] = canvas[top + 8][x] = None
    for x in (left, right):
        rect(canvas, x, top + 3, x, top + 5, "stone_dark")
    canvas[top + 4][left + 1] = "stone_dark"
    canvas[top + 4][right - 1] = "stone_dark"
    # Two cords round the roll.
    for x in (left + 3, right - 3):
        rect(canvas, x, top + 1, x, top + 7, "soil")
        canvas[top + 1][x] = "soil_light"
    return canvas


# The rows of the bedroll cell from which the bedroll covers a player lying in it: below the
# rolled blanket at the head end, so only the head shows.
BEDROLL_COVER_FROM_ROW = 62


def bedroll_cover():
    """The part of the bedroll drawn over the player lying on it (assets/bedroll_cover.png): the
    cell of `bedroll` with everything above BEDROLL_COVER_FROM_ROW cleared, and its ground
    shadow, which the atlas draws on its own."""
    canvas = bedroll()
    for y in range(BEDROLL_COVER_FROM_ROW):
        canvas[y] = [None] * OBJECT_CELL_WIDTH
    return [[None if colour == "shadow" else colour for colour in row] for row in canvas]
