"""Art for the stork's nest on a roof ridge, the 16 px art: two sheets at
assets/wildlife/<name>.png, as tools/art/stork_nest.py draws them at 32 px (see there for what is
in them). A frame is rows of characters; the bird has a one pixel outline, the bill and legs are
drawn over it.
"""

from birds import BARE, STORK_KEYS, STORK_OUTLINE, on_cell
from livestock import to_picture

NEST_SIZE = (24, 7)
CHICK_SIZE = (20, 17)

# Keys of the nest: sticks from dark to pale.
NEST_KEYS = {"d": "mud_dark", "m": "soil_dark", "b": "mud", "l": "bare", "s": "soil_dark"}
# The sticks as they cross: one row of the heap's pattern, which repeats.
STICKS = ("dbmldbmbd", "bldmbldmb", "mbdlmdbld")
HEAP_ROWS = ((3, 20), (2, 21), (1, 22), (1, 22), (0, 23), (0, 23))


def nest_rows():
    """A half ellipse of crossed sticks with a few poking out over the rim."""
    rows = ["." * NEST_SIZE[0]]
    for y, (first, last) in enumerate(HEAP_ROWS):
        pattern = STICKS[y % len(STICKS)]
        row = "".join(pattern[x % len(pattern)] if first <= x <= last else "." for x in range(NEST_SIZE[0]))
        rows.append(row)
    for x in (4, 9, 15, 20):
        rows[0] = rows[0][:x] + "s" + rows[0][x + 1 :]
    return rows


# The heads of the young, over the rim: grey down, then paler, then white with a red bill.
KEYS = STORK_KEYS | {"g": "stone_light", "G": "stone", "p": "bare_light", "n": "stone_dark"}
HEAD_SMALL = (
    ".............k..",
    "........ggg.k...",
    "........gge.k...",
    "........ggg.....",
    ".........gg.....",
    ".........gg.....",
    ".........gg.....",
)
HEAD_HALF_GROWN = (
    "..............n.",
    ".........ppp.n..",
    "........ppppR...",
    "........ppep....",
    ".........pp.....",
    ".........pp.....",
    ".........pp.....",
    ".........pp.....",
)
HEAD_GROWN = (
    "............rr..",
    "...........rr...",
    ".........wwrR...",
    "........wwwer...",
    "........wwww....",
    ".........ww.....",
    ".........ww.....",
    ".........ww.....",
    ".........ww.....",
)

# The grown young, standing on the rim, and flapping: the same body, the wings up and out.
STANDING = (
    "..........ww....",
    ".........wwerrr.",
    ".........ww..Rrr",
    "..........w.....",
    "..........ww....",
    "...wwwwwwwww....",
    ".wwwwwwwwwws....",
    "kkkkkwwwwss.....",
    ".kkkkkkssss.....",
    "....kkk.........",
    "....LM..........",
    "....LM..........",
    "....LM..........",
    "....LM..........",
    "...LLMM.........",
)
LOOKING_ROUND = (
    "..........ww....",
    ".........wwerr..",
    ".........ww..R..",
) + STANDING[3:]
FLAP_UP = (
    "..k..k..........",
    "..kk.kk...ww....",
    "...kkkwk.wwerrr.",
    "...wwwwwwwwwRrr.",
    "...wwwwwwwwwss..",
    "....wwwwwwss....",
    ".....kkkss......",
    "....LM..........",
    "....LM..........",
    "...LM...........",
    "...LM...........",
)
FLAP_LEVEL = (
    "........kkk.....",
    ".......kwwwww...",
    ".kkkkwwwwwwerrr.",
    "LL.wwwwwwwwwRrr.",
    "...wwwwwwwss....",
    "....kkkkkss.....",
    "....LM..........",
    "...LM...........",
)
FLAP_DOWN = (
    "..........ww....",
    "kk.wwwwwwwwerrr.",
    ".kkwwwwwwwwwRrr.",
    "..kkwwwwwwss....",
    "...kkkkkss......",
    "....kk..........",
    "....LM..........",
    "...LM...........",
)


def chick_sheet():
    width, height = CHICK_SIZE
    standing = [on_cell(shape, CHICK_SIZE, 2, height - len(shape)) for shape in (STANDING, LOOKING_ROUND)]
    flaps = [on_cell(shape, CHICK_SIZE, 2, 1) for shape in (FLAP_UP, FLAP_LEVEL, FLAP_DOWN)]
    heads = [[on_cell(shape, CHICK_SIZE, 0, height - len(shape))] for shape in (HEAD_SMALL, HEAD_HALF_GROWN, HEAD_GROWN)]
    rows = [*heads, standing, flaps]
    return [[to_picture(frame, KEYS, STORK_OUTLINE, BARE) for frame in frames] for frames in rows]


def sheets():
    """(name, cell size, rows of cells) of every sheet."""
    nest = to_picture(nest_rows(), NEST_KEYS, "ink", set())
    return [("stork_nest", NEST_SIZE, [[nest]]), ("stork_chick", CHICK_SIZE, chick_sheet())]
