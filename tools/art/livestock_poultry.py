"""Art for the poultry: the hen's sheets (wildlife/chicken_<look>.png) and the rooster's (wildlife/chicken_rooster.png).

The shared drawing is in livestock.py.
"""

import forms
import numpy as np
from canvas import blank, outline
from livestock import ACTIONS, TOP_LIGHT, moved, place_piece, rounded

# A hen drawn a little larger than life, 22 px from the tail to the beak: a plump body with the
# breast forward, the tail raised behind, a folded wing in rows of feathers, a red comb and
# wattle, an eye with a glint and yellow legs with spread toes. She is drawn whole for each
# frame: her head and body move for a pose (`hen_frame`). The rooster is drawn after her.

CHICKEN_SIZE = (24, 24)
CHICKEN_GROUND = 22
# A walk: how far each foot is ahead and how high it is lifted, the near foot then the far one.
CHICKEN_STEPS = [(2, 0, -2, 0), (0, 2, 0, 0), (-2, 0, 2, 0), (0, 0, 0, 2)]
# The head's middle standing, pecking at the ground and coming up from it, and drawn in asleep
# (breathing out, it sinks a little).
HEN_HEADS = {"up": (18, 5), "peck": (21, 17), "peck_up": (21, 11), "tucked": (17, 10), "sunk": (17, 11)}
CHICKEN_LOOKS = {
    # A brown farm hen.
    "brown": {
        "plumage": ("umber", "ochre_dark", "ochre", "leaf_orange"),
        "wing": ("soil_dark", "umber", "ochre_dark"),
        "tail": ("soil_dark", "umber", "ochre_dark"),
        "scallop": "ochre",
        "outline": "soil_dark",
    },
    "white": {
        "plumage": ("stone_light", "lime", "lime", "snow_light"),
        "wing": ("stone", "stone_light", "lime"),
        "tail": ("stone", "stone_light", "lime"),
        "scallop": "snow_light",
        "outline": "stone",
    },
}


def chicken_legs(picture, steps):
    """The legs and toes, standing or in a step (CHICKEN_STEPS); `steps` None for a sitting hen."""
    if steps is None:
        return
    for x, (ahead, lift) in ((10, steps[2:]), (13, steps[:2])):
        x, foot = x + ahead, CHICKEN_GROUND - lift
        forms.dots(picture, [(x, y) for y in range(16, foot)], "ochre_dark")
        forms.dots(picture, [(x + 1, y) for y in range(17, foot - 1)], "ochre")
        forms.dots(picture, [(x + dx, foot) for dx in range(-2, 3)] + [(x - 1, foot - 1)], "ochre")


def hen_frame(look, head="up", steps=(0, 0, 0, 0), eye_shut=False):
    """One frame of a hen of `look`: her head at HEN_HEADS[head], her legs in `steps` (None: she
    sits on them), her eye open or shut."""
    style = CHICKEN_LOOKS[look]
    width, height = CHICKEN_SIZE
    picture = blank(width, height)
    sitting = steps is None
    drop = 4 if sitting else 0
    hx, hy = HEN_HEADS[head]
    # Pecking, the body tips forward and the tail rises.
    tip = 2 if head.startswith("peck") else 0
    chicken_legs(picture, steps)
    tail = moved([(2, 3), (5, 2), (8, 8), (8, 14), (3, 13), (1, 7)], 0, drop - tip)
    forms.shade(picture, forms.polygon(width, height, tail), style["tail"], 2)
    forms.dots(picture, rounded(moved([(3, 5), (4, 7), (4, 9), (5, 11)], 0, drop - tip)), style["tail"][0])
    body = forms.ellipse(width, height, 12, 12 + drop, 8, 6.5) | forms.ellipse(width, height, 15 + tip, 10 + drop + tip, 5.5, 5)
    neck = forms.capsule(width, height, (15 + tip, 9 + drop + tip), (hx - 1, hy + 1), 2.8, 2.4)
    forms.shade(picture, body | neck, style["plumage"], 4)
    wing = forms.ellipse(width, height, 11, 12 + drop, 5.2, 3.6)
    forms.shade(picture, wing, style["wing"], 2)
    for y in (12, 14, 16):
        forms.dots(picture, [(x, y + drop) for x in range(7 + (y // 2) % 2, 16, 2) if wing[y + drop, x]], style["scallop"])
    forms.shade(picture, forms.ellipse(width, height, hx, hy, 3.4, 3.4), style["plumage"], 2)
    # The comb on the crown, the beak, the wattle under it and the eye.
    comb = [(hx - 2, hy - 4), (hx - 1, hy - 4), (hx, hy - 4), (hx - 1, hy - 5), (hx + 1, hy - 4), (hx - 3, hy - 3)]
    forms.dots(picture, comb, "red_light")
    forms.dots(picture, [(hx + 3, hy), (hx + 4, hy), (hx + 3, hy + 1)], "gold")
    forms.dots(picture, [(hx + 4, hy + 1)], "ochre_dark")
    wattle = [(hx + 2, hy + 2), (hx + 2, hy + 3), (hx + 1, hy + 3)]
    forms.dots(picture, wattle, "red_light")
    if eye_shut:
        forms.dots(picture, [(hx + 1, hy - 1)], style["plumage"][0])
    else:
        forms.dots(picture, [(hx + 1, hy - 2), (hx + 1, hy - 1)], "ink")
        forms.dots(picture, [(hx + 2, hy - 2)], "cream")
    return outline(picture, style["outline"])


def chicken_sheet(look):
    walk = [hen_frame(look, steps=steps) for steps in CHICKEN_STEPS]
    frames = {
        "idle": [hen_frame(look), hen_frame(look, eye_shut=True)],
        "walk": walk,
        "graze": [hen_frame(look, head="peck"), hen_frame(look, head="peck_up")],
        "sleep": [hen_frame(look, head="tucked", steps=None, eye_shut=True), hen_frame(look, head="sunk", steps=None, eye_shut=True)],
        "run": walk,
    }
    return [frames[action] for action in ACTIONS]


# The rooster of a flock, a head taller than his hens and drawn by hand as maps of letters like
# the cow (see COW_TORSO): 27 px from the tail to the beak and 30 px from the toes to the tips of
# his tail, which rises behind him in a tall arch of sickle feathers and hangs down at its end. He
# stands upright on long yellow legs with a spur, his breast forward, with a big red comb, long
# wattles and a red face, a cape of golden hackles over his shoulders and golden saddle hackles
# over the root of his tail, a red-brown back and a dark green bar across his wing. The pieces
# (`ROOSTER_TAIL`, `ROOSTER_BODY`, the neck and head of each pose in `ROOSTER_HEADS`) are laid
# over the legs (`rooster_legs`); he has the hen's frames: pecking, his body tips forward and his
# tail rises, asleep he sits on his legs with his head drawn in.
#
# The letters: t the tail, s and S the sickles and their glossy upper edge; b the plumage, d its
# dark underside, w the wing, W its bar, h and H the hackles and their dark streaks; c the comb,
# C its shade (and a shut eye), f the face, r the wattles, e the eye and g its glint, k the beak
# and K its lower half; L and l the near leg and its shade, F the far leg, p the spur.

ROOSTER_SIZE = (34, 32)
ROOSTER_GROUND = 30
ROOSTER_TAIL = ((1, 1), (
    "........SSSSSS",
    ".....SSSssssssSS",
    "....SSssttttttss",
    "...SssttSSSSSStt",
    "..SsstSSssssssSS",
    ".SsstSSssttttsst",
    ".SstSssttSSSSttt",
    "SsttSstSSsssttt",
    "SstSstSSsttttttt",
    "SstSstSstttttttt",
    "SstSstSstttttttt",
    "SstSs...tttttttt",
    "SstSs....ttttttt",
    "Sst......ttttttt",
    "Ss.......ttttttt",
    "Ss.......ttttttt",
    ".S",
))
ROOSTER_BODY = ((9, 11), (
    "...hhhbbbbbbbbbbb",
    ".hHhHhbbbbbbbbbbbbb",
    ".hHhHhbbbbbbbbbbbbbbb",
    ".HhHhbbbbbbbbbbbbbbbb",
    ".hHbbbbbbbbbbbbbbbbbb",
    ".bbbbwwwwwwwbbbbbbbbb",
    ".bbbwwwwwwwwwbbbbbbbd",
    "bbbwwwwwwwwwwwbbbbbdd",
    "bbbWWWWWWWWWWwbbbbbdd",
    ".bbbWWWWWWWWWbbbbddd",
    "..bbbbbbbbbbbbbbbdd",
    "...ddbbbbbbbbbbddd",
    ".....ddddddddddd",
))
# The neck and head: standing, pecking at the ground and coming up from it, and drawn in asleep.
ROOSTER_HEADS = {
    "up": ((17, 1), (
        ".....c.c.c",
        "....ccccccc",
        "....cccccccc",
        "...hCCfffff",
        "...hffegfffkk",
        "...hhffefffkkk",
        "...hhhfffrKK",
        "..hhhhhfrrr",
        "..hhhhhhrrr",
        ".hhhhhhbrrC",
        "hhhhhhhbbrr",
        "hhHhHhhbbbC",
        ".hHhHh",
        "..H.H",
    )),
    "peck": ((17, 10), (
        "hhh",
        "hhhhh",
        "hhhhhhh",
        "hHhHhhhh",
        ".HhHhhhhh",
        "..H.Hhhhhh",
        "......hhhhh",
        ".......hhhhh",
        "........hhhh",
        "........hhhhc",
        "........Hhhccc",
        ".........hfccc",
        ".........fffcc",
        "........rfegfc",
        "........rffefc",
        "........rrffk",
        ".........r.kk",
        "...........kK",
    )),
    "peck_up": ((17, 8), (
        "hhh",
        "hhhhh",
        "hhhhhhh",
        "hHhhhhhhh.c.c",
        ".hHhHhhhhcccccc",
        "..HhHhhhhffffcc",
        "....hhhhfegffkk",
        ".....hhhffeffkkk",
        "......hhhfrrKK",
        ".......hhrrr",
        "........brr",
    )),
    "tucked": ((17, 9), (
        "......c.c.c",
        ".....cccccc",
        "....hCCffffk",
        "...hhfCCfffkk",
        "..hhhhfffrKK",
        ".hhhhhhhrrr",
        "hhhhhhhhrrr",
        "hHhHhhhhhhh",
        ".HhHhHhhhh",
        "..H.H.H",
    )),
}
# Breathing out asleep, his head sinks a little.
ROOSTER_HEADS["sunk"] = ((17, 10), ROOSTER_HEADS["tucked"][1])
# Asleep, he sits this much lower, his belly on the ground.
ROOSTER_SITTING_DROP = 6


def rooster_legs(letters, steps):
    """Lays the legs into `letters` in a step of CHICKEN_STEPS (the near foot then the far one):
    a shank from the thigh down to the toes, leaning to the foot, the near one with its spur."""
    for x, (ahead, lift), near in ((15, steps[2:], False), (20, steps[:2], True)):
        foot = ROOSTER_GROUND - lift
        shank = range(24, foot)
        for index, y in enumerate(shank):
            lean = round(ahead * index / max(1, len(shank) - 1))
            letters[y, x + lean] = "L" if near else "F"
            letters[y, x + lean + 1] = "l" if near else "F"
        if near:
            letters[foot - 2, x - 1 + ahead] = "p"
        letters[foot, x + ahead - 2 : x + ahead + 3] = "L" if near else "F"


def rooster_frame(head="up", steps=(0, 0, 0, 0), eye_shut=False):
    """One frame of the rooster facing right: his neck and head in ROOSTER_HEADS[head], his legs
    in `steps` (None: he sits on them), his eye open or shut."""
    width, height = ROOSTER_SIZE
    letters = np.full((height, width), ".")
    sitting = steps is None
    drop = ROOSTER_SITTING_DROP if sitting else 0
    tip = 1 if head.startswith("peck") else 0
    if not sitting:
        rooster_legs(letters, steps)
    place_piece(letters, ROOSTER_TAIL, drop - 1 if sitting else 0)
    place_piece(letters, ROOSTER_BODY, drop + tip)
    place_piece(letters, ROOSTER_HEADS[head], drop)
    if eye_shut:
        letters[letters == "g"] = "f"
        letters[letters == "e"] = "C"
    picture = blank(width, height)

    def mask(keys):
        return np.isin(letters, list(keys))

    level = forms.light_level(mask("bdwWhH"), 4, TOP_LIGHT)
    forms.shade_by_level(picture, mask("b"), ("rust_dark", "rust", "rust", "leaf_orange"), level)
    forms.shade_by_level(picture, mask("d"), ("russet_deep", "rust_dark", "rust_dark", "rust"), level)
    forms.shade_by_level(picture, mask("w"), ("russet_deep", "rust_dark", "rust", "rust"), level)
    forms.shade_by_level(picture, mask("W"), ("ink", "green_deep", "green_deep", "green_dark"), level)
    forms.shade_by_level(picture, mask("h"), ("ochre_dark", "ochre", "gold", "gold"), level + 0.2)
    tail_level = forms.light_level(mask("tsS"), 3, 0.3)
    forms.shade_by_level(picture, mask("t"), ("ink", "ink", "green_deep"), tail_level)
    forms.shade_by_level(picture, mask("s"), ("green_deep", "green_deep", "green_dark"), tail_level)
    forms.shade_by_level(picture, mask("S"), ("green_dark", "green_dark", "green"), tail_level)
    colours = {
        "H": "ochre_dark",
        "c": "red_light",
        "C": "ember",
        "f": "red_light",
        "r": "red_light",
        "e": "ink",
        "g": "cream",
        "k": "gold",
        "K": "ochre_dark",
        "L": "ochre",
        "l": "ochre_dark",
        "F": "ochre_dark",
        "p": "ochre_dark",
    }
    for key, colour in colours.items():
        forms.paint(picture, mask(key), colour)
    # The outline is the plumage's darkest colour, ink round the dark tail.
    tail = {"ink", "green_deep", "green_dark", "green"}
    return outline(picture, lambda colour: "ink" if colour in tail else "russet_deep")


def rooster_sheet():
    walk = [rooster_frame(steps=steps) for steps in CHICKEN_STEPS]
    frames = {
        "idle": [rooster_frame(), rooster_frame(eye_shut=True)],
        "walk": walk,
        "graze": [rooster_frame(head="peck"), rooster_frame(head="peck_up")],
        "sleep": [rooster_frame(head="tucked", steps=None, eye_shut=True), rooster_frame(head="sunk", steps=None, eye_shut=True)],
        "run": walk,
    }
    return [frames[action] for action in ACTIONS]


def sheets():
    """Every sheet of the poultry as (file name, cell size, rows of cells for palette.save)."""
    for look in CHICKEN_LOOKS:
        yield f"chicken_{look}", CHICKEN_SIZE, chicken_sheet(look)
    yield "chicken_rooster", ROOSTER_SIZE, rooster_sheet()
