"""The pig pen (task 165) in the classic 16 px art: the fence of split oak rails, its gate shut and
open, and the pigs' shelter, as tools/art/pen.py draws them at 32 px, at half the size.
"""

import math

from boundaries import MASKS, TILE, along_line, cluster_value, draw_line, ramp_shade, skeleton_distance
from canvas import blank, outline_edge, rect
from yard import icon_of

POST_SPACING = 8
POST_HEIGHT = 12
RAILS = ((3, 3), (6, 6), (9, 10))
RAIL_REACH = 1.0
SPLIT_OAK = ("bare_light", "bare", "mud", "mud_dark")
POSTS = ("soil_light", "soil_mid", "soil", "soil_dark")
GATE_POST_HEIGHT = 14
GATE_LEAF = (2, 13)
GATE_BOARDS = ("sand_light", "sand", "mud", "mud_dark")
OPEN_ANGLE = math.radians(40)


def _layers_of_heights(heights, material):
    """The layers of a column that has `material` at the heights in `heights` and gaps between."""
    layers = []
    for z in sorted(heights):
        if layers and layers[-1][1] == material and layers[-1][0] == z - 1:
            layers[-1] = (z, material)
        else:
            if z > (layers[-1][0] if layers else 0) + 1:
                layers.append((z - 1, None))
            layers.append((z, material))
    return layers


def _rail_heights():
    return {z for bottom, top in RAILS for z in range(bottom, top + 1)}


def _fence_layers(mask, x, y):
    if skeleton_distance(mask, x + 0.5, y + 0.5) >= RAIL_REACH + 0.5:
        return []
    if along_line(x, y) % POST_SPACING == 0:
        return [(POST_HEIGHT, "post")]
    return _layers_of_heights(_rail_heights(), "rail")


def _fence_colour(material, x, y, z, light, is_top):
    if material == "post":
        return ramp_shade(POSTS, light + (0.3 if is_top else 0.0))
    return ramp_shade(SPLIT_OAK, light + (0.3 if is_top else -0.1) + 0.2 * cluster_value(x, y, z, 165))


def _fence_outline(material):
    return {"post": POSTS[-1], "rail": None}[material]


def pen_fence(mask):
    return draw_line(mask, _fence_layers, _fence_colour, _fence_outline)


def pen_fence_row():
    return [pen_fence(mask) for mask in MASKS]


def _leaf_heights(along):
    first, last = GATE_LEAF
    if along < first or along > last:
        return set()
    if along in (first, last):
        return set(range(RAILS[0][0], RAILS[-1][1] + 1))
    brace = RAILS[0][0] + (along - first) * (RAILS[-1][1] - RAILS[0][0]) / (last - first)
    return _rail_heights() | {round(brace)}


def _runs_north_south(mask):
    """Whether the gate runs north-south: when the line through it joins only to the north or the
    south. Otherwise (and alone) it runs east-west."""
    return not mask & 0b1010 and bool(mask & 0b0101)


def _gate_layers(is_open):
    def layers(mask, x, y):
        along, across = (y, x) if _runs_north_south(mask) else (x, y)
        if not (0 <= along < TILE):
            return []
        on_line = abs(across + 0.5 - TILE / 2) < RAIL_REACH + 0.5
        if on_line and along in (0, TILE - 1):
            return [(GATE_POST_HEIGHT, "post")]
        if not is_open:
            return _layers_of_heights(_leaf_heights(along), "board") if on_line else []
        # Swung open towards the front, as at 32 px.
        dx, dy = along + 0.5 - (GATE_LEAF[0] - 0.5), across + 0.5 - TILE / 2
        distance = dx * math.cos(OPEN_ANGLE) + dy * math.sin(OPEN_ANGLE)
        off_line = -dx * math.sin(OPEN_ANGLE) + dy * math.cos(OPEN_ANGLE)
        if abs(off_line) >= RAIL_REACH or distance < 0:
            return []
        return _layers_of_heights(_leaf_heights(GATE_LEAF[0] + round(distance)), "board")

    return layers


def _gate_colour(material, x, y, z, light, is_top):
    ramp = POSTS if material == "post" else GATE_BOARDS
    return ramp_shade(ramp, light + (0.3 if is_top else 0.0))


def _gate_outline(material):
    # The boards are a pixel thick: an outline would make the gate all dark.
    return {"post": POSTS[-1], "board": None}[material]


def pen_gate(mask, is_open=False):
    return draw_line(mask, _gate_layers(is_open), _gate_colour, _gate_outline)


def pen_gate_row(is_open=False):
    return [pen_gate(mask, is_open) for mask in MASKS]


THATCH = ("sand", "bare_light", "bare", "mud_dark")
BOARDS = ("soil_mid", "soil", "soil_dark")
STRAW = ("gold", "straw", "ochre")


def pig_shelter():
    """The pigs' shelter, 32x22 px: a lean-to of boards under reed thatch, open to the front, with
    straw on its floor and a post at each front corner."""
    width, height = 32, 22
    picture = blank(width, height)
    eaves = 10
    rect(picture, 1, eaves, width - 2, height - 1, "umber")
    for x in range(3, width - 2, 3):
        rect(picture, x, eaves, x, height - 4, "soil_dark")
    for y in range(height - 4, height):
        for x in range(2, width - 2):
            picture[y][x] = STRAW[0 if y == height - 4 else 1 if (x + y) % 3 else 2]
    for x0 in (0, width - 2):
        rect(picture, x0, eaves - 1, x0 + 1, height - 1, BOARDS[1])
        rect(picture, x0, eaves - 1, x0, height - 1, BOARDS[0])
    for y in range(eaves):
        for x in range(width):
            row = y % 4
            light = 0 if row == 0 else 1 if row == 1 else 2 if (x * 5 + y) % 3 else 3
            picture[y][x] = THATCH[light]
    for x in range(width):
        picture[eaves - 1][x] = THATCH[1]
        picture[eaves][x] = THATCH[3] if x % 2 else THATCH[2]
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def icons():
    """The icons of the pen's items, by item id."""
    return {
        "pen_fence": icon_of(pen_fence(0b1010)),
        "pen_gate": icon_of(pen_gate(0b1010)),
        "pig_shelter": icon_of(pig_shelter()),
    }
