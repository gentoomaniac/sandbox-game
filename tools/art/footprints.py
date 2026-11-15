"""The footprints a walker leaves in snow and in mud (issue #64), for both art sets (the classic
generator imports this module too, with its 16 px tile).

assets/effects/footprints.png is a sheet of 4 cells, each a tile square, with one print in the
middle of its cell, the toes up (the game turns it to the way the walker goes, at any angle): a
left and a right foot in snow, a left and a right foot in mud. The foot is about a shoe long (14 px of the 32 px tile, 7 px of the 16 px one), narrow at the arch,
which lies on the inside, so the two feet are mirrors.

A print is a dent: its floor is a shade darker than what it is pressed into, the rim towards the
light (top left) falls into shadow, and the rim away from the light catches it. The picture is
opaque; the game fades it by its alpha.
"""

from canvas import blank

# What a print is made of: its floor, the shaded rim at the top left and the lit one at the
# lower right. A print in snow is a soft grey-blue dent; one in mud is dark with a pale rim.
SNOW = ("snow_shadow", "snow_deep", "snow_shadow")
MUD = ("soil_dark", "sand", "sand_light")
KINDS = {"snow": SNOW, "mud": MUD}

# The left foot, toes up, arch on its right: a broad ball, a narrow waist and a round heel, as
# the sole of a shoe. The right foot is its mirror.
LEFT_FOOT = {
    32: (
        ".XXXX.",
        "XXXXXX",
        "XXXXXX",
        "XXXXXX",
        "XXXXXX",
        ".XXXXX",
        ".XXXX.",
        ".XXX..",
        ".XXX..",
        ".XXXX.",
        ".XXXXX",
        ".XXXXX",
        ".XXXX.",
        "..XX..",
    ),
    16: (
        ".XXX",
        "XXXX",
        "XXXX",
        ".XX.",
        ".XX.",
        ".XXX",
        "..XX",
    ),
}


def _imprint(shape, colours):
    """A print of the rows `shape` (X where the foot pressed): the rim with no print above or
    to its left is the shaded one, the rim with none below or to its right the lit one."""
    floor, shade, lit = colours
    height, width = len(shape), len(shape[0])

    def pressed(x, y):
        return 0 <= x < width and 0 <= y < height and shape[y][x] == "X"

    picture = [[None] * width for _ in range(height)]
    for y in range(height):
        for x in range(width):
            if not pressed(x, y):
                continue
            if not pressed(x - 1, y) or not pressed(x, y - 1):
                picture[y][x] = shade
            elif not pressed(x + 1, y) or not pressed(x, y + 1):
                picture[y][x] = lit
            else:
                picture[y][x] = floor
    return picture


def _in_cell(print_rows, tile):
    """The print in the middle of a clear tile."""
    cell = blank(tile)
    top = (tile - len(print_rows)) // 2
    left = (tile - len(print_rows[0])) // 2
    for y, row in enumerate(print_rows):
        cell[top + y][left : left + len(row)] = row
    return cell


def sheet(tile):
    """The cells of the sheet, left to right: snow left, snow right, mud left, mud right."""
    left_foot = LEFT_FOOT[tile]
    right_foot = tuple(row[::-1] for row in left_foot)
    return [[_in_cell(_imprint(foot, colours), tile) for colours in KINDS.values() for foot in (left_foot, right_foot)]]
