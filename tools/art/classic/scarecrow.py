"""The scarecrow of tools/art/scarecrow.py in the classic art, drawn at 16 px per tile: a cross of
driftwood poles, an old patched coat with a rope round its middle, straw at the cuffs and under the
hem, a head of straw under an old felt hat; a little taller than the player.

A map of letters drawn by hand, a flat colour per letter, rimmed in the darkest shade of each
region. `frames` are the SWAY_FRAMES pictures: still, then the skirt and the straw blown a little
and a little more to the right, as in the new art.
"""

from canvas import blank

SWAY_FRAMES = 3
WIDTH, HEIGHT = 22, 33

POLE = ((10, 21), ["LD"] * 12)
# The straw out of the cuffs, by frame: the wind blows it back into the left sleeve and out of
# the right one.
CUFF_STRAW = (
    (((0, 10), ["..s", ".zS", "sS.", "S.z", ".s.", "z.."]), ((19, 10), ["s..", "Sz.", ".Ss", "z.S", ".s.", "..z"])),
    (((0, 10), ["...", "..S", ".sS", ".Sz", "..s", "..."]), ((19, 10), ["s..", "SzS", ".Ss", "z.S", "..s", "..."])),
    (((0, 10), ["...", "...", "..S", ".sz", "...", "..."]), ((19, 10), ["...", "SzS", "sSs", "zSz", "..s", "..."])),
)
HEM_STRAW = ((6, 22), [".S..z.S..s", ".s..z.s..z"])
COAT = (
    (0, 10),
    [
        "........cCCCCF",
        "...GcccccCCCCCCCCFG",
        "...GccXXcCoFCCCCCFG",
        "....FccccCCFCCCCFF",
        "......cccCoFCCCF",
        "......RRRRRRRRRr",
        "......cccCCFCrCF",
        "......ccFCCFCrCF",
        ".....cccFCCFMMCF",
        ".....ccFCCCFMmCCF",
        ".....ccFCCCFCCCCF",
        ".....c.CC.CFC.CC.",
    ],
)
HEAD = (
    (0, 5),
    [
        ".......kkkkkkkk",
        "......sKSKKzKKKz",
        "......zKSKKKzKKs",
        ".......KKSKzKKK",
        "........KKKzKK",
        ".........TTTT",
    ],
)
HAT = (
    (0, 0),
    [
        ".........HHHH",
        "........HHHdHH",
        "........HHHHHH",
        ".......hhhhhhhh",
        "...BBBBBBBBBBBBBBBB",
        "....bbb........bbbb",
        "..................bb",
    ],
)
COLOURS = {
    "L": "bare_light",
    "D": "bare",
    "H": "soil",
    "d": "soil_dark",
    "h": "soil_dark",
    "B": "soil_mid",
    "b": "soil",
    "K": "straw",
    "k": "ochre_dark",
    "T": "umber",
    "c": "water_light",
    "C": "water",
    "F": "water_deep",
    "G": "water_deep",
    "o": "ochre",
    "R": "ochre",
    "r": "ochre_dark",
    "X": "sand_light",
    "M": "rust_dark",
    "m": "russet_deep",
    "S": "straw",
    "s": "ochre",
    "z": "ochre_dark",
}
# The rim of each colour: the darkest of its region. Loose straw has none.
RIMS = {
    "bare_light": "mud_dark",
    "bare": "mud_dark",
    "soil": "soil_dark",
    "soil_mid": "soil_dark",
    "soil_dark": "soil_dark",
    "straw": "umber",
    "ochre": "umber",
    "ochre_dark": "umber",
    "umber": "soil_dark",
    "sand_light": "mud_dark",
    "rust_dark": "russet_deep",
}
LOOSE = "Ssz"
# How far the skirt leans in each frame, in pixels per SWAY_ROWS rows below SWAY_TOP.
SWAY_TOP = 15
SWAY_ROWS = 6
LEANS = (0, 1, 1.5)


def _place(letters, piece, lean=0.0):
    """Lays a piece ((left, top), rows) into `letters`, each row below SWAY_TOP moved right by
    `lean` pixels per SWAY_ROWS rows."""
    (left, top), rows = piece
    for index, row in enumerate(rows):
        y = top + index
        dx = round(max(0, y - SWAY_TOP) * lean / SWAY_ROWS)
        for column, key in enumerate(row):
            x = left + column + dx
            if key != "." and 0 <= x < WIDTH and 0 <= y < HEIGHT:
                letters[y][x] = key


def letters(frame=0):
    """The map of a frame (0 still, then blown a little more each)."""
    grid = [["."] * WIDTH for _ in range(HEIGHT)]
    _place(grid, POLE)
    for cuff in CUFF_STRAW[frame]:
        _place(grid, cuff)
    _place(grid, HEM_STRAW, LEANS[frame] * 1.3)
    _place(grid, COAT, LEANS[frame])
    _place(grid, HEAD)
    _place(grid, HAT)
    return grid


def scarecrow(frame=0):
    """A frame of the scarecrow, 22x33 px, standing (its bottom row on the ground)."""
    return _painted(letters(frame), keep_bottom=True)


def _painted(grid, keep_bottom=False):
    """The picture of a map: a colour per letter, rimmed in the darkest shade of each region
    but for the loose straw (and the bottom row, with `keep_bottom`)."""
    height, width = len(grid), len(grid[0])
    picture = blank(width, height)
    for y, row in enumerate(grid):
        for x, key in enumerate(row):
            if key != ".":
                picture[y][x] = COLOURS[key]
    rims = []
    for y in range(height - 1 if keep_bottom else height):
        for x in range(width):
            if picture[y][x] is None or grid[y][x] in LOOSE:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < width and 0 <= ny < height) or picture[ny][nx] is None:
                    rims.append((x, y, RIMS.get(picture[y][x], "ink")))
                    break
    for x, y, colour in rims:
        picture[y][x] = colour
    return picture


def frames():
    """The SWAY_FRAMES pictures of the scarecrow, still first."""
    return [scarecrow(frame) for frame in range(SWAY_FRAMES)]


# The icon of the scarecrow, the item that places one: the scarecrow drawn small, 14x16 px, in
# the letters of the map above.
ICON = [
    ".....HHHH.....",
    "....HHdHHH....",
    "....hhhhhh....",
    "..BBBBBBBBBB..",
    "...bkkkkkkbb..",
    "....KSKzKK....",
    "....KSKKzK....",
    "zS...TTTT...Sz",
    "SsGccccCCCCGsS",
    ".zGcXXCoFCCGz.",
    "...FccCoFCCF..",
    "....RRRRRr....",
    "....ccCFCC....",
    "....c.CF.C....",
    "......LD......",
    "......LD......",
]


def icon():
    """The icon of the scarecrow, 16x16 px."""
    picture = _painted([list(row) for row in ICON])
    return [[None] + row + [None] for row in picture]
