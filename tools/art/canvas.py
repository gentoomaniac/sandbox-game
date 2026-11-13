"""The blank pictures and the one clipped rectangle that all the art code draws with.

A picture is a list of rows of palette colour names (None = clear), `picture[y][x]`.
"""

import math

# The tile of the 16 px art, in pixels: the classic art (tools/art/classic/) is drawn on it and
# scaled up to the game's tile pixel for pixel when it is written (DOUBLED there).
TILE = 16
# The game's tile in pixels (TerrainTileset.TILE_SIZE), which all the new art is drawn at.
GAME_TILE = 32
# Every cell of the object atlas is this big: a tree fits, and smaller things are drawn at
# the cell's bottom centre. A multi-tile object is centred on its footprint instead.
GAME_OBJECT_CELL_WIDTH = 3 * GAME_TILE
GAME_OBJECT_CELL_HEIGHT = 5 * GAME_TILE
GAME_OBJECT_CENTRE = GAME_OBJECT_CELL_WIDTH // 2
GAME_OBJECT_BOTTOM = GAME_OBJECT_CELL_HEIGHT - 1
# The same cell at the 16 px art's tile, which the classic object atlas is drawn in.
OBJECT_CELL_WIDTH = 3 * TILE
OBJECT_CELL_HEIGHT = 5 * TILE
OBJECT_CENTRE = OBJECT_CELL_WIDTH // 2
OBJECT_BOTTOM = OBJECT_CELL_HEIGHT - 1

NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def blank(width=TILE, height=None):
    """A clear picture, square unless a height is given."""
    height = width if height is None else height
    return [[None] * width for _ in range(height)]


def filled(colour, size=TILE):
    return [[colour] * size for _ in range(size)]


def copy(picture):
    return [row[:] for row in picture]


def centred_on_tile(picture, tile):
    """A picture of something on a tile, which is the picture's bottom `tile` rows, moved up or
    down so that what is drawn sits in the middle of the tile: as far below the tile's top as
    above its bottom. What reaches above the tile stays where it is, standing on the tile."""
    tile_top = len(picture) - tile
    drawn = [y for y, row in enumerate(picture) if any(colour is not None for colour in row)]
    if not drawn or drawn[0] < tile_top:
        return picture
    lift = (drawn[0] - tile_top - (len(picture) - 1 - drawn[-1])) // 2
    width = len(picture[0])
    if lift >= 0:
        return picture[lift:] + blank(width, lift)
    return blank(width, -lift) + picture[:lift]


def swinging(hanging, outline_colour, frames, max_degrees):
    """The frames of something that hangs from its top middle and swings, side by side in one
    picture: `hanging` outlined (but not along its top, where it hangs from something), then
    leaning from -max_degrees to +max_degrees in `frames` steps, the middle one upright. Each row
    slides sideways by its distance from the top times the lean, so the rows stay crisp, as
    pixel art wants, where turning the pixels would blur their edges."""
    width, height = len(hanging[0]), len(hanging)
    # A row above keeps the top edge from being outlined, and is cut off again.
    outlined = outline_edge([[outline_colour] * width] + copy(hanging), outline_colour)[1:]
    strip = blank(width * frames, height)
    for frame in range(frames):
        lean = math.tan(math.radians(max_degrees * (2 * frame / (frames - 1) - 1)))
        for y, row in enumerate(outlined):
            shift = round(y * lean)
            for x, colour in enumerate(row):
                if colour is not None and 0 <= x + shift < width:
                    strip[y][frame * width + x + shift] = colour
    return strip


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


def mirrored(half, darker):
    """Rows of characters for a shape that is the same on both sides, from its left half: the
    right half is the left one mirrored, each character swapped by `darker` (a dict; a missing
    one stays), as the right side is turned away from the light from the top left."""
    width = max(len(row) for row in half)
    rows = []
    for row in half:
        padded = row.ljust(width, ".")
        rows.append(padded + "".join(darker.get(char, char) for char in reversed(padded)))
    return rows
