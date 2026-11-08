"""Drawing kit for version B: pictures as numpy arrays of palette indices (-1 is clear), the
palette of tools/art/palette.py, shapes as masks, and shading by a light from the top left."""

import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, "/home/marco/git-private/sandbox-game/tools/art")
import palette  # noqa: E402

NAMES = list(palette.PALETTE)
INDEX = {name: i for i, name in enumerate(NAMES)}
RGB = np.array([list(bytes.fromhex(palette.PALETTE[n])) for n in NAMES], dtype=np.uint8)
CLEAR = -1


def c(name):
    return INDEX[name]


def new(w, h):
    return np.full((h, w), CLEAR, dtype=np.int16)


def to_image(pic):
    h, w = pic.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    on = pic >= 0
    out[on, :3] = RGB[pic[on]]
    out[on, 3] = 255
    return Image.fromarray(out, "RGBA")


def stamp(dst, src, x, y):
    """Draws src onto dst with its top left at (x, y), clipped; clear pixels stay out."""
    h, w = src.shape
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(dst.shape[1], x + w), min(dst.shape[0], y + h)
    if x0 >= x1 or y0 >= y1:
        return
    part = src[y0 - y:y1 - y, x0 - x:x1 - x]
    region = dst[y0:y1, x0:x1]
    region[part >= 0] = part[part >= 0]


def flip(pic):
    return pic[:, ::-1].copy()


def ascii_pic(keys, rows):
    """A picture from rows of characters; '.' and ' ' are clear, others map through keys."""
    w = max(len(r) for r in rows)
    pic = new(w, len(rows))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch not in ". ":
                pic[y, x] = c(keys[ch])
    return pic


# Masks ---------------------------------------------------------------------------------------

def _draw_mask(w, h, fn):
    im = Image.new("L", (w, h), 0)
    fn(ImageDraw.Draw(im))
    return np.array(im) > 0


def ellipse(w, h, cx, cy, rx, ry):
    yy, xx = np.mgrid[0:h, 0:w]
    return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0


def poly(w, h, points):
    return _draw_mask(w, h, lambda d: d.polygon([tuple(p) for p in points], fill=255))


def capsule(w, h, x0, y0, x1, y1, r0, r1=None):
    """A tapered stroke from (x0, y0) radius r0 to (x1, y1) radius r1."""
    r1 = r0 if r1 is None else r1
    yy, xx = np.mgrid[0:h, 0:w]
    px, py = xx + 0.5, yy + 0.5
    dx, dy = x1 - x0, y1 - y0
    length2 = dx * dx + dy * dy or 1e-9
    t = np.clip(((px - x0) * dx + (py - y0) * dy) / length2, 0, 1)
    qx, qy = x0 + t * dx, y0 + t * dy
    r = r0 + (r1 - r0) * t
    return (px - qx) ** 2 + (py - qy) ** 2 <= r * r


def limb(w, h, points, radii):
    """A chain of tapered strokes through points with a radius at each: a leg with a joint."""
    m = np.zeros((h, w), bool)
    for (a, ra), (b, rb) in zip(zip(points, radii), zip(points[1:], radii[1:])):
        m |= capsule(w, h, a[0], a[1], b[0], b[1], ra, rb)
    return m


def inner_distance(mask, cap):
    """Steps (4-neighbour) from each mask pixel to the outside, up to cap."""
    d = np.zeros(mask.shape, np.float32)
    cur = mask.copy()
    for i in range(cap):
        d[cur] += 1
        shrunk = cur.copy()
        shrunk[1:, :] &= cur[:-1, :]
        shrunk[:-1, :] &= cur[1:, :]
        shrunk[:, 1:] &= cur[:, :-1]
        shrunk[:, :-1] &= cur[:, 1:]
        shrunk[0, :] = shrunk[-1, :] = False
        shrunk[:, 0] = shrunk[:, -1] = False
        cur = shrunk
        if not cur.any():
            break
    return d


LIGHT = np.array([-0.55, -0.75, 0.75])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def light_level(mask, radius, light=LIGHT, bias=0.0, vgrad=0.0):
    """How lit each pixel of a rounded form is, about -1..1: the mask as a dome whose rim
    rises over `radius` px, lit from the top left; `vgrad` adds light at the top and takes it
    from the bottom, for big forms whose middle would be flat."""
    d = inner_distance(mask, radius)
    t = np.clip(d / radius, 0, 1)
    height = np.sqrt(1 - (1 - t) ** 2) * radius
    gy, gx = np.gradient(height)
    n = np.dstack([-gx, -gy, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    level = n @ light
    if vgrad and mask.any():
        ys = np.nonzero(mask)[0]
        top, bottom = ys.min(), ys.max()
        rows = np.arange(mask.shape[0])[:, None]
        level = level + vgrad * (1 - 2 * (rows - top) / max(1, bottom - top))
    return np.where(mask, level + bias, -9)


def shade(pic, mask, ramp, radius=4, thresholds=None, bias=0.0, light=LIGHT, vgrad=0.0):
    """Fills mask into pic with ramp (dark to light) by light_level."""
    level = light_level(mask, radius, light, bias, vgrad)
    n = len(ramp)
    if thresholds is None:
        thresholds = {2: [0.55], 3: [0.45, 0.8], 4: [0.3, 0.62, 0.9], 5: [0.2, 0.45, 0.7, 0.92]}[n]
    idx = np.zeros(mask.shape, int)
    for t in thresholds:
        idx += level > t
    for i, name in enumerate(ramp):
        pic[mask & (idx == i)] = c(name)
    return pic


def fill(pic, mask, name):
    pic[mask] = c(name)
    return pic


def outline(pic, colour, only_clear_neighbours=True, bottom=None):
    """Draws `colour` on clear pixels next to the picture (4-neighbours). With `bottom`, the
    outline below the picture (pixels whose upper neighbour is set) gets that colour."""
    on = pic >= 0
    near = np.zeros_like(on)
    near[1:, :] |= on[:-1, :]
    near[:-1, :] |= on[1:, :]
    near[:, 1:] |= on[:, :-1]
    near[:, :-1] |= on[:, 1:]
    ring = near & ~on
    out = pic.copy()
    out[ring] = c(colour) if isinstance(colour, str) else colour
    if bottom:
        below = np.zeros_like(on)
        below[1:, :] = on[:-1, :]
        out[ring & below] = c(bottom)
    return out


def pad(pic, n):
    h, w = pic.shape
    out = new(w + 2 * n, h + 2 * n)
    out[n:n + h, n:n + w] = pic
    return out


def edge_of(mask):
    """Mask pixels with a 4-neighbour outside the mask."""
    inner = mask.copy()
    inner[1:, :] &= mask[:-1, :]
    inner[:-1, :] &= mask[1:, :]
    inner[:, 1:] &= mask[:, :-1]
    inner[:, :-1] &= mask[:, 1:]
    return mask & ~inner


def value_noise(w, h, cell, seed):
    """Smooth noise about -1..1 with features about `cell` px big."""
    rng = np.random.RandomState(seed)
    gw, gh = w // cell + 3, h // cell + 3
    grid = rng.uniform(-1, 1, (gh, gw))
    yy, xx = np.mgrid[0:h, 0:w]
    fx, fy = xx / cell, yy / cell
    ix, iy = fx.astype(int), fy.astype(int)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = grid[iy, ix] * (1 - tx) + grid[iy, ix + 1] * tx
    b = grid[iy + 1, ix] * (1 - tx) + grid[iy + 1, ix + 1] * tx
    return a * (1 - ty) + b * ty
