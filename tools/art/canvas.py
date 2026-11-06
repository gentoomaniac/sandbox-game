"""The blank pictures and the one clipped rectangle that all the art code draws with.

A picture is a list of rows of palette colour names (None = clear), `picture[y][x]`.
"""

TILE = 16
# Every cell of the object atlas is this big: a tree fits, and smaller things are drawn at
# the cell's bottom centre. A multi-tile object is centred on its footprint instead.
OBJECT_CELL_WIDTH = 48
OBJECT_CELL_HEIGHT = 80
OBJECT_CENTRE = OBJECT_CELL_WIDTH // 2
OBJECT_BOTTOM = OBJECT_CELL_HEIGHT - 1


def blank(width=TILE, height=None):
    """A clear picture, square unless a height is given."""
    height = width if height is None else height
    return [[None] * width for _ in range(height)]


def copy(picture):
    return [row[:] for row in picture]


def rect(picture, x0, y0, x1, y1, colour):
    """Fills x0..x1 and y0..y1, both ends included, clipped to the picture."""
    for y in range(max(0, y0), min(len(picture) - 1, y1) + 1):
        for x in range(max(0, x0), min(len(picture[0]) - 1, x1) + 1):
            picture[y][x] = colour
