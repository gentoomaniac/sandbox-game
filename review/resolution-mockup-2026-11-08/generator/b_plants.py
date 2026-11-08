"""Version B plants at 32 px per tile: the pollard willow, reeds with bulrush heads, tall grass,
ripe wheat and cabbage. Each returns a picture with its foot at the bottom centre."""

import math
import random

import numpy as np

from b_core import c, ellipse, light_level, new, shade


def setp(p, x, y, name):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < p.shape[1] and 0 <= y < p.shape[0]:
        p[y, x] = c(name)


def line(p, x0, y0, x1, y1, name, bend=0.0):
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 1.5) + 1
    for k in range(steps + 1):
        t = k / steps
        setp(p, x0 + (x1 - x0) * t + bend * math.sin(t * math.pi), y0 + (y1 - y0) * t, name)


def blade(p, x0, y0, height, lean, tones, width=2, droop=0.0):
    """A leaf or grass blade from its foot (x0, y0): `width` px wide low down, one px at the
    tip, curving by `lean` and drooping at the end; its left edge lit, its right in shade."""
    steps = int(height * 1.5) + 1
    dark, mid, light = tones
    for k in range(steps):
        t = k / steps
        x = x0 + lean * t * t
        y = y0 - height * t + droop * t ** 4
        wide = width if t < 0.55 else 1
        if wide >= 2:
            setp(p, x, y, light)
            setp(p, x + 1, y, mid)
            if width >= 3 and t < 0.3:
                setp(p, x + 2, y, dark)
        else:
            setp(p, x, y, mid if t < 0.85 else light)


# Pollard willow ----------------------------------------------------------------------------

BARK = ("soil_dark", "mud_dark", "bare", "bare_light")
KNOBS = ("mud_dark", "mud", "sand")
LEAVES = ("green_dark", "olive", "dry", "dry_light")


def willow():
    """The Kopfweide: a short furrowed trunk, a knobbly head cut back again and again, and a
    crown of straight rods springing from it, dense with narrow grey-green leaves, some showing
    their silver side."""
    rng = random.Random(321)
    w, h = 112, 150
    p = new(w, h)
    cx, bottom = 56, h - 1
    p[ellipse(w, h, cx, bottom - 1.5, 22, 3.5)] = c("green_deep")
    head_y = bottom - 38
    trunk = np.zeros((h, w), bool)
    for y in range(head_y, bottom):
        t = (y - head_y) / (bottom - head_y)
        half = 10 + 3 * (1 - t) ** 3 + 3 * t ** 6
        trunk[y, int(cx - half):int(cx + half) + 1] = True
    shade(p, trunk, list(BARK), radius=6, bias=0.05)
    for fx in range(cx - 8, cx + 9, 4):
        x = fx + rng.uniform(-1, 1)
        for y in range(head_y + rng.randint(2, 6), bottom - rng.randint(1, 4)):
            x += rng.choice((-0.4, 0, 0, 0.4))
            setp(p, x, y, "soil_dark" if fx > cx else "mud_dark")
            if fx < cx and rng.random() < 0.5:
                setp(p, x - 1, y, "bare_light")
    p[ellipse(w, h, cx + 3, head_y + 17, 2.5, 4)] = c("ink")
    # The rods, fanning up from the head.
    rods = []
    for i in range(70):
        angle = -0.9 + 1.8 * i / 69 + rng.uniform(-0.05, 0.05)
        length = rng.uniform(52, 76) * (1 - 0.3 * abs(angle))
        sx = cx + rng.uniform(-12, 12)
        sy = head_y - rng.uniform(0, 4)
        rods.append((sx, sy, sx + math.sin(angle) * length, sy - math.cos(angle) * length))
    # The leaf mass: soft bunches along the upper part of every rod, as one loose rounded crown
    # lit from the top left, with gaps where the sky shows through.
    mass = np.zeros((h, w), bool)
    for sx, sy, ex, ey in rods:
        for t in (0.45, 0.6, 0.75, 0.88):
            if rng.random() < 0.8:
                r = rng.uniform(2.5, 4.5)
                mass |= ellipse(w, h, sx + (ex - sx) * t, sy + (ey - sy) * t, r, r * 0.8)
    holes = np.zeros((h, w), bool)
    for _ in range(26):
        holes |= ellipse(w, h, rng.uniform(15, w - 15), rng.uniform(10, head_y - 10), rng.uniform(1.5, 3), rng.uniform(1.5, 3))
    mass &= ~holes
    level = light_level(mass, 8, vgrad=0.25)
    for i, t in enumerate((-9, 0.2, 0.55, 0.85)):
        p[mass & (level > t)] = c(LEAVES[i])
    for sx, sy, ex, ey in rods:
        line(p, sx, sy, sx + (ex - sx) * 0.5, sy + (ey - sy) * 0.5, "reed" if ex < cx else "umber")
    # Leaves over the mass: narrow strokes slanting off the rods, lit or shaded by where they
    # sit in the crown, and a few silver undersides.
    for sx, sy, ex, ey in rods:
        n = int(math.hypot(ex - sx, ey - sy) / 1.6)
        for k in range(n // 3, n + 2):
            t = k / n
            x, y = sx + (ex - sx) * t, sy + (ey - sy) * t
            side = 1 if k % 2 else -1
            lv = level[min(h - 1, int(y)), min(w - 1, int(x))]
            lv = (lv if lv > -9 else 0) + rng.uniform(-0.35, 0.35)
            name = LEAVES[3 if lv > 0.9 else 2 if lv > 0.5 else 1 if lv > 0.1 else 0]
            if rng.random() < 0.03:
                name = "frost"
            for j in range(3):
                setp(p, x + side * (j * 0.9 + 0.6), y + j * 0.6 - 0.3, name)
    # The head: knobs where the rods were cut, each lit on its upper left.
    knobs = sorted((head_y + rng.uniform(-6, 3), cx + rng.uniform(-13, 13), rng.uniform(3.5, 5.5)) for _ in range(12))
    for ky, kx, r in knobs:
        shade(p, ellipse(w, h, kx, ky, r, r * 0.85), list(KNOBS), radius=2)
        setp(p, kx - r * 0.35, ky - r * 0.35, "sand_light")
    for i in range(7):
        sx = cx + rng.uniform(-12, 12)
        line(p, sx, head_y - 3, sx + rng.uniform(-8, 8), head_y - rng.uniform(12, 22), "dry_light")
    return p


# Reeds -------------------------------------------------------------------------------------

def reeds(seed):
    """A clump of bulrush: long leaves standing up thick and bending over at the tips, the far
    ones in shade, two or three brown velvet heads on stalks."""
    rng = random.Random(500 + seed)
    w, h = 44, 60
    p = new(w, h)
    cx, bottom = w // 2, h - 1
    p[ellipse(w, h, cx, bottom - 1, 14, 2.5)] = c("green_deep")
    rings = [("green_deep", "green_dark", "green"), ("green_dark", "green", "green_light"),
             ("green", "green_light", "green_bright")]
    leaves = sorted((rng.random(), cx + rng.uniform(-11, 10), rng.uniform(22, 46), rng.uniform(-10, 10)) for _ in range(32))
    for depth, x0, height, lean in leaves:
        tones = rings[min(2, int(depth * 3))]
        blade(p, x0, bottom - 1, height, lean, tones, width=2, droop=abs(lean) * 0.6)
    for i in range(2 + seed % 2):
        x = int(cx + rng.uniform(-6, 6))
        top = int(bottom - rng.uniform(42, 50))
        line(p, x, bottom - 2, x, top, "olive")
        for y in range(top + 2, top + 12):
            setp(p, x - 1, y, "soil_mid")
            setp(p, x, y, "soil")
            setp(p, x + 1, y, "soil_dark")
        setp(p, x - 1, top + 3, "soil_light")
        setp(p, x - 1, top + 4, "soil_light")
        setp(p, x, top + 1, "soil_dark")
        setp(p, x, top + 12, "soil_dark")
        line(p, x, top, x, top - 4, "reed")
    return p


def tall_grass(seed):
    """A clump of tall meadow grass: thick arching blades and seed heads on stalks above them."""
    rng = random.Random(600 + seed)
    w, h = 36, 44
    p = new(w, h)
    cx, bottom = w // 2, h - 1
    p[ellipse(w, h, cx, bottom - 1, 11, 2)] = c("green_deep")
    rings = [("green_dark", "olive", "dry"), ("olive", "dry", "dry_light"), ("green", "green_light", "green_bright")]
    for depth, x0, height, lean in sorted((rng.random(), cx + rng.uniform(-8, 7), rng.uniform(12, 26), rng.uniform(-11, 11))
                                          for _ in range(26)):
        blade(p, x0, bottom - 1, height, lean, rings[min(2, int(depth * 3))], width=2, droop=abs(lean) * 0.5)
    for i in range(5):
        x0 = cx + rng.uniform(-6, 6)
        lean = rng.uniform(-7, 7)
        height = rng.uniform(28, 38)
        line(p, x0, bottom - 2, x0 + lean, bottom - height, "dry_light", bend=lean * 0.2)
        hx, hy = x0 + lean, bottom - height
        for j in range(7):
            setp(p, hx - 1 + (j % 2) * 2, hy + j, "straw" if j % 2 == 0 else "reed")
            setp(p, hx, hy + j, "dry_light")
        setp(p, hx, hy - 1, "straw")
    return p


# Crops -------------------------------------------------------------------------------------

def wheat(seed):
    """Ripe wheat on one tile, thick as it grows: golden stalks, each ear a column of paired
    grains lit on the left with long awns, the back stalks a step darker."""
    rng = random.Random(700 + seed)
    w, h = 32, 64
    p = new(w, h)
    bottom = h - 1
    stalks = sorted((rng.random(), 2 + i * 2.9 + rng.uniform(-0.8, 0.8), rng.uniform(3, 16), rng.uniform(-2.5, 2.5))
                    for i in range(10))
    for depth, x, top, lean in stalks:
        back = depth < 0.4
        line(p, x, bottom - 1, x + lean, top + 16, "reed" if back else "straw")
        if rng.random() < 0.5:
            ly = bottom - rng.uniform(14, 28)
            side = rng.choice((-1, 1))
            line(p, x, ly, x + side * 4, ly + 4, "reed" if back else "straw")
        ex, ey = x + lean, top
        grain = ("ochre", "ochre_dark", "umber") if back else ("gold", "ochre", "ochre_dark")
        for g in range(8):
            gy = ey + 1 + g * 2
            setp(p, ex - 1, gy, grain[0])
            setp(p, ex, gy, grain[0] if g % 2 else grain[1])
            setp(p, ex + 1, gy, grain[1])
            setp(p, ex - 1, gy + 1, grain[1])
            setp(p, ex, gy + 1, grain[2])
            setp(p, ex + 1, gy + 1, grain[2])
        line(p, ex - 1, ey + 2, ex - 4, ey - 5, "straw" if back else "sand_light")
        line(p, ex + 1, ey + 2, ex + 4, ey - 4, "straw")
        line(p, ex, ey, ex, ey - 5, "sand_light" if not back else "straw")
    return p


def cabbage(seed):
    """A cabbage head ready to cut: a tight pale heart, wrapper leaves cupped round it, the outer
    leaves spread wide with a pale midrib and veins, wavy edges, the far ones in shade."""
    rng = random.Random(800 + seed)
    w, h = 32, 32
    p = new(w, h)
    cx, cy = 16, 18
    p[ellipse(w, h, cx, 29.5, 15, 2.5)] = c("green_deep")
    leaves = [(-9, -2, 7, 5, -1), (9, -2, 7, 5, 1), (-10, 5, 7, 5, -1), (10, 5, 7, 5, 1), (-4, 8, 7, 4.5, -1),
              (5, 8, 7, 4.5, 1)]
    for dx, dy, rx, ry, side in leaves:
        leaf = ellipse(w, h, cx + dx, cy + dy, rx, ry)
        far = dy < 0
        shade(p, leaf, ["green_deep", "green_dark", "green", "green_light"] if not far else
              ["green_deep", "green_deep", "green_dark", "green"], radius=3)
        # Midrib out from the stalk, two veins off it.
        for k in range(int(rx) + 1):
            t = k / rx
            mx, my = cx + dx * (0.25 + 0.75 * t), cy + dy * (0.6 + 0.3 * t)
            setp(p, mx, my, "green_light" if not far else "green")
            if k in (2, 4):
                setp(p, mx + side, my - 1, "green_light" if not far else "green")
                setp(p, mx + side, my + 1, "green" if not far else "green_dark")
    # Wrapper leaves and the head, lit on the top left.
    head = ellipse(w, h, cx, cy - 1, 9.5, 8.2)
    shade(p, head, ["green", "green_light", "green_bright", "spring_pale"], radius=5)
    for r, start, end, name in ((8.6, 2.0, 3.6, "green"), (6.4, 3.4, 5.4, "green_light"), (8.0, 0.0, 1.5, "green"),
                                (4.5, 4.4, 6.0, "green")):
        for k in range(30):
            a = start + (end - start) * k / 29
            setp(p, cx + r * math.cos(a), cy - 1 + r * 0.86 * math.sin(a), name)
    for k in range(7):
        setp(p, cx - 1 + k * 0.5, cy - 7 + k, "spring_pale")
    return p
