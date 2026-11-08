"""Version B ground at 32 px per tile: the same dual-grid idea (soft edges between tile
centres, each layer over the ones below) worked out per pixel, and textures that use the
extra pixels: grass tufts with a shaded root and lit tips, clover and daisies in drifts,
pebbles with a shadow, tilled ridges with clods, water with a bank and ripples."""

import random

import numpy as np

from b_core import ascii_pic, c, new, value_noise
from scene import GROUND, H, W

T = 32
PW, PH = W * T, H * T
LAYER = {"w": 0, "g": 4, "l": 7, "d": 8, "t": 9, "p": 10, "s": 11}
BASE = {0: 0, 4: 4, 7: 4, 8: 4, 9: 9, 10: 10, 11: 11}
# How much each layer's edge wanders, in tile units.
WANDER = {0: 0.32, 4: 0.0, 7: 0.4, 8: 0.4, 9: 0.35, 10: 0.14, 11: 0.04}


def tile_layers():
    return np.array([[LAYER[ch] for ch in row] for row in GROUND])


def layer_map():
    tiles = tile_layers()
    base = np.vectorize(BASE.get)(tiles)
    yy, xx = np.mgrid[0:PH, 0:PW]
    u = (xx + 0.5) / T - 0.5
    v = (yy + 0.5) / T - 0.5
    i0 = np.clip(np.floor(u).astype(int), 0, W - 1)
    j0 = np.clip(np.floor(v).astype(int), 0, H - 1)
    i1 = np.clip(np.floor(u).astype(int) + 1, 0, W - 1)
    j1 = np.clip(np.floor(v).astype(int) + 1, 0, H - 1)
    fu = np.clip(u - np.floor(u), 0, 1)
    fv = np.clip(v - np.floor(v), 0, 1)
    fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
    corners = [(j0, i0), (j0, i1), (j1, i0), (j1, i1)]
    weights = [(1 - fu) * (1 - fv), fu * (1 - fv), (1 - fu) * fv, fu * fv]
    noise = value_noise(PW, PH, 16, 7) * 0.8 + value_noise(PW, PH, 6, 8) * 0.2
    result = np.minimum.reduce([tiles[j, i] for j, i in corners])
    for layer in sorted(set(LAYER.values())):
        present = np.zeros((PH, PW), bool)
        for j, i in corners:
            present |= (tiles[j, i] == layer) | (base[j, i] == layer)
        f = sum(w * (tiles[j, i] >= layer) for w, (j, i) in zip(weights, corners))
        result[present & (f + noise * WANDER[layer] > 0.5)] = layer
    return result


def scatter(rng, mask, count, spacing=None):
    """`count` random points (x, y) inside mask; with spacing, at most one per cell."""
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return []
    points = []
    taken = set()
    for _ in range(count):
        p = rng.randrange(len(xs))
        x, y = int(xs[p]), int(ys[p])
        if spacing:
            cell = (x // spacing, y // spacing)
            if cell in taken:
                continue
            taken.add(cell)
        points.append((x, y))
    return points


def put(pic, x, y, name, where=None):
    if 0 <= x < PW and 0 <= y < PH and (where is None or where[y, x]):
        pic[y, x] = c(name)


def put_pic(pic, sprite, x, y, where):
    """Stamps a small picture with its bottom centre at (x, y), only inside `where`."""
    h, w = sprite.shape
    for sy in range(h):
        for sx in range(w):
            if sprite[sy, sx] >= 0:
                px, py = x - w // 2 + sx, y - h + 1 + sy
                if 0 <= px < PW and 0 <= py < PH and where[py, px]:
                    pic[py, px] = sprite[sy, sx]


# Grass tufts: blades fanning up from a shaded root to lit tips. k deep, d dark, l light, b bright.
TUFT_ROWS = [
    ("l...l", ".d.l.", ".d.d.", "..k.."),
    ("..b..", "l.l..", "d.l.l", ".dkd."),
    ("l..", ".l.", "dd.", "k.."),
    ("..l", "l.d", "dd.", ".k."),
    (".b.l.", ".l.d.", "d.ld.", "dkdk."),
    ("l.", "d.", ".k"),
]


def tufts(ramp):
    deep, dark, light, bright = ramp
    keys = {"k": deep, "d": dark, "l": light, "b": bright}
    return [ascii_pic(keys, rows) for rows in TUFT_ROWS]


def grass(pic, mask, rng, ramp, density, base, flowers=True, clover=True):
    """ramp: (deep, dark, light, bright). Tufts gather where a slow noise is high, so the turf has
    calm stretches and thick ones, never an even sprinkle."""
    deep, dark, light, bright = ramp
    pic[mask] = c(base)
    gather = value_noise(PW, PH, 24, rng.randrange(1000)) + 0.4 * value_noise(PW, PH, 8, rng.randrange(1000))
    shapes = tufts(ramp)
    count = int(mask.sum() * density)
    for x, y in scatter(rng, mask, count * 3):
        if rng.random() > 0.25 + 0.6 * max(0.0, gather[y, x]):
            continue
        put_pic(pic, rng.choice(shapes), x, y, mask)
    # Single dark blade roots between, so the base is not flat.
    for x, y in scatter(rng, mask, count):
        put(pic, x, y, dark, mask)
        if rng.random() < 0.5:
            put(pic, x + 1, y - 1, dark, mask)
    if clover:
        for x, y in scatter(rng, mask & (gather < -0.35), count // 6, spacing=7):
            # Clover: three round leaflets, lit on the top left, the far one in shade.
            leaf = ascii_pic({"l": light, "d": dark, "b": bright},
                             (".bl..", "lll.l", ".lldl", "..dd.", "...d."))
            put_pic(pic, leaf, x, y, mask)
    if flowers:
        drift = value_noise(PW, PH, 36, rng.randrange(1000))
        daisy = ascii_pic({"w": "lime", "c": "cream", "g": "gold", "d": dark},
                          (".w.", "wgw", ".c.", ".d."))
        cup = ascii_pic({"g": "gold", "o": "ochre", "d": dark}, ("gg", "go", ".d"))
        for x, y in scatter(rng, mask & (drift > 0.55), count // 9, spacing=6):
            put_pic(pic, daisy if rng.random() < 0.65 else cup, x, y, mask)


def path(pic, mask, rng):
    """Packed earth, paler and dustier where most feet go, with clog prints, small dents and
    pebbles lit on top with their shadow under them."""
    pic[mask] = c("mud")
    dist = np.zeros((PH, PW), int)
    cur = mask.copy()
    for _ in range(10):
        dist[cur] += 1
        cur = shrink(cur)
    n = value_noise(PW, PH, 12, 31) + 0.4 * value_noise(PW, PH, 4, 32)
    worn = mask & (dist + n * 3 > 6)
    pic[worn] = c("sand")
    for x, y in scatter(rng, mask, int(mask.sum() * 0.01)):
        put(pic, x, y, "mud_dark", mask)
        put(pic, x + 1, y, "mud_dark", mask)
        put(pic, x, y + 1, "sand_light" if worn[y, x] else "sand", mask)
    small = ascii_pic({"l": "stone_light", "s": "stone", "d": "stone_dark", "m": "mud_dark"},
                      ("ls.", "sdm", ".m."))
    big = ascii_pic({"l": "stone_light", "s": "stone", "d": "stone_dark", "m": "mud_dark"},
                    (".ll..", "llss.", "sssdm", ".ddm.", "..m.."))
    for x, y in scatter(rng, mask, int(mask.sum() * 0.002), spacing=8):
        put_pic(pic, big if rng.random() < 0.3 else small, x, y, mask)


def soil(pic, mask, rng):
    """Tilled ridges, four to a tile, running along the field: a lit crest, the slope, a dark
    furrow. The furrow line wobbles by a pixel; clods sit on the crests."""
    wobble = value_noise(PW, PH, 6, 41)
    yy, xx = np.mgrid[0:PH, 0:PW]
    phase = (yy + np.round(wobble * 0.8).astype(int)) % 8
    ramp = np.array([c("soil_light"), c("soil_mid"), c("soil_mid"), c("soil_mid"), c("soil"),
                     c("soil"), c("soil_dark"), c("soil_dark")])
    pic[mask] = ramp[phase[mask]]
    for x, y in scatter(rng, mask & (phase <= 2), int(mask.sum() * 0.018)):
        put(pic, x, y, "soil_light", mask)
        put(pic, x + 1, y, "soil_light", mask)
        put(pic, x, y + 1, "soil", mask)
        put(pic, x + 1, y + 1, "soil", mask)
        put(pic, x + 2, y + 1, "soil_dark", mask)
    for x, y in scatter(rng, mask & (phase >= 6), int(mask.sum() * 0.003)):
        put(pic, x, y, "stone", mask)
        put(pic, x + 1, y, "stone_dark", mask)


def shrink(mask):
    return mask & np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1)


def water(pic, mask, rng):
    dist = np.zeros((PH, PW), int)
    cur = mask.copy()
    for _ in range(8):
        dist[cur] += 1
        cur = shrink(cur)
    pic[mask] = c("water")
    pic[mask & (dist + 2 * value_noise(PW, PH, 9, 53) >= 6)] = c("water_deep")
    # The banks to the west and north shade the water next to them.
    shaded = mask & (~np.roll(mask, 3, 1) | ~np.roll(mask, 2, 0))
    pic[shaded] = c("water_deep")
    for x, y in scatter(rng, mask & (dist >= 3), int(mask.sum() * 0.01), spacing=4):
        length = rng.randint(2, 5)
        inner = mask & (dist >= 2)
        for dx in range(length):
            put(pic, x + dx, y, "water_light", inner)
        put(pic, x + length // 2, y + 1, "water_deep", inner)
        if rng.random() < 0.3:
            put(pic, x + 1, y - 1, "foam", inner)
    # The east waterline catches the light.
    lit_line = mask & ~np.roll(mask, -1, 1)
    pic[lit_line & (value_noise(PW, PH, 5, 52) > -0.2)] = c("water_light")
    land = ~mask
    rim = land & (np.roll(mask, 1, 1) | np.roll(mask, -1, 1) | np.roll(mask, -1, 0) | np.roll(mask, 1, 0))
    rim2 = land & ~rim & (np.roll(mask, 2, 1) | np.roll(mask, -2, 1) | np.roll(mask, -2, 0))
    pic[rim] = c("mud_dark")
    pic[rim2 & (value_noise(PW, PH, 4, 71) > -0.1)] = c("mud")


def overhang(pic, below, above, rng, ramp, chance=0.45):
    """Grass blades from `above` hanging over the edge into `below` (path, soil)."""
    deep, dark, light, bright = ramp
    edge = below & (np.roll(above, 1, 0) | np.roll(above, 1, 1) | np.roll(above, -1, 1))
    for y, x in zip(*np.nonzero(edge)):
        if rng.random() < chance:
            for k in range(rng.choice((1, 2, 2, 3))):
                put(pic, x, y + k, light if k == 0 else dark, below)


GRASS = ("green_deep", "green_dark", "green_light", "green_bright")
LUSH = ("green_deep", "green_deep", "green_dark", "green_light")
DRY = ("olive", "olive", "dry_light", "straw")


def render():
    rng = random.Random(11)
    layers = layer_map()
    pic = new(PW, PH)
    grassy = (layers == 4) | (layers == 7) | (layers == 8) | (layers == 9)
    grass(pic, layers == 4, rng, GRASS, 0.018, "green")
    grass(pic, layers == 7, rng, LUSH, 0.03, "green", flowers=False)
    grass(pic, layers == 8, rng, DRY, 0.025, "dry", flowers=False, clover=False)
    trod = layers == 9
    grass(pic, trod, rng, GRASS, 0.012, "green", flowers=False, clover=False)
    bare = value_noise(PW, PH, 6, 61)
    pic[trod & (bare > 0.15)] = c("mud")
    pic[trod & (bare > 0.55)] = c("sand")
    path(pic, layers == 10, rng)
    soil(pic, layers == 11, rng)
    water(pic, layers == 0, rng)
    # Grass hangs over the banks into the water.
    wet = layers == 0
    overhang(pic, wet, grassy, rng, GRASS, chance=0.35)
    # Path and soil lie a little below the turf: a dark line under the grass edge, and blades
    # hanging over it.
    for low, shade in ((layers == 10, "mud_dark"), (layers == 11, "soil_dark")):
        cut = low & (np.roll(grassy, 1, 0) | np.roll(grassy, 1, 1) | np.roll(grassy, -1, 1) | np.roll(grassy, -1, 0))
        pic[cut] = c(shade)
        overhang(pic, low, grassy, rng, GRASS)
    return pic, layers
