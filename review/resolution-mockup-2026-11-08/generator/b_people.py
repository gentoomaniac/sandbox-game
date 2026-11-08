"""Version B people, 32x64 cells (twice the 16x32 of today), feet on the bottom row.

Built from shapes shaded by a light from the top left, outlined in ink, then the details put
in by hand: eyes with a glint and brows, a nose shadow, cheeks and a mouth, buttons, the
garter below the knee, clogs with a lit top and a dark sole."""

import numpy as np

from b_core import c, capsule, ellipse, fill, new, outline, poly, shade

W, H = 32, 64


def px(pic, points, name):
    for x, y in points:
        if 0 <= x < pic.shape[1] and 0 <= y < pic.shape[0]:
            pic[y, x] = c(name)


def hline(pic, x0, x1, y, name):
    pic[y, x0:x1 + 1] = c(name)


def rect(w, h, x0, y0, x1, y1):
    m = np.zeros((h, w), bool)
    m[y0:y1 + 1, x0:x1 + 1] = True
    return m


def round_rect(w, h, x0, y0, x1, y1, r=1):
    m = rect(w, h, x0, y0, x1, y1)
    for (x, y) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        m[y, x] = False
    if r > 1:
        for (x, y) in ((x0 + 1, y0), (x0, y0 + 1), (x1 - 1, y0), (x1, y0 + 1)):
            m[y, x] = False
    return m


def player():
    """The player facing down: straw hat, brown hair, a white linen shirt under a red waistcoat
    with a row of tin buttons, brown knee breeches, white stockings and pale clogs."""
    p = new(W, H)
    # Clogs: wide, pale wood, lit on top, the sole dark; the toes turn up a little.
    for x0 in (9, 17):
        clog = round_rect(W, H, x0, 57, x0 + 6, 62, 2)
        shade(p, clog, ["mud", "sand", "sand_light"], radius=2)
        hline(p, x0 + 1, x0 + 5, 62, "mud")
        px(p, [(x0 + 1, 58), (x0 + 2, 58)], "cream")
    # Stockings, white with a shaded inner side, and the knee breeches over them.
    for x0 in (10, 17):
        leg = rect(W, H, x0, 49, x0 + 4, 57)
        shade(p, leg, ["sand_light", "lime", "lime"], radius=2)
    px(p, [(15, 50), (15, 51), (16, 50)], "sand")
    breeches = poly(W, H, [(9, 42), (23, 42), (23, 50), (17, 50), (16, 47), (15, 50), (9, 50)])
    shade(p, breeches, ["soil", "soil_mid", "soil_light"], radius=3)
    hline(p, 10, 14, 50, "soil")
    hline(p, 17, 22, 50, "soil")
    px(p, [(16, 47), (16, 48), (15, 49)], "soil_dark")
    # Knee buttons.
    px(p, [(13, 49), (20, 49)], "ochre")
    # The shirt: body and full sleeves, gathered at the wrist.
    shirt = round_rect(W, H, 9, 26, 22, 43, 2)
    shade(p, shirt, ["sand_light", "lime", "lime"], radius=3)
    for side, (x0, x1) in (("l", (5, 9)), ("r", (22, 26))):
        sleeve = capsule(W, H, (x0 + x1) / 2 + (0.5 if side == "l" else -0.5), 29, (x0 + x1) / 2 + (-0.5 if side == "l" else 0.5), 39, 2.9, 2.5)
        shade(p, sleeve, ["sand_light", "lime", "lime"], radius=2)
    # Hands.
    for hx in (7, 24):
        hand = ellipse(W, H, hx + 0.5, 42, 2.4, 2.2)
        shade(p, hand, ["skin_shade", "skin"], radius=2)
    # The waistcoat: open at the neck in a V, longer at the front, buttons down the middle.
    vest = poly(W, H, [(10, 27), (14, 27), (16, 33), (18, 27), (22, 27), (22, 42), (17, 44), (16, 43), (15, 44), (10, 42)])
    shade(p, vest, ["rust_dark", "rust", "red_light"], radius=3)
    for y in range(34, 43, 3):
        px(p, [(16, y)], "stone_light")
        px(p, [(16, y + 1)], "stone")
    px(p, [(15, y) for y in range(34, 44)], "rust_dark")
    # Pockets.
    hline(p, 11, 13, 39, "rust_dark")
    hline(p, 19, 21, 39, "rust_dark")
    # Neck and collar.
    neck = rect(W, H, 14, 24, 17, 27)
    fill(p, neck, "skin_shade")
    px(p, [(14, 26), (15, 27), (17, 26), (16, 27)], "lime")
    px(p, [(13, 26), (18, 26), (14, 27), (17, 27)], "lime")
    # Head: the face, lit on the left, shaded under the brim and on the right.
    face = ellipse(W, H, 16, 17.5, 7.6, 7.8)
    shade(p, face, ["skin_shade", "skin", "skin"], radius=3)
    # Ears.
    px(p, [(8, 18), (8, 19)], "skin")
    px(p, [(24, 18), (24, 19)], "skin_shade")
    # Hair at the sides and the nape, below the brim.
    hair = (ellipse(W, H, 16, 15.5, 8.6, 8) & ~ellipse(W, H, 16, 19, 7.2, 7.4)) & rect(W, H, 0, 10, 31, 22)
    shade(p, hair, ["soil_dark", "soil", "soil_mid"], radius=2)
    # The brim's shadow on the forehead.
    hline(p, 10, 22, 12, "skin_shade")
    hline(p, 12, 20, 13, "skin_shade")
    # Eyes: dark with a glint, brows above, cheeks, a nose shadow on the right, a mouth.
    for ex in (12, 19):
        px(p, [(ex, 17), (ex + 1, 17), (ex, 18), (ex + 1, 18)], "ink")
        px(p, [(ex, 17)], "lime")
        hline(p, ex - 1, ex + 1, 15, "soil")
    px(p, [(10, 20), (11, 20), (21, 20), (22, 20)], "petal")
    px(p, [(17, 19), (17, 20)], "skin_shade")
    px(p, [(15, 22), (16, 22), (17, 22)], "rust")
    px(p, [(16, 23)], "skin_shade")
    # The straw hat: a wide brim seen a little from above, a round crown, a dark band.
    brim = ellipse(W, H, 16, 10.5, 13.2, 3.6)
    crown = round_rect(W, H, 10, 2, 22, 9, 2)
    shade(p, brim, ["reed", "straw", "sand_light"], radius=2)
    shade(p, crown, ["reed", "straw", "sand_light"], radius=3)
    hline(p, 10, 22, 8, "soil")
    hline(p, 10, 22, 9, "umber")
    # Plaited straw: a few darker strokes round the crown and brim.
    px(p, [(12, 4), (15, 5), (18, 4), (20, 6), (13, 6)], "reed")
    px(p, [(6, 11), (9, 12), (23, 12), (26, 11), (4, 10)], "reed")
    p = outline(p, "ink")
    # Between the legs and between the clogs, ink.
    px(p, [(15, 51), (15, 52), (15, 53), (15, 54), (15, 55), (15, 56), (16, 51), (16, 52), (16, 53), (16, 54),
           (16, 55), (16, 56), (16, 57), (16, 58), (16, 59), (16, 60), (16, 61), (16, 62)], "ink")
    # The arms are separated from the body by a shade line.
    px(p, [(9, y) for y in range(30, 40)], "sand")
    px(p, [(22, y) for y in range(30, 40)], "sand")
    return p


def villager():
    """A villager woman facing right: a white coif, fair hair in a bun under it, a laced blue
    bodice over the linen chemise, a madder-red skirt to the ankle, a white apron, clogs."""
    p = new(W, H)
    # Clogs, the far one a step darker.
    far = round_rect(W, H, 15, 58, 21, 62, 2)
    shade(p, far, ["mud", "sand", "sand"], radius=2)
    near = round_rect(W, H, 11, 58, 18, 62, 2)
    shade(p, near, ["mud", "sand", "sand_light"], radius=2)
    hline(p, 12, 17, 62, "mud")
    px(p, [(17, 59), (18, 60)], "cream")
    # The skirt: full, falling in folds, longer at the back.
    skirt = poly(W, H, [(11, 40), (21, 40), (23, 52), (24, 58), (20, 59), (8, 59), (8, 52)])
    shade(p, skirt, ["rust_dark", "rust", "red_light"], radius=4)
    for fx, top in ((12, 46), (16, 44), (20, 47)):
        px(p, [(fx, y) for y in range(top, 59)], "rust_dark")
        px(p, [(fx - 1, y) for y in range(top + 2, 59, 1)], "rust") if fx > 12 else None
    hline(p, 9, 23, 58, "rust_dark")
    # The apron, in front (to the right), with its own folds.
    apron = poly(W, H, [(17, 39), (21, 39), (24, 50), (25, 57), (19, 57), (17, 48)])
    shade(p, apron, ["sand_light", "lime", "snow_light"], radius=2)
    px(p, [(21, y) for y in range(44, 57)], "sand_light")
    hline(p, 19, 25, 57, "sand_light")
    # The bodice, laced at the front, over the white chemise sleeves.
    bodice = round_rect(W, H, 11, 27, 21, 40, 1)
    shade(p, bodice, ["water_deep", "water", "water_light"], radius=3)
    for y in range(29, 39, 2):
        px(p, [(19, y), (20, y + 1)], "lime")
        px(p, [(20, y), (19, y + 1)], "water_deep")
    hline(p, 11, 21, 40, "sand_light")
    hline(p, 13, 21, 41, "sand_light")
    # The apron band round the waist.
    hline(p, 11, 21, 39, "snow_light")
    # The arm: a white sleeve to the elbow, the forearm bent forward, the hand in front.
    sleeve = capsule(W, H, 14, 30, 14.5, 37, 3.2, 2.8)
    shade(p, sleeve, ["sand", "sand_light", "lime"], radius=2)
    forearm = capsule(W, H, 15, 38, 20, 40, 1.9, 1.7)
    shade(p, forearm, ["skin_shade", "skin"], radius=2)
    hand = ellipse(W, H, 21.5, 40, 2.1, 2.0)
    shade(p, hand, ["skin_shade", "skin"], radius=2)
    # Neck.
    fill(p, rect(W, H, 15, 24, 18, 27), "skin_shade")
    px(p, [(17, 25), (18, 25), (18, 26)], "skin")
    # The head in profile: face to the right with a small nose, chin, and the coif behind.
    face = ellipse(W, H, 17, 17, 6.6, 7.0)
    shade(p, face, ["skin_shade", "skin", "skin"], radius=3, bias=0.25)
    px(p, [(24, 18)], "skin")  # nose
    px(p, [(23, 19)], "skin_shade")
    # Eye: a white, a dark iris looking forward, a brow; a cheek; the mouth.
    px(p, [(20, 16), (21, 16), (21, 17), (20, 17)], "ink")
    px(p, [(20, 16)], "lime")
    px(p, [(20, 14), (21, 14), (22, 14)], "straw")
    px(p, [(19, 19), (20, 19)], "petal")
    px(p, [(22, 21), (21, 21)], "rust")
    # The coif: white linen over the head and down the neck at the back, a frill at the front,
    # and the bun pushing it out behind.
    coif = (ellipse(W, H, 15, 14, 8.2, 7.8) | ellipse(W, H, 9.5, 17, 3.6, 4.2) | rect(W, H, 9, 15, 15, 25)) \
        & ~ellipse(W, H, 21, 18.5, 6.2, 7.2)
    shade(p, coif, ["sand_light", "lime", "snow_light"], radius=3)
    # Its frill and the seam where the crown piece meets the band.
    px(p, [(x, 8 + abs(x - 17) // 4) for x in range(13, 23)], "snow_light")
    px(p, [(15, y) for y in range(10, 22)], "sand_light")
    px(p, [(16, 9), (16, 22)], "sand_light")
    # A curl of fair hair at the temple, under the coif's edge.
    px(p, [(16, 12), (17, 12), (17, 13), (16, 13)], "straw")
    px(p, [(16, 14)], "ochre")
    p = outline(p, "ink")
    return p
