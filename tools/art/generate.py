"""Generates every PNG under assets/ (run it with `make assets`).

Tiles are drawn as 16x16 grids of palette colour names (None = transparent), so the
palette is the only source of colours. Each terrain layer has one function that returns
its atlas row and its decorations. After writing, every PNG under assets/ is checked
against the palette.

Both atlases are read by game/scenes/terrain_tileset.gd and have one row per terrain
layer, bottom to top: water, floodplain, wetland, grass, lush grass, dry grass, soil.

assets/terrain.png, per row:
- EDGE_VARIANTS blocks of 15 columns: the dual-grid edge shapes for masks 0..14 (mask 0
  stays empty). A mask bit is set when that corner's world tile is on this layer or above;
- then the full-tile variants (mask 15), at least one per row.

assets/decorations.png, per row: small visual-only sprites (flowers, pebbles, reeds...)
drawn on top of world tiles of that layer. A row may be empty.

assets/objects.png: world objects, 32x48 cells (OBJECT_CELL x OBJECT_CELL_HEIGHT; sprites
of 32 rows sit at the bottom of their cell). Row 0 is the oak (3 variants),
row 1 the stone (2 variants), then the camp site: row 2 the fireplace, row 3 the sleeping bag
(1 variant each), then the vegetation rows from 4 (see vegetation()) and row 11 the turnip crop (one
variant per growth stage). The rows and counts are in game/state/world_object_types.gd.
An object stands on one tile: the bottom centre 16x16 of its cell (x 8..23, y 32..47). The
oak's canopy rises above that, over the tiles north of it.

assets/player.png: the player character, 16x16 cells with the feet on the bottom row. One row
per facing (down, up, left, right), columns: idle, walk 1, walk 2 (see game/scenes/player_view.gd).

assets/buildings/<type>.png: one picture per building type, as wide as its footprint (16 px
per tile) and as tall as the footprint plus the roof rising above it. The bottom edge is the
footprint's bottom edge. Sizes and door tiles are in game/state/building_types.gd.
"""

import math
import random
from pathlib import Path

from PIL import Image

ASSETS = Path(__file__).resolve().parents[2] / "assets"
TILE = 16
OBJECT_CELL = 32
# Trees are taller than they are wide; every cell of the object atlas is this high, and a
# shorter sprite is drawn on its bottom rows.
OBJECT_CELL_HEIGHT = 48

# fmt: off
PALETTE = {
    # Darks and neutrals.
    "ink":            "1d1b26",
    "stone_dark":     "4a4852",
    "stone":          "77737a",
    "stone_light":    "a8a39c",
    # Grass and leaves.
    "green_deep":     "26402c",
    "green_dark":     "345433",
    "green":          "46703d",
    "green_light":    "5f8a45",
    "green_bright":   "82a352",
    "lush":           "40783a",
    "olive":          "5c6634",
    # Dry grass, straw, reeds.
    "dry":            "68743e",
    "dry_light":      "8a9250",
    "reed":           "807a40",
    "straw":          "b0a05e",
    # Damp floodplain meadow.
    "meadow_dark":    "29483a",
    "meadow":         "37603e",
    "meadow_light":   "4f8048",
    # Earth: tilled soil and mud.
    "soil_dark":      "3a2920",
    "soil":           "573c2b",
    "soil_mid":       "6f4f37",
    "soil_light":     "8c6a4b",
    "mud_dark":       "4f4436",
    "mud":            "6b5c47",
    "sand":           "8f7f5e",
    "sand_light":     "b3a27c",
    # Wetland ground.
    "bog_dark":       "252e26",
    "bog":            "38432f",
    # Water.
    "water_deep":     "2b4561",
    "water":          "385c79",
    "water_light":    "507b93",
    "foam":           "92b4bd",
    # Warm accents: fire, lamps, flowers.
    "ember":          "a8402e",
    "flame":          "dc7a37",
    "gold":           "eec25a",
    "cream":          "f1e6c2",
    "petal":          "c47a8c",
    # Spare colours for magic later.
    "arcane":         "6f4c91",
    "spirit":         "4e9e9b",
}
# fmt: on

# Dual-grid corner bits, shared with game/scenes/terrain_tileset.gd.
TL, TR, BL, BR = 1, 2, 4, 8
FULL = TL | TR | BL | BR
# Edge-shape variants per mask, shared with game/scenes/terrain_tileset.gd.
EDGE_VARIANTS = 3

NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def blank():
    return [[None] * TILE for _ in range(TILE)]


def filled(colour):
    return [[colour] * TILE for _ in range(TILE)]


def copy(tile):
    return [row[:] for row in tile]


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
    blade = sprite({"l": "meadow_light", "d": "meadow_dark"}, "l", "d")
    dark_blade = sprite({"d": "meadow_dark"}, "d.d", ".d.")
    clover = sprite({"g": "green_light", "d": "meadow_dark"}, "g.g", "dgd")
    puddle = sprite(
        {"m": "mud_dark", "w": "water", "l": "water_light"},
        ".mmm.",
        "mwlwm",
        ".mmm.",
    )
    flowers = [
        sprite({"c": "cream", "d": "meadow_dark"}, "c..c", "d.cd", "..d."),
        sprite({"c": "gold", "d": "meadow_dark"}, ".c.", ".dc", "c.d", "d.."),
        sprite({"c": "petal", "d": "meadow_dark"}, "c.c", "d.d"),
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
        decoration(32, reeds, flowers[0]),
        decoration(33, flowers[0], flowers[1]),
        decoration(34, flowers[2], clover),
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


def common_flowers(stem):
    return [
        sprite({"c": "cream", "d": stem}, "c...", "d.c.", "..d."),
        sprite({"c": "gold", "d": stem}, ".c..", ".d.c", "...d"),
        sprite({"c": "petal", "d": stem}, "c.c", "d.d", ".c.", ".d."),
    ]


def grass():
    tufts = [
        sprite({"b": "green_bright", "d": "green_dark"}, "b...b", ".d.d.", "..d.."),
        sprite({"b": "green_bright", "d": "green_dark"}, ".b.", "bdb", "d.d"),
        sprite({"b": "green_light", "d": "green_dark"}, "b.b", "d.d"),
    ]
    flowers = common_flowers("green_dark")
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
        decoration(51, flowers[0]),
        decoration(52, flowers[1]),
        decoration(53, flowers[2]),
        decoration(54, flowers[0], flowers[1]),
        decoration(55, clover),
        decoration(56, pebbles),
        decoration(57, fern),
        decoration(58, tufts[0], tufts[1]),
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
    flowers = common_flowers("green_deep")
    brown_caps = sprite({"m": "soil_mid", "l": "soil_light", "s": "cream"}, ".m..", "mlm.", ".sml", ".s.s")
    fern = sprite({"l": "green_light", "g": "green_deep"}, "l...l", ".l.l.", "l.g.l", ".ggg.", "..g..")
    tufts = [(), (tuft,), (clover,), (), (tuft, clover), (tuft,), (), (clover,)]
    decorations = [
        decoration(61, clover, clover),
        decoration(62, flowers[0]),
        decoration(63, flowers[2], flowers[0]),
        decoration(64, fern),
        decoration(65, brown_caps),
        decoration(66, fern, clover),
    ]
    return tinted_grass(("lush", "green", "green_deep"), 60, tufts, decorations)


def dry_grass():
    tuft = sprite({"s": "straw", "r": "reed"}, "s...s", ".r.r.", "..r..")
    stalks = sprite({"s": "straw", "r": "reed"}, "s.s", "r.r", "rr.")
    pebbles = sprite({"s": "stone_light", "m": "stone", "d": "stone_dark"}, ".s...", "smd.s", ".d..d")
    flower = sprite({"c": "gold", "d": "olive"}, ".c..", ".d.c", "...d")
    tufts = [(), (tuft,), (stalks,), (), (tuft, stalks), (stalks,), (), (tuft,)]
    decorations = [
        decoration(71, tuft, stalks),
        decoration(72, pebbles),
        decoration(73, flower),
        decoration(74, stalks, stalks),
        decoration(75, pebbles, tuft),
    ]
    return tinted_grass(("dry", "dry_light", "olive"), 70, tufts, decorations)


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


LAYERS = [water, floodplain, wetland, grass, lush_grass, dry_grass, soil]


def object_canvas(height=OBJECT_CELL):
    """A blank sprite. Sprites of height OBJECT_CELL_HEIGHT (trees) fill a whole atlas cell,
    shorter ones are put on the bottom of theirs."""
    return [[None] * OBJECT_CELL for _ in range(height)]


def shaded_blob(canvas, rng, blobs, shades, outline):
    """Fills the union of circles (cx, cy, radius) with `shades`, lightest first: light
    comes from the top left, so a pixel is darker the further down and right of its
    circle's centre it is. Pixels on the blob's border get `outline`."""
    covered = set()
    for y in range(len(canvas)):
        for x in range(OBJECT_CELL):
            best = None
            for cx, cy, radius in blobs:
                distance = math.hypot(x - cx, y - cy)
                if distance <= radius:
                    # 0 at the lit top left of the circle, 1 at its dark bottom right.
                    light = ((x - cx) * 0.5 + (y - cy) * 0.9) / radius * 0.5 + 0.5
                    if best is None or light < best:
                        best = light
            if best is not None:
                covered.add((x, y))
                noise = rng.random() * 0.25 - 0.12
                index = min(len(shades) - 1, max(0, int((best + noise) * len(shades))))
                canvas[y][x] = shades[index]
    for x, y in covered:
        if any((x + dx, y + dy) not in covered for dx, dy in NEIGHBOURS):
            canvas[y][x] = outline


BARK = ("soil_mid", "soil", "soil", "soil_dark")
LEAVES = ("green_bright", "green_light", "green", "green_dark", "green_deep", "olive")


def ground_shadow(canvas, half_width, bottom=None):
    """A soft dark ellipse on the ground under an object, 3 rows high, with a dithered
    rim; it is drawn first so the object covers its middle."""
    bottom = len(canvas) - 1 if bottom is None else bottom
    for y, reach in ((bottom - 2, half_width - 3), (bottom - 1, half_width), (bottom, half_width - 2)):
        for x in range(16 - reach, 16 + reach):
            if abs(x - 16) < reach - 1 or (x + y) % 2 == 0:
                canvas[y][x] = "green_deep"


def tree_trunk(canvas, top, shades=BARK):
    """A trunk on the bottom tile, 3 wide above the lower rows and 4 wide below, with a
    root flare at its foot."""
    bottom = len(canvas) - 1
    for y in range(top, bottom + 1):
        width = 4 if y > bottom - 9 else 3
        for index in range(width):
            canvas[y][14 + index] = shades[index + (width == 3 and index == 2)]
    canvas[bottom][13] = canvas[bottom - 1][13] = shades[1]
    canvas[bottom][18] = canvas[bottom - 1][18] = shades[-1]
    canvas[bottom][12] = canvas[bottom][19] = shades[-1]


def limb(canvas, x, y, direction, length, colour="soil"):
    """A 2px thick limb rising diagonally from the trunk at (x, y); the crown drawn over it
    hides its far end."""
    for step in range(length):
        canvas[y - step][x + step * direction] = colour
        canvas[y - step + 1][x + step * direction] = colour


def shade_under_crown(canvas, shades=BARK):
    """Darkens the trunk where the crown above it casts a shadow, and the crown's own
    underside, so the two read as joined rather than stacked."""
    dark = shades[-1]
    for y in range(len(canvas)):
        for x in range(OBJECT_CELL):
            if canvas[y][x] in shades and any(
                y - up >= 0 and canvas[y - up][x] in LEAVES for up in (1, 2, 3)
            ):
                canvas[y][x] = dark
    for x in range(OBJECT_CELL):
        lowest = max((y for y in range(len(canvas)) if canvas[y][x] in LEAVES), default=None)
        if lowest is not None and canvas[lowest - 1][x] in ("green_bright", "green_light", "green"):
            canvas[lowest - 1][x] = "green_dark"


def oak(seed):
    rng = random.Random(seed)
    canvas = object_canvas(OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 10)
    tree_trunk(canvas, 30)
    # Limbs into the crown, on some variants.
    if seed % 3 != 0:
        limb(canvas, 14, 40, -1, 6)
    if seed % 3 != 1:
        limb(canvas, 17, 38, 1, 6)
    # Canopy: a few overlapping puffs, different for every variant. It is wide and reaches
    # down over most of the trunk, so that a dense forest reads as one canopy, not as
    # trunks in rows.
    blobs = [(16 + rng.uniform(-1, 1), 22 + rng.uniform(-1, 1), rng.uniform(9, 10))]
    for cx, cy in ((8, 27), (24, 27), (16, 14), (11, 18), (21, 19), (12, 31), (20, 31)):
        blobs.append((cx + rng.uniform(-2, 2), cy + rng.uniform(-1.5, 1.5), rng.uniform(5, 7)))
    shaded_blob(canvas, rng, blobs, LEAVES[:5], "green_deep")
    shade_under_crown(canvas)
    return canvas


def stone(seed):
    rng = random.Random(seed)
    canvas = object_canvas()
    # A boulder, and for the second variant a smaller one beside it, on the lower 16 rows.
    blobs = [(16, 25, 6.5)] if seed % 2 else [(14, 26, 5.5), (20, 28, 3.5)]
    shaded_blob(canvas, rng, blobs, ("stone_light", "stone", "stone", "stone_dark"), "ink")
    return canvas


def conifer_tier(canvas, rng, top, bottom, half_width):
    """One ragged triangle of needles centred on x = 16, lit from the left, with a dark
    underside so the tiers read as layers."""
    for y in range(top, bottom + 1):
        progress = (y - top) / (bottom - top)
        reach = half_width * (0.2 + 0.8 * progress) + rng.uniform(-0.7, 0.7)
        for x in range(math.floor(16 - reach), math.ceil(16 + reach) + 1):
            side = (x - 16) / max(reach, 1)
            if abs(x - 16) > reach - 0.5 or y == bottom:
                canvas[y][x] = "green_deep"
            else:
                canvas[y][x] = ("green_light", "green", "green", "green_dark")[
                    min(3, int((side * 0.6 + progress * 0.5 + 0.5 + rng.uniform(-0.2, 0.2)) * 2.2))
                ]


def spruce(seed):
    rng = random.Random(seed)
    canvas = object_canvas(OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 9)
    tree_trunk(canvas, 38, ("soil_mid", "soil", "soil", "soil_dark"))
    # Tall and narrow: five tiers, the widest at the bottom, each overlapping the next.
    tiers = [(30, 41, 9.5), (23, 34, 8), (16, 28, 6.5), (9, 21, 5), (3 + rng.randint(0, 1), 14, 3.5)]
    for top, bottom, half_width in tiers:
        conifer_tier(canvas, rng, top, bottom, half_width + rng.uniform(-0.5, 0.5))
    shade_under_crown(canvas)
    return canvas


def pine(seed):
    rng = random.Random(seed)
    canvas = object_canvas(OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 9)
    # A tall trunk in dull, dark bark, with limbs into the crown.
    tree_trunk(canvas, 23, ("mud", "mud_dark", "soil_dark", "soil_dark"))
    limb(canvas, 14, 30, -1, 5, "mud_dark")
    limb(canvas, 17, 28, 1, 5, "mud_dark")
    # Umbrella crown: a flat, wide cloud of needles.
    blobs = [(16, 21, 6.5), (9, 24, 5.5), (23, 24, 5.5), (13, 17, 4.5), (20, 17, 4.5)]
    blobs = [(cx + rng.uniform(-1, 1), cy + rng.uniform(-1, 1), r) for cx, cy, r in blobs]
    shaded_blob(canvas, rng, blobs, ("green_light", "olive", "green", "green_dark"), "green_deep")
    shade_under_crown(canvas, ("mud", "mud_dark", "soil_dark"))
    return canvas


def draw_branch(canvas, rng, x, y, direction, length, colour):
    """A twisting 1px branch going up from (x, y), drifting sideways; may fork once."""
    for step in range(length):
        y -= 1
        if y < 0 or not 0 <= x < OBJECT_CELL:
            return
        canvas[y][x] = colour
        if step < length // 2:
            canvas[y][x + 1] = "mud_dark"
        if rng.random() < 0.55:
            x += direction
            canvas[y][x] = colour
        if step == length // 2 and length > 6:
            draw_branch(canvas, rng, x, y, -direction, length // 2, colour)


def dead_tree(seed):
    rng = random.Random(seed)
    canvas = object_canvas(OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 9)
    # A grey-brown trunk narrowing to a snag, with crooked bare branches that start inside it.
    for y in range(22, 48):
        width = 4 if y > 38 else 3 if y > 30 else 2
        x_left = 16 - width // 2 + (1 if y < 30 else 0)
        for index in range(width):
            canvas[y][x_left + index] = ("stone", "mud", "mud", "mud_dark")[
                index if width == 4 else min(index + 1, 3)
            ]
    canvas[47][13] = canvas[46][13] = "mud"
    canvas[47][18] = canvas[46][18] = "mud_dark"
    canvas[47][12] = canvas[47][19] = "mud_dark"
    for x, y, direction, length in (
        (16, 30, -1, 8 + rng.randint(0, 3)),
        (17, 27, 1, 9 + rng.randint(0, 3)),
        (16, 24, rng.choice((-1, 1)), 7 + rng.randint(0, 3)),
        (15, 36, -1, 4 + rng.randint(0, 2)),
    ):
        draw_branch(canvas, rng, x, y, direction, length, "mud" if direction < 0 else "stone")
    return canvas


def berry_bush(seed):
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 12)
    blobs = [(16, 24, 7), (10, 26, 5), (22, 26, 5), (16, 20, 4.5)]
    shaded_blob(canvas, rng, blobs, ("green_light", "green", "green", "green_dark"), "green_deep")
    # Berries on the leaves: red, purple or both, with a pale glint.
    berries = {0: ("ember",), 1: ("arcane",)}.get(seed % 3, ("ember", "arcane", "petal"))
    for _ in range(9):
        x, y = rng.randint(8, 23), rng.randint(18, 29)
        if canvas[y][x] not in ("green_light", "green", "green_dark"):
            continue
        canvas[y][x] = rng.choice(berries)
        canvas[y][x + 1] = canvas[y][x]
        if canvas[y - 1][x] is not None:
            canvas[y - 1][x] = "cream" if rng.random() < 0.3 else canvas[y - 1][x]
    return canvas


def shrub(seed):
    rng = random.Random(seed)
    canvas = object_canvas()
    shades = (("green_bright", "green_light", "green", "green_dark"),
              ("green_light", "olive", "olive", "green_dark"),
              ("dry_light", "dry", "olive", "green_dark"))[seed % 3]
    ground_shadow(canvas, 10)
    blobs = [(16, 25, 5.5), (11, 27, 3.5), (21, 27, 3.5)]
    shaded_blob(canvas, rng, blobs, shades, "green_deep")
    return canvas


def sapling(seed):
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 6)
    lean = rng.choice((-1, 0, 1))
    for y in range(20, 32):
        canvas[y][16 + lean * (31 - y) // 8] = "soil_mid"
    top = 16 + lean * 11 // 8
    blobs = [(top, 19, 3.5), (top - 4, 23, 2.5), (top + 4, 22, 2.5)]
    shaded_blob(canvas, rng, blobs, ("green_bright", "green_light", "green"), "green_dark")
    return canvas


def fern_bush(seed):
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 10)
    # Fronds fan out from the base and droop at their tips.
    for angle in (-75, -55, -30, -8, 12, 35, 58, 78):
        angle = math.radians(angle + rng.uniform(-6, 6))
        length = rng.uniform(8, 12)
        for step in range(int(length * 2)):
            s = step / 2
            x = round(16 + math.sin(angle) * s)
            y = round(29 - math.cos(angle) * s * 0.9 + s * s * 0.012 * abs(math.sin(angle)))
            canvas[y][x] = "green_light" if step > length * 0.8 else "green"
            if step % 3 == 2 and abs(math.sin(angle)) > 0.2 and y < 31:
                canvas[y + 1][x] = "green_dark"
    return canvas


def vegetation():
    """The vegetation rows of assets/objects.png, in the order of their atlas_row in
    game/state/world_object_types.gd, starting at row 4, after the camp rows."""
    return [
        [spruce(seed) for seed in (121, 122, 123)],
        [pine(seed) for seed in (131, 132, 133)],
        [dead_tree(seed) for seed in (141, 142, 143)],
        [berry_bush(seed) for seed in (151, 152, 153)],
        [shrub(seed) for seed in (161, 162, 163)],
        [sapling(seed) for seed in (171, 172, 173)],
        [fern_bush(seed) for seed in (181, 182, 183)],
    ]


OBJECTS = [[oak(seed) for seed in (101, 102, 103)], [stone(seed) for seed in (111, 112)]]


# Camp site objects (assets/objects.png rows 2 and 3).


def fill_rect(canvas, x0, y0, x1, y1, colour):
    """Fills x0..x1 and y0..y1, both ends included."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            canvas[y][x] = colour


def fireplace():
    rng = random.Random(121)
    canvas = object_canvas()
    # Ash bed, with two crossed logs on it.
    for y in range(22, 29):
        for x in range(9, 23):
            if ((x - 16) / 7.0) ** 2 + ((y - 25.5) / 3.5) ** 2 <= 1:
                canvas[y][x] = "soil_dark"
    for i in range(9):
        canvas[24 + i // 3][11 + i] = "soil_mid"
        canvas[27 - i // 3][11 + i] = "soil"
    # Flame: a teardrop from the logs up into the tile north, jagged at the edges.
    for y in range(12, 26):
        tip = (25 - y) / 13.0
        half_width = 4.5 * (1 - tip) ** 0.7
        for colour, scale, lowest in (("flame", 1.0, 25), ("gold", 0.65, 25), ("cream", 0.3, 24)):
            reach = half_width * scale + rng.uniform(-0.4, 0.4)
            for x in range(16 - int(reach + 1), 16 + int(reach + 1)):
                if abs(x + 0.5 - 16) <= reach and y <= lowest:
                    canvas[y][x] = colour
    # Ring of stones around the ash.
    for step in range(12):
        angle = step / 12 * 2 * math.pi
        x = round(16 + 7.5 * math.cos(angle))
        y = round(25.5 + 4 * math.sin(angle))
        fill_rect(canvas, x - 1, y - 1, x + 1, y, "stone")
        fill_rect(canvas, x - 1, y - 1, x, y - 1, "stone_light")
        fill_rect(canvas, x + 1, y, x + 1, y, "stone_dark")
    return canvas


def sleeping_bag():
    canvas = object_canvas()
    fill_rect(canvas, 11, 18, 20, 30, "ink")
    fill_rect(canvas, 12, 19, 19, 29, "ember")
    fill_rect(canvas, 12, 19, 13, 29, "flame")
    fill_rect(canvas, 18, 19, 19, 29, "soil")
    fill_rect(canvas, 12, 26, 19, 26, "soil_dark")
    # Pillow.
    fill_rect(canvas, 13, 20, 18, 22, "cream")
    fill_rect(canvas, 13, 22, 18, 22, "sand_light")
    return canvas


CAMP_OBJECTS = [[fireplace()], [sleeping_bag()]]


# The turnip crop (assets/objects.png row 4): one cell per growth stage, drawn on the tile.

CROP_KEYS = {
    "g": "green_bright",
    "l": "green_light",
    "d": "green",
    "k": "green_dark",
    "h": "soil_light",
    "m": "soil_mid",
    "s": "soil_dark",
    "c": "cream",
    "p": "petal",
    "e": "sand_light",
}


def crop_stage(*pictures):
    """A crop cell: sprites given as (rows, x, y) stamped on the object's tile, the bottom
    centre 16x16 of the cell."""
    tile = blank()
    for rows, x, y in pictures:
        stamp(tile, sprite(CROP_KEYS, *rows), x, y)
    canvas = object_canvas()
    for y in range(TILE):
        for x in range(TILE):
            canvas[TILE + y][TILE // 2 + x] = tile[y][x]
    return canvas


def turnip_stages():
    mound = ((".ee...", ".shhs.", "smmmms", ".ssss."), 5, 10)
    return [
        crop_stage(mound),
        crop_stage(mound, (("g...g.", ".g.g..", "..k..."), 5, 7)),
        crop_stage(
            mound,
            (("..l..l..", ".lglgl.l", "lgdgdgl.", ".kdgdk..", "..kdk..."), 4, 5),
        ),
        crop_stage(
            (("l..gl..l", ".lgdgl..", "lgdgdgl.", ".kdgdk.."), 4, 4),
            (("..pppp..", ".ppppcp.", ".cccccc.", "..cccce.", "...ee..."), 4, 8),
        ),
    ]


TURNIP_STAGES = turnip_stages()


# The player character (assets/player.png).

PLAYER_FACINGS = ("down", "up", "left", "right")
PLAYER_FRAMES = ("idle", "walk1", "walk2")


def player_frame(facing, frame):
    """One 16x16 frame: a figure 6 px wide with a 1 px ink outline, feet on the bottom row."""
    canvas = blank()
    side = facing in ("left", "right")
    # Legs: a walking frame lifts one leg; seen from the side the legs swing apart instead.
    legs = ((6, 7), (7, 8)) if side else ((6, 7), (8, 9))
    lifted_leg = {"idle": None, "walk1": 0, "walk2": 1}[frame]
    for index, (x0, x1) in enumerate(legs):
        lifted = index == lifted_leg
        shift = 0
        if side and lifted_leg is not None:
            shift = (1 if lifted else -1) * (1 if facing == "right" else -1)
        fill_rect(canvas, x0 + shift, 11, x1 + shift, 12 if lifted and not side else 13, "soil")
        fill_rect(canvas, x0 + shift, 13 if lifted and not side else 14, x1 + shift, 13 if lifted and not side else 14, "soil_dark")
    # Torso and arms.
    fill_rect(canvas, 5, 7, 10, 10, "water_light")
    fill_rect(canvas, 5, 10, 10, 10, "water")
    if not side:
        fill_rect(canvas, 4, 7, 4, 10, "water")
        fill_rect(canvas, 11, 7, 11, 10, "water")
        canvas[10][4] = canvas[10][11] = "sand_light"
    else:
        fill_rect(canvas, 7, 8, 8, 10, "water")
        canvas[10][7] = canvas[10][8] = "sand_light"
    # Head: skin with hair on top, and over the whole head from behind.
    fill_rect(canvas, 5, 2, 10, 6, "sand_light")
    fill_rect(canvas, 5, 2, 10, 3, "soil_dark")
    if facing == "down":
        canvas[5][6] = canvas[5][9] = "ink"
    elif facing == "up":
        fill_rect(canvas, 5, 2, 10, 6, "soil_dark")
    elif facing == "left":
        fill_rect(canvas, 8, 2, 10, 6, "soil_dark")
        canvas[5][6] = "ink"
    else:
        fill_rect(canvas, 5, 2, 7, 6, "soil_dark")
        canvas[5][9] = "ink"
    # Outline.
    covered = {(x, y) for y in range(TILE) for x in range(TILE) if canvas[y][x] is not None}
    for x, y in covered:
        for dx, dy in NEIGHBOURS:
            if 0 <= x + dx < TILE and 0 <= y + dy < TILE and (x + dx, y + dy) not in covered:
                canvas[y + dy][x + dx] = "ink"
    return canvas


PLAYER = [[player_frame(facing, frame) for frame in PLAYER_FRAMES] for facing in PLAYER_FACINGS]



# The small house (assets/buildings/small_house.png).


def small_house():
    """A timber-framed cottage with a thatched roof, 4x3 tiles plus 1 tile of roof. The
    door is on the bottom row, in the second tile from the left."""
    rng = random.Random(121)
    canvas = [[None] * 64 for _ in range(64)]

    # Chimney first, so the roof covers its foot.
    fill_rect(canvas, 44, 0, 51, 16, "stone")
    fill_rect(canvas, 44, 0, 51, 1, "stone_dark")
    fill_rect(canvas, 44, 2, 45, 16, "stone_light")
    fill_rect(canvas, 50, 2, 51, 16, "stone_dark")
    for y in range(5, 16, 4):
        fill_rect(canvas, 44, y, 51, y, "stone_dark")

    # Walls: plaster between a timber frame, on a stone foundation.
    fill_rect(canvas, 4, 28, 59, 63, "sand_light")
    for _ in range(40):
        canvas[rng.randrange(32, 56)][rng.randrange(6, 58)] = "sand"
    for x in (4, 5, 58, 59, 13, 14, 33, 34, 49, 50):
        fill_rect(canvas, x, 28, x, 57, "soil_mid" if x % 2 else "soil")
    fill_rect(canvas, 4, 42, 59, 43, "soil")
    fill_rect(canvas, 4, 42, 59, 42, "soil_mid")
    fill_rect(canvas, 4, 56, 59, 57, "soil")
    fill_rect(canvas, 4, 58, 59, 63, "stone")
    for y in (58, 61):
        for x in range(4 + (y == 61) * 4, 60, 8):
            fill_rect(canvas, x, y, min(x + 4, 59), y + 1, "stone_light")
    fill_rect(canvas, 4, 63, 59, 63, "stone_dark")

    # Windows: a frame, glass and a cross bar.
    for left in (7, 52):
        fill_rect(canvas, left, 33, left + 5, 40, "soil_dark")
        fill_rect(canvas, left + 1, 34, left + 4, 39, "water")
        fill_rect(canvas, left + 1, 34, left + 2, 35, "water_light")
        fill_rect(canvas, left + 2, 34, left + 2, 39, "soil_dark")
        fill_rect(canvas, left + 1, 37, left + 4, 37, "soil_dark")
        fill_rect(canvas, left - 1, 41, left + 6, 41, "soil_mid")

    # Door, on tile (1, 2): x 16..31, y 48..63.
    fill_rect(canvas, 19, 46, 28, 63, "soil_dark")
    fill_rect(canvas, 20, 47, 27, 63, "soil_mid")
    for x in (22, 25):
        fill_rect(canvas, x, 47, x, 63, "soil")
    fill_rect(canvas, 20, 47, 20, 63, "soil_light")
    canvas[56][26] = "gold"
    fill_rect(canvas, 18, 62, 29, 63, "stone_light")

    # Thatched roof: a trapezoid, shifted out a little on the sides as an overhang.
    for y in range(6, 31):
        left = round(10 - 10 * (y - 6) / 24)
        for x in range(left, 64 - left):
            canvas[y][x] = "straw" if (y // 2) % 2 == 0 else "dry_light"
            if rng.random() < 0.12:
                canvas[y][x] = "reed"
        # Straw hangs unevenly along the eaves.
        if y >= 28:
            for x in range(left, 64 - left):
                canvas[y][x] = rng.choice(("dry", "reed", "dry")) if y == 28 else "soil_dark"
    for x in range(10, 54):
        canvas[6][x] = "dry_light"
    for y in range(7, 29):
        left = round(10 - 10 * (y - 6) / 24)
        canvas[y][left] = "reed"
        canvas[y][63 - left] = "dry"
    fill_rect(canvas, 0, 29, 63, 29, "soil_dark")
    fill_rect(canvas, 0, 30, 63, 30, "soil")

    # Outline. The bottom edge of the canvas is the ground, so it gets none.
    outline = [
        (x, y)
        for y in range(63)
        for x in range(64)
        if canvas[y][x] is not None
        and any(canvas[y + dy][x + dx] is None for dx, dy in NEIGHBOURS if 0 <= x + dx < 64)
        or canvas[y][x] is not None
        and x in (0, 63)
    ]
    for x, y in outline:
        canvas[y][x] = "ink"
    return canvas


def to_image(rows, size=TILE, height=None):
    """Lays out rows of tiles as one image. Tiles are size wide and `height` high (default
    size); a tile with fewer rows of pixels sits at the bottom of its cell."""
    height = height or size
    width = max(1, max(len(row) for row in rows)) * size
    image = Image.new("RGBA", (width, len(rows) * height), (0, 0, 0, 0))
    pixels = image.load()
    for row_index, row in enumerate(rows):
        for column, tile in enumerate(row):
            top = height - len(tile)
            for y in range(len(tile)):
                for x in range(size):
                    name = tile[y][x]
                    if name is not None:
                        rgb = bytes.fromhex(PALETTE[name])
                        pixels[column * size + x, row_index * height + top + y] = (*rgb, 255)
    return image


def write_palette():
    swatch = 8
    per_row = 8
    names = list(PALETTE)
    rows = math.ceil(len(names) / per_row)
    image = Image.new("RGBA", (per_row * swatch, rows * swatch), (0, 0, 0, 0))
    for index, name in enumerate(names):
        x, y = index % per_row * swatch, index // per_row * swatch
        image.paste((*bytes.fromhex(PALETTE[name]), 255), (x, y, x + swatch, y + swatch))
    image.save(ASSETS / "palette.png")

    lines = ["GIMP Palette", "Name: Sandbox Game", f"Columns: {per_row}", "#"]
    for name, hex_colour in PALETTE.items():
        r, g, b = bytes.fromhex(hex_colour)
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    (ASSETS / "palette.gpl").write_text("\n".join(lines) + "\n")


def check_palette():
    """Fails if any PNG under assets/ has a pixel that is neither transparent nor a
    palette colour, so hand-drawn replacements are held to the palette too."""
    allowed = {(*bytes.fromhex(hex_colour), 255) for hex_colour in PALETTE.values()}
    bad = []
    for path in sorted(ASSETS.rglob("*.png")):
        colours = {c for _, c in Image.open(path).convert("RGBA").getcolors(1 << 24)}
        stray = {c for c in colours if c[3] != 0 and c not in allowed}
        if stray:
            bad.append(f"{path.relative_to(ASSETS)}: {len(stray)} colours not in the palette")
    if bad:
        raise SystemExit("Palette check failed:\n" + "\n".join(bad))


def main():
    ASSETS.mkdir(exist_ok=True)
    terrain_rows = []
    decoration_rows = []
    for layer in LAYERS:
        tiles, decorations = layer()
        # Full tiles hide the layers below them, so they must be opaque.
        for tile in tiles[EDGE_VARIANTS * FULL :]:
            assert all(None not in line for line in tile), f"{layer.__name__}: full tile has holes"
        terrain_rows.append(tiles)
        decoration_rows.append(decorations)
    to_image(terrain_rows).save(ASSETS / "terrain.png")
    to_image(decoration_rows).save(ASSETS / "decorations.png")
    to_image(OBJECTS + CAMP_OBJECTS + vegetation() + [TURNIP_STAGES], OBJECT_CELL, OBJECT_CELL_HEIGHT).save(
        ASSETS / "objects.png"
    )
    to_image(PLAYER).save(ASSETS / "player.png")
    (ASSETS / "buildings").mkdir(exist_ok=True)
    to_image([[small_house()]], 64).save(ASSETS / "buildings" / "small_house.png")
    write_palette()
    check_palette()
    print("Wrote terrain.png, decorations.png, objects.png, player.png, buildings/small_house.png, palette.png and palette.gpl to assets/; palette check passed.")


if __name__ == "__main__":
    main()
