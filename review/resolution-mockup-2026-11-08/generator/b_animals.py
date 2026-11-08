"""Version B animals, facing right, at twice today's frame sizes or more for the small ones:
horse 88x72, cow 64x48, chicken 26x26, cat 34x26, mouse 22x14, frog 22x16.

Bodies are put together from rounded parts (barrel, chest, hindquarters, neck, head) and legs
with a joint (upper leg, knee or hock, cannon, fetlock, hoof), each shaded as a rounded form lit
from the top left; far legs a step darker. Then by hand: eyes with a glint, nostrils, ears,
mane and tail strands, coat texture (muscle lines, feather scallops, tabby stripes)."""

import math

import numpy as np

from b_core import ascii_pic, c, capsule, ellipse, fill, light_level, limb, new, outline, poly, shade, stamp


def px(pic, points, name):
    for x, y in points:
        if 0 <= x < pic.shape[1] and 0 <= y < pic.shape[0]:
            pic[y, x] = c(name)


def where(pic, mask, name):
    pic[mask & (pic >= 0)] = c(name)


def strands(pic, w, h, start, end, bend, width, ramp, count, seed):
    """A tail or mane: `count` strands from start to end, bowed by `bend`, dark with lit strands."""
    rng = np.random.RandomState(seed)
    for i in range(count):
        t0 = i / max(1, count - 1) - 0.5
        sx, sy = start[0] + t0 * width * 0.4, start[1]
        ex, ey = end[0] + t0 * width + rng.uniform(-1, 1), end[1] + rng.uniform(-2, 2)
        steps = 40
        prev = None
        for k in range(steps + 1):
            t = k / steps
            x = sx + (ex - sx) * t + bend * math.sin(t * math.pi)
            y = sy + (ey - sy) * t
            name = ramp[1] if (i % 3 == 1 and 0.15 < t < 0.8) else ramp[0]
            xi, yi = int(round(x)), int(round(y))
            if 0 <= xi < w and 0 <= yi < h:
                pic[yi, xi] = c(name)
                if i % 2 == 0 and xi + 1 < w:
                    pic[yi, xi + 1] = c(ramp[0])


# Horse -------------------------------------------------------------------------------------

HORSE_BODY = [
    (20, 22), (24, 19), (30, 18), (37, 20), (44, 23), (50, 22), (54, 19), (58, 15), (63, 10), (68, 5),
    (71, 3), (74, 4), (76, 7), (80, 12), (84, 18), (85, 22), (84, 25), (80, 26), (77, 24), (73, 21),
    (70, 20), (68, 24), (66, 30), (66, 37), (63, 43), (58, 45), (46, 47), (36, 45), (31, 45), (26, 46),
    (21, 45), (18, 40), (17, 33), (18, 27),
]


def horse():
    """A bay horse standing: red-brown coat, black mane, tail and lower legs, a white blaze."""
    w, h = 88, 76
    p = new(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    coat = ["soil_dark", "soil", "soil_mid", "soil_light"]
    far_coat = ["soil_dark", "soil_dark", "soil", "soil_mid"]
    # The far legs, behind the body, a step darker; black below the knee and hock.
    far_front = limb(w, h, [(57, 42), (57, 57), (57, 67), (58, 71)], [3.0, 2.0, 1.5, 1.8])
    far_hind = limb(w, h, [(32, 42), (28, 58), (30, 67), (30, 71)], [3.8, 2.0, 1.5, 1.8])
    for leg in (far_front, far_hind):
        shade(p, leg, far_coat, radius=2)
        shade(p, leg & (yy > 55), ["ink", "ink", "bog_dark"], radius=2)
    for hx in (58, 30):
        fill(p, ellipse(w, h, hx + 0.5, 73, 2.6, 1.8), "stone_dark")
    # The tail, falling from the dock in a long dark switch.
    strands(p, w, h, (19, 23), (13, 55), -4, 9, ["ink", "stone_dark"], 9, 3)
    body = poly(w, h, HORSE_BODY)
    shade(p, body, coat, radius=9, bias=0.02, vgrad=0.28)
    # Muscle lines one shade down: the hip, the stifle, the back of the shoulder blade, the
    # girth; a gleam on the croup, the shoulder and the cheek.
    for points in ([(27, 23), (31, 27), (32, 33), (30, 39)], [(32, 37), (34, 44)], [(56, 20), (59, 28), (58, 37)],
                   [(55, 38), (58, 44)], [(40, 30), (46, 31)]):
        line = limb(w, h, points, [0.55] * len(points))
        where(p, line & body & (p != c("soil_dark")), "soil")
    px(p, [(24, 21), (25, 21), (26, 20), (27, 20), (28, 20), (25, 22), (29, 20)], "sand")
    px(p, [(61, 26), (62, 25), (61, 27), (62, 30), (62, 31)], "sand")
    px(p, [(76, 14), (77, 15), (77, 16)], "soil_light")
    # Near legs: forearm, knee, cannon, fetlock, hoof; gaskin, the hock pointing back.
    near_front = limb(w, h, [(62, 40), (62, 57), (62, 67), (63, 71)], [3.6, 2.2, 1.6, 1.9])
    near_hind = limb(w, h, [(27, 40), (30, 46), (22, 58), (24, 67), (24, 71)], [5.0, 3.6, 2.2, 1.6, 1.9])
    for leg in (near_hind, near_front):
        shade(p, leg & ~body | leg & (yy > 46), coat, radius=3, vgrad=0.2)
        shade(p, leg & (yy > 55), ["ink", "ink", "stone_dark"], radius=2)
    # The joints as lit knobs on the black: knee and hock, fetlock.
    px(p, [(61, 56), (61, 57), (21, 57), (21, 58), (61, 66), (23, 66)], "stone_dark")
    for hx in (63, 24):
        hoof = ellipse(w, h, hx + 0.5, 73, 2.9, 1.9)
        shade(p, hoof, ["mud_dark", "stone_dark", "stone"], radius=1)
    # Mane along the crest, strands falling on the near side; the forelock.
    crest = poly(w, h, [(52, 20), (57, 15), (62, 10), (67, 5), (71, 3), (71, 7), (67, 11), (63, 16), (59, 21),
                        (56, 25)])
    shade(p, crest, ["ink", "ink", "stone_dark"], radius=2)
    for x, y in [(57, 21), (60, 17), (63, 13), (66, 10)]:
        px(p, [(x, y + 1), (x, y + 2), (x + 1, y + 3)], "ink")
    px(p, [(73, 5), (74, 6), (75, 7), (74, 7), (73, 6)], "ink")
    # Ears.
    for ear_x, tone in ((69, "soil"), (71, "soil_mid")):
        ear = poly(w, h, [(ear_x, 5), (ear_x + 1, -1), (ear_x + 3, 4)])
        fill(p, ear, tone)
    px(p, [(72, 1), (72, 2)], "soil_dark")
    # The blaze; the eye with a glint; the nostril, the mouth, the round of the jowl.
    blaze = poly(w, h, [(76, 7), (78, 8), (84, 18), (84, 22), (82, 20)])
    fill(p, blaze & body, "lime")
    px(p, [(77, 8), (78, 10), (79, 11)], "snow_light")
    px(p, [(74, 10), (75, 10), (74, 11), (75, 11)], "ink")
    px(p, [(74, 10)], "cream")
    px(p, [(73, 9), (74, 9), (76, 9)], "soil_dark")
    px(p, [(83, 21), (83, 22), (82, 22)], "ink")
    px(p, [(80, 25), (81, 25), (82, 25), (83, 24)], "soil_dark")
    jowl = limb(w, h, [(71, 14), (72, 18), (75, 21), (78, 22)], [0.55] * 4)
    where(p, jowl & body, "soil")
    p = outline(p, "soil_dark", bottom="ink")
    return p


# Cow ---------------------------------------------------------------------------------------

COW_HEAD_KEYS = {"B": "bog_dark", "D": "stone_dark", "S": "stone", "W": "lime", "w": "stone_light",
                 "L": "snow_light", "P": "petal", "p": "skin_shade", "e": "ink", "g": "stone_light",
                 "r": "rust_dark"}
COW_HEAD = (
    "...BBDW........",
    "..BDDDWW.......",
    ".BDDDDWLW......",
    "BDDeeDWLLW.....",
    "BDDegDWWLLW....",
    "wBDDDWWWWLLW...",
    "wwBDWWWWWWLLW..",
    ".wwWWWWWWWWLW..",
    "..wwWWWWWWWLLW.",
    "...wwWWWWWWWLW.",
    "....wwWWWWWPPP.",
    ".....wwWWPPPPPP",
    "......wwpPPPrPP",
    ".......wpPPPPPp",
    "........ppppp..",
)


def cow():
    """A black and white marsh cow: a long straight back, the hip and pin bones showing, a
    deep belly, a pink udder, short legs with cloven hooves, small horns, a blaze down the face."""
    w, h = 64, 48
    p = new(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    black = ["bog_dark", "stone_dark", "stone"]
    white = ["stone_light", "lime", "snow_light"]
    far_white = ["stone", "stone_light", "lime"]
    far_front = limb(w, h, [(44, 30), (45, 38), (45, 44)], [3.0, 1.9, 1.9])
    far_hind = limb(w, h, [(17, 30), (15, 38), (16, 44)], [3.6, 1.9, 1.9])
    for leg in (far_front, far_hind):
        shade(p, leg, far_white, radius=2)
    for hx in (45, 16):
        fill(p, ellipse(w, h, hx + 0.5, 45.5, 2.5, 1.6), "ink")
    # Tail: a thin rope from the tail head down the back of the thigh, a dark tuft.
    fill(p, limb(w, h, [(9, 13), (7, 22), (7, 33)], [1.2, 0.9, 0.9]), "stone_dark")
    fill(p, ellipse(w, h, 7, 35, 1.8, 3), "bog_dark")
    # Body: a boxy barrel, the hips standing out at the back, the neck low and thick.
    barrel = poly(w, h, [(10, 12), (14, 10), (40, 11), (47, 12), (51, 18), (50, 30), (44, 34), (20, 35), (12, 31), (9, 22)])
    belly = ellipse(w, h, 30, 27, 17, 9)
    hip = ellipse(w, h, 14, 15, 6, 5)
    neck = poly(w, h, [(44, 12), (51, 12), (55, 18), (55, 27), (50, 33), (45, 24)])
    whole = barrel | belly | hip | neck
    shade(p, whole, white, radius=5)
    patches = (ellipse(w, h, 22, 18, 9, 7) | ellipse(w, h, 38, 15, 7, 5.5) | ellipse(w, h, 13, 25, 4.5, 6)
               | ellipse(w, h, 50, 19, 5.5, 8) | ellipse(w, h, 31, 24, 4, 3))
    patches &= whole & (yy < 29)
    level = light_level(whole, 5)
    for i, t in enumerate((-9, 0.45, 0.8)):
        p[patches & (level > t)] = c(black[i])
    # Hip and pin bones and the last ribs show through the hide.
    px(p, [(15, 11), (16, 11), (17, 12), (11, 13)], "stone")
    px(p, [(26, 27), (28, 28), (30, 28), (33, 28)], "stone_light")
    # The udder, under the belly at the back.
    udder = ellipse(w, h, 18, 35, 4.5, 3.4)
    shade(p, udder, ["skin_shade", "petal", "petal"], radius=2)
    px(p, [(16, 38), (19, 38)], "skin_shade")
    # Near legs: short and straight, a knee, the hock bent back, cloven hooves.
    near_front = limb(w, h, [(47, 30), (48, 38), (48, 44)], [3.4, 2.1, 2.1])
    near_hind = limb(w, h, [(21, 28), (23, 33), (18, 39), (19, 44)], [4.6, 3.4, 2.1, 2.1])
    for leg in (near_hind, near_front):
        shade(p, leg, white, radius=2)
    for hx in (48, 19):
        hoof = ellipse(w, h, hx + 0.5, 45.5, 2.7, 1.8)
        shade(p, hoof, ["ink", "bog_dark", "stone_dark"], radius=1)
        px(p, [(hx, 46), (hx, 45)], "ink")
    px(p, [(46, 37), (17, 38)], "stone")
    # The head, hand drawn: a white face, black round the eye and the poll, a pink wet muzzle.
    stamp(p, ascii_pic(COW_HEAD_KEYS, COW_HEAD), 48, 13)
    # The ear out to the side behind the eye, the horn curving up and forward.
    ear = poly(w, h, [(51, 15), (45, 14), (46, 17), (51, 18)])
    shade(p, ear, ["bog_dark", "stone_dark"], radius=1)
    px(p, [(47, 15), (48, 15), (49, 16)], "petal")
    fill(p, limb(w, h, [(52, 14), (51, 11), (53, 9)], [1.2, 1.0, 0.7]), "cream")
    px(p, [(53, 9)], "stone")
    p = outline(p, "ink")
    return p

# Chicken -----------------------------------------------------------------------------------

def chicken():
    """A brown hen: plump, tail up, scalloped feathers, a red comb and wattle, yellow legs."""
    w, h = 26, 26
    p = new(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    ramp = ["umber", "ochre_dark", "ochre", "leaf_orange"]
    # Legs and toes, ochre, behind the body.
    for lx in (11, 14):
        px(p, [(lx, y) for y in range(19, 24)], "ochre_dark")
        px(p, [(lx + 1, y) for y in range(20, 23)], "ochre")
        px(p, [(lx - 2, 24), (lx - 1, 24), (lx, 24), (lx + 1, 24), (lx + 2, 24)], "ochre")
        px(p, [(lx - 1, 23)], "ochre")
    # Tail feathers, raised at the back.
    tail = poly(w, h, [(3, 5), (6, 4), (9, 10), (9, 16), (4, 15), (2, 9)])
    shade(p, tail, ["soil_dark", "umber", "ochre_dark"], radius=2)
    px(p, [(4, 7), (5, 9), (5, 11), (6, 13)], "soil_dark")
    # Body: a plump egg, breast forward.
    body = ellipse(w, h, 13, 14, 8, 6.5) | ellipse(w, h, 16, 12, 5.5, 5)
    shade(p, body, ramp, radius=4)
    # Wing folded on the side, its feathers in rows of scallops.
    wing = ellipse(w, h, 12, 14, 5.2, 3.6)
    shade(p, wing, ["soil_dark", "umber", "ochre_dark"], radius=2)
    for y in (13, 15, 17):
        for x in range(8 + (y // 2) % 2, 17, 2):
            if wing[y, x]:
                p[y, x] = c("ochre")
    px(p, [(x, 17) for x in range(9, 16, 2)], "soil_dark")
    # Head and neck with a darker hackle.
    head = ellipse(w, h, 19, 6.5, 3.6, 3.6) | ellipse(w, h, 18, 9, 3, 3)
    shade(p, head, ramp, radius=2)
    px(p, [(17, 10), (16, 9), (18, 11)], "ochre_dark")
    # Comb, beak, wattle, eye.
    px(p, [(18, 2), (19, 2), (20, 2), (18, 3), (19, 3), (20, 3), (21, 3), (17, 3)], "red_light")
    px(p, [(19, 1), (21, 2)], "red_light")
    px(p, [(17, 2)], "rust")
    px(p, [(23, 6), (24, 6), (23, 7)], "gold")
    px(p, [(24, 7)], "ochre_dark")
    px(p, [(22, 8), (22, 9), (21, 9)], "red_light")
    px(p, [(20, 5), (20, 6)], "ink")
    px(p, [(21, 5)], "cream")
    p = outline(p, "soil_dark")
    return p


# Cat ---------------------------------------------------------------------------------------

def cat():
    """A grey-brown tabby walking: dark stripes over the back and down the legs, a ringed tail
    held up in a curve, pointed ears pink inside, olive-green eyes."""
    w, h = 34, 26
    p = new(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    ramp = ["mud", "sand", "sand_light"]
    far = ["mud_dark", "mud", "sand"]
    # Far legs, mid-stride.
    shade(p, limb(w, h, [(24, 15), (26, 20), (27, 24)], [2.2, 1.4, 1.5]), far, radius=1)
    shade(p, limb(w, h, [(10, 15), (7, 20), (8, 24)], [2.6, 1.4, 1.5]), far, radius=1)
    # Tail: up from the rump and curving forward at the tip, ringed.
    tail_pts = [(6, 13), (3, 9), (3, 4), (5, 1), (8, 1)]
    tail = limb(w, h, tail_pts, [1.8, 1.7, 1.6, 1.5, 1.3])
    shade(p, tail, ramp, radius=1)
    for y in (3, 6, 9):
        where(p, tail & (yy == y), "mud_dark")
    px(p, [(8, 1), (7, 1)], "mud_dark")
    # Body, long and low, chest forward; the head turned a little to the viewer.
    body = ellipse(w, h, 16, 14, 10, 4.6)
    shade(p, body, ramp, radius=3)
    head = ellipse(w, h, 27, 10, 4.6, 4.2)
    shade(p, head, ramp, radius=2)
    # Ears.
    for ex in (24, 28):
        ear = poly(w, h, [(ex - 1, 7), (ex + 1, 2), (ex + 3, 7)])
        shade(p, ear, ramp, radius=1)
        px(p, [(ex + 1, 5), (ex + 1, 6)], "petal")
    # Tabby stripes across the back and flank, bars on the forehead.
    for sx in range(9, 24, 3):
        px(p, [(sx, 10), (sx, 11), (sx + 1, 12), (sx + 1, 13)], "mud_dark")
    px(p, [(26, 7), (27, 7), (28, 7), (27, 8)], "mud_dark")
    # Eyes, muzzle, nose, whiskers.
    px(p, [(26, 10), (29, 10)], "olive")
    px(p, [(26, 11), (29, 11)], "ink")
    px(p, [(30, 12), (30, 13), (31, 12)], "lime")
    px(p, [(31, 11)], "petal")
    px(p, [(32, 13), (33, 12), (32, 14)], "stone_light")
    # Pale chest and belly.
    px(p, [(x, 18) for x in range(13, 22)], "sand_light")
    # Near legs.
    shade(p, limb(w, h, [(22, 15), (21, 20), (21, 24)], [2.4, 1.5, 1.6]), ramp, radius=1)
    shade(p, limb(w, h, [(12, 15), (14, 19), (12, 24)], [3.0, 1.6, 1.6]), ramp, radius=1)
    px(p, [(21, 19), (13, 19), (21, 21), (12, 21)], "mud_dark")
    px(p, [(20, 24), (21, 24), (22, 24), (11, 24), (12, 24), (13, 24)], "sand_light")
    p = outline(p, "mud_dark", bottom="ink")
    return p


# Mouse -------------------------------------------------------------------------------------

def mouse():
    """A house mouse, drawn larger than life: grey-brown, a pale belly, a big round ear pink
    inside, a beady eye with a glint, whiskers, a long bare tail."""
    w, h = 24, 14
    p = new(w, h)
    # Tail, a long thin curve on the ground behind.
    for x, y in [(0, 8), (1, 9), (2, 10), (3, 11), (4, 11), (5, 12), (6, 12), (7, 12), (8, 11)]:
        px(p, [(x, y)], "skin_shade")
    body = ellipse(w, h, 13, 9, 6.5, 3.8) | ellipse(w, h, 18, 8, 3.8, 3)
    shade(p, body, ["mud_dark", "mud", "bare_light"], radius=3)
    # Pale belly line.
    px(p, [(x, 12) for x in range(10, 17)], "sand_light")
    # Ear: round, pink inside.
    ear = ellipse(w, h, 16, 4.5, 2.3, 2.3)
    shade(p, ear, ["mud", "bare_light"], radius=1)
    px(p, [(16, 4), (16, 5), (15, 5)], "petal")
    # Eye, nose, whiskers.
    px(p, [(19, 7), (20, 7)], "ink")
    px(p, [(19, 7)], "cream")
    px(p, [(23, 8)], "petal")
    # Feet.
    px(p, [(11, 13), (12, 13), (17, 12), (18, 12)], "petal")
    p = outline(p, "mud_dark")
    px(p, [(23, 6), (24, 7)], "stone_light")
    return p


# Frog --------------------------------------------------------------------------------------

def frog():
    """A common frog sitting: olive with dark blotches, a pale throat, the eye high on the head
    with a gold ring, the hind leg folded with dark bars on the thigh."""
    w, h = 22, 16
    p = new(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    ramp = ["olive", "dry", "dry_light"]
    body = poly(w, h, [(2, 13), (4, 8), (9, 5), (15, 4), (19, 6), (21, 10), (19, 12), (14, 13)])
    shade(p, body, ramp, radius=3)
    # The folded hind leg: thigh and shin along the side, barred.
    thigh = ellipse(w, h, 6.5, 11, 4.5, 2.8)
    shade(p, thigh, ramp, radius=2)
    for x in (4, 7, 9):
        px(p, [(x, 10), (x, 11)], "green_dark")
    foot = poly(w, h, [(2, 13), (9, 13), (11, 15), (1, 15)])
    shade(p, foot, ramp, radius=1)
    # Front leg.
    arm = limb(w, h, [(15, 10), (16, 13), (17, 15)], [1.6, 1.2, 1.2])
    shade(p, arm, ramp, radius=1)
    px(p, [(16, 15), (18, 15)], "dry_light")
    # Blotches on the back; the dark mask behind the eye; pale throat.
    px(p, [(9, 7), (10, 7), (12, 6), (6, 9), (11, 9), (12, 9)], "green_dark")
    px(p, [(16, 8), (17, 8), (17, 9)], "soil")
    px(p, [(19, 10), (20, 10), (18, 11)], "sand_light")
    # The eye, high on the head.
    eye = ellipse(w, h, 16.5, 5, 2, 2)
    fill(p, eye, "ochre")
    px(p, [(16, 5), (17, 5)], "ink")
    px(p, [(16, 4)], "cream")
    px(p, [(20, 9)], "ink")
    p = outline(p, "green_deep")
    return p
