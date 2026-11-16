"""The byre and the store of the interiors (assets/interior/<name>.png): the stall partition and the
hay pile of the stable, and the barrel, the sacks and the crate of the store.

The room, and the drawing all furniture shares (the grain of wood, the dithered shadow), are in
interior.py.
"""

import random

import forms
from canvas import blank, outline_edge, rect
from interior import OAK, T, dither, floor_shadow, grain


def stall_partition():
    """A stall partition 1x2 tiles: an oak post with two rails pegged to it that run on into the
    next stall, and a little straw at its foot."""
    canvas = blank(T, 2 * T)
    for top in (12, 32):
        rect(canvas, 0, top, 31, top + 6, "soil")
        rect(canvas, 0, top, 31, top + 1, "soil_mid")
        rect(canvas, 0, top, 31, top, "soil_light")
        rect(canvas, 0, top + 6, 31, top + 6, "soil_dark")
        grain(canvas, 0, top + 2, 31, top + 5, "soil_dark", 181 + top, count=3)
    rect(canvas, 11, 0, 20, 61, "soil_mid")
    rect(canvas, 11, 0, 13, 61, "soil_light")
    rect(canvas, 18, 0, 20, 61, "soil")
    rect(canvas, 11, 0, 20, 1, "sand")
    grain(canvas, 14, 2, 17, 58, "soil", 183, along_x=False, count=4)
    for top in (12, 32):
        rect(canvas, 15, top + 2, 16, top + 4, "soil_dark")
        canvas[top + 2][15] = "soil_light"
    rect(canvas, 6, 59, 25, 63, "soil_dark")
    rng = random.Random(184)
    for _ in range(14):
        x = rng.randrange(4, 28)
        rect(canvas, x, 60 + rng.randrange(2), x + 1, 63, rng.choice(("straw", "reed", "sand")))
    return outline_edge(canvas, "soil_dark", keep_bottom=True)


def hay_pile():
    """A pile of hay 2x1 tiles: a mound lit from the top left, shaggy along its top, in wisps
    of straw and gold, darker and trodden at its foot."""
    rng = random.Random(391)
    width, height = 2 * T, T
    mound = forms.grid(width, height)
    xs, ys = mound
    top = 4 + 13 * (1 - (1 - ((xs - 32) / 31) ** 2).clip(0) ** 0.6)
    mask = (ys >= top + rng.random()) & (xs > 0.5) & (xs < width - 0.5)
    for x in range(width):
        lift = rng.choice((0, 0, 1, 2))
        for y in range(height):
            if mask[y, x] and y > 0:
                mask[y - lift, x] = True
                break
    canvas = blank(width, height)
    forms.shade(canvas, mask, ("ochre_dark", "ochre", "straw", "gold"), radius=6, top_light=0.3)
    for _ in range(90):
        x, y = rng.randrange(2, width - 3), rng.randrange(4, height - 2)
        if mask[y, x]:
            colour = rng.choice(("gold", "straw", "ochre_dark", "sand"))
            dx = rng.choice((-1, 1))
            for step in range(rng.randrange(2, 5)):
                if 0 <= x + step * dx < width and 0 <= y + step < height and mask[y + step, x + step * dx]:
                    canvas[y + step][x + step * dx] = colour
    rect(canvas, 2, height - 3, width - 3, height - 1, "sand")
    dither(canvas, 2, height - 3, width - 3, height - 1, "mud")
    canvas = outline_edge(canvas, "mud_dark", keep_bottom=True)
    return canvas


def barrel():
    """A barrel, 1x1 tiles: oak staves bulging round, lit on the left, a lid, and two iron
    hoops with a glint."""
    canvas = blank(T, T)
    xs, ys = forms.grid(T, T)
    body = (abs(xs - 15.5) <= 11 - ((ys - 18) / 14) ** 2 * 3) & (ys > 6) & (ys < T)
    forms.shade(canvas, body, OAK, radius=7)
    for x in (9, 14, 19, 23):
        for y in range(8, T):
            if body[y, x]:
                canvas[y][x] = "soil" if canvas[y][x] != "soil" else "soil_dark"
    lid = forms.ellipse(T, T, 15.5, 7, 10, 4)
    forms.paint(canvas, lid, "soil")
    forms.paint(canvas, forms.shrunk(lid), "soil_mid")
    rect(canvas, 9, 5, 18, 5, "soil_light")
    rect(canvas, 8, 7, 22, 7, "soil")
    for y in (13, 25):
        for x in range(T):
            if body[y, x]:
                canvas[y][x] = "stone_dark"
                if body[y - 1, x]:
                    canvas[y - 1][x] = "stone" if x > 9 else "stone_light"
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 16, 22, 31, 31)
    return canvas


def sacks():
    """Two sacks of grain, 1x1 tiles, tied at the neck with cord, one of linen and one of
    coarse sacking, a few grains spilled."""
    canvas = blank(T, T)
    for cx, top, ramp, seed in ((10, 7, ("sand", "sand_light", "cream"), 191), (21, 13, ("mud", "sand", "straw"), 192)):
        width_half = 8 if cx == 10 else 7
        body = forms.ellipse(T, T, cx, (top + T) / 2 + 2, width_half, (T - top) / 2 - 1) & (forms.grid(T, T)[1] < T)
        body |= forms.box(T, T, cx - width_half + 1, (top + T) // 2 + 2, cx + width_half - 2, T - 1)
        forms.shade(canvas, body, ramp, radius=4)
        neck = forms.ellipse(T, T, cx - 0.5, top + 1, 2.5, 2.5)
        forms.shade(canvas, neck, ramp, radius=1)
        rect(canvas, cx - 3, top + 3, cx + 1, top + 3, "soil")
        rect(canvas, cx - 3, top + 4, cx + 1, top + 4, "soil_dark")
        rng = random.Random(seed)
        for _ in range(6):
            x, y = rng.randrange(cx - width_half + 2, cx + width_half - 2), rng.randrange(top + 8, T - 2)
            if body[y, x]:
                canvas[y][x] = ramp[0]
    for x, y in ((3, 30), (5, 31), (28, 31)):
        canvas[y][x] = "gold"
    canvas = outline_edge(canvas, "mud_dark", keep_bottom=True, ignoring=("gold",))
    floor_shadow(canvas, 8, 25, 31, 31)
    return canvas


def crate():
    """A wooden crate, 1x1 tiles: boards seen from a little above, braced with a cross, nailed
    at the corners."""
    canvas = blank(T, T)
    rect(canvas, 0, 6, 27, 9, "soil_light")
    rect(canvas, 0, 6, 27, 6, "sand_light")
    rect(canvas, 0, 10, 27, 31, "soil_mid")
    for y in (16, 23):
        rect(canvas, 0, y, 27, y, "soil")
    grain(canvas, 2, 11, 25, 30, "soil", 193, count=6)
    for i in range(18):
        for x0, x1 in ((3 + i, 4 + i), (24 - i, 23 - i)):
            canvas[11 + i][min(x0, x1)] = "soil_light"
            canvas[11 + i][max(x0, x1)] = "soil"
    rect(canvas, 0, 10, 2, 31, "soil_light")
    rect(canvas, 25, 10, 27, 31, "soil")
    rect(canvas, 0, 10, 27, 11, "soil_mid")
    rect(canvas, 0, 29, 27, 31, "soil")
    for x, y in ((1, 12), (26, 12), (1, 29), (26, 29)):
        canvas[y][x] = "stone_dark"
    canvas = [row[:28] + [None] * 4 for row in canvas]
    canvas = outline_edge(canvas, "soil_dark", keep_bottom=True)
    floor_shadow(canvas, 24, 6, 31, 31)
    floor_shadow(canvas, 28, 8, 31, 31)
    return canvas


def pieces():
    """The furniture of the byre and the store by name: its picture and its footprint in tiles."""
    return {
        "stall_partition": (stall_partition(), (1, 2)),
        "hay_pile": (hay_pile(), (2, 1)),
        "barrel": (barrel(), (1, 1)),
        "sacks": (sacks(), (1, 1)),
        "crate": (crate(), (1, 1)),
    }
