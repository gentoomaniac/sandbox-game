"""Art for the cattle: the cow's sheets (wildlife/cow_<look>.png), drawn by hand as maps of letters.

The shared drawing and the way a letter map is laid over another are in livestock.py.
"""

import forms
import numpy as np
from canvas import blank, outline
from livestock import ACTIONS, TOP_LIGHT, WALK_STEPS, place_piece

# A cow of the period after the user's reference picture of a Holstein (task 159), 64 px from the
# rump to the muzzle and 35 px to the withers (a person is 61 px tall): a deep body with a level
# back, a deep neck sloping from the withers to a big head that hangs a little below the back
# line, the udder far back under the belly between the hind legs, forelegs from the chest with a
# wide forearm, a knee and a slim cannon, and hind legs from a big thigh with a slight hock.
#
# It is drawn by hand, a pixel at a time, as maps of letters, since a cow put together from
# shapes read as a box with a head stuck on: the body, the neck and the head looking ahead or
# down to the grass, each leg, the tail and the udder, every one at its place in the cell. A frame
# lays them over each other and shades them by their letters: the body, the neck, the head and
# the near legs as one form lit from the top left (so that the belly's shadow stops between the
# legs), the patches of a pied coat with it, the far legs a step darker.
#
# The letters: b the coat, k a patch (the coat in a whole-coloured look), s a shadow in the coat,
# f a far leg, h and H a near and a far hoof, u the udder and t a teat, T the tail and K its
# tuft; on the head e the eye and g its glint, p the pink inside an ear, c a horn and C its tip,
# m the muzzle, M its shade and o the nostril.

COW_SIZE = (72, 54)
# The body without the legs below the belly and without the neck: the near forearm and thigh
# are in it, and so are the shadows of the flank before the thigh and behind the elbow.
COW_TORSO = ((4, 16), (
    ".........bbbbb....................bbbbbbb",
    "..kkkkkkkbbbbbbbbkkkkkkkkkkkkkkkbbbbbbbkkkkkk",
    ".kkkkkkkkkbbbbbbkkkkkkkkkkkkkkkkkbbbbbkkkkkkk",
    "kkkkkkkkkkbbbbbkkkkkkkkkkkkkkkkkkkbbbbkkkkkkk",
    "kkkkkkkkkkbbbbbkkkkkkkkkkkkkkkkkkkbbbbkkkkkkk",
    "kkkkkkkkkbbbbbbkkkkkkkkkkkkkkkkkkkkbbbbkkkkkk",
    "kkkkkkkkbbbbbbbbkkkkkkkkkkkkkkkkkkkbbbbkkkkkk",
    "bkkkkkkkbbbbbbbbkkkkkkkkkkkkkkkkkkbbbbbbkkkkk",
    "bbkkkkkbbbbbbbbbbkkkkkkkkkkkkkkkkkbbbbbbkkkkk",
    "bbbkkkbbbbbbbbbbbkkkkkkkkkkkkkkkkkbbbbbbbkkkk",
    "bbbbbbbbbbbbbbbbbbkkkkkkkkkkkkkkkbbbbbbbbkkkk",
    "bbbbbbbbbbbbbbbbbbkkkkkkkkkkkkkkkbbbbbbbbbkkb",
    "bbbbbbbbbbbbbbbbbbbkkkkkkkkkkkkkbbbbbbbbbbbbb",
    "bbbbbbbbbbbbbbbbbbbkkkkkkkkkkkkkbbbbbbbbbbbbb",
    "bbbbbbbbbbbbbbbbbbbbkkkkkkkkkkkkbbbbbbbbbbbbb",
    "bbbbbbbbbbbbbbbbbbbbkkkkkkkkkkkbbbbbbbbbbbbbb",
    ".bbbbbbbbbbbbbbbbbbbbkkkkkkkkkkbbbbbbbbbbbbbb",
    ".bbbbbbbbbbbbbssbbbbbbkkkkkkkkbbbbbbbbbbbbbbb",
    ".bbbbbbbbbbbbssssbbbbbbkkkkkkbbbbbbbbbbbbbbbb",
    ".bbbbbbbbbbbbsssssbbbbbbbkkkbbbbbbbbbbbbbbbbb",
    "..bbbbbbbbbbbssssssbbbbbbbbbbbbbbbbssbbbbbbbb",
    "..bbbbbbbbbbb......bbbbbbbbbbbbbbbbsssbbbbbbb",
    "..bbbbbbbbbbb......bbbbbbbbbbbbbbbbbssbbbbbbb",
    "...bbbbbbbbb........bbbbbbbbbbbbbbbb..bbbbbbb",
    "...bbbbbbbb...........................bbbbbb",
))
# The neck from the shoulder to the head: deep at the shoulder, its top sloping gently from the
# withers, the throat running into the chest with a soft dewlap; grazing, it reaches down in
# front of the forelegs.
COW_NECKS = {
    "ahead": ((49, 18), (
        "k",
        "kbbb",
        "kbbbbbb",
        "kbbbbbb",
        "kbbbbbbb",
        "kkbbbbbb",
        "kbbbbbbb",
        "kbbbbbbb",
        "bbbbbbbb",
        "bbbbbbbb",
        "bbbbbbbb",
        "bbbbbbbb",
        "bbbbbbbb",
        "bbbbbbbb",
        "bbbbbbb",
        "bbbbbb",
        "bbbbb",
        "bbbb",
        "bbb",
        "bbb",
        "bb",
    )),
    "down": ((49, 18), (
        "k",
        "kb",
        "kkb",
        "kkb",
        "kkkb",
        "kkkb",
        "kkbbb",
        "kbbbb",
        "bbbbbb",
        "bbbbbb",
        "bbbbbbb",
        "bbbbbbb",
        "bbbbbbbb",
        "bbbbbbbb",
        "bbbbbbbb",
        "bbbbbbbbb",
        "bbbbbbbbb",
        "bbbbbbbbbb",
        "bbbbbbbbbb",
        "bbbbbbbb",
        "bbbbbbb",
        ".bbbbbb",
        "...bbbb",
        "....bbb",
        ".....bb",
    )),
}
# The head, a quarter of the cow's length, looking ahead and down to the grass: black round the
# eye and white down the face, the pink muzzle, short horns, and the ears out to the sides, the
# near one behind the head and the far one in front of the face.
COW_HEADS = {
    "ahead": ((51, 16), (
        "......C.....C",
        ".......c...c",
        ".......kkkkb",
        ".bbbbkkkkkkkb.kkk",
        "bppbbkkkkkkkbbkppk",
        ".bbbkkkkkkkkbbkkk",
        "....kkkkkkkkbb",
        "....kkkkkgekbb",
        "....kkkkkeekbbb",
        ".....kkkkkkkbbb",
        ".....kkkkkkkbbb",
        "......kkkkkkbbbb",
        "......bkkkkkbbbm",
        ".......bkkkbbbmmm",
        ".......bbbbbbmmmo",
        "........bbbbbmmmm",
        "........bbbbmmmmm",
        ".........bbMMMMb",
    )),
    "down": ((50, 34), (
        ".......C....C",
        "........c..c",
        ".......kkkkk",
        ".....kkkkkkkb",
        ".kkkkkkkkkkkbbkkk",
        "kppkkkkkkkkkbbkppk",
        ".kkkkkkkkgebbbkkk",
        "....kkkkkeebbb",
        ".....kkkkkkbbb",
        ".....kkkkkbbbb",
        ".....bkkkkbbbb",
        "......bkkbbbbb",
        "......bbbbbbbb",
        "......bbbbbmmm",
        "......bbbmmmmm",
        ".......bmmmmmo",
        ".......bmmmmm",
        "........MMMM",
    )),
}
# The legs below the body, standing: the near ones with their knee and hock, the far ones behind
# them, the far hind leg showing under the udder in front of the near one.
COW_LEGS = {
    "near_front": ((42, 41), (
        "bbbbbb",
        ".bbbbb",
        ".bbbbb",
        ".bbbbb",
        ".bbbbb",
        "..bbb",
        "..bbb",
        "..bbb",
        "..bbb",
        "..bbb",
        ".hhhhh",
        ".hhhhh",
    )),
    "near_hind": ((7, 41), (
        ".bbbbbb",
        ".bbbbb",
        "bbbbbb",
        ".bbbbb",
        "...bbb",
        "...bbb",
        "...bbb",
        "...bbb",
        "...bbb",
        "...bbb",
        "..hhhhh",
        "..hhhhh",
    )),
    "far_front": ((38, 39), (
        "ffff",
        "ffff",
        "ffff",
        "ffff",
        ".ffff",
        ".ffff",
        ".ffff",
        "..fff",
        "..fff",
        "..fff",
        "..fff",
        ".HHHH",
        ".HHHH",
    )),
    "far_hind": ((14, 40), (
        "fff",
        "fff",
        "fff",
        "fff",
        "ffff",
        "fff",
        "fff",
        "fff",
        "fff",
        "fff",
        "HHHH",
        "HHHH",
    )),
}
# Lying, the near legs folded under the body: the foreleg with its knee forward under the chest,
# the hind leg's cannon along the ground under the belly.
COW_FOLDED_LEGS = [
    ((42, 50), (
        ".....bbbbbb",
        "hhhhbbbbbbbb",
        "hhhhbbbbbbb",
    )),
    ((7, 50), (
        ".bbbbbbbbb..hhh",
        "bbbbbbbbbbbbhhh",
        ".bbbbbbbbbbbhhh",
    )),
]
COW_UDDER = ((15, 37), (
    ".uuuuuuu",
    "uuuuuuuu",
    "uuuuuuuu",
    "uuuuuuu",
    ".uuuuu",
    "..t..t",
))
# The tail behind the rump with its tuft: hanging, flicked up, and lying on the ground.
COW_TAILS = {
    "hanging": ((1, 18), ("..TT",) + (".T",) * 18 + (".KK", "KKK", "KKK", "KKK", ".K")),
    "swishing": ((1, 18), ("..TT",) + (".T",) * 6 + ("T",) * 9 + ("KK", "KKK", "KKK", "KKK", ".K")),
    "lying": ((1, 30), ("..TT",) + (".T",) * 17 + (".KK", "KKKK", "KKKKK", ".KKKK")),
}
# How far a leg's hoof is set forward of its top for a step of a walk (WALK_STEPS).
COW_STRIDES = {"stand": 0, "forward": 2, "back": -2}
# Lying, the body is this much lower, the belly on the ground.
COW_LYING_DROP = 12
# The letters of the one form lit from the top left.
COW_BODY = "bkseglpcmMo"

COW_LOOKS = {
    # Angler: the dark red cattle of Angeln on the Baltic side, red all over.
    "angler": {
        "coat": ("russet_deep", "rust_dark", "rust_dark", "rust"),
        "muzzle": ("skin_shade", "russet_deep"),
        "outline": "russet_deep",
        "lid": "russet_deep",
    },
    # Black and white marsh cattle of the North Sea coast, a white face with black round the eye.
    "black_pied": {
        "coat": ("stone_light", "lime", "lime", "snow_light"),
        "patches": ("bog_dark", "stone_dark", "stone"),
        "outline": "ink",
        "lid": "stone",
    },
    # Red pied: mostly white with red patches, the cattle of the marsh farms.
    "red_pied": {
        "coat": ("stone_light", "lime", "lime", "snow_light"),
        "patches": ("rust_dark", "rust", "red_light"),
        "outline": "russet_deep",
        "lid": "russet_deep",
    },
}
COW_SHARED = {"hoof": ("ink", "bog_dark", "stone_dark"), "muzzle": ("petal", "skin_shade")}


def cow_letters(steps, head, tail, lying, head_drop):
    """The letters of a frame: the pieces laid over each other from the far legs to the near
    ones, a lying cow `COW_LYING_DROP` lower with its legs folded and its eyes shut."""
    width, height = COW_SIZE
    letters = np.full((height, width), ".")
    (near_hind, near_front), (far_hind, far_front) = steps
    dy = COW_LYING_DROP if lying else 0
    if not lying:
        place_piece(letters, COW_LEGS["far_front"], stride=COW_STRIDES[far_front])
        place_piece(letters, COW_LEGS["far_hind"], stride=COW_STRIDES[far_hind])
    place_piece(letters, COW_TAILS[tail])
    if not lying:
        place_piece(letters, COW_UDDER)
    place_piece(letters, COW_TORSO, dy)
    place_piece(letters, COW_NECKS[head], dy)
    place_piece(letters, COW_HEADS[head], dy + head_drop)
    if lying:
        for leg in COW_FOLDED_LEGS:
            place_piece(letters, leg)
        # The eye shut: its lid a line where the bottom of the eye was.
        letters[letters == "g"] = "k"
        eye = letters == "e"
        letters[eye & (np.arange(height)[:, None] == np.nonzero(eye)[0].min())] = "k"
        letters[letters == "e"] = "l"
    else:
        place_piece(letters, COW_LEGS["near_front"], stride=COW_STRIDES[near_front])
        place_piece(letters, COW_LEGS["near_hind"], stride=COW_STRIDES[near_hind])
    return letters


def cow_frame(look, steps=WALK_STEPS[1], head="ahead", tail="hanging", lying=False, head_drop=0):
    """One frame of a cow facing right (see COW_TORSO and the pieces after it)."""
    letters = cow_letters(steps, head, tail, lying, head_drop)
    picture = blank(*COW_SIZE)

    def mask(keys):
        return np.isin(letters, list(keys))

    coat = look["coat"]
    patches = look.get("patches")
    body = mask(COW_BODY)
    level = forms.light_level(body, 4, TOP_LIGHT)
    forms.shade_by_level(picture, mask("b" if patches else "bk"), coat, level)
    if patches:
        # Mostly the darkest shade, lit only along the very top.
        forms.shade_by_level(picture, mask("k"), (patches[0], patches[0], patches[0], patches[1]), level - 0.12)
    forms.paint(picture, mask("s"), coat[0])
    forms.shade(picture, mask("f"), (coat[0], coat[0], coat[1], coat[2]), 2)
    forms.shade(picture, mask("h"), look["hoof"], 1)
    forms.shade(picture, mask("H"), look["hoof"], 1)
    forms.shade(picture, mask("u"), ("skin_shade", "petal", "petal"), 2)
    forms.paint(picture, mask("T"), coat[1])
    forms.paint(picture, mask("K"), (patches or coat)[0])
    colours = {
        "t": "skin_shade",
        "e": "ink",
        "g": "snow_light",
        "l": look["lid"],
        "p": "petal",
        "c": "cream",
        "C": "stone",
        "m": look["muzzle"][0],
        "M": look["muzzle"][1],
        "o": "rust_dark",
    }
    for key, colour in colours.items():
        forms.paint(picture, mask(key), colour)
    return outline(picture, look["outline"])


def cow_sheet(look):
    """The rows of a cow's sheet (ACTIONS): it flicks its tail standing, chews with its head down,
    breathes lying down and hurries at a walk (it has no gallop)."""
    style = COW_SHARED | COW_LOOKS[look]
    walk = [cow_frame(style, steps=steps) for steps in WALK_STEPS]
    frames = {
        "idle": [cow_frame(style), cow_frame(style, tail="swishing")],
        "walk": walk,
        "graze": [cow_frame(style, head="down"), cow_frame(style, head="down", head_drop=-1)],
        "sleep": [cow_frame(style, lying=True, tail="lying"), cow_frame(style, lying=True, tail="lying", head_drop=1)],
        "run": walk,
    }
    return [frames[action] for action in ACTIONS]


def sheets():
    """Every sheet of the cows as (file name, cell size, rows of cells for palette.save)."""
    for look in COW_LOOKS:
        yield f"cow_{look}", COW_SIZE, cow_sheet(look)
