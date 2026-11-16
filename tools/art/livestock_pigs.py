"""Art for the pigs: the pig's sheets (wildlife/pig_<look>.png), drawn by hand as maps of letters like the cow's.

The shared drawing is in livestock.py.
"""

import forms
import numpy as np
from canvas import blank, outline
from livestock import ACTIONS, WALK_STEPS, place_piece

# A pig of the old breeds after the user's reference picture (task 165), 40 px from the tail to
# the snout and 23 px tall: a short, deep body whose back arches over the loin and the shoulders
# and whose rump rounds down to a low-set curly tail, a belly curving up between the legs, a big
# head hanging forward and down below the back line, a wedge down to the snout's disc with a big
# ear flopping forward over the eye, and longish legs on trotters, the hind one slanting back to
# its hock. The old breeds were bristly and of many colours, so the coat has broken tones of
# bristles along the back and the flank and comes in several looks.
#
# It is drawn by hand as maps of letters like the cow (see COW_TORSO): the body, the head looking
# ahead or rooting with the snout on the ground, its ear, each leg and the tail, laid over each
# other for a pose and shaded by their letters. The body, the head and the near legs are one form
# lit from the top left, the ear a flap of its own over the face, the far legs a step darker. A
# look with a second colour (a saddle, spots) has a map of where it is (`pattern`, laid over the
# body), the near foreleg white or not with it.
#
# The letters: b the coat, d its dark tone (the belly, the snout, the lower legs), s a shadow in
# it, r and q the bristles' lit tips and their dark, f a far leg, h and H a near and a far
# trotter, a the ear and A its dark underside, e the eye and g its glint, n the snout's disc and
# o the nostril, m the mouth, T the tail.

PIG_SIZE = (52, 32)
PIG_TORSO = ((7, 8), (
    "........brbbbrbbbbrbbb",
    "...rbbbbbbbbbbbbbbbbbbbbbbr",
    "..bbbbbbbqbbbbbbbbbbbqbbbbb",
    ".bbbbbbbqbbbbbqbbbbbqbbbbbbb",
    "bbbbqbbbbbbbbqbbbbbbbbbbqbbb",
    "bbbqbbbbsbbbbbbbbqbbbbbqbbbb",
    "bbbbbbbbbsbbbbbbqbbbbbbbbbbb",
    "bbbbbbbqbsbbqbbbbbbbbqbbbbbb",
    "bqbbbbbbbsbbqbbbbbbbqbbbbbbb",
    "qbbbbbbbbbsbbbbbbbbbbsbbbbbb",
    "bbbbbbbbbbsbbbbbbbbbbsbbbbbb",
    "bbbbbbbbbbbbbbbbbbbbbsbbbbbb",
    ".bbbbbbbbbbddddddddddbbbbbbb",
    "..bbbbbbbb..........bbbbbbbb",
    "...bbbbb.............bbbbb",
))
# The head with its neck, hanging forward below the back line, and rooting with the snout's disc
# on the ground in front of the forelegs.
PIG_HEADS = {
    "ahead": ((31, 9), (
        "bbb",
        "bbbbr",
        "bbbbbbb",
        "bbbbbbbbb",
        "bbbbbbbbbb",
        "bbbbbbbbbbb",
        "bbbbbbbbbbbd",
        "bbbbbbbbbbbdd",
        "bbbbbbbbbbbddd",
        "bbbbbbbbbbbdddn",
        "bbbbbbbbbbbbddon",
        "bbbbbbbbbbbbdddn",
        "bbbbbbbbbmmmmddn",
        ".bbbbbbbbddddnn",
    )),
    "down": ((31, 12), (
        "bbbb",
        "bbbbb",
        "bbbbbb",
        "bbbbbbb",
        "bbbbbbbb",
        "bbbbbbbbb",
        "bbbbbbbbbb",
        "bbbbbbbbbbb",
        "bbbbbbbbbbbd",
        "bbbbbbbbbbddd",
        ".bbbbbbbbbddd",
        "...bbbbbbbddd",
        ".....bbbdddd",
        "......mbddddd",
        ".......mddddd",
        "........dddddd",
        ".........dddod",
        "..........nnnn",
        "...........nnnn",
    )),
}
# The ear flopping forward over the eye, its dark underside over the face, and the eye under it.
PIG_EARS = {
    "ahead": ((33, 9), (
        ".aa",
        ".aaaa",
        "..aaaaa",
        "..aaaaaa",
        "...aaaaaA",
        "....aaaAA",
        "...geAAA",
        ".......A",
    )),
    "down": ((33, 13), (
        ".aa",
        ".aaaa",
        "..aaaaa",
        "..aaaaaa",
        "...aaaaaA",
        "....aaaAA",
        "...ge.AA",
        ".......A",
    )),
}
# The legs below the body, standing, as limbs out of it: the near hind leg from the big ham of
# the rump, narrowing to the hock that points back and slanting back down a slim cannon to the
# trotter; the near foreleg from a wide forearm in the chest to a knee halfway down and a slim
# leg below it. Their tops are in the body's letters, so they are shaded with it and the belly's
# shadow stops between them. The far legs are behind, a step darker, the far hind leg partly
# hidden by the near ham.
PIG_LEGS = {
    "near_front": ((26, 18), (
        "bbbbbb",
        "bbbbbb",
        "bbbbbb",
        ".bbbbb",
        ".bbbb",
        "..bbb",
        "..bbb",
        "..bbbb",
        "...dd",
        "...dd",
        "...dd",
        "...hhh",
        "...hhh",
    )),
    "near_hind": ((7, 18), (
        ".bbbbbbbbb",
        ".bbbbbbbbb",
        "..bbbbbbb",
        "..bbbbbb",
        "..bbbbb",
        "..bbbb",
        ".bbbb",
        ".ddd",
        ".dd",
        ".dd",
        "dd",
        "hhh",
        "hhh",
    )),
    "far_front": ((23, 21), ("fff", "fff", "fff", "fff", "ffff", ".ff", ".ff", ".ff", ".HHH", ".HHH")),
    "far_hind": ((12, 21), (".ffff", ".fff", ".fff", "fff", ".ff", ".ff", "ff", "ff", "HHH", "HHH")),
}
# Lying, the forelegs folded under the chest with the trotters back, the hind leg along the ground.
PIG_FOLDED_LEGS = [
    ((22, 28), ("..dddd", "..dddd", "hhhddd")),
    ((13, 29), ("ddddd", "dddddhh")),
]
# The curly tail, growing out of the top of the rump: curled and flicked; T in the coat, t lit.
PIG_TAILS = {
    "curled": ((5, 5), (".TT", "Tt.T", "T..T", "...TT", "....T")),
    "flicked": ((6, 4), ("..TT", ".T..T", ".t", "..T", "...T", "...T")),
}
PIG_STRIDES = {"stand": 0, "forward": 3, "back": -3}
PIG_LYING_DROP = 7
# The letters of the one form lit from the top left, and the light added at its top: less than
# the other animals', so the bristly back is not one bright band.
PIG_BODY = "bdsqrmegno"
PIG_TOP_LIGHT = 0.12

PIG_LOOKS = {
    # Red-brown and bristly, like the old landrace pigs of the marsh farms.
    "red": {
        "coat": ("russet_deep", "rust_dark", "rust", "leaf_orange"),
        "snout": ("rust_dark", "russet_deep"),
        "outline": "russet_deep",
    },
    # Sandy, a pale yellow-brown.
    "sandy": {
        "coat": ("mud", "sand", "sand_light", "cream"),
        "snout": ("skin_shade", "soil"),
        "outline": "mud_dark",
    },
    # Black with a white saddle over the shoulders and the forelegs (a saddleback).
    "saddleback": {
        "coat": ("ink", "stone_dark", "stone_dark", "stone"),
        "patches": ("stone", "stone_light", "lime", "snow_light"),
        "pattern": ((24, 8), (
            "..bbbbb",
            ".bbbbbbb",
            ".bbbbbbbb",
            "..bbbbbbbb",
            "..bbbbbbbb",
            "..bbbbbbbbb",
            "...bbbbbbbb",
            "...bbbbbbbb",
            "..bbbbbbbbb",
            "..bbbbbbbbb",
            "...bbbbbbbb",
            "...bbbbbbbbb",
            "....bbbbbbbb",
            "....bbbbbbbb",
            "....bbbbbbbb",
        )),
        "white_foreleg": True,
        "snout": ("stone_dark", "ink"),
        "outline": "ink",
    },
    # Pale with black spots.
    "spotted": {
        "coat": ("skin_shade", "skin", "skin", "cream"),
        "patches": ("ink", "stone_dark", "stone_dark", "stone"),
        "pattern": ((7, 8), (
            "",
            "....bbb...........bbb",
            "...bbbbb.........bbbbb",
            "...bbbbbb........bbbb",
            "....bbbb....bbb...bb",
            "............bbbbb",
            ".............bbbb",
            "",
            "",
            "..bbb................bbb",
            ".bbbbb..............bbbbb",
            "..bbb................bbb",
        )),
        "snout": ("skin_shade", "soil"),
        "outline": "soil",
    },
}
PIG_SHARED = {"hoof": ("ink", "soil_dark", "mud_dark")}


def pig_letters(steps, head, tail, lying, head_drop, pattern):
    """The letters of a frame, as for the cow (`cow_letters`), and where the look's second colour
    is: its `pattern` laid over the body, under the head and the near legs (but the near foreleg
    of a look with `white_foreleg`)."""
    width, height = PIG_SIZE
    letters = np.full((height, width), ".")
    patched = np.zeros(letters.shape, bool)
    (near_hind, near_front), (far_hind, far_front) = steps
    dy = PIG_LYING_DROP if lying else 0
    white_foreleg = pattern is not None and pattern.get("white_foreleg", False)
    if not lying:
        far_foreleg = place_piece(letters, PIG_LEGS["far_front"], stride=PIG_STRIDES[far_front])
        place_piece(letters, PIG_LEGS["far_hind"], stride=PIG_STRIDES[far_hind])
        if white_foreleg:
            patched |= far_foreleg
    place_piece(letters, PIG_TAILS[tail], dy)
    torso = place_piece(letters, PIG_TORSO, dy)
    if pattern is not None:
        patched |= place_piece(np.full(letters.shape, "."), pattern["pattern"], dy) & torso
    patched &= ~place_piece(letters, PIG_HEADS[head], dy + head_drop)
    patched &= ~place_piece(letters, PIG_EARS[head], dy + head_drop)
    if lying:
        for leg in PIG_FOLDED_LEGS:
            patched &= ~place_piece(letters, leg)
        # The eye shut: its lid a line in the ear's dark.
        letters[(letters == "e") | (letters == "g")] = "A"
    else:
        foreleg = place_piece(letters, PIG_LEGS["near_front"], stride=PIG_STRIDES[near_front])
        patched &= ~foreleg
        if white_foreleg:
            patched |= foreleg
        patched &= ~place_piece(letters, PIG_LEGS["near_hind"], stride=PIG_STRIDES[near_hind])
    return letters, patched


def pig_frame(look, steps=WALK_STEPS[1], head="ahead", tail="curled", lying=False, head_drop=0):
    """One frame of a pig facing right (see PIG_TORSO and the pieces after it)."""
    letters, patched = pig_letters(steps, head, tail, lying, head_drop, look if "pattern" in look else None)
    width, height = PIG_SIZE
    picture = blank(width, height)

    def mask(keys):
        return np.isin(letters, list(keys))

    def shade_in_region(keys, tones, level):
        """Shades the letters' pixels by `level` in the ramp of their region (the coat or the
        look's second colour), picking the ramp's shades by their indices in `tones`."""
        for y, x in zip(*np.nonzero(mask(keys))):
            ramp = look["patches"] if patched[y, x] else look["coat"]
            step = sum(int(level[y, x] > threshold) for threshold in forms.THRESHOLDS.get(len(tones), ()))
            picture[y][x] = ramp[tones[step]]

    level = forms.light_level(mask(PIG_BODY), 4, PIG_TOP_LIGHT)
    shade_in_region("b", (0, 1, 2, 3), level)
    shade_in_region("d", (0, 0, 1, 2), level)
    shade_in_region("s", (0,), level)
    # The bristles: their dark lying back along the flank, their tips catching the light on the back.
    shade_in_region("q", (0, 0, 1, 2), level)
    shade_in_region("r", (1, 2, 3, 3), level)
    shade_in_region("aA", (0, 1, 2), forms.light_level(mask("aA"), 2))
    shade_in_region("A", (0,), level)
    shade_in_region("f", (0, 0, 1, 2), forms.light_level(mask("f"), 2))
    forms.shade(picture, mask("h"), look["hoof"], 1)
    forms.shade(picture, mask("H"), look["hoof"], 1)
    forms.paint(picture, mask("m"), look["coat"][0])
    forms.paint(picture, mask("n"), look["snout"][0])
    forms.paint(picture, mask("o"), look["snout"][1])
    forms.paint(picture, mask("e"), "ink")
    forms.paint(picture, mask("g"), "cream")
    forms.paint(picture, mask("T"), look["coat"][2])
    forms.paint(picture, mask("t"), look["coat"][3])
    return outline(picture, look["outline"])


def pig_sheet(look):
    """The rows of a pig's sheet (ACTIONS): it flicks its tail standing, roots with its snout on
    the ground, breathes lying down and hurries at a walk."""
    style = PIG_SHARED | PIG_LOOKS[look]
    walk = [pig_frame(style, steps=steps) for steps in WALK_STEPS]
    frames = {
        "idle": [pig_frame(style), pig_frame(style, tail="flicked")],
        "walk": walk,
        "graze": [pig_frame(style, head="down"), pig_frame(style, head="down", head_drop=-1)],
        "sleep": [pig_frame(style, lying=True), pig_frame(style, lying=True, head_drop=1)],
        "run": walk,
    }
    return [frames[action] for action in ACTIONS]


def sheets():
    """Every sheet of the pigs as (file name, cell size, rows of cells for palette.save)."""
    for look in PIG_LOOKS:
        yield f"pig_{look}", PIG_SIZE, pig_sheet(look)
