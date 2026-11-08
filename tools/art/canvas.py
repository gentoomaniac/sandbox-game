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

NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def blank(width=TILE, height=None):
    """A clear picture, square unless a height is given."""
    height = width if height is None else height
    return [[None] * width for _ in range(height)]


def filled(colour):
    return [[colour] * TILE for _ in range(TILE)]


def copy(picture):
    return [row[:] for row in picture]


def rect(picture, x0, y0, x1, y1, colour):
    """Fills x0..x1 and y0..y1, both ends included, clipped to the picture."""
    for y in range(max(0, y0), min(len(picture) - 1, y1) + 1):
        for x in range(max(0, x0), min(len(picture[0]) - 1, x1) + 1):
            picture[y][x] = colour


def outline(picture, colour, ignoring=()):
    """The picture with a one pixel outline on the clear pixels next to a drawn one, drawn
    pixels stay. `colour` is a name, or a function that gives it from the colour of the pixel
    the outline surrounds (`palette.darkest_of`). Colours in `ignoring` count as clear but are
    not drawn over: a ground shadow."""
    height, width = len(picture), len(picture[0])
    result = copy(picture)
    for y in range(height):
        for x in range(width):
            if picture[y][x] is not None:
                continue
            for dx, dy in NEIGHBOURS:
                nx, ny = x + dx, y + dy
                if 0 <= nx < width and 0 <= ny < height and picture[ny][nx] not in (None, *ignoring):
                    result[y][x] = colour(picture[ny][nx]) if callable(colour) else colour
                    break
    return result


def outline_edge(picture, colour, keep_bottom=False, ignoring=()):
    """Gives the drawn pixels on the picture's border (next to a clear one, a colour in
    `ignoring`, or the picture's edge) `colour`, in place. keep_bottom leaves the bottom row
    alone: the picture stands on the ground there."""
    height, width = len(picture), len(picture[0])
    clear = (None, *ignoring)
    border = []
    for y in range(height - 1 if keep_bottom else height):
        for x in range(width):
            if picture[y][x] in clear:
                continue
            for dx, dy in NEIGHBOURS:
                nx, ny = x + dx, y + dy
                if not (0 <= nx < width and 0 <= ny < height) or picture[ny][nx] in clear:
                    border.append((x, y))
                    break
    for x, y in border:
        picture[y][x] = colour
    return picture
