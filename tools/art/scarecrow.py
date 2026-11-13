"""The scarecrow (task 226), drawn at 32 px per tile: a cross of two driftwood poles in the ground,
an old patched coat buttoned over it with a rope round its middle, straw sticking out at the cuffs,
the collar and under the hem, a head of straw bound under an old felt hat. It is a little taller
than the player.

It is drawn by hand as a map of letters, one per region, laid together from pieces like the cow of
livestock.py, and shaded by region, lit from the top left. The wind moves it: `frames` are the
SWAY_FRAMES pictures of it, still and then blown a little and a little more to the right (the
coat's skirt and the straw; the poles, the head and the hat stay), for the cells of its row of the
object atlas, the still one first. `scarecrow()` is the still one, the ghost while it is placed;
the body of its item's icon is that picture too.
"""

import forms
import items
import numpy as np
from canvas import blank

# The pictures of the scarecrow in the wind: still, blown, blown harder.
SWAY_FRAMES = 3
# The ground shadow: half its width (the coat does not reach the ground, so it is narrow).
SHADOW = 9

# The map of the scarecrow, 42x65 px, by region (see COLOURS and RAMPS):
#   P the upright pole (the crossbar is in the sleeves), L its lit edge, D its shaded edge; H the hat's crown, B its brim
#   (both shaded), d the dent in the crown, h the band, b the underside of the brim;
#   K the straw head (shaded), k the shadow of the brim on it, T the cord tying it;
#   C the coat (shaded), F its folds and seams, o a button, R the rope (r its shade),
#   G the turned-back cuffs, X a patch of sacking, x its stitches, M a patch of brown cloth, m its
#   stitches, t a tear;
#   S s z straw, lit, mid and dark.
# The pieces are laid in order, the later over the earlier.
POLE = (
    (0, 22),
    [
        *[".....................LPD"] * 21,
        *["....................LPD"] * 10,
        *["...................LPPD"] * 4,
        *["....................LPD"] * 8,
    ],
)
# The straw out of the cuffs, by frame: the wind blows it back into the left sleeve and out of
# the right one.
CUFF_STRAW = (
    {
        "left": ((0, 19), ["....sS", "..zSsS", ".SsSzs", "zSs.Ss", ".sSzSz", "S.zs.s", ".z.S..", "...z.."]),
        "right": ((35, 19), ["zs....", "sSsz..", "zsSsS.", "sS.sSz", "zsSzs.", "s.sz.S", "..S.z.", "..z..."]),
    },
    {
        "left": ((0, 19), [".....S", "...zSs", "..SsSz", ".zSsSs", "..sSzS", ".S.zs.", "..z.S.", "....z."]),
        "right": ((35, 19), ["zs.....", "sSsz.S.", "zsSsSzs", "sS.sSzS", "zsSzs.s", "s.sz.S.", "...S.z.", "....z.."]),
    },
    {
        "left": ((0, 19), ["......", "....zS", "...SsS", "..zSsz", "...sSs", "..S.zS", "...z.s", "......"]),
        "right": ((35, 19), ["zs.....", "sSszSs.", "zsSsSzSs", "sS.sSzsS", "zsSzsSz.", "s.szS.s", "....Sz..", "........"]),
    },
)
# The straw under the hem, in tufts of two or three strands; it blows with the skirt.
HEM_STRAW = ((10, 46), ["..sS..zS...Ss..sS..zS", "..zs..sz...sz..zs..sz", "...z...z....s...z...s"])
COAT = (
    (0, 17),
    [
        "................CCCCCCCCC",
        "...........CCCCCCCCCCCCCCCCCCC",
        "......GCCCCCCCCCCCCCCFCCCCCCCCCCCCG",
        ".....GGCCCCCCCCCCCCCCFCCCCCCCCCCCCGG",
        ".....GGCCCCCXXXXCCCCoFCCCCCCCCCCCCGG",
        ".....GGCFCCCXxXXCCCCCFCCCCCCCFCCCCGG",
        ".....GGCFCCCXXxXCCCCCFCCCCCCCFCCCCGG",
        ".....GGCCFCCxXXXCCCCCFCCCCCCFCCCCCGG",
        "......GCCCCCCCCCCCCCoFCCCCCCCCCCCCG",
        ".......FCCCFFCCCCCCCCFCCCCCCFFCCCF",
        "........CCC.CCCCCCCCCFCCCCCCC.CCC",
        "............CCCCCCCCCFCCCCCCC",
        "............CCCCCCCCCFCCCCCCC",
        "............CCCCCCCCoFCCCCCCC",
        "............RRRRRRRRRRRRRRrRR",
        "............rrrrrrrrrrrrrRrrr",
        "............CCCCCCCCCFCCCCRCC",
        "...........CCCCCCCCCCFCCCCRCCC",
        "...........CCFCCCCCCCFCCCCCrCC",
        "...........CCFCCCCCCCFCCCCCCCC",
        "...........CCFCCCCCCCFCCMMMMCC",
        "..........CCCFCCCCCCCFCCMmMMCCC",
        "..........CCFCCCCCCCCFCCMMMmCCC",
        "..........CCFCCCtCCCCFCCmMMMCCC",
        "..........CCFCCCCCCCCFCCCCCCFCC",
        ".........CCCFCCCCCCCCFCCCCCCFCCC",
        ".........CCFCCCCCCCCCFCCCCCCFCCC",
        ".........CCFCCCCCCCCCFCCCCCCCFCC",
        ".........CC.CCCC.CCCCFCC.CCCC.CC",
        "..........C...CC...CC....CC...C",
    ],
)
# The straw round the neck, under the cord.
NECK_STRAW = ((15, 15), ["..zSsSzSsz", ".sSzsSzSsSz", "zs.S.z.s.Sz"])
HEAD = (
    (0, 7),
    [
        "...............kkkkkkkkkk",
        "..............kkkkkkkkkkkk",
        "...........zSkkkkkkkkkkkkkSz",
        "..........SszKSKzKSKKzKKKKzsS",
        "..........zsKKSKzKSKKzKKzKKsz",
        "...........zKKSKzKKSKzKKzKKz",
        "............KKSKKzKSKKzKKzK",
        "............KKKSKzKSKKzKKKK",
        ".............KKSKzKKSKzKKK",
        "..............KKSKzKKzKKK",
        "................TTTTTTTT",
    ],
)
HAT = (
    (0, 0),
    [
        "...............HHHHHHHH",
        "..............HHHHddHHHH",
        ".............HHHHHHHdHHHH",
        ".............HHHHHHHHHHHHH",
        ".............HHHHHHHHHHHHHH",
        ".............hhhhhhhhhhhhhh",
        ".......BBBBBBBBBBBBBBBBBBBBBBBBBB",
        "......BBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
        ".......bbbbbb...............bbbbbbb",
        "..................................bb",
    ],
)

# What the regions are shaded in, dark to light.
RAMPS = {
    "P": ("mud_dark", "bare", "bare_light"),
    "H": ("soil_dark", "soil", "soil_mid"),
    "B": ("soil", "soil_mid", "soil_light"),
    "K": ("ochre_dark", "ochre", "straw"),
    "C": ("water_deep", "water", "water_light"),
    "G": ("water_deep", "water_deep", "water"),
}
# How far each region's light rises from its rim (see forms.light_level), and the light added at
# its top (a long form).
FORM = {"P": (1, 0.0), "H": (2, 0.2), "B": (2, 0.3), "K": (3, 0.2), "C": (4, 0.35), "G": (4, 0.35)}
COLOURS = {
    "L": "bare_light",
    "D": "mud_dark",
    "d": "soil_dark",
    "h": "soil_dark",
    "b": "soil_dark",
    "k": "ochre_dark",
    "T": "umber",
    "F": "water_deep",
    "o": "ochre",
    "R": "ochre",
    "r": "ochre_dark",
    "X": "sand_light",
    "x": "mud",
    "t": "soil_dark",
    "M": "rust_dark",
    "m": "russet_deep",
    "S": "straw",
    "s": "ochre",
    "z": "ochre_dark",
}
# The rim of the whole picture: the darkest shade of what it surrounds.
RIMS = {
    "water_deep": "ink",
    "water": "ink",
    "water_light": "ink",
    "sand_light": "mud_dark",
    "rust_dark": "russet_deep",
    "soil_mid": "soil_dark",
    "soil_light": "soil_dark",
    "soil": "soil_dark",
}
# The letters of the coat, shaded as one form.
COAT_LETTERS = "CGFoRrXxMmt"
# The wind moves the coat's rows below SWAY_TOP (the skirt) and the straw under its hem: in each
# frame they lean to the right by LEANS pixels per SWAY_ROWS rows; the cuffs' straw is drawn per
# frame.
SWAY_TOP = 26
SWAY_ROWS = 10
LEANS = (0, 1, 1.5)
WIDTH, HEIGHT = 42, 65


def _place(letters, piece, lean=0.0, top_of_lean=0):
    """Lays a piece ((left, top), rows) into `letters`, each row below `top_of_lean` moved
    right by `lean` pixels per SWAY_ROWS rows."""
    (left, top), rows = piece
    for index, row in enumerate(rows):
        y = top + index
        dx = round(max(0, y - top_of_lean) * lean / SWAY_ROWS)
        for column, key in enumerate(row):
            x = left + column + dx
            if key != "." and 0 <= x < WIDTH and 0 <= y < HEIGHT:
                letters[y, x] = key


def letters(frame=0):
    """The map of a frame (0 still, then blown a little more each)."""
    grid = np.full((HEIGHT, WIDTH), ".")
    _place(grid, POLE)
    for side in ("left", "right"):
        _place(grid, CUFF_STRAW[frame][side])
    _place(grid, HEM_STRAW, lean=LEANS[frame] * 1.3, top_of_lean=SWAY_TOP)
    _place(grid, COAT, lean=LEANS[frame], top_of_lean=SWAY_TOP)
    _place(grid, NECK_STRAW)
    _place(grid, HEAD)
    _place(grid, HAT)
    return grid


def scarecrow(frame=0):
    """A frame of the scarecrow, 42x65 px, standing (its bottom row on the ground)."""
    grid = letters(frame)
    picture = blank(WIDTH, HEIGHT)
    for key, ramp in RAMPS.items():
        # A region is shaded as one form with its details (the folds of the coat, the hat's dent).
        details = {"C": COAT_LETTERS, "G": COAT_LETTERS, "H": "Hdh", "K": "Kk", "B": "Bb", "P": "PLD"}[key]
        form = np.isin(grid, list(details))
        radius, top_light = FORM[key]
        level = forms.light_level(form, radius, top_light)
        forms.shade_by_level(picture, grid == key, ramp, level)
    for key, colour in COLOURS.items():
        forms.paint(picture, grid == key, colour)
    # Loose straw has no rim round its single strands (see the style rules).
    _rim(picture, np.isin(grid, list("Ssz")))
    return picture


def _rim(picture, loose):
    """Rims the picture's edge in the darkest shade of each region (in place), but for the
    `loose` pixels; the bottom row is left alone (it stands on the ground)."""
    rims = []
    for y in range(HEIGHT - 1):
        for x in range(WIDTH):
            colour = picture[y][x]
            if colour is None or loose[y, x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < WIDTH and 0 <= ny < HEIGHT) or picture[ny][nx] is None:
                    rims.append((x, y, _rim_of(colour)))
                    break
    for x, y, colour in rims:
        picture[y][x] = colour


def _rim_of(colour):
    """The rim of a pixel of `colour`: the darkest shade of its region."""
    if colour in ("straw", "gold", "ochre", "ochre_dark", "umber"):
        return "umber" if colour != "umber" else "soil_dark"
    if colour in ("bare", "bare_light", "mud_dark"):
        return "mud_dark"
    return RIMS.get(colour, colour)


def frames():
    """The SWAY_FRAMES pictures of the scarecrow, still first."""
    return [scarecrow(frame) for frame in range(SWAY_FRAMES)]


def icons():
    """The body of the icon of the scarecrow, the item that places one: its picture, still."""
    return {"scarecrow": items.icon_of(scarecrow())}

