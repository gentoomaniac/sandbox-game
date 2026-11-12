"""Art for the lines that run across the land: the Knick (a hedge of hazel and hawthorn on an earth
bank), the wattle fence, the fieldstone wall and the dyke, drawn at 32 px per tile.

A line is drawn tile by tile, and each tile has 16 pictures, one per connection mask: which of
its 4 sides it joins a neighbour on (bit 0 north, 1 east, 2 south, 3 west, as World
CONNECTION_SIDES in the game). A line can have variants of these, which differ only inside the
tile, so they all meet at the seams: picture v * 16 + n of an atlas row is variant v of mask n.

Each line is a solid on the ground: a stack of layers (bank, hedge) whose heights depend on how
far a ground pixel is from the line's skeleton, the centre of the tile and the arms to the sides
it joins. It is drawn in the 3/4 view of everything else, a pixel at height z shown z rows up,
and shaded by the slope of its layer with light from the top left. A tile draws only the columns
that stand on its own 32x32 ground, but it works them out over its neighbours too, as if the line
ran on straight into them, so outlines and shading meet across the seams. Textures that depend
on the position repeat every tile for the same reason. The ground shadow falls to the lower
right. Each line is rimmed in the darkest shade of its own colours where it stands against the
ground; the dyke, which is turf like the ground, is not.
"""

import math
import random

import items
from canvas import GAME_OBJECT_BOTTOM, GAME_OBJECT_CELL_HEIGHT, GAME_OBJECT_CELL_WIDTH, GAME_TILE, blank

TILE = GAME_TILE
# The sides a line joins, as (bit, direction), in the order of the mask bits.
SIDES = ((1, (0, -1)), (2, (1, 0)), (4, (0, 1)), (8, (-1, 0)))
MASKS = range(16)
# The Knick and the wall have variants, so a long line does not repeat every tile.
LINE_VARIANTS = 3
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


def draw_line(mask, layers, colour, outline, shadow_reach=2, joints=False, has_faces=True):
    """One tile of a line as an object cell (96x160, the tile at its bottom centre).

    `layers(mask, x, y)` gives the layers that stand on ground pixel (x, y) of the tile (outside
    0..31 on the neighbours), bottom first, as (height of its top, material); heights are whole
    pixels and grow, and a layer of material None is a gap, through which what is behind shows
    (the ground under a fence's rails). `colour(material, x, y, z, light, is_top)` picks a pixel's
    colour, `light` -1 to 1, and `outline(material)` the colour of the silhouette (None for none).
    With `joints` the outline also runs where a material meets another above or beside it (between
    stones).
    Steep layers have a face that looks to the front (a hedge, a fence); without `has_faces`
    every pixel is shaded by its slope (round stones)."""
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
                # A layer of no material is a gap: what is behind shows through it.
                if material is None:
                    bottom = top
                    continue
                gradient_x = (height(x + 1, y, index) - height(x - 1, y, index)) / 2
                gradient_y = (height(x, y + 1, index) - height(x, y - 1, index)) / 2
                light = _brightness(gradient_x, gradient_y)
                # Below the top of a steep layer is its face, which looks to the front.
                face_light = _FACE_LIGHT if has_faces and abs(gradient_y) > 2 else light
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

    canvas = blank(GAME_OBJECT_CELL_WIDTH, GAME_OBJECT_CELL_HEIGHT)
    left, ground_top = (GAME_OBJECT_CELL_WIDTH - TILE) // 2, GAME_OBJECT_BOTTOM + 1 - TILE
    for (x, y), (name, material, owned) in screen.items():
        if not owned or not 0 <= ground_top + y < GAME_OBJECT_CELL_HEIGHT:
            continue
        if material is not None and outline(material) is not None:
            is_edge = any(
                (x + dx, y + dy) not in screen
                or screen[(x + dx, y + dy)][1] is None
                or (joints and dy <= 0 and screen[(x + dx, y + dy)][1] != material)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            )
            if is_edge:
                name = outline(material)
        canvas[ground_top + y][left + x] = name
    return canvas


def pixel_hash(*parts):
    """A value in [-1, 1) for whole numbers `parts`, the same every run."""
    value = 0
    for part in parts:
        value = (value * 1103515245 + part * 12345 + 1013904223) % 2**31
        value ^= value >> 13
    return value % 2000 / 1000 - 1


def _cluster(x, y, z, salt, size=2):
    """A value in [-1, 1) that is the same over size x size clusters of pixels and repeats every
    tile, for the texture of turf and stone."""
    return pixel_hash(x // size % (TILE // size), y // size % (TILE // size), z // size, salt)


def ramp_shade(shades, light):
    """The shade of a ramp (lightest first) for a light of -1 to 1."""
    index = round((0.85 - light) / 1.25 * (len(shades) - 1))
    return shades[min(len(shades) - 1, max(0, index))]


# --- The Knick ---

# The earth bank: this many px high, flat on top out to BANK_CREST from the skeleton and down to
# the ground at BANK_FOOT, under turf.
BANK_HEIGHT = 12
BANK_CREST = 5.0
BANK_FOOT = 15.0
# The hedge on the crest: a low rounded core of leaves this wide out from the skeleton and this
# high above the bank, out of which the bushes of hazel and hawthorn rise.
HEDGE_REACH = 7.0
HEDGE_CORE = 14
# The bushes along an arm, at these places in every tile along it (so a straight hedge repeats
# every tile and neighbours agree): (along, across, half width, height above the bank,
# species). One stands on the centre of every tile too.
BUSHES = (
    (4.0, -1.0, 13.0, 26, "hazel"),
    (20.0, 0.0, 13.0, 28, "hawthorn"),
)
CENTRE_BUSH = (0.0, -1.0, 12.0, 26, "hazel")
# Hazel and hawthorn, lit to dark, and the edge of their leaves: hazel is light and fresh,
# hawthorn dark and dense.
HAZEL = ("green_bright", "green_light", "green", "green_dark")
HAWTHORN = ("meadow_light", "meadow", "green_deep", "green_deep")
LEAF_EDGES = {"hazel": "green_dark", "hawthorn": "bog_dark"}
TURF = ("dry_light", "dry", "olive")


def _bushes(mask, variant):
    """The bushes of a tile's hedge as (x, y, half width, height, species), in the ground
    coordinates of the tile, on the arms it has and running on through the neighbours. The
    bushes that stand inside the tile are of another size or kind in each variant but the first;
    those across its seams are the same in all."""
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
                    place += 6
                offset = (place - _CENTRE) * (dx + dy)
                if 0 < offset <= TILE + _REACH:
                    bushes.append((
                        place if dx else _CENTRE + across,
                        place if dy else _CENTRE + across,
                        radius, height, species,
                    ))
    if variant == 0:
        return bushes
    rng = random.Random(f"knick-{mask}-{variant}")
    varied = []
    for bx, by, radius, height, species in bushes:
        if 0 <= bx < TILE and 0 <= by < TILE:
            radius += rng.uniform(-2.0, 1.5)
            height += rng.choice((-4, -2, 0, 2, 4))
            if rng.random() < 0.5:
                species = "hazel" if species == "hawthorn" else "hawthorn"
        varied.append((bx, by, radius, height, species))
    return varied


def _bank_height(mask, x, y):
    """The height of the Knick's bank over the ground point (x, y), 0 off it."""
    distance = skeleton_distance(mask, x, y)
    if distance >= BANK_FOOT:
        return 0
    slope = max(0.0, (distance - BANK_CREST) / (BANK_FOOT - BANK_CREST))
    return max(1, round(BANK_HEIGHT * (1 - slope * slope)))


def _knick_layers(mask, x, y):
    px, py = x + 0.5, y + 0.5
    bank = _bank_height(mask, px, py)
    if not bank:
        return []
    layers = [(bank, "bank")]
    distance = skeleton_distance(mask, px, py)
    if distance < HEDGE_REACH:
        core = round(HEDGE_CORE * math.sqrt(1 - (distance / HEDGE_REACH) ** 2))
        if core >= 1:
            layers.append((bank + core, "core"))
    return layers


def _knick_colour(material, x, y, z, light, is_top):
    if material == "bank":
        # Turf in tufts: the face's tufts lie on the screen, so they don't run down it.
        tuft = _cluster(x, y, z, 1) if is_top else _cluster(x, y - z, 0, 1)
        return ramp_shade(TURF, light - 0.15 + 0.25 * tuft)
    # The core of the hedge, in the shade of the bushes over it: dark leaves and stems.
    return "green_dark" if _cluster(x, y - z, 0, 2) > 0.2 else "green_deep"


def _knick_outline(material):
    return None


def _bush(canvas, rng, cx, base, half_width, height, species):
    """A bush of the hedge on the canvas, standing on screen row `base` round column `cx`: a
    ragged dome `half_width` px to either side and `height` px tall, lit from the top left, its
    surface broken into sprays of leaves about 3 px across, each lit on its own upper left and
    dark where it meets the next, darker towards its foot, rimmed in the darkest leaves."""
    shades = HAZEL if species == "hazel" else HAWTHORN
    edge = LEAF_EDGES[species]
    cy = base - height / 2
    ry = height / 2 + 1
    phase, lobes = rng.uniform(0, 6.3), rng.choice((7, 8, 9))
    points = []
    count = max(6, round(math.pi * half_width * ry / 7))
    while len(points) < count:
        px, py = rng.uniform(-1, 1), rng.uniform(-1, 1)
        if px * px + py * py <= 1:
            points.append((cx + px * half_width, cy + py * ry))
    drawn = set()
    levels = {}
    for y in range(math.floor(cy - ry - 2), base + 1):
        for x in range(math.floor(cx - half_width - 2), math.ceil(cx + half_width + 2)):
            u, v = (x + 0.5 - cx) / half_width, (y + 0.5 - cy) / ry
            angle = math.atan2(v, u)
            ragged = 1 + 0.07 * math.sin(angle * lobes + phase) + 0.04 * math.sin(angle * 15 + phase * 2)
            distance = math.hypot(u, v) / ragged
            if distance > 1 or not 0 <= x < GAME_OBJECT_CELL_WIDTH:
                continue
            rise = math.sqrt(max(0.0, 1 - distance * distance))
            lit = (-0.55 * u - 0.75 * v + 0.75 * rise) / 1.2
            near = sorted((math.hypot(x + 0.5 - px, y + 0.5 - py), px, py) for px, py in points)[:2]
            (first, px, py), (second, _, _) = near
            spray = -((x + 0.5 - px) * 0.6 + (y + 0.5 - py) * 0.8) / 3
            seam = max(0.0, 1 - (second - first) / 1.2)
            foot = 0.35 * (y - (cy - ry)) / (2 * ry)
            levels[(x, y)] = lit + 0.3 * spray - 0.45 * seam - foot
            drawn.add((x, y))
    for (x, y), level in levels.items():
        is_rim = any((x + dx, y + dy) not in drawn for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if is_rim or level < -0.7:
            canvas[y][x] = edge
        else:
            canvas[y][x] = shades[sum(level <= threshold for threshold in (0.55, 0.25, -0.1))]


def knick(mask, variant=0):
    """A tile of the Knick: the bank and the low core of its hedge as a line (see `draw_line`),
    and the bushes that stand on the tile's own ground, each drawn whole by this tile, from the
    back to the front. Each bush's leaves are the same in every picture it is in."""
    canvas = draw_line(mask, _knick_layers, _knick_colour, _knick_outline, shadow_reach=4)
    left, ground_top = (GAME_OBJECT_CELL_WIDTH - TILE) // 2, GAME_OBJECT_BOTTOM + 1 - TILE
    own = [bush for bush in _bushes(mask, variant) if 0 <= bush[0] < TILE and 0 <= bush[1] < TILE]
    for bx, by, half_width, height, species in sorted(own, key=lambda bush: (bush[1], bush[0])):
        rng = random.Random(f"bush-{bx}-{by}-{half_width}-{height}-{species}")
        base = ground_top + round(by) - _bank_height(mask, bx, by) + 2
        _bush(canvas, rng, left + bx, base, half_width, height, species)
    return canvas


def knick_row():
    """The atlas row of the Knick: its variants, one picture per connection mask each."""
    return [knick(mask, variant) for variant in range(LINE_VARIANTS) for mask in MASKS]


# --- The wattle fence ---

# Hazel rods woven between stakes, about knee high: this far out from the skeleton (wide enough
# that a fence running north-south, seen from above, still shows its rods) and this high, the
# posts higher, one every POST_SPACING px, POST_WIDTH px thick. Between them the rods go round
# thin stakes every WEAVE px, in front of one and behind the next, the stakes' tips showing over
# the rods.
WATTLE_REACH = 2.5
WATTLE_HEIGHT = 18
STAKE_HEIGHT = 20
POST_HEIGHT = 24
POST_SPACING = 16
POST_WIDTH = 3
WEAVE = 8
RODS = ("sand_light", "sand", "mud", "mud_dark")
POSTS = ("soil_light", "soil_mid", "soil", "soil_dark")


def along_line(x, y):
    """Where a pixel lies along the line: x on an arm running east-west, y on one running
    north-south."""
    return y if abs(x + 0.5 - _CENTRE) < abs(y + 0.5 - _CENTRE) else x


def _wattle_layers(mask, x, y):
    if skeleton_distance(mask, x + 0.5, y + 0.5) >= WATTLE_REACH:
        return []
    along = along_line(x, y)
    if (along + 1) % POST_SPACING < POST_WIDTH:
        return [(POST_HEIGHT, "post")]
    if along % WEAVE == WEAVE - 1:
        return [(WATTLE_HEIGHT, "rods"), (STAKE_HEIGHT, "stake")]
    return [(WATTLE_HEIGHT, "rods")]


def _wattle_colour(material, x, y, z, light, is_top):
    along = along_line(x, y)
    if material in ("post", "stake"):
        # A split post, its top cut flat and lit, its left side catching the light.
        side = (along + 1) % POST_SPACING if material == "post" else 1
        side_light = 0.2 if side == 0 else -0.2 if side == POST_WIDTH - 1 else 0.0
        return ramp_shade(POSTS, light + (0.3 if is_top else 0.0) + side_light)
    # The rods are 2 px thick, lit on top and dark below. Between two stakes a rod comes out in
    # front, bulging lit in the middle, or lies behind in the shade, in turn along it and from one
    # rod to the next, so the weave shows.
    rod = z // 2
    is_out = (along // WEAVE + rod) % 2 == 0
    middle = 1 - abs(along % WEAVE - (WEAVE - 1) / 2) / (WEAVE / 2)
    band = 0.25 if z % 2 == 0 else -0.2
    weave = 0.35 * middle if is_out else -0.3
    # Some rods are older and greyer than others.
    age = 0.15 * pixel_hash(along // WEAVE % (TILE // WEAVE), rod, 9)
    return ramp_shade(RODS, light + band + weave + age + (0.1 if is_top else 0.0))


def _wattle_outline(material):
    # A fence running north-south is seen from above, as a thin line: an outline would make it
    # all dark.
    return {"post": POSTS[-1], "stake": None, "rods": None}[material]


def wattle_fence(mask):
    return draw_line(mask, _wattle_layers, _wattle_colour, _wattle_outline)


def wattle_fence_row():
    """The atlas row of the wattle fence: one picture per connection mask."""
    return [wattle_fence(mask) for mask in MASKS]


# --- The fieldstone wall ---

# Round boulders from the fields, stacked dry: big stones every STONE_SPACING px along the
# skeleton, smaller ones on top between them, each a squat dome longer along the wall than
# across it: (along, across, height) and (along, across, base, height) in px.
STONE_SPACING = 16
BASE_STONE = (9.5, 7.5, 8.0)
TOP_STONE = (8.5, 6.0, 6.0, 7.0)
# Granite in a cool and a warm grey, lit to dark; moss on the tops.
COOL_STONE = ("stone_light", "stone", "stone_dark")
WARM_STONE = ("sand_light", "bare_light", "bare", "stone_dark")


def _stones(mask, variant):
    """The stones of a tile's wall as (x, y, along, across, base, height, is_warm, runs_across),
    in its ground coordinates, on its arms and on through the neighbours; `runs_across` if the
    wall runs east-west there. Their sizes come from their place along the line, so neighbours
    agree; the stones inside the tile are of another size or grey in each variant but the
    first."""
    places = {(_CENTRE, _CENTRE): not mask & (1 | 4)}
    for bit, (dx, dy) in SIDES:
        if mask & bit:
            for step in range(1, (TILE + _REACH) * 2 // STONE_SPACING + 1):
                offset = step * STONE_SPACING / 2
                places[(_CENTRE + dx * offset, _CENTRE + dy * offset)] = dx != 0
    stones = []
    rng = random.Random(f"wall-{mask}-{variant}")
    for (x, y), runs_across in sorted(places.items()):
        # Repeats every tile: a tile is 4 places long.
        index = round(x + y) // (STONE_SPACING // 2) % (TILE * 2 // STONE_SPACING)
        wobble = (index * 7 % 5 - 2) * 0.3
        is_warm = index * 5 % 3 == 0
        if index % 2 == 0:
            along, across, height = BASE_STONE
            base = 0.0
        else:
            along, across, base, height = TOP_STONE
        place = x if runs_across else y
        if variant and along <= place <= TILE - along:
            wobble += rng.uniform(-1.0, 0.8)
            height += rng.choice((-2, 0, 2))
            is_warm = rng.random() < 0.4
        stones.append((x, y, along + wobble, across + wobble / 2, base, height, is_warm, runs_across))
    return stones


def _wall_layers(stones, mask, x, y):
    px, py = x + 0.5, y + 0.5
    best = None
    for sx, sy, along, across, base, height, is_warm, runs_across in stones:
        reach_x, reach_y = (along, across) if runs_across else (across, along)
        reach = ((px - sx) / reach_x) ** 2 + ((py - sy) / reach_y) ** 2
        if reach < 1:
            top = base + height * math.sqrt(1 - reach)
            if best is None or top > best[0]:
                best = (top, (round(sx), round(sy), is_warm))
    if best is None or round(best[0]) < 1:
        return []
    return [(round(best[0]), best[1])]


def _wall_colour(material, x, y, z, light, is_top):
    is_warm = material[2]
    # Moss and lichen in patches on the lit tops.
    if is_top and light > 0.45 and _cluster(x, y, z, 4) > 0.55:
        return "olive" if _cluster(x, y, z, 6, 1) > -0.3 else "dry"
    # The grain of the granite, in specks of the next shade.
    light += 0.22 * _cluster(x, y - z, 0, 5, 1)
    return ramp_shade(WARM_STONE if is_warm else COOL_STONE, light)


def _wall_outline(material):
    return "stone_dark"


def stone_wall(mask, variant=0):
    stones = _stones(mask, variant)
    return draw_line(
        mask,
        lambda mask, x, y: _wall_layers(stones, mask, x, y),
        _wall_colour,
        _wall_outline,
        joints=True,
        has_faces=False,
    )


def stone_wall_row():
    """The atlas row of the fieldstone wall: its variants, one picture per connection mask each."""
    return [stone_wall(mask, variant) for variant in range(LINE_VARIANTS) for mask in MASKS]


# --- The dyke ---

# A long smooth bank of clay under turf, the whole tile wide: this many px high on its crest,
# which is DYKE_CREST px either side of the skeleton, and down to the ground at the tile's edges
# across it. Where it turns a corner it bends round in a quarter circle, so a dyke that runs on the
# slant (a stair of corners) is one bank winding along.
DYKE_HEIGHT = 14
DYKE_CREST = 3.0
DYKE_FOOT = TILE / 2
DYKE_TURF = ("green_light", "green", "green_dark", "green_deep")
# The sheep keep a track along the crest: it is this wide, in px either side of the skeleton.
DYKE_TRACK = 1.5


def dyke_skeleton_distance(mask, x, y):
    """`skeleton_distance` for the dyke: a tile joined on two sides that meet at a corner (north
    and east, say) has, in place of its centre and two arms, a quarter circle round that corner
    from the middle of one side to the middle of the other. Across each of those sides its
    distances are those of a straight arm, so it meets its neighbours."""
    sides = [direction for bit, direction in SIDES if mask & bit]
    is_straight = len(sides) == 2 and sides[0][0] + sides[1][0] == 0 and sides[0][1] + sides[1][1] == 0
    if len(sides) != 2 or is_straight:
        return skeleton_distance(mask, x, y)
    corner_x = _CENTRE + _CENTRE * (sides[0][0] + sides[1][0])
    corner_y = _CENTRE + _CENTRE * (sides[0][1] + sides[1][1])
    # The quarter of the circle lies in the tile; past the tile's sides the arms run on straight
    # into the neighbours.
    best = math.inf
    if (x - corner_x) * (_CENTRE - corner_x) >= 0 and (y - corner_y) * (_CENTRE - corner_y) >= 0:
        best = abs(math.hypot(x - corner_x, y - corner_y) - _CENTRE)
    for dx, dy in sides:
        start_x, start_y = _CENTRE + dx * _CENTRE, _CENTRE + dy * _CENTRE
        along = min(max((x - start_x) * dx + (y - start_y) * dy, 0.0), _REACH + _CENTRE)
        best = min(best, math.hypot(x - start_x - dx * along, y - start_y - dy * along))
    return best


def _dyke_layers(mask, x, y):
    distance = dyke_skeleton_distance(mask, x + 0.5, y + 0.5)
    if distance >= DYKE_FOOT:
        return []
    slope = max(0.0, distance - DYKE_CREST) / (DYKE_FOOT - DYKE_CREST)
    height = round(DYKE_HEIGHT * (math.cos(math.pi * slope) + 1) / 2)
    if height < 1:
        return []
    return [(height, "track" if distance < DYKE_TRACK else "turf")]


def _dyke_colour(material, x, y, z, light, is_top):
    # Grazed short: a turf of tufts in clusters, smoother than the hedge's leaves, its blades
    # lit at the tip; on the crest the sheep's track, worn to the paler, drier grass.
    if material == "track" and is_top:
        return "dry_light" if _cluster(x, y, z, 7, 1) > -0.4 else "dry"
    tuft = 0.12 * _cluster(x, y, z, 5) + 0.1 * _cluster(x, y, z, 8, 1)
    return ramp_shade(DYKE_TURF, light + tuft)


def _dyke_outline(material):
    return None


def dyke(mask):
    return draw_line(mask, _dyke_layers, _dyke_colour, _dyke_outline, has_faces=False)


def dyke_row():
    """The atlas row of the dyke: one picture per connection mask."""
    return [dyke(mask) for mask in MASKS]


def one_tile(picture):
    """A line's cell cut to the tile it stands on (the middle third of the cell), for an icon."""
    return [row[TILE : 2 * TILE] for row in picture]


def icons():
    """The bodies of the icons of the items that put a wattle fence or a stone wall down."""
    return {
        "wattle_fence": items.icon_of(one_tile(wattle_fence(0b1010))),
        "stone_wall": items.icon_of(one_tile(stone_wall(0b1010))),
    }
