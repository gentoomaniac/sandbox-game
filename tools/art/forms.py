"""Rounded forms for the figures drawn at 32 px per tile (character.py, villagers.py): shapes as
masks, filled into a picture in the shades of a ramp by a light from the top left.

A mask is a numpy array of booleans as big as the picture, `mask[y, x]`. A shape's numbers are
in pixels, a pixel's middle at x + 0.5, so a shape centred on 16 in a 32 px wide picture is
symmetric. `shade` fills a mask as a dome: lit on its top left rim, shaded on the bottom right
one, its middle in the ramp's middle shade.
"""

import numpy as np
from PIL import Image, ImageDraw

# The light: from the top left and a little in front.
LIGHT = np.array([-0.55, -0.75, 0.75])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
# How lit a pixel must be for each shade of a ramp of 2 to 4 colours, dark to light.
THRESHOLDS = {2: (0.55,), 3: (0.45, 0.8), 4: (0.3, 0.62, 0.9)}


def grid(width, height):
    """The middles of the pixels of a picture, as their x and y."""
    ys, xs = np.mgrid[0:height, 0:width]
    return xs + 0.5, ys + 0.5


def box(width, height, x0, y0, x1, y1):
    """The pixels x0..x1 and y0..y1, both ends included."""
    mask = np.zeros((height, width), bool)
    mask[max(0, y0) : max(0, y1 + 1), max(0, x0) : max(0, x1 + 1)] = True
    return mask


def rounded_box(width, height, x0, y0, x1, y1):
    """A box without its four corner pixels."""
    mask = box(width, height, x0, y0, x1, y1)
    for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        if 0 <= x < width and 0 <= y < height:
            mask[y, x] = False
    return mask


def ellipse(width, height, cx, cy, rx, ry):
    xs, ys = grid(width, height)
    return ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2 <= 1.0


def polygon(width, height, points):
    image = Image.new("L", (width, height), 0)
    ImageDraw.Draw(image).polygon([tuple(point) for point in points], fill=255)
    return np.array(image) > 0


def capsule(width, height, start, end, start_radius, end_radius=None):
    """A stroke from `start` to `end` with round ends, `start_radius` thick at the start and
    tapering to `end_radius`: an arm, a leg, a plait."""
    end_radius = start_radius if end_radius is None else end_radius
    xs, ys = grid(width, height)
    (x0, y0), (x1, y1) = start, end
    dx, dy = x1 - x0, y1 - y0
    along = np.clip(((xs - x0) * dx + (ys - y0) * dy) / (dx * dx + dy * dy or 1e-9), 0, 1)
    radius = start_radius + (end_radius - start_radius) * along
    return (xs - x0 - along * dx) ** 2 + (ys - y0 - along * dy) ** 2 <= radius * radius


def limb(width, height, points, radii):
    """Capsules through `points`, each as thick as its radius there: a leg with a knee."""
    mask = np.zeros((height, width), bool)
    for start, end, start_radius, end_radius in zip(points, points[1:], radii, radii[1:]):
        mask |= capsule(width, height, start, end, start_radius, end_radius)
    return mask


def shrunk(mask):
    """The mask without its border pixels (those next to a pixel outside it)."""
    inner = mask.copy()
    inner[1:, :] &= mask[:-1, :]
    inner[:-1, :] &= mask[1:, :]
    inner[:, 1:] &= mask[:, :-1]
    inner[:, :-1] &= mask[:, 1:]
    inner[0, :] = inner[-1, :] = inner[:, 0] = inner[:, -1] = False
    return inner


def edge(mask):
    """The border pixels of the mask."""
    return mask & ~shrunk(mask)


def light_level(mask, radius):
    """How lit each pixel of the mask is, about -1 to 1: the mask as a dome whose rim rises
    over `radius` pixels, lit by LIGHT."""
    depth = np.zeros(mask.shape, np.float32)
    inside = mask.copy()
    for _ in range(radius):
        depth[inside] += 1
        inside = shrunk(inside)
    rise = np.clip(depth / radius, 0, 1)
    dome = np.sqrt(1 - (1 - rise) ** 2) * radius
    gy, gx = np.gradient(dome)
    normals = np.dstack([-gx, -gy, np.ones_like(gx)])
    normals /= np.linalg.norm(normals, axis=2, keepdims=True)
    return normals @ LIGHT


def shade(picture, mask, ramp, radius=3):
    """Fills the mask into the picture in the colours of `ramp` (dark to light) by how lit
    each pixel is (see `light_level`)."""
    level = light_level(mask, radius)
    steps = sum((level > threshold).astype(int) for threshold in THRESHOLDS[len(ramp)])
    for y, x in zip(*np.nonzero(mask)):
        picture[y][x] = ramp[steps[y, x]]
    return picture


def paint(picture, mask, colour):
    """Fills the mask into the picture in one colour (None clears it)."""
    for y, x in zip(*np.nonzero(mask)):
        picture[y][x] = colour
    return picture


def dots(picture, points, colour):
    """Sets single pixels, (x, y), those outside the picture left out."""
    for x, y in points:
        if 0 <= y < len(picture) and 0 <= x < len(picture[0]):
            picture[y][x] = colour
    return picture


def drawn(picture):
    """The mask of the picture's drawn pixels."""
    return np.array([[colour is not None for colour in row] for row in picture])
