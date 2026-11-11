"""The pig pen (task 165), drawn at 32 px per tile: the fence of split oak rails, its gate and the
pigs' shelter.

The fence and the gate are lines across the land like the wattle fence (boundaries.py): one
picture per connection mask, the gate joining the fence on either side. The rails are split oak,
weathered grey, on posts of the dark wet oak; between and under them the ground shows, so they
are drawn as layers with gaps. The gate is newer, paler boards with a brace between two taller
posts. The shelter is drawn once, standing, as the stations are, a lean-to of boards under reed
thatch, open to the front, with straw in it.
"""

import items
from boundaries import MASKS, TILE, along_line, draw_line, pixel_hash, ramp_shade, skeleton_distance
from canvas import blank, outline_edge, rect

# Posts every POST_SPACING px along the line, POST_WIDTH thick; three rails, each a run of heights
# (bottom, top) above the ground, RAIL_REACH px out from the skeleton.
POST_SPACING = 16
POST_WIDTH = 3
POST_HEIGHT = 24
RAILS = ((5, 7), (12, 14), (19, 21))
RAIL_REACH = 1.5
SPLIT_OAK = ("bare_light", "bare", "mud", "mud_dark")
POSTS = ("soil_light", "soil_mid", "soil", "soil_dark")
# The gate: posts at both ends of the tile, taller; between them the leaf, its rails, a stile at
# each end and a brace from the foot of the hinge stile to the top of the latch stile.
GATE_POST_HEIGHT = 28
GATE_LEAF = (4, 27)
GATE_BOARDS = ("sand_light", "sand", "mud", "mud_dark")


def _layers_of_heights(heights, material):
    """The layers of a column that has `material` at the heights in `heights` and nothing in
    between: gaps are layers of no material."""
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
    if (along_line(x, y) + 1) % POST_SPACING < POST_WIDTH:
        return [(POST_HEIGHT, "post")]
    return _layers_of_heights(_rail_heights(), "rail")


def _fence_colour(material, x, y, z, light, is_top):
    along = along_line(x, y)
    if material == "post":
        side = (along + 1) % POST_SPACING
        side_light = 0.2 if side == 0 else -0.2 if side == POST_WIDTH - 1 else 0.0
        return ramp_shade(POSTS, light + (0.3 if is_top else 0.0) + side_light)
    # A split rail: lit along its top, dark along its underside, with the grain of the split
    # wood in streaks along it.
    edge = 0.3 if is_top else -0.3 if z in {bottom for bottom, _ in RAILS} else 0.0
    grain = 0.2 * pixel_hash(along // 5 % (TILE // 5), z, 165)
    return ramp_shade(SPLIT_OAK, light + edge + grain)


def _fence_outline(material):
    # Like the wattle: a fence running north-south is seen from above, and an outlined rail would
    # be all dark.
    return {"post": POSTS[-1], "rail": None}[material]


def pen_fence(mask):
    return draw_line(mask, _fence_layers, _fence_colour, _fence_outline)


def pen_fence_row():
    """The atlas row of the pen's fence: one picture per connection mask."""
    return [pen_fence(mask) for mask in MASKS]


def _leaf_heights(along):
    """The heights the gate's leaf has at a place `along` it (from the hinge post's side)."""
    first, last = GATE_LEAF
    if along < first or along > last:
        return set()
    if along - first < 2 or last - along < 2:
        return set(range(RAILS[0][0], RAILS[-1][1] + 1))
    brace = RAILS[0][0] + (along - first) * (RAILS[-1][1] - RAILS[0][0]) / (last - first)
    return _rail_heights() | {z for z in range(RAILS[0][0], RAILS[-1][1] + 1) if abs(z - brace) < 1.5}


def _runs_north_south(mask):
    """Whether the gate runs north-south: when the line through it joins only to the north or the
    south. Otherwise (and alone) it runs east-west."""
    return not mask & 0b1010 and bool(mask & 0b0101)


def _gate_layers(mask, x, y):
    along, across = (y, x) if _runs_north_south(mask) else (x, y)
    if not (0 <= along < TILE) or abs(across + 0.5 - TILE / 2) >= RAIL_REACH + 0.5:
        return []
    if along < POST_WIDTH or along >= TILE - POST_WIDTH:
        return [(GATE_POST_HEIGHT, "post")]
    return _layers_of_heights(_leaf_heights(along), "board")


def _gate_colour(material, x, y, z, light, is_top):
    if material == "post":
        return ramp_shade(POSTS, light + (0.3 if is_top else 0.0))
    edge = 0.3 if is_top else 0.0
    grain = 0.15 * pixel_hash(along_line(x, y) // 4 % (TILE // 4), z, 166)
    return ramp_shade(GATE_BOARDS, light + edge + grain)


def _gate_outline(material):
    return {"post": POSTS[-1], "board": GATE_BOARDS[-1]}[material]


def pen_gate(mask):
    return draw_line(mask, _gate_layers, _gate_colour, _gate_outline)


def pen_gate_row():
    """The atlas row of the gate: one picture per connection mask."""
    return [pen_gate(mask) for mask in MASKS]


# The shelter's reed thatch, lit to dark, its boards and the straw on its floor.
THATCH = ("sand", "bare_light", "bare", "mud_dark")
BOARDS = ("soil_mid", "soil", "soil_dark")
STRAW = ("gold", "straw", "ochre", "ochre_dark")
SHELTER_SIZE = (64, 44)


def pig_shelter():
    """The pigs' shelter, 64x44 px: a lean-to two tiles wide, its back wall of boards under a
    roof of reed thatch that slopes down to the front, open below the eaves, where straw lies in
    the dark under the roof; a post at each front corner."""
    width, height = SHELTER_SIZE
    picture = blank(width, height)
    eaves = 20
    # The back wall seen under the roof: dark, boards with their joints.
    rect(picture, 2, eaves, width - 3, height - 1, "umber")
    for x in range(5, width - 3, 6):
        rect(picture, x, eaves, x, height - 7, "soil_dark")
    # The straw on the floor, a heap lit along its top.
    for y in range(height - 8, height):
        for x in range(4, width - 4):
            depth = y - (height - 8)
            if depth == 0 and (x * 3) % 7 < 2:
                continue
            light = 0 if depth <= 1 else 1 if depth <= 4 else 2
            if (x * 5 + y * 3) % 7 == 0:
                light = min(3, light + 1)
            picture[y][x] = STRAW[light]
    # The front posts, lit on their left.
    for x0 in (1, width - 5):
        rect(picture, x0, eaves - 2, x0 + 3, height - 1, BOARDS[1])
        rect(picture, x0, eaves - 2, x0, height - 1, BOARDS[0])
        rect(picture, x0 + 3, eaves - 2, x0 + 3, height - 1, BOARDS[2])
    # The thatch: courses of reed laid across the slope, 7 px high, each lit along its top, with
    # the ends of the reeds in uneven lengths darkening its foot, and a thick rolled eave in front
    # with a ragged hem.
    for y in range(eaves):
        for x in range(width):
            course, row = divmod(y, 7)
            reed_end = 4 + round(1.5 * (pixel_hash(x, course, 167) + 1))
            light = 0 if row == 0 else 1 if row < 3 else 2
            if row >= reed_end:
                light = 3
            elif row == 1 and pixel_hash(x, course, 168) > 0.6:
                light = 0
            picture[y][x] = THATCH[light]
    for x in range(width):
        picture[eaves - 2][x] = THATCH[0]
        picture[eaves - 1][x] = THATCH[1]
        picture[eaves][x] = THATCH[2]
        if (x * 7) % 3:
            picture[eaves + 1][x] = THATCH[3]
    return outline_edge(picture, "soil_dark", keep_bottom=True)


def _one_tile(picture):
    """A line's cell cut to the tile it stands on (the middle third of the cell), for an icon."""
    return [row[TILE : 2 * TILE] for row in picture]


def icons():
    """The bodies of the icons of the pen's items, by item id: their pictures."""
    return {
        "pen_fence": items.icon_of(_one_tile(pen_fence(0b1010))),
        "pen_gate": items.icon_of(_one_tile(pen_gate(0b1010))),
        "pig_shelter": items.icon_of(pig_shelter()),
    }
