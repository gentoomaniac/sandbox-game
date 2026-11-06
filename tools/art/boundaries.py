"""Art for the lines that run across the land: the Knick (a hedge of hazel and hawthorn on an earth
bank).

A line is drawn tile by tile, and each tile has 16 pictures, one per connection mask: which of
its 4 sides it joins a neighbour on (bit 0 north, 1 east, 2 south, 3 west, as World
CONNECTION_SIDES in the game). Picture n of an atlas row is mask n.

Each line is a solid on the ground: a stack of layers (bank, hedge) whose heights depend on how
far a ground pixel is from the line's skeleton, the centre of the tile and the arms to the sides
it joins. It is drawn in the 3/4 view of everything else, a pixel at height z shown z rows up,
and shaded by the slope of its layer with light from the top left. A tile draws only the columns
that stand on its own 16x16 ground, but it works them out over its neighbours too, as if the line
ran on straight into them, so outlines and shading meet across the seams. Textures that depend
on the position repeat every 16 px for the same reason. The ground shadow falls to the lower
right.
"""

import math

from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, TILE, blank

# The sides a line joins, as (bit, direction), in the order of the mask bits.
SIDES = ((1, (0, -1)), (2, (1, 0)), (4, (0, 1)), (8, (-1, 0)))
MASKS = range(16)
# The ground worked out around a tile: its neighbours on every side.
_REACH = TILE
_CENTRE = TILE / 2
# Light from the top left of the screen: from the west and from above, a little from the front.
_LIGHT = (-0.6, 0.15, 0.8)
_LIGHT_LENGTH = math.sqrt(sum(c * c for c in _LIGHT))


def skeleton_distance(mask, x, y):
    """How far the point (x, y) of the ground is from the skeleton of a tile with `mask`: its
    centre and an arm to each side it joins, running on through the neighbour."""
    best = math.hypot(x - _CENTRE, y - _CENTRE)
    for bit, (dx, dy) in SIDES:
        if mask & bit:
            along = min(max((x - _CENTRE) * dx + (y - _CENTRE) * dy, 0.0), TILE + _REACH)
            best = min(best, math.hypot(x - _CENTRE - dx * along, y - _CENTRE - dy * along))
    return best


def periodic(x, y, terms):
    """A smooth wave over the ground that repeats every tile, so it matches across the seams:
    the sum of (amplitude, cycles across x, cycles across y, phase) terms."""
    return sum(
        amplitude * math.sin(2 * math.pi * (fx * x + fy * y) / TILE + phase)
        for amplitude, fx, fy, phase in terms
    )


def _brightness(gradient_x, gradient_y):
    """How lit a surface with this slope is, -1 to 1."""
    normal = (-gradient_x, -gradient_y, 1.0)
    length = math.sqrt(sum(c * c for c in normal))
    return sum(n * l for n, l in zip(normal, _LIGHT)) / length / _LIGHT_LENGTH


_FACE_LIGHT = _brightness(0.0, 3.0)


def draw_line(mask, layers, colour, outline, shadow_reach=1):
    """One tile of a line as an object cell (48x80, the tile at its bottom centre).

    `layers(mask, x, y)` gives the layers that stand on ground pixel (x, y) of the tile (outside
    0..15 on the neighbours), bottom first, as (height of its top, material); heights are whole
    pixels and grow. `colour(material, x, y, z, light, is_top)` picks a pixel's colour, `light`
    -1 to 1, and `outline(material)` the colour of the silhouette (None for none)."""
    span = range(-_REACH, TILE + _REACH)
    stacks = {(x, y): layers(mask, x, y) for y in span for x in span}

    def height(x, y, index=None):
        stack = stacks.get((x, y), ())
        if index is None:
            return stack[-1][0] if stack else 0
        return stack[index][0] if index < len(stack) else 0

    # (screen x, screen y) -> (colour, material, owned): back to front, so the columns in front
    # cover those behind. Owned pixels stand on the tile's own ground.
    screen = {}
    for y in span:
        for x in span:
            stack = stacks[(x, y)]
            owned = 0 <= x < TILE and 0 <= y < TILE
            if not stack:
                continue
            bottom = 0
            for index, (top, material) in enumerate(stack):
                gradient_x = (height(x + 1, y, index) - height(x - 1, y, index)) / 2
                gradient_y = (height(x, y + 1, index) - height(x, y - 1, index)) / 2
                light = _brightness(gradient_x, gradient_y)
                # Below the top of a steep layer is its face, which looks to the front.
                face_light = _FACE_LIGHT if abs(gradient_y) > 2 else light
                for z in range(bottom + 1, top + 1):
                    is_top = z == top
                    shade = light if is_top else face_light
                    screen[(x, y - z)] = (colour(material, x, y, z, shade, is_top), material, owned)
                bottom = top
    # The ground shadow, on ground nothing stands on, below and right of what does.
    for y in span:
        for x in span:
            if stacks[(x, y)] or (x, y) in screen:
                continue
            if any(stacks.get((x - step, y - step)) or stacks.get((x, y - step)) for step in range(1, shadow_reach + 1)):
                screen[(x, y)] = ("shadow", None, 0 <= x < TILE and 0 <= y < TILE)

    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    left, ground_top = (OBJECT_CELL_WIDTH - TILE) // 2, OBJECT_BOTTOM + 1 - TILE
    for (x, y), (name, material, owned) in screen.items():
        if not owned or not 0 <= ground_top + y < OBJECT_CELL_HEIGHT:
            continue
        if material is not None and outline(material) is not None:
            is_edge = any(
                (x + dx, y + dy) not in screen or screen[(x + dx, y + dy)][1] is None
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            )
            if is_edge:
                name = outline(material)
        canvas[ground_top + y][left + x] = name
    return canvas


def _cluster(x, y, z, salt):
    """A value in [-1, 1) that is the same over 2x2 clusters of pixels and repeats every tile,
    for the texture of leaves and turf."""
    cell = (x // 2 % (TILE // 2), y // 2 % (TILE // 2), z // 2, salt)
    value = 0
    for part in cell:
        value = (value * 1103515245 + part * 12345 + 1013904223) % 2**31
        value ^= value >> 13
    return value % 2000 / 1000 - 1


def _ramp(shades, light):
    """The shade of a ramp (lightest first) for a light of -1 to 1."""
    index = round((0.85 - light) / 1.25 * (len(shades) - 1))
    return shades[min(len(shades) - 1, max(0, index))]


# --- The Knick ---

# The earth bank: this many px high, flat on top out to BANK_CREST from the skeleton and down to
# the ground at BANK_FOOT, under turf.
BANK_HEIGHT = 6
BANK_CREST = 2.5
BANK_FOOT = 7.5
# The hedge on the crest: a rounded core this wide out from the skeleton and this high above
# the bank, with bushes of hazel and hawthorn rising out of it.
HEDGE_REACH = 3.5
HEDGE_CORE = 10
# The bushes along an arm, at these places in every tile along it (so a straight hedge repeats
# every tile and neighbours agree): (along, across, ground radius, height above the bank,
# species). One stands on the centre of every tile too.
BUSHES = (
    (2.0, -0.5, 5.0, 15, "hazel"),
    (10.0, 0.0, 5.5, 16, "hawthorn"),
)
CENTRE_BUSH = (0.0, -0.5, 4.5, 15, "hazel")
# How ragged the bushes are: their radius waves by this much around them.
_RAGGED = ((0.9, 3, 2, 0.4), (0.7, 2, -3, 2.9), (0.5, 4, 1, 1.3))
# A bush rises this much out of the core at its middle.
BUSH_RISE = 5
# Hazel and hawthorn, lit to dark; their outline is the darkest shade.
HAZEL = ("green_bright", "green_light", "green", "green_dark")
HAWTHORN = ("meadow_light", "meadow", "green_deep", "bog_dark")
TURF = ("dry_light", "dry", "olive")


def _bushes(mask):
    """The bushes of a tile's hedge as (x, y, ground radius, height, species), in the ground
    coordinates of the tile, on the arms it has and running on through the neighbours."""
    x, y, radius, height, species = CENTRE_BUSH
    bushes = [(_CENTRE + x, _CENTRE + y, radius, height, species)]
    for bit, (dx, dy) in SIDES:
        if not mask & bit:
            continue
        for tile in range(-1, 3):
            for along, across, radius, height, species in BUSHES:
                place = tile * TILE + along
                # Only the part of the arm out from the centre: vertical arms put the bushes a
                # little off the horizontal ones' places, so a corner does not stack two.
                if dy:
                    place += 3
                offset = (place - _CENTRE) * (dx + dy)
                if 0 < offset <= TILE + _REACH:
                    bushes.append((
                        place if dx else _CENTRE + across,
                        place if dy else _CENTRE + across,
                        radius, height, species,
                    ))
    return bushes


_BUSH_CACHE = {}


def _knick_layers(mask, x, y):
    px, py = x + 0.5, y + 0.5
    distance = skeleton_distance(mask, px, py)
    if distance >= BANK_FOOT:
        return []
    slope = max(0.0, (distance - BANK_CREST) / (BANK_FOOT - BANK_CREST))
    bank = max(1, round(BANK_HEIGHT * (1 - slope * slope)))
    layers = [(bank, "bank")]
    if mask not in _BUSH_CACHE:
        _BUSH_CACHE[mask] = _bushes(mask)
    top, species, nearest = 0.0, None, None
    ragged = periodic(x, y, _RAGGED)
    for bx, by, radius, height, kind in _BUSH_CACHE[mask]:
        reach = math.hypot(px - bx, py - by)
        radius += ragged
        if nearest is None or reach < nearest[0]:
            nearest = (reach, kind)
        if reach < radius:
            dome = height - BUSH_RISE + BUSH_RISE * math.sqrt(1 - (reach / radius) ** 2)
            if dome > top:
                top, species = dome, kind
    if distance < HEDGE_REACH:
        core = HEDGE_CORE * math.sqrt(1 - (distance / HEDGE_REACH) ** 2)
        if core > top:
            top, species = core, nearest[1]
    if species is not None and round(top) >= 1:
        layers.append((bank + round(top), species))
    return layers


def _knick_colour(material, x, y, z, light, is_top):
    if material == "bank":
        return _ramp(TURF, light - 0.15)
    shades = HAZEL if material == "hazel" else HAWTHORN
    # Leaves in clusters, darker low in the hedge where the crowns shade it.
    # The clusters of a face lie on the screen, so they don't run down it in streaks.
    cluster = _cluster(x, y, z, 2) if is_top else _cluster(x, y - z, 0, 3)
    light += 0.35 * cluster - (0.35 if z < BANK_HEIGHT + 4 else 0)
    return _ramp(shades, light)


def _knick_outline(material):
    return {"bank": None, "hazel": HAZEL[-1], "hawthorn": HAWTHORN[-1]}[material]


def knick(mask):
    return draw_line(mask, _knick_layers, _knick_colour, _knick_outline, shadow_reach=2)


def knick_row():
    """The atlas row of the Knick: one picture per connection mask."""
    return [knick(mask) for mask in MASKS]
