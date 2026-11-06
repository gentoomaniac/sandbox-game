"""The ground: the terrain layers of assets/terrain.png and their decorations in
assets/decorations.png.

Tiles are drawn as 16x16 grids of palette colour names (None = transparent). Each terrain layer
has one function that returns its atlas row and its decorations; `LAYERS` lists them bottom to
top: water, floodplain, wetland, grass, lush grass, dry grass, trodden grass, path, soil. Both
atlases are read by game/scenes/terrain_tileset.gd.

assets/terrain.png, per row:
- EDGE_VARIANTS blocks of 15 columns: the dual-grid edge shapes for masks 0..14 (mask 0
  stays empty). A mask bit is set when that corner's world tile is on this layer or above;
- then the full-tile variants (mask 15), at least one per row.

assets/decorations.png, per row: small visual-only sprites (pebbles, tufts, reeds...)
drawn on top of world tiles of that layer. A row may be empty. Under the layers' rows comes
one more, the meadow flowers of flowers.py.
"""

import math
import random

from canvas import NEIGHBOURS, TILE, blank, copy, filled

# Dual-grid corner bits, shared with game/scenes/terrain_tileset.gd.
TL, TR, BL, BR = 1, 2, 4, 8
FULL = TL | TR | BL | BR
# Edge-shape variants per mask, shared with game/scenes/terrain_tileset.gd.
EDGE_VARIANTS = 3


def sprite(keys, *rows):
    """A small picture: rows of characters, each mapped to a colour by `keys` ("." is clear)."""
    return {"keys": keys, "rows": rows}


def stamp(tile, picture, x, y):
    """Draws a sprite. It wraps around the tile edges, so textures stay seamless."""
    for dy, row in enumerate(picture["rows"]):
        for dx, char in enumerate(row):
            if char != ".":
                tile[(y + dy) % TILE][(x + dx) % TILE] = picture["keys"][char]


def sprinkle(tile, rng, pictures, spacing, chance):
    """Scatters sprites evenly but not in a grid: one chance per spacing x spacing cell,
    at a random spot inside it. Sprites stay inside the tile, so every variant can have
    its own scatter and still fit next to any other."""
    for cell_y in range(0, TILE, spacing):
        for cell_x in range(0, TILE, spacing):
            if rng.random() < chance:
                picture = rng.choice(pictures)
                width = max(len(row) for row in picture["rows"])
                height = len(picture["rows"])
                x = min(cell_x + rng.randrange(spacing), TILE - width)
                y = min(cell_y + rng.randrange(spacing), TILE - height)
                stamp(tile, picture, x, y)


def details(texture, seed, *pictures):
    """A full-tile variant: its own scatter of the terrain's texture, plus a few sprites
    inside the tile, clear of the border. Nothing crosses the border, so any variant fits
    next to any other."""
    rng = random.Random(seed)
    tile = texture(seed)
    for picture in pictures:
        width = max(len(row) for row in picture["rows"])
        height = len(picture["rows"])
        stamp(tile, picture, rng.randrange(1, TILE - width), rng.randrange(1, TILE - height))
    return tile


def decoration(seed, *pictures):
    """A decoration: sprites on a clear tile, inside its middle so they stay on the
    terrain they belong to."""
    return details(lambda seed: blank(), seed, *pictures)


def periodic_noise(seed, waves):
    """A smooth noise field that repeats every TILE pixels on both axes, so it lines up
    across neighbouring tiles. `waves` are (frequency, weight) pairs; result is about -1..1.
    """
    rng = random.Random(seed)
    terms = []
    for frequency, weight in waves:
        angle = rng.uniform(0, math.tau)
        fx = round(math.cos(angle) * frequency)
        fy = round(math.sin(angle) * frequency)
        if fx == 0 and fy == 0:
            fx = frequency
        terms.append((fx, fy, rng.uniform(0, math.tau), weight))
    total = sum(weight for *_, weight in terms)

    def noise(x, y):
        value = sum(w * math.sin(math.tau * (fx * x + fy * y) / TILE + p) for fx, fy, p, w in terms)
        return value / total

    return noise


def edge_shapes(seed, waves, roughness):
    """The coverage functions of a terrain's edge tiles: shapes[variant][mask](x, y).

    The cell's corners sit on the centres of its 4 world tiles. Corner coverage is blended
    bilinearly across the cell, so the edge runs along the tile border and rounds off at
    corners. A periodic noise shared by all variants bends it into an irregular line that
    meets the neighbouring cells' edges; each variant adds its own noise, faded out
    towards the cell border, so variants differ inside but still fit together.

    covered(x, y) also answers for pixels just outside the cell, by extrapolating, so rims
    and overhangs along the cell border match the neighbour's. It only grows as corners
    are added to the mask, so a layer cut with the same shapes never sticks out of them.
    """
    shared = periodic_noise(seed, waves)
    shapes = []
    for variant in range(EDGE_VARIANTS):
        own = periodic_noise(seed * 10 + variant, waves)
        shapes.append([coverage(mask, shared, own, roughness) for mask in range(FULL)])
    return shapes


def coverage(mask, shared, own, roughness):
    corners = [1.0 if mask & bit else 0.0 for bit in (TL, TR, BL, BR)]

    def covered(x, y):
        u = (x + 0.5) / TILE
        v = (y + 0.5) / TILE
        top = corners[0] * (1 - u) + corners[1] * u
        bottom = corners[2] * (1 - u) + corners[3] * u
        value = top * (1 - v) + bottom * v
        fade = math.sin(math.pi * u) * math.sin(math.pi * v)
        return value + roughness * (shared(x, y) + 1.5 * fade * own(x, y)) > 0.5

    return covered


def edge_distance(covered, x, y, limit):
    """How far a covered pixel is from the terrain's edge: 1 on the rim, at most limit."""
    for distance in range(1, limit):
        for dx in range(-distance, distance + 1):
            dy = distance - abs(dx)
            if not covered(x + dx, y + dy) or not covered(x + dx, y - dy):
                return distance
    return limit


def is_rim(covered, x, y):
    """A covered pixel next to an uncovered one."""
    return covered(x, y) and not all(covered(x + dx, y + dy) for dx, dy in NEIGHBOURS)


def edge_tiles(texture, shapes, seed, decorate):
    """Every edge tile of a terrain: its own scatter of the texture, cut by each shape,
    then decorated. `decorate(tile, covered, rng)` gets its own random source per tile."""
    tiles = []
    for variant, masks in enumerate(shapes):
        for mask, covered in enumerate(masks):
            tile_seed = seed * 1000 + variant * 100 + mask
            full = texture(tile_seed)
            tile = [[full[y][x] if covered(x, y) else None for x in range(TILE)] for y in range(TILE)]
            if mask:
                decorate(tile, covered, random.Random(tile_seed))
            tiles.append(tile)
    return tiles


def blades(tile, covered, rng, colour, chance, direction, lengths):
    """Blades of grass sticking out of an edge, in `direction` (1 down, -1 up): uneven
    lengths, irregular spacing and the odd gap, so the edge does not look combed."""
    skip = 0
    for y in range(TILE):
        for x in range(TILE):
            if covered(x, y) or not covered(x, y - direction):
                continue
            if skip:
                skip -= 1
                continue
            if rng.random() > chance:
                continue
            for step in range(rng.choice(lengths)):
                ty = y + step * direction
                if not 0 <= ty < TILE or covered(x, ty):
                    break
                tile[ty][x] = colour
            skip = rng.choice((0, 1, 1, 2, 4))


# Terrains, bottom layer first. Each returns (atlas row, decorations). The atlas row is
# the edge tiles followed by the full variants. Every terrain has a texture function;
# each full variant is its own scatter of it plus details, edge tiles are cut from one.


def water():
    ripple = sprite({"d": "water_deep"}, "dddd")
    short_ripple = sprite({"d": "water_deep"}, "dd")
    glint = sprite({"l": "water_light"}, "ll")
    crest = sprite({"l": "water_light", "f": "foam"}, ".lf", "l..")
    lily = sprite({"g": "green_dark", "l": "green_light"}, ".ggg.", "gglgg", "gg.gg", ".ggg.")
    lily_flower = sprite(
        {"g": "green_dark", "l": "green_light", "p": "petal", "c": "cream"},
        ".ggg.",
        "gpcpg",
        "gglgg",
        ".ggg.",
    )

    # Flat water: its few marks all sit in the variants, so they never line up in a grid.
    def texture(seed):
        return filled("water")

    fulls = [
        details(texture, 11),
        details(texture, 12, ripple),
        details(texture, 13, short_ripple, glint),
        details(texture, 14, crest),
        details(texture, 15, ripple, short_ripple),
        details(texture, 16, glint),
        details(texture, 17),
        details(texture, 18, short_ripple),
    ]
    decorations = [decoration(19, lily), decoration(20, lily, lily), decoration(21, lily_flower)]
    # Water is the bottom layer and always full, so it needs no edge shapes.
    return [blank()] * (EDGE_VARIANTS * FULL) + fulls, decorations


def floodplain():
    blade = sprite({"l": "meadow_light", "d": "green_deep"}, "l", "d")
    dark_blade = sprite({"d": "green_deep"}, "d.d", ".d.")
    clover = sprite({"g": "green_light", "d": "green_deep"}, "g.g", "dgd")
    puddle = sprite(
        {"m": "mud_dark", "w": "water", "l": "water_light"},
        ".mmm.",
        "mwlwm",
        ".mmm.",
    )
    flowers = [
        sprite({"c": "cream", "d": "green_deep"}, "c..c", "d.cd", "..d."),
        sprite({"c": "gold", "d": "green_deep"}, ".c.", ".dc", "c.d", "d.."),
        sprite({"c": "petal", "d": "green_deep"}, "c.c", "d.d"),
    ]
    reed_keys = {"t": "straw", "r": "reed", "o": "olive", "c": "soil_mid"}
    reeds = sprite(reed_keys, "t..t.", "r.tr.", "rr.rt", "r.rr.", ".oro.")
    cattails = sprite(reed_keys, ".c..", ".c.c", ".r.c", "rr.r", ".rr.", ".o..")

    # A lush, damp meadow: fertile land, darker and richer than ordinary grass.
    def texture(seed):
        tile = filled("meadow")
        sprinkle(tile, random.Random(seed), [blade, blade, dark_blade], spacing=4, chance=0.55)
        return tile

    fulls = [
        details(texture, 21),
        details(texture, 22, clover),
        details(texture, 23, flowers[0]),
        details(texture, 24, puddle),
        details(texture, 25, clover, flowers[1]),
        details(texture, 26),
        details(texture, 27, flowers[2]),
        details(texture, 28, clover, clover),
    ]
    shapes = edge_shapes(20, [(1, 1.0), (2, 0.6), (3, 0.3)], 0.14)
    foam_noise = periodic_noise(25, [(3, 1.0), (5, 0.5)])

    def decorate(tile, covered, rng):
        # The floodplain only ever borders water below it: a narrow muddy bank, and a
        # line of foam on the water.
        for y in range(TILE):
            for x in range(TILE):
                if covered(x, y):
                    distance = edge_distance(covered, x, y, 4)
                    if distance == 1:
                        tile[y][x] = "mud_dark"
                    elif distance == 2 or (distance == 3 and (x + y) % 2):
                        tile[y][x] = "mud"
                elif is_rim(lambda x, y: not covered(x, y), x, y):
                    tile[y][x] = "foam" if foam_noise(x, y) > 0.3 else "water_light"

    decorations = [
        decoration(30, reeds),
        decoration(31, cattails),
        decoration(34, clover),
        decoration(35, puddle),
    ]
    return edge_tiles(texture, shapes, 20, decorate) + fulls, decorations


def wetland():
    sedge = sprite({"g": "green_dark"}, "g", "g")
    moss = sprite({"o": "olive"}, "o")
    reed_keys = {"t": "straw", "r": "reed", "o": "olive", "c": "soil_mid"}
    reeds = [
        sprite(reed_keys, "..t..", "t.r..", "r.r.t", "r.r.r", "rrr.r", ".rrr.", ".oo.."),
        sprite(reed_keys, "t..", "r.t", "rrr", "oro"),
        # Cattails.
        sprite(reed_keys, ".c..", ".c.c", ".r.c", "rr.r", ".rr.", ".o.."),
    ]
    pool = sprite(
        {"w": "water_deep", "l": "water", "b": "bog_dark"},
        ".bbbb..",
        "bwwlwb.",
        "bwwwwwb",
        ".bbbbb.",
    )
    toadstool = sprite({"e": "ember", "c": "cream", "s": "stone_light"}, ".eee.", "ecece", "..s..")
    brown_caps = sprite({"m": "soil_mid", "l": "soil_light", "s": "cream"}, ".m..", "mlm.", ".sml", ".s.s")

    def texture(seed):
        tile = filled("bog")
        sprinkle(tile, random.Random(seed), [sedge, sedge, moss], spacing=4, chance=0.4)
        return tile

    fulls = [
        details(texture, 31, reeds[0]),
        details(texture, 32, pool),
        details(texture, 33, reeds[1], reeds[2]),
        details(texture, 34, reeds[2]),
        details(texture, 35, reeds[0], reeds[1]),
        details(texture, 36),
        details(texture, 37, reeds[1]),
        details(texture, 38),
        details(texture, 39, reeds[2], reeds[2]),
        details(texture, 40, reeds[0]),
    ]
    shapes = edge_shapes(30, [(2, 1.0), (3, 0.7), (4, 0.3)], 0.18)

    def decorate(tile, covered, rng):
        # A dark soaked rim, with sedge poking out on the north side and seeping mud on
        # the south side.
        for y in range(TILE):
            for x in range(TILE):
                if is_rim(covered, x, y):
                    tile[y][x] = "bog_dark"
        blades(tile, covered, rng, "mud_dark", 0.5, 1, (1, 1, 2))
        blades(tile, covered, rng, "olive", 0.4, -1, (1, 2, 2, 3))

    decorations = [
        decoration(41, toadstool),
        decoration(42, brown_caps),
        decoration(43, reeds[0], reeds[1]),
        decoration(44, reeds[0]),
        decoration(45, reeds[2]),
        decoration(46, reeds[2], reeds[1]),
    ]
    return edge_tiles(texture, shapes, 30, decorate) + fulls, decorations


# All grass layers share their edge shapes, so lush and dry grass never stick out of the
# ordinary grass drawn beneath them.
GRASS_SHAPES = edge_shapes(40, [(2, 1.0), (3, 0.6), (5, 0.3)], 0.18)


def grass_texture(colours):
    """A grass texture: short blades scattered over the base colour."""
    base_colour, light, dark = colours
    blade = sprite({"l": light, "d": dark}, "l", "d")
    dark_blade = sprite({"d": dark}, "d.d", ".d.")

    def texture(seed):
        tile = filled(base_colour)
        sprinkle(tile, random.Random(seed), [blade, blade, dark_blade], spacing=4, chance=0.45)
        return tile

    return texture


# Dots in flower colours, which autumn turns into leaf colours (see seasons.py). The
# game shows them only in autumn (see data/vegetation.cfg).
fallen_leaves = sprite({"a": "gold", "b": "petal", "c": "cream"}, "aa..b", "..c.b", ".b..a", "c.aa.")


def grass():
    tufts = [
        sprite({"b": "green_bright", "d": "green_dark"}, "b...b", ".d.d.", "..d.."),
        sprite({"b": "green_bright", "d": "green_dark"}, ".b.", "bdb", "d.d"),
        sprite({"b": "green_light", "d": "green_dark"}, "b.b", "d.d"),
    ]
    clover = sprite({"g": "green_bright", "d": "green_dark"}, ".g.g", "gdgd", ".dg.")
    pebbles = sprite({"s": "stone_light", "m": "stone", "d": "stone_dark"}, ".s...", "smd.s", ".d..d")
    fern = sprite({"l": "green_light", "g": "green_dark"}, "l...l", ".l.l.", "l.g.l", ".ggg.", "..g..")

    texture = grass_texture(("green", "green_light", "green_dark"))
    fulls = [
        details(texture, 41),
        details(texture, 42),
        details(texture, 43, tufts[0]),
        details(texture, 44, tufts[1]),
        details(texture, 45, tufts[2]),
        details(texture, 46, tufts[0], tufts[2]),
        details(texture, 47, tufts[1]),
        details(texture, 48),
        details(texture, 49, tufts[2]),
        details(texture, 50, tufts[1], tufts[2]),
    ]

    def decorate(tile, covered, rng):
        # A dark rim, with blades of uneven length hanging over the lower terrain on the
        # south side and tips poking out on the north side.
        for y in range(TILE):
            for x in range(TILE):
                if is_rim(covered, x, y):
                    tile[y][x] = "green_dark"
        blades(tile, covered, rng, "green_deep", 0.7, 1, (1, 1, 2, 2, 3))
        blades(tile, covered, rng, "green_dark", 0.45, -1, (1, 1, 2))

    decorations = [
        decoration(55, clover),
        decoration(56, pebbles),
        decoration(57, fern),
        decoration(58, tufts[0], tufts[1]),
        decoration(53, tufts[2]),
        decoration(59, fallen_leaves),
    ]
    return edge_tiles(texture, GRASS_SHAPES, 40, decorate) + fulls, decorations


def tinted_grass(colours, seed, tufts, decorations):
    """A grass family (lush or dry) drawn over ordinary grass. Its edge leaves the grass
    rim showing and fades out in a dither, so the colour shifts softly."""
    texture = grass_texture(colours)
    fulls = [details(texture, seed + n, *picks) for n, picks in enumerate(tufts)]

    def decorate(tile, covered, rng):
        for y in range(TILE):
            for x in range(TILE):
                if covered(x, y):
                    distance = edge_distance(covered, x, y, 4)
                    if distance == 1 or (distance < 4 and (x + y + distance) % 2):
                        tile[y][x] = None

    return edge_tiles(texture, GRASS_SHAPES, seed, decorate) + fulls, decorations


def lush_grass():
    tuft = sprite({"b": "green_bright", "d": "green_deep"}, "b.b.b", ".d.d.", "..d..")
    clover = sprite({"g": "green_bright", "d": "green_deep"}, ".g.g", "gdgd", ".dg.")
    brown_caps = sprite({"m": "soil_mid", "l": "soil_light", "s": "cream"}, ".m..", "mlm.", ".sml", ".s.s")
    fern = sprite({"l": "green_light", "g": "green_deep"}, "l...l", ".l.l.", "l.g.l", ".ggg.", "..g..")
    tufts = [(), (tuft,), (clover,), (), (tuft, clover), (tuft,), (), (clover,)]
    decorations = [
        decoration(61, clover, clover),
        decoration(64, fern),
        decoration(65, brown_caps),
        decoration(66, fern, clover),
        decoration(67, fallen_leaves),
    ]
    return tinted_grass(("green", "green", "green_deep"), 60, tufts, decorations)


def dry_grass():
    tuft = sprite({"s": "straw", "r": "reed"}, "s...s", ".r.r.", "..r..")
    stalks = sprite({"s": "straw", "r": "reed"}, "s.s", "r.r", "rr.")
    pebbles = sprite({"s": "stone_light", "m": "stone", "d": "stone_dark"}, ".s...", "smd.s", ".d..d")
    tufts = [(), (tuft,), (stalks,), (), (tuft, stalks), (stalks,), (), (tuft,)]
    decorations = [
        decoration(71, tuft, stalks),
        decoration(72, pebbles),
        decoration(74, stalks, stalks),
        decoration(75, pebbles, tuft),
        decoration(76, fallen_leaves),
    ]
    return tinted_grass(("dry", "dry_light", "olive"), 70, tufts, decorations)


# Desire paths: grass that is walked often turns trodden, then a path of bare earth (see
# data/paths.cfg). Both are drawn over whatever grass they wore, so their edges fade into it.


def trodden():
    """Thin, flattened grass with the earth showing through in patches."""
    blade = sprite({"l": "green_light", "d": "green_dark"}, "l", "d")
    flat_blades = sprite({"d": "dry", "l": "dry_light"}, "dl", ".d")
    bare_spots = [
        sprite({"m": "mud"}, "mm"),
        sprite({"m": "mud", "d": "dry"}, ".m", "md"),
        sprite({"m": "mud", "d": "mud_dark"}, "mm.", ".dm"),
        sprite({"m": "mud"}, "m", "m"),
    ]
    pebble = sprite({"s": "stone", "d": "mud_dark"}, "s", "d")

    def texture(seed):
        rng = random.Random(seed)
        tile = filled("green")
        for y in range(TILE):
            for x in range(TILE):
                if rng.random() < 0.3:
                    tile[y][x] = "dry"
        sprinkle(tile, rng, bare_spots, spacing=4, chance=0.7)
        sprinkle(tile, rng, [flat_blades, blade], spacing=5, chance=0.4)
        return tile

    fulls = [details(texture, 90 + n, *picks) for n, picks in enumerate([(), (pebble,), (), ()])]
    shapes = edge_shapes(90, [(2, 1.0), (3, 0.7), (5, 0.3)], 0.22)

    def decorate(tile, covered, rng):
        # Fades out in a dither into the grass around it, so no line marks where it ends.
        for y in range(TILE):
            for x in range(TILE):
                if covered(x, y):
                    distance = edge_distance(covered, x, y, 4)
                    if distance == 1 or (distance < 4 and rng.random() < 0.6 / distance):
                        tile[y][x] = None

    # A worn tile has no decorations: its flowers and tufts were trodden down.
    return edge_tiles(texture, shapes, 90, decorate) + fulls, []


def path():
    """Bare trodden earth, with grit and the odd stone; grass creeps in at the edges."""
    grit = sprite({"l": "sand"}, "l")
    dark = sprite({"d": "mud_dark"}, "d")
    stone = sprite({"s": "stone_light", "d": "stone"}, "s", "d")
    pebbles = sprite({"s": "stone", "d": "stone_dark", "l": "stone_light"}, "l.s", ".d.")
    tuft = sprite({"b": "green_light", "d": "green_dark"}, "b.b", ".d.")

    def texture(seed):
        rng = random.Random(seed)
        tile = filled("mud")
        sprinkle(tile, rng, [grit, dark, dark], spacing=3, chance=0.5)
        return tile

    fulls = [
        details(texture, 101),
        details(texture, 102, stone),
        details(texture, 103),
        details(texture, 104, pebbles),
        details(texture, 105),
        details(texture, 106, tuft),
    ]
    shapes = edge_shapes(100, [(2, 1.0), (3, 0.6), (4, 0.3)], 0.2)

    def decorate(tile, covered, rng):
        # The grass beside it shows through a ragged rim, and blades of it lean in.
        for y in range(TILE):
            for x in range(TILE):
                if not covered(x, y):
                    continue
                distance = edge_distance(covered, x, y, 4)
                if distance == 1 and rng.random() < 0.7:
                    tile[y][x] = None
                elif distance == 2 and rng.random() < 0.3:
                    tile[y][x] = rng.choice(("green_dark", "green", None))
                elif distance == 3 and rng.random() < 0.12:
                    tile[y][x] = "green_dark"

    return edge_tiles(texture, shapes, 100, decorate) + fulls, []


def soil():
    clod = sprite({"l": "soil_light", "m": "soil_mid"}, "l", "m")

    # Tilled rows: a lit ridge, its body, and a dark furrow, every 4 pixels.
    base = [[("soil_light", "soil_mid", "soil", "soil_dark")[y % 4]] * TILE for y in range(TILE)]

    def variant(seed):
        rng = random.Random(seed)
        tile = copy(base)
        # A few clods break up the rows.
        for _ in range(rng.randrange(3, 6)):
            stamp(tile, clod, rng.randrange(1, 15), rng.randrange(0, 4) * 4 + 1)
        return tile

    fulls = [variant(seed) for seed in (81, 82, 83, 84)]
    shapes = edge_shapes(80, [(1, 1.0), (2, 0.5)], 0.08)

    def decorate(tile, covered, rng):
        # A raised field border: dark on its south side, a lighter lip elsewhere.
        for y in range(TILE):
            for x in range(TILE):
                if covered(x, y) and not covered(x, y + 1):
                    tile[y][x] = "soil_dark"
                elif is_rim(covered, x, y):
                    tile[y][x] = "soil_mid"

    # A tilled field is the player's work, so it stays free of decorations.
    return edge_tiles(lambda seed: copy(base), shapes, 80, decorate) + fulls, []


LAYERS = [water, floodplain, wetland, grass, lush_grass, dry_grass, trodden, path, soil]
