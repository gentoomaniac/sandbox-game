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

assets/objects.png: world objects, 48x80 cells (OBJECT_CELL_WIDTH x OBJECT_CELL_HEIGHT). Row 0
is the oak (3 variants), row 1 the stone (2 variants), then the camp site: row 2 the fireplace,
row 3 the sleeping bag (1 variant each), then the vegetation rows from 4 (see vegetation()),
row 11 the turnip crop (one variant per growth stage), row 12 the boulder and row 13 the stump. The rows and
counts are in game/state/world_object_types.gd.
An object stands on one tile: the bottom centre 16x16 of its cell (x 16..31, y 64..79). A tree's
crown rises above that, over the tiles around it. An object on several tiles (boulder 2x1,
sleeping bag 1x2) is centred on its footprint, with the cell's bottom on the footprint's bottom.

assets/character/<slot>_<variant>.png: one sheet per layer of the player character, 16x32 cells
with the feet on the bottom row. One row per facing (down, up, left, right), columns: idle,
walk 1 to 4 (see game/state/appearance.gd and game/scenes/player_view.gd).

assets/buildings/<type>.png: one picture per building type, as wide as its footprint (16 px
per tile) and as tall as the footprint plus the roof rising above it. The bottom edge is the
footprint's bottom edge. <type>_lit.png is the same with lit windows, for the night. Sizes
and door tiles are in game/state/building_types.gd.

assets/items/<item id>.png (16x16) and assets/ui/slot.png, slot_selected.png (20x20): drawn in
items.py.
"""

import math
import random
from pathlib import Path

from PIL import Image

import items
import ui

ASSETS = Path(__file__).resolve().parents[2] / "assets"
TILE = 16
# Every cell of the object atlas is this big: a tree fits, and smaller things are drawn at
# the cell's bottom centre. A multi-tile object is centred on its footprint instead.
OBJECT_CELL_WIDTH = 48
OBJECT_CELL_HEIGHT = 80
OBJECT_CENTRE = OBJECT_CELL_WIDTH // 2
OBJECT_BOTTOM = OBJECT_CELL_HEIGHT - 1

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
    # Skin.
    "skin":           "d09a72",
    "skin_shade":     "a96d4c",
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


def object_canvas():
    """A blank sprite the size of one atlas cell. Objects are drawn at the cell's bottom
    centre: x = OBJECT_CENTRE, ground row y = OBJECT_BOTTOM."""
    return [[None] * OBJECT_CELL_WIDTH for _ in range(OBJECT_CELL_HEIGHT)]


def shaded_blob(canvas, rng, blobs, shades, outline):
    """Fills the union of circles (cx, cy, radius) with `shades`, lightest first: light
    comes from the top left, so a pixel is darker the further down and right of its
    circle's centre it is. Pixels on the blob's border get `outline`."""
    covered = set()
    for y in range(len(canvas)):
        for x in range(OBJECT_CELL_WIDTH):
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


def ground_shadow(canvas, half_width, centre=OBJECT_CENTRE):
    """A soft dark ellipse on the ground under an object, 3 rows high, with a dithered
    rim; it is drawn first so the object covers its middle."""
    bottom = OBJECT_BOTTOM
    for y, reach in ((bottom - 2, half_width - 3), (bottom - 1, half_width), (bottom, half_width - 2)):
        for x in range(centre - reach, centre + reach):
            if abs(x - centre) < reach - 1 or (x + y) % 2 == 0:
                canvas[y][x] = "green_deep"


def tree_trunk(canvas, rng, top, width, shades=BARK):
    """A trunk from `top` down to the ground, lit on the left, with a root flare at its
    foot and a few bark marks. Its outline is the darkest shade."""
    left = OBJECT_CENTRE - width // 2
    for y in range(top, OBJECT_BOTTOM + 1):
        flare = 2 if y == OBJECT_BOTTOM else 1 if y > OBJECT_BOTTOM - 4 else 0
        for x in range(left - flare, left + width + flare):
            index = x - left
            if index <= -1 or index >= width - 1:
                colour = shades[-1]
            elif index == 0:
                colour = shades[1] if flare else shades[0]
            elif index == width - 2:
                colour = shades[2]
            else:
                colour = shades[1]
            canvas[y][x] = colour
    for _ in range((OBJECT_BOTTOM - top) // 5):
        x, y = left + rng.randint(1, width - 3), rng.randint(top, OBJECT_BOTTOM - 4)
        canvas[y][x] = canvas[y + 1][x] = shades[-1]
        canvas[y][x + 1] = shades[2]


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
        for x in range(OBJECT_CELL_WIDTH):
            if canvas[y][x] in shades and any(
                y - up >= 0 and canvas[y - up][x] in LEAVES for up in (1, 2, 3, 4)
            ):
                canvas[y][x] = dark
    for x in range(OBJECT_CELL_WIDTH):
        lowest = max((y for y in range(len(canvas)) if canvas[y][x] in LEAVES), default=None)
        if lowest is not None and canvas[lowest - 1][x] in ("green_bright", "green_light", "green"):
            canvas[lowest - 1][x] = "green_dark"


def oak(seed):
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 13)
    tree_trunk(canvas, rng, 52, 7)
    # Limbs into the crown, on some variants.
    if seed % 3 != 0:
        limb(canvas, 20, 62, -1, 8)
    if seed % 3 != 1:
        limb(canvas, 27, 60, 1, 8)
    # Canopy of three lobes on top of a broad base, different for every variant. It reaches
    # down over the upper trunk, so that a dense forest reads as one canopy.
    blobs = [(24 + rng.uniform(-1, 1), 38 + rng.uniform(-1, 1), rng.uniform(12, 14))]
    for cx, cy, radius in ((9, 44, 8), (39, 44, 8), (24, 26, 8), (14, 31, 8), (34, 31, 8), (18, 51, 6), (30, 51, 6)):
        blobs.append((cx + rng.uniform(-2, 2), cy + rng.uniform(-1.5, 1.5), radius + rng.uniform(-1, 1)))
    shaded_blob(canvas, rng, blobs, LEAVES[:5], "green_deep")
    shade_under_crown(canvas)
    return canvas


def stone(seed):
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 8)
    # A small stone of 13x12 px, and for the second variant a pebble beside it.
    blobs = [(24, 73, 6)] if seed % 2 else [(22, 73, 5.5), (29, 76, 2.5)]
    shaded_blob(canvas, rng, blobs, ("stone_light", "stone", "stone_dark"), "stone_dark")
    return canvas


def boulder(seed):
    """A boulder on 2x1 tiles: the cell is centred on the footprint, which is 32 px wide."""
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 14)
    blobs = [(23, 68, 10), (16, 71, 6), (31, 70, 6.5), (26, 64, 7)]
    shaded_blob(canvas, rng, blobs, ("stone_light", "stone", "stone", "stone_dark"), "stone_dark")
    # A crack, and moss on the lit top.
    for step in range(7):
        canvas[62 + step][27 + step // 3] = "stone_dark"
    for _ in range(14):
        x, y = rng.randint(14, 30), rng.randint(58, 66)
        if canvas[y][x] in ("stone_light", "stone"):
            canvas[y][x] = rng.choice(("green_light", "olive", "green"))
    return canvas


def conifer_tier(canvas, rng, top, bottom, half_width):
    """One ragged triangle of needles centred on the cell, lit from the left, with a dark
    underside so the tiers read as layers."""
    centre = OBJECT_CENTRE
    for y in range(top, bottom + 1):
        progress = (y - top) / (bottom - top)
        reach = half_width * (0.2 + 0.8 * progress) + rng.uniform(-0.7, 0.7)
        for x in range(math.floor(centre - reach), math.ceil(centre + reach) + 1):
            side = (x - centre) / max(reach, 1)
            if abs(x - centre) > reach - 0.5 or y == bottom:
                canvas[y][x] = "green_deep"
            else:
                canvas[y][x] = ("green_light", "green", "green", "green_dark")[
                    min(3, int((side * 0.6 + progress * 0.5 + 0.5 + rng.uniform(-0.2, 0.2)) * 2.2))
                ]


def spruce(seed):
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 10)
    tree_trunk(canvas, rng, 66, 5)
    # Tall and narrow: six tiers, the widest at the bottom, each overlapping the next.
    tiers = [(55, 70, 14), (46, 61, 12.5), (37, 53, 11), (28, 45, 9), (20, 37, 7), (13 + rng.randint(0, 2), 29, 5)]
    for top, bottom, half_width in tiers:
        conifer_tier(canvas, rng, top, bottom, half_width + rng.uniform(-0.5, 0.5))
    shade_under_crown(canvas)
    return canvas


def pine(seed):
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 10)
    # A tall bare trunk in dull, dark bark, with limbs into the crown.
    dull = ("mud", "mud_dark", "soil_dark", "soil_dark")
    tree_trunk(canvas, rng, 40, 6, dull)
    limb(canvas, 21, 52, -1, 8, "mud_dark")
    limb(canvas, 27, 50, 1, 8, "mud_dark")
    # Umbrella crown: a flat, wide cloud of needles with a smaller tuft on top.
    blobs = [(24, 44, 8), (12, 46, 7), (36, 46, 7), (18, 40, 6), (31, 40, 6), (25, 26 + rng.randint(0, 2), 6.5), (19, 31, 5), (30, 32, 5)]
    blobs = [(cx + rng.uniform(-1, 1), cy + rng.uniform(-1, 1), r) for cx, cy, r in blobs]
    shaded_blob(canvas, rng, blobs, ("green_light", "olive", "green", "green_dark"), "green_deep")
    shade_under_crown(canvas, ("mud", "mud_dark", "soil_dark"))
    return canvas


def draw_branch(canvas, rng, x, y, direction, length, colour):
    """A twisting branch going up from (x, y), drifting sideways, 2 px thick near the
    trunk; may fork once."""
    for step in range(length):
        y -= 1
        if y < 0 or not 0 <= x < OBJECT_CELL_WIDTH - 1:
            return
        canvas[y][x] = colour
        if step < length // 2:
            canvas[y][x + 1] = "mud_dark"
        if rng.random() < 0.7:
            x += direction
            canvas[y][x] = colour
        if step == length // 2 and length > 6:
            draw_branch(canvas, rng, x, y, -direction, length // 2, colour)


def dead_tree(seed):
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 10)
    # A grey-brown trunk narrowing to a snag, with crooked bare branches that start inside it.
    shades = ("stone_dark", "stone", "mud", "mud", "mud_dark", "stone_dark")
    for y in range(52, OBJECT_BOTTOM + 1):
        width = 6 if y > 70 else 5 if y > 62 else 4
        x_left = OBJECT_CENTRE - width // 2 + (1 if y < 60 else 0)
        for index in range(width):
            canvas[y][x_left + index] = shades[index if index < width - 1 else 5]
    canvas[79][OBJECT_CENTRE - 5] = canvas[78][OBJECT_CENTRE - 4] = "mud"
    canvas[79][OBJECT_CENTRE + 4] = canvas[78][OBJECT_CENTRE + 3] = "mud_dark"
    for x, y, direction, length in (
        (24, 62, -1, 19 + rng.randint(0, 3)),
        (25, 57, 1, 20 + rng.randint(0, 3)),
        (24, 52, rng.choice((-1, 1)), 16 + rng.randint(0, 3)),
        (23, 70, -1, 10 + rng.randint(0, 3)),
        (26, 68, 1, 9 + rng.randint(0, 3)),
    ):
        draw_branch(canvas, rng, x, y, direction, length, "mud" if direction < 0 else "stone")
    return canvas


def berry_bush(seed, is_picked=False):
    """With berries, or picked: the same bush without them."""
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 14)
    blobs = [(24, 68, 8.5), (17, 70, 5.5), (31, 70, 5.5), (20, 64, 5.5), (28, 64, 5.5)]
    shaded_blob(canvas, rng, blobs, ("green_light", "green", "green", "green_dark"), "green_deep")
    # Berries on the leaves: red, purple or both, with a pale glint.
    berries = {0: ("ember",), 1: ("arcane",)}.get(seed % 3, ("ember", "arcane", "petal"))
    for _ in range(0 if is_picked else 11):
        x, y = rng.randint(14, 33), rng.randint(63, 74)
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
    ground_shadow(canvas, 12)
    blobs = [(24, 71, 6.5), (17, 73, 4.5), (31, 73, 4.5), (22, 67, 4)]
    shaded_blob(canvas, rng, blobs, shades, "green_deep")
    return canvas


def sapling(seed):
    """A young tree 13 px wide and about 22 tall: a thin trunk tied to a stake."""
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 7)
    lean = rng.choice((-1, 0, 1))
    for y in range(62, OBJECT_BOTTOM - 1):
        x = OBJECT_CENTRE + lean * (OBJECT_BOTTOM - 2 - y) // 10
        canvas[y][x] = "soil_mid"
        canvas[y][x + 1] = "soil_dark"
    for y in range(64, OBJECT_BOTTOM - 1):
        canvas[y][OBJECT_CENTRE + 3] = "straw"
    canvas[70][OBJECT_CENTRE + 2] = canvas[70][OBJECT_CENTRE + 3] = "sand_light"
    top = OBJECT_CENTRE + lean * 2
    blobs = [(top, 61, 4), (top - 3, 65, 2.5), (top + 3, 64, 2.5)]
    shaded_blob(canvas, rng, blobs, ("green_bright", "green_light", "green"), "green_dark")
    return canvas


def fern_bush(seed):
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 11)
    # Fronds fan out from the base and droop at their tips, with leaflets along them.
    for angle in (-78, -58, -36, -14, 8, 30, 54, 76):
        angle = math.radians(angle + rng.uniform(-6, 6))
        length = rng.uniform(9, 12)
        for step in range(int(length * 2)):
            s = step / 2
            x = round(OBJECT_CENTRE + math.sin(angle) * s)
            y = round(77 - math.cos(angle) * s * 0.95 + s * s * 0.02 * abs(math.sin(angle)))
            canvas[y][x] = "green_light" if step > length * 0.8 else "green"
            if step % 3 == 1 and step > 3:
                canvas[y + 1][x] = "green_dark"
                canvas[y - 1][x + (1 if step % 2 else -1)] = "green"
    return canvas


def stump(seed):
    """What is left of a felled tree: about 20x12 px, the cut top with rings, bark below."""
    rng = random.Random(seed)
    canvas = object_canvas()
    ground_shadow(canvas, 12)
    centre_x, top_y, radius_x, radius_y, height = OBJECT_CENTRE, 72, 9, 4, 6
    for y in range(top_y - radius_y, OBJECT_BOTTOM + 1):
        for x in range(centre_x - radius_x - 2, centre_x + radius_x + 2):
            dx, dy = x + 0.5 - centre_x, y + 0.5 - top_y
            # The root flare widens the foot.
            flare = 2 if y > OBJECT_BOTTOM - 3 else 0
            if (dx / radius_x) ** 2 + (dy / radius_y) ** 2 <= 1:
                ring = round(math.hypot(dx / radius_x, dy / radius_y) * 3)
                canvas[y][x] = ("sand_light", "sand", "sand_light", "straw")[min(ring, 3)]
            elif dy > 0 and abs(dx) <= radius_x + flare and y <= top_y + height + 1:
                index = x - (centre_x - radius_x)
                canvas[y][x] = "soil_mid" if index < 4 else "soil_dark" if index > 2 * radius_x - 3 else "soil"
    for _ in range(3):
        x = rng.randint(centre_x - radius_x + 2, centre_x + radius_x - 3)
        y = rng.randint(top_y + radius_y, top_y + height - 1)
        canvas[y][x] = canvas[y + 1][x] = "soil_dark"
    outline_in_bark(canvas)
    return canvas


def outline_in_bark(canvas):
    """A one pixel outline in the darkest bark colour round everything drawn except the
    ground shadow."""
    height = len(canvas)
    marked = []
    for y in range(height):
        for x in range(OBJECT_CELL_WIDTH):
            if canvas[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < OBJECT_CELL_WIDTH and 0 <= ny < height and canvas[ny][nx] not in (None, "green_deep"):
                    marked.append((x, y))
                    break
    for x, y in marked:
        canvas[y][x] = "soil_dark"


def vegetation():
    """The vegetation rows of assets/objects.png, in the order of their atlas_row in
    game/state/world_object_types.gd, starting at row 4, after the camp rows."""
    return [
        [spruce(seed) for seed in (121, 122, 123)],
        [pine(seed) for seed in (131, 132, 133)],
        [dead_tree(seed) for seed in (141, 142, 143)],
        # Columns 0 to 2 bear berries, 3 to 5 are the same bushes picked.
        [berry_bush(seed) for seed in (151, 152, 153)]
        + [berry_bush(seed, is_picked=True) for seed in (151, 152, 153)],
        [shrub(seed) for seed in (161, 162, 163)],
        [sapling(seed) for seed in (171, 172, 173)],
        [fern_bush(seed) for seed in (181, 182, 183)],
    ]


OBJECTS = [[oak(seed) for seed in (101, 102, 103)], [stone(seed) for seed in (111, 112)]]
BOULDERS = [[boulder(seed) for seed in (191, 192)]]
STUMPS = [[stump(seed) for seed in (201, 202)]]


# Camp site objects (assets/objects.png rows 2 and 3).


def fill_rect(canvas, x0, y0, x1, y1, colour):
    """Fills x0..x1 and y0..y1, both ends included."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            canvas[y][x] = colour


def fire_stone(canvas, x, y):
    fill_rect(canvas, x - 1, y - 1, x + 1, y, "stone")
    fill_rect(canvas, x - 1, y - 1, x, y - 1, "stone_light")
    fill_rect(canvas, x + 1, y, x + 1, y, "stone_dark")


def fireplace():
    rng = random.Random(121)
    canvas = object_canvas()
    centre, ground = OBJECT_CENTRE, 71
    # Ash bed, with three logs on it, laid like the spokes of a wheel.
    for y in range(ground - 4, ground + 5):
        for x in range(centre - 10, centre + 10):
            if ((x - centre) / 9.5) ** 2 + ((y - ground) / 4.2) ** 2 <= 1:
                canvas[y][x] = "soil_dark"
    for dx, dy, shades in ((-7, -2, ("soil_mid", "soil")), (7, -2, ("soil", "soil_dark")), (0, 3, ("soil_mid", "soil"))):
        for i in range(9):
            x, y = round(centre + dx * i / 8), round(ground + dy * i / 8)
            canvas[y][x] = canvas[y + 1][x] = shades[0]
            canvas[y + 2][x] = shades[1]
    # Flame: a teardrop from the logs up into the tile north, jagged at the edges.
    for y in range(58, ground):
        tip = (ground - y) / 16.0
        half_width = 5.5 * (1 - tip) ** 0.7
        for colour, scale, lowest in (("flame", 1.0, ground), ("gold", 0.65, ground), ("cream", 0.3, ground - 1)):
            reach = half_width * scale + rng.uniform(-0.4, 0.4)
            for x in range(centre - int(reach + 1), centre + int(reach + 1)):
                if abs(x + 0.5 - centre) <= reach and y <= lowest:
                    canvas[y][x] = colour
    # Ring of stones around the ash; those in front of the fire are drawn over it.
    ring = [
        (round(centre + 10.5 * math.cos(step / 14 * 2 * math.pi)), round(ground + 3 + 4 * math.sin(step / 14 * 2 * math.pi)), math.sin(step / 14 * 2 * math.pi))
        for step in range(14)
    ]
    for x, y, depth in sorted(ring, key=lambda stone: stone[2]):
        fire_stone(canvas, x, y)
    return canvas


def sleeping_bag():
    """14x26 px, lying vertically on 1x2 tiles: the cell's bottom edge is the footprint's."""
    canvas = object_canvas()
    left, top, bottom = OBJECT_CENTRE - 7, 51, 76
    fill_rect(canvas, left, top, left + 13, bottom, "soil_dark")
    fill_rect(canvas, left + 1, top + 1, left + 12, bottom - 1, "ember")
    fill_rect(canvas, left + 1, top + 8, left + 3, bottom - 1, "flame")
    fill_rect(canvas, left + 10, top + 8, left + 12, bottom - 1, "soil")
    # Rounded corners.
    for x, y in ((left, top), (left + 13, top), (left, bottom), (left + 13, bottom)):
        canvas[y][x] = None
    # Rolled pillow at the head.
    fill_rect(canvas, left + 2, top + 1, left + 11, top + 6, "cream")
    fill_rect(canvas, left + 2, top + 5, left + 11, top + 6, "sand_light")
    fill_rect(canvas, left + 2, top + 7, left + 11, top + 7, "soil")
    # Folded blanket across the middle, with the fold's shadow below it.
    fill_rect(canvas, left + 1, top + 12, left + 12, top + 14, "gold")
    fill_rect(canvas, left + 10, top + 12, left + 12, top + 14, "straw")
    fill_rect(canvas, left + 1, top + 15, left + 12, top + 15, "soil")
    # Strap round the foot end.
    fill_rect(canvas, left + 1, bottom - 5, left + 12, bottom - 4, "soil_dark")
    # Contact shadow.
    fill_rect(canvas, left + 2, bottom + 1, left + 13, bottom + 2, "green_deep")
    return canvas


CAMP_OBJECTS = [[fireplace()], [sleeping_bag()]]


# The turnip crop (assets/objects.png row 11): one cell per growth stage, drawn on the tile.

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
    "a": "arcane",
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
            canvas[OBJECT_CELL_HEIGHT - TILE + y][OBJECT_CENTRE - TILE // 2 + x] = tile[y][x]
    return canvas


def turnip_stages():
    # Seed mound 8x5 with a soil hump; sprout 10x8; leaf rosette 12x12; ripe 14x14 with
    # the root showing.
    mound = (("..ehhe..", ".ehhmhm.", "ehhmmmms", "hmmmmmss", ".ssssss."), 4, 11)
    sprout = ((".gl....lg.", "..dgkkgd..", "....kk...."), 3, 8)
    rosette = (
        (
            "....g..g....",
            "..gl....lg..",
            ".lgdl..ldgl.",
            "lgddgllgddgl",
            ".kdgdggdgdk.",
            "..kdgddgdk..",
            "...kkddkk...",
        ),
        2,
        4,
    )
    leaves = (
        (
            "..gl..lg..gl..",
            ".lgdl.gdl.ldgl",
            "lgddgllgddgdgl",
            ".kdgdkdgdgdkd.",
            "..kkdkkdkkkk..",
        ),
        1,
        2,
    )
    root = (
        (
            "..aaaaaa..",
            ".appppppa.",
            ".ppppccpp.",
            ".cccccccc.",
            "..cccccce.",
            "...cccce..",
            "....cce...",
            ".....e....",
        ),
        3,
        7,
    )
    return [
        crop_stage(mound),
        crop_stage(mound, sprout),
        crop_stage(mound, rosette),
        crop_stage(root, leaves),
    ]


TURNIP_STAGES = turnip_stages()


# The player character (assets/character/<slot>_<variant>.png).
#
# One sheet per layer and variant, all with the same layout: 16x32 frames, one row per
# facing (down, up, left, right), columns idle, walk 1..4. Drawn for "right" and "left" is
# its mirror image. The layers are drawn in the same coordinates, so any combination lines
# up; game/state/appearance.gd says which are worn and in what order.
#
# The figure is 28 rows tall (outline included, y 4..31, feet on the bottom row): head 8
# rows (y 5..12), torso 10 (13..22), legs 8 (23..30). Only the outer silhouette has the ink
# outline; inside it, parts are separated by darker shades of their own colour.

CHARACTER_WIDTH = 16
CHARACTER_HEIGHT = 32
PLAYER_FACINGS = ("down", "up", "left", "right")
PLAYER_FRAMES = ("idle", "walk1", "walk2", "walk3", "walk4")

# Colours of the variants. A tunic or hair is a base colour with a light and a shade.
CLOTHES_COLOURS = {
    "0": {"base": "water", "light": "water_light", "shade": "water_deep"},
    "1": {"base": "ember", "light": "flame", "shade": "soil"},
}
HAIR_COLOURS = {
    "0": {"base": "soil", "light": "soil_light", "shade": "soil_dark", "long": False},
    "1": {"base": "straw", "light": "gold", "shade": "reed", "long": True},
}

# The undershirt and shorts that the bare body wears.
UNDERSHIRT = "sand_light"
UNDERSHIRT_SHADE = "sand"
SHORTS = "mud"

# A walk is two contact frames (walk 1 and 3: the hips sink, the legs spread) and two
# passing frames (walk 2 and 4: one leg swings through). `lift` is how far each of the two
# legs is raised (the far or left leg first), `stride` how far the near leg is ahead in a
# side view and `swing` how far the near arm swings against it.
POSES = {
    "idle": {"sink": 0, "lift": (0, 0), "stride": 0, "swing": 0},
    "walk1": {"sink": 1, "lift": (0, 0), "stride": 2, "swing": -2},
    "walk2": {"sink": 0, "lift": (1, 0), "stride": 0, "swing": 0},
    "walk3": {"sink": 1, "lift": (0, 0), "stride": -2, "swing": 2},
    "walk4": {"sink": 0, "lift": (0, 1), "stride": 0, "swing": 0},
}


def character_canvas():
    return [[None] * CHARACTER_WIDTH for _ in range(CHARACTER_HEIGHT)]


def leg_boxes(facing, pose):
    """The columns, top row and bottom row of each leg, back leg first."""
    stride = pose["stride"]
    if facing in ("down", "up"):
        columns = ((5, 7), (9, 11))
    else:
        columns = ((6 - stride, 8 - stride), (7 + stride, 9 + stride))
    return [(x0, x1, 23 + pose["sink"], 30 - lift) for (x0, x1), lift in zip(columns, pose["lift"])]


def draw_body(facing, pose, skin="skin", shade="skin_shade", **_):
    """The figure in a linen undershirt and shorts: head, arms with hands, and legs. Worn
    clothes cover most of it, so this layer is also the silhouette that the outline follows."""
    canvas = character_canvas()
    sink, swing = pose["sink"], pose["swing"]
    # The head, with its top corners cut.
    fill_rect(canvas, 4, 6 + sink, 12, 12 + sink, skin)
    fill_rect(canvas, 5, 5 + sink, 11, 5 + sink, skin)
    fill_rect(canvas, 5, 12 + sink, 11, 12 + sink, shade)
    boxes = leg_boxes(facing, pose)
    for x0, x1, top, bottom in boxes:
        fill_rect(canvas, x0, top, x1, bottom, skin)
        fill_rect(canvas, x0, bottom - 1, x1, bottom, shade)
    if facing in ("down", "up"):
        fill_rect(canvas, 6, 13 + sink, 10, 22 + sink, shade)
        fill_rect(canvas, 8, boxes[0][2], 8, boxes[0][3] - 3, shade)
        # The right arm swings; the left one holds the tool.
        fill_rect(canvas, 4, 14 + sink, 5, 20 + sink, skin)
        fill_rect(canvas, 11, 14 + sink + swing // 2, 12, 20 + sink + swing // 2, skin)
        if facing == "down":
            for x in (6, 10):
                fill_rect(canvas, x, 9 + sink, x, 10 + sink, "soil_dark")
            canvas[11 + sink][5] = canvas[11 + sink][11] = "petal"
        # The undershirt, with short sleeves, and the shorts down to the thighs.
        fill_rect(canvas, 6, 13 + sink, 10, 20 + sink, UNDERSHIRT)
        fill_rect(canvas, 10, 15 + sink, 10, 20 + sink, UNDERSHIRT_SHADE)
        for x0, dy in ((4, 0), (11, swing // 2)):
            fill_rect(canvas, x0, 14 + sink + dy, x0 + 1, 15 + sink + dy, UNDERSHIRT)
        fill_rect(canvas, 6, 21 + sink, 10, 22 + sink, SHORTS)
    else:
        fill_rect(canvas, 5, 13 + sink, 10, 22 + sink, shade)
        canvas[10 + sink][13] = skin
        fill_rect(canvas, 11, 9 + sink, 11, 10 + sink, "soil_dark")
        fill_rect(canvas, 7 + swing // 2, 14 + sink, 8 + swing // 2, 17 + sink, skin)
        fill_rect(canvas, 7 + swing, 18 + sink, 8 + swing, 20 + sink, skin)
        fill_rect(canvas, 5, 13 + sink, 10, 20 + sink, UNDERSHIRT)
        fill_rect(canvas, 5, 15 + sink, 5, 20 + sink, UNDERSHIRT_SHADE)
        fill_rect(canvas, 7 + swing // 2, 14 + sink, 8 + swing // 2, 15 + sink, UNDERSHIRT)
        fill_rect(canvas, 5, 21 + sink, 10, 22 + sink, SHORTS)
    for x0, x1, top, _bottom in boxes:
        fill_rect(canvas, x0, top, x1, top + 2, SHORTS)
    return canvas


def draw_legs(facing, pose, **_):
    """Linen trousers and leather boots."""
    canvas = character_canvas()
    boxes = leg_boxes(facing, pose)
    for index, (x0, x1, top, bottom) in enumerate(boxes):
        fill_rect(canvas, x0, top, x1, bottom - 3, "sand")
        fill_rect(canvas, x0, bottom - 2, x1, bottom, "soil")
        fill_rect(canvas, x0, bottom - 2, x1, bottom - 2, "soil_light")
        fill_rect(canvas, x0, bottom, x1, bottom, "soil_dark")
        # The inside of each leg is shaded, which also marks it against the other one.
        seam = x1 if index == 0 and facing in ("down", "up") else x0
        fill_rect(canvas, seam, top, seam, bottom - 3, "mud")
        if facing in ("left", "right"):
            canvas[bottom][x1 + 1] = canvas[bottom - 1][x1 + 1] = "soil_dark"
    if facing in ("down", "up"):
        fill_rect(canvas, 8, boxes[0][2], 8, boxes[0][3] - 3, "mud_dark")
    return canvas


def draw_clothes(facing, pose, base, light, shade, **_):
    """A belted tunic with sleeves."""
    canvas = character_canvas()
    sink, swing = pose["sink"], pose["swing"]
    if facing in ("down", "up"):
        fill_rect(canvas, 6, 13 + sink, 10, 22 + sink, base)
        fill_rect(canvas, 5, 21 + sink, 11, 22 + sink, base)
        fill_rect(canvas, 6, 13 + sink, 10, 14 + sink, light)
        fill_rect(canvas, 10, 15 + sink, 10, 20 + sink, shade)
        fill_rect(canvas, 5, 22 + sink, 11, 22 + sink, shade)
        fill_rect(canvas, 6, 19 + sink, 10, 19 + sink, "soil_dark")
        # Sleeves; the right one swings with the arm.
        for x0, dy in ((4, 0), (11, swing // 2)):
            fill_rect(canvas, x0, 14 + sink + dy, x0 + 1, 18 + sink + dy, base)
            fill_rect(canvas, x0, 14 + sink + dy, x0 + 1, 14 + sink + dy, light)
            fill_rect(canvas, x0 + 1, 15 + sink + dy, x0 + 1, 17 + sink + dy, shade)
            fill_rect(canvas, x0, 18 + sink + dy, x0 + 1, 18 + sink + dy, shade)
        if facing == "down":
            fill_rect(canvas, 7, 13 + sink, 9, 13 + sink, "cream")
            canvas[14 + sink][8] = "cream"
            canvas[19 + sink][8] = "gold"
        else:
            fill_rect(canvas, 6, 13 + sink, 10, 13 + sink, shade)
    else:
        fill_rect(canvas, 5, 13 + sink, 10, 22 + sink, base)
        fill_rect(canvas, 5, 21 + sink, 11, 22 + sink, base)
        fill_rect(canvas, 5, 13 + sink, 10, 14 + sink, light)
        fill_rect(canvas, 5, 15 + sink, 5, 21 + sink, shade)
        fill_rect(canvas, 5, 22 + sink, 11, 22 + sink, shade)
        fill_rect(canvas, 5, 19 + sink, 10, 19 + sink, "soil_dark")
        canvas[19 + sink][10] = "gold"
        fill_rect(canvas, 8, 13 + sink, 10, 13 + sink, "cream")
        # The near sleeve over the torso: a shaded edge at the back, and the cuff.
        for y in range(14 + sink, 19 + sink):
            x = 7 + (swing // 2 if y < 17 + sink else swing)
            canvas[y][x], canvas[y][x + 1] = shade, base
        fill_rect(canvas, 7 + swing // 2, 14 + sink, 8 + swing // 2, 14 + sink, light)
        fill_rect(canvas, 7 + swing, 18 + sink, 8 + swing, 18 + sink, shade)
    return canvas


def draw_hair(facing, pose, base, light, shade, long, **_):
    """Short or long hair over the head (the same 9x8 block in every view), and from behind
    over the whole back of it. The darkest shade is the line to the face."""
    canvas = character_canvas()
    sink = pose["sink"]
    fill_rect(canvas, 5, 5 + sink, 11, 5 + sink, base)
    fill_rect(canvas, 4, 6 + sink, 12, 7 + sink, base)
    fill_rect(canvas, 5, 6 + sink, 7, 6 + sink, light)
    if facing == "down":
        fill_rect(canvas, 6, 7 + sink, 10, 7 + sink, shade)
        for x in (4, 12):
            fill_rect(canvas, x, 8 + sink, x, 9 + sink, base)
            canvas[9 + sink][x] = shade
        if long:
            for x in (4, 12):
                fill_rect(canvas, x, 10 + sink, x, 14 + sink, base)
                fill_rect(canvas, x, 13 + sink, x, 14 + sink, shade)
    elif facing == "up":
        fill_rect(canvas, 4, 8 + sink, 12, 11 + sink, base)
        fill_rect(canvas, 5, 12 + sink, 11, 12 + sink, shade)
        fill_rect(canvas, 8, 7 + sink, 8, 11 + sink, shade)
        fill_rect(canvas, 6, 8 + sink, 6, 9 + sink, light)
        if long:
            fill_rect(canvas, 4, 12 + sink, 12, 16 + sink, base)
            fill_rect(canvas, 5, 17 + sink, 11, 17 + sink, base)
            fill_rect(canvas, 8, 12 + sink, 8, 16 + sink, shade)
            fill_rect(canvas, 6, 13 + sink, 6, 15 + sink, light)
            fill_rect(canvas, 5, 16 + sink, 11, 17 + sink, shade)
    else:
        fill_rect(canvas, 10, 7 + sink, 12, 7 + sink, shade)
        fill_rect(canvas, 4, 8 + sink, 8, 11 + sink, base)
        fill_rect(canvas, 8, 8 + sink, 8, 11 + sink, shade)
        fill_rect(canvas, 5, 12 + sink, 7, 12 + sink, shade)
        fill_rect(canvas, 5, 8 + sink, 5, 9 + sink, light)
        if long:
            fill_rect(canvas, 3, 8 + sink, 6, 16 + sink, base)
            fill_rect(canvas, 3, 15 + sink, 6, 16 + sink, shade)
            fill_rect(canvas, 4, 11 + sink, 4, 14 + sink, light)
    return canvas


def draw_straw_hat(facing, pose, **_):
    """A straw hat: a round crown with a dark band and a wide brim over the hair. Seen from
    the side the brim reaches further forward (right, mirrored for left) than back."""
    canvas = character_canvas()
    sink = pose["sink"]
    brim = (2, 14) if facing in ("down", "up") else (3, 14)
    fill_rect(canvas, 5, 3 + sink, 11, 5 + sink, "straw")
    fill_rect(canvas, 6, 2 + sink, 10, 2 + sink, "straw")
    fill_rect(canvas, 6, 2 + sink, 8, 2 + sink, "sand_light")
    fill_rect(canvas, 5, 5 + sink, 11, 5 + sink, "soil")
    fill_rect(canvas, brim[0], 6 + sink, brim[1], 7 + sink, "straw")
    fill_rect(canvas, brim[0], 6 + sink, brim[1], 6 + sink, "sand_light")
    fill_rect(canvas, brim[0], 7 + sink, brim[1], 7 + sink, "reed")
    return canvas


def draw_held_hoe(facing, pose, **_):
    """A hoe in the right hand, in dark soil colours with a light edge on the blade."""
    canvas = character_canvas()
    sink = pose["sink"]
    if facing in ("down", "up"):
        shaft = 3 if facing == "down" else 13
        top = 13 + sink
        fill_rect(canvas, shaft, top, shaft, 30, "soil_dark")
        blade = (shaft - 2, shaft) if facing == "down" else (shaft, shaft + 2)
        fill_rect(canvas, blade[0], top - 1, blade[1], top, "soil_dark")
        fill_rect(canvas, blade[0], top - 1, blade[1], top - 1, "soil_light")
        if facing == "down":
            fill_rect(canvas, shaft, 19, shaft, 20, "skin")
    else:
        top = 13 + sink
        fill_rect(canvas, 12, top, 12, 30, "soil_dark")
        fill_rect(canvas, 12, top + 1, 14, top + 2, "soil_dark")
        fill_rect(canvas, 12, top + 1, 14, top + 1, "soil_light")
        fill_rect(canvas, 11, 19, 12, 20, "skin")
    return canvas


def mirrored(canvas):
    return [row[::-1] for row in canvas]


def outlined(canvas, skip):
    """Adds a 1 px ink outline around the drawing, except on pixels covered by `skip`: the
    body already outlines itself, and a layer drawn over it must not cut lines into it."""
    covered = {(x, y) for y in range(CHARACTER_HEIGHT) for x in range(CHARACTER_WIDTH) if canvas[y][x] is not None}
    for x, y in covered:
        for dx, dy in NEIGHBOURS:
            nx, ny = x + dx, y + dy
            if 0 <= nx < CHARACTER_WIDTH and 0 <= ny < CHARACTER_HEIGHT and (nx, ny) not in covered and (nx, ny) not in skip:
                canvas[ny][nx] = "ink"
    return canvas


def character_sheet(draw, variant_colours):
    """One layer's sheet: the layer drawn in every facing and frame, with its outline."""
    rows = []
    for facing in PLAYER_FACINGS:
        drawn_facing = "right" if facing == "left" else facing
        row = []
        for frame in PLAYER_FRAMES:
            pose = POSES[frame]
            body = draw_body(drawn_facing, pose)
            body_pixels = {(x, y) for y in range(CHARACTER_HEIGHT) for x in range(CHARACTER_WIDTH) if body[y][x] is not None}
            canvas = draw(drawn_facing, pose, **variant_colours)
            canvas = outlined(canvas, set() if draw is draw_body else body_pixels)
            row.append(mirrored(canvas) if facing == "left" else canvas)
        rows.append(row)
    return rows


# Layer sheets by file name (assets/character/<name>.png).
CHARACTER_SHEETS = {"body_0": character_sheet(draw_body, {})}
for _variant, _colours in CLOTHES_COLOURS.items():
    CHARACTER_SHEETS[f"clothes_{_variant}"] = character_sheet(draw_clothes, _colours)
for _variant, _colours in HAIR_COLOURS.items():
    CHARACTER_SHEETS[f"hair_{_variant}"] = character_sheet(draw_hair, _colours)
CHARACTER_SHEETS["legs_0"] = character_sheet(draw_legs, {})
CHARACTER_SHEETS["head_straw_hat"] = character_sheet(draw_straw_hat, {})
CHARACTER_SHEETS["held_hoe"] = character_sheet(draw_held_hoe, {})



# The interior (assets/interior.png and assets/interior/*.png), used by maps/interiors/*.tsx
# and game/scenes/interior_view.gd. The room is seen in 3/4 view: the back wall as a face 2
# tiles high, the side and front walls only as their 8 px thick tops.
#
# assets/interior.png is one row of 16x16 tiles, in the order of INTERIOR_GROUND_TILES, then
# one marker tile per piece of furniture (the top left tile of its footprint, so Tiled shows
# what is where). The game draws the furniture from assets/interior/<name>.png instead:
# sprites of any size, centred on their footprint with their bottom edge on its bottom edge.

RIM = 8


def outline(canvas, colour, keep_bottom=False):
    """Gives the picture's border (pixels next to clear ones or the image edge) `colour`.
    keep_bottom leaves the bottom edge alone: the picture stands on the ground there."""
    height, width = len(canvas), len(canvas[0])
    border = []
    for y in range(height):
        for x in range(width):
            if canvas[y][x] is None or (keep_bottom and y == height - 1):
                continue
            for dx, dy in NEIGHBOURS:
                nx, ny = x + dx, y + dy
                if not (0 <= nx < width and 0 <= ny < height) or canvas[ny][nx] is None:
                    border.append((x, y))
                    break
    for x, y in border:
        canvas[y][x] = colour
    return canvas


def sprite_canvas(width, height):
    return [[None] * width for _ in range(height)]


def planks(canvas, light, dark):
    for y in range(TILE):
        for x in range(TILE):
            canvas[y][x] = light if (y // 4) % 2 == 0 else dark
    for y in range(3, TILE, 4):
        fill_rect(canvas, 0, y, TILE - 1, y, "soil")
    # Board ends, staggered row by row.
    for row, x in enumerate((5, 12, 8, 2)):
        fill_rect(canvas, x, row * 4, x, row * 4 + 2, "soil")
    return canvas


def interior_floor():
    return planks(blank(), "soil_light", "soil_mid")


def interior_floor_shaded():
    """The floor row along the back wall, in its shadow."""
    canvas = planks(blank(), "soil_mid", "soil")
    fill_rect(canvas, 0, 0, TILE - 1, 1, "soil_dark")
    return canvas


def clear_columns(canvas, left, right):
    """Clears the columns left..right (both ends included)."""
    for row in canvas:
        for x in range(left, right + 1):
            row[x] = None
    return canvas


WALL_TOP_SHADES = ("soil_dark", "soil_light", "soil_mid", "soil_mid", "soil_mid", "soil_mid", "soil", "soil_dark")


def rim_left():
    """The top of the left wall: its 8 px next to the room are the right half of the tile."""
    canvas = blank()
    for x, colour in zip(range(RIM, TILE), WALL_TOP_SHADES):
        fill_rect(canvas, x, 0, x, TILE - 1, colour)
    return canvas


def rim_front():
    """The top of the front wall: its 8 px next to the room are the top half of the tile."""
    canvas = blank()
    for y, colour in zip(range(RIM), WALL_TOP_SHADES[::-1]):
        fill_rect(canvas, 0, y, TILE - 1, y, colour)
    return canvas


def mirrored_tile(canvas):
    return [row[::-1] for row in canvas]


def interior_doormat():
    """The exit: a woven mat 16x8 across the gap in the front wall."""
    canvas = blank()
    fill_rect(canvas, 0, 0, TILE - 1, 7, "soil_dark")
    fill_rect(canvas, 1, 1, TILE - 2, 6, "straw")
    for y in (2, 4):
        fill_rect(canvas, 1, y, TILE - 2, y, "dry_light")
    fill_rect(canvas, 1, 6, TILE - 2, 6, "reed")
    return canvas


def back_wall_top():
    """The upper tile of the back wall: a beam over plaster."""
    canvas = filled("sand_light")
    rng = random.Random(131)
    for _ in range(9):
        canvas[rng.randrange(5, TILE)][rng.randrange(TILE)] = "sand"
    fill_rect(canvas, 0, 0, TILE - 1, 0, "soil_mid")
    fill_rect(canvas, 0, 1, TILE - 1, 2, "soil")
    fill_rect(canvas, 0, 2, TILE - 1, 2, "soil_dark")
    fill_rect(canvas, 0, 3, TILE - 1, 3, "mud")
    return canvas


def back_wall_bottom():
    """The lower tile of the back wall: plaster over a wainscot of panels."""
    canvas = filled("sand_light")
    rng = random.Random(132)
    for _ in range(5):
        canvas[rng.randrange(0, 5)][rng.randrange(TILE)] = "sand"
    fill_rect(canvas, 0, 5, TILE - 1, 5, "soil_light")
    fill_rect(canvas, 0, 6, TILE - 1, 6, "soil")
    fill_rect(canvas, 0, 7, TILE - 1, 13, "soil_mid")
    fill_rect(canvas, 0, 14, TILE - 1, 15, "soil_dark")
    for x in (0, 7, 8, 15):
        fill_rect(canvas, x, 7, x, 13, "soil")
    return canvas


def back_wall_end(tile, is_left):
    """A back wall tile at a corner: only the 8 px next to the room, ending in a post."""
    canvas = copy(tile)
    if is_left:
        clear_columns(canvas, 0, RIM - 1)
        post = (RIM, RIM + 1)
    else:
        clear_columns(canvas, RIM, TILE - 1)
        post = (RIM - 1, RIM - 2)
    for y in range(TILE):
        canvas[y][post[0]] = "soil_dark"
        canvas[y][post[1]] = "soil_mid"
    return canvas


def window_picture():
    """A 10x10 window with a sill, 16x32: drawn over the plaster of the back wall face."""
    canvas = sprite_canvas(TILE, 2 * TILE)
    fill_rect(canvas, 3, 7, 12, 16, "soil_dark")
    fill_rect(canvas, 4, 8, 11, 15, "water")
    fill_rect(canvas, 4, 8, 6, 10, "water_light")
    fill_rect(canvas, 7, 8, 7, 15, "soil_dark")
    fill_rect(canvas, 4, 12, 11, 12, "soil_dark")
    fill_rect(canvas, 2, 17, 13, 17, "soil_light")
    fill_rect(canvas, 2, 18, 13, 18, "soil_mid")
    fill_rect(canvas, 3, 19, 12, 19, "mud")
    return canvas


def bed():
    """A bed 1x2 tiles, head to the north: frame, pillow and a blanket with a folded edge."""
    canvas = sprite_canvas(TILE, 2 * TILE)
    fill_rect(canvas, 0, 0, 15, 31, "soil_mid")
    fill_rect(canvas, 0, 0, 15, 5, "soil")
    fill_rect(canvas, 1, 1, 14, 1, "soil_light")
    fill_rect(canvas, 2, 6, 13, 12, "cream")
    fill_rect(canvas, 2, 12, 13, 12, "sand_light")
    fill_rect(canvas, 2, 13, 13, 28, "ember")
    fill_rect(canvas, 2, 13, 13, 15, "flame")
    fill_rect(canvas, 2, 15, 13, 15, "ember")
    fill_rect(canvas, 11, 16, 13, 28, "soil")
    fill_rect(canvas, 5, 20, 7, 21, "soil")
    fill_rect(canvas, 2, 29, 13, 31, "soil")
    fill_rect(canvas, 0, 29, 15, 29, "soil_light")
    outline(canvas, "soil_dark")
    return canvas


def table():
    """A table 2x1 tiles: a plank top, an apron and two legs; a candle and a bowl on it."""
    canvas = sprite_canvas(2 * TILE, 24)
    fill_rect(canvas, 0, 0, 31, 15, "soil_light")
    for y in (4, 9, 14):
        fill_rect(canvas, 0, y, 31, y, "soil_mid")
    fill_rect(canvas, 0, 16, 31, 17, "soil_mid")
    fill_rect(canvas, 0, 18, 31, 18, "soil_dark")
    for x in (2, 27):
        fill_rect(canvas, x, 19, x + 2, 23, "soil")
        fill_rect(canvas, x, 19, x, 23, "soil_mid")
    fill_rect(canvas, 23, 5, 24, 9, "cream")
    fill_rect(canvas, 23, 3, 24, 4, "gold")
    fill_rect(canvas, 7, 6, 12, 9, "stone_light")
    fill_rect(canvas, 8, 7, 11, 8, "stone_dark")
    return outline(canvas, "soil_dark", keep_bottom=True)


def stool():
    """A stool, 10x10 on its 16x16 tile."""
    canvas = sprite_canvas(10, 10)
    fill_rect(canvas, 0, 0, 9, 4, "soil_light")
    fill_rect(canvas, 0, 4, 9, 4, "soil_mid")
    for x in (1, 7):
        fill_rect(canvas, x, 5, x + 1, 9, "soil")
    fill_rect(canvas, 4, 5, 5, 8, "soil_dark")
    return outline(canvas, "soil_dark", keep_bottom=True)


def chest():
    """A chest with iron bands and a gold lock, 1x1 tiles."""
    canvas = sprite_canvas(TILE, TILE)
    fill_rect(canvas, 0, 1, 15, 6, "soil_mid")
    fill_rect(canvas, 1, 1, 14, 1, "soil_light")
    fill_rect(canvas, 0, 7, 15, 15, "soil")
    for x in (2, 12):
        fill_rect(canvas, x, 1, x + 1, 15, "stone")
        fill_rect(canvas, x, 1, x, 15, "stone_light")
    fill_rect(canvas, 7, 5, 8, 8, "gold")
    fill_rect(canvas, 0, 7, 15, 7, "soil_dark")
    return outline(canvas, "soil_dark", keep_bottom=True)


def hearth():
    """A stone hearth 2x2 tiles with a fire in it."""
    canvas = sprite_canvas(2 * TILE, 2 * TILE)
    fill_rect(canvas, 0, 0, 31, 29, "stone")
    for y in range(4, 30, 4):
        fill_rect(canvas, 0, y, 31, y, "stone_dark")
        for x in range(2 + (y // 4 % 2) * 4, 32, 8):
            fill_rect(canvas, x, y - 3, x, y - 1, "stone_dark")
    fill_rect(canvas, 0, 0, 31, 2, "stone_light")
    fill_rect(canvas, 0, 3, 31, 3, "stone_dark")
    # Firebox with two logs and a flame.
    fill_rect(canvas, 7, 9, 24, 28, "stone_dark")
    fill_rect(canvas, 8, 10, 23, 28, "soil_dark")
    fill_rect(canvas, 9, 25, 22, 27, "soil")
    fill_rect(canvas, 9, 25, 22, 25, "soil_mid")
    for y in range(13, 26):
        reach = 5.5 * (1 - (25 - y) / 14.0) ** 0.7
        for colour, scale in (("flame", 1.0), ("gold", 0.65), ("cream", 0.3)):
            for x in range(10, 22):
                if abs(x + 0.5 - 16) <= reach * scale:
                    canvas[y][x] = colour
    # Hearthstone in front.
    fill_rect(canvas, 2, 29, 29, 31, "stone_light")
    fill_rect(canvas, 2, 31, 29, 31, "stone")
    return outline(canvas, "soil_dark", keep_bottom=True)


# Furniture by name: its picture and its footprint in tiles. The marker tiles and the files
# follow this order.
FURNITURE = {
    "bed": (bed(), (1, 2)),
    "table": (table(), (2, 1)),
    "stool": (stool(), (1, 1)),
    "chest": (chest(), (1, 1)),
    "hearth": (hearth(), (2, 2)),
    "window": (window_picture(), (1, 2)),
}


def marker_tile(picture, footprint):
    """The top left tile of the footprint of a sprite that is centred on it."""
    width, height = len(picture[0]), len(picture)
    left = (width - footprint[0] * TILE) // 2
    top = height - footprint[1] * TILE
    tile = blank()
    for y in range(TILE):
        for x in range(TILE):
            if 0 <= top + y < height and 0 <= left + x < width:
                tile[y][x] = picture[top + y][left + x]
    return tile


INTERIOR_GROUND_TILES = {
    "floor": interior_floor(),
    "floor_shaded": interior_floor_shaded(),
    "rim_left": rim_left(),
    "rim_right": mirrored_tile(rim_left()),
    "rim_front": rim_front(),
    "front_left": clear_columns(rim_front(), 0, RIM - 1),
    "front_right": clear_columns(rim_front(), RIM, TILE - 1),
    "doormat": interior_doormat(),
    "back_top": back_wall_top(),
    "back_bottom": back_wall_bottom(),
    "back_left_top": back_wall_end(back_wall_top(), True),
    "back_left_bottom": back_wall_end(back_wall_bottom(), True),
    "back_right_top": back_wall_end(back_wall_top(), False),
    "back_right_bottom": back_wall_end(back_wall_bottom(), False),
}
INTERIOR_TILES = list(INTERIOR_GROUND_TILES.values()) + [
    marker_tile(*FURNITURE[name]) for name in FURNITURE
]


# The small house (assets/buildings/small_house.png, and small_house_lit.png with lit
# windows for the night). 5x3 tiles plus the roof above: 80x96. Seen from the front in 3/4
# view: a stone foundation, plaster walls with timber, a thatched roof whose eaves hang 3 px
# past the walls, and a chimney. Light comes from the top left, so the right of the wall is
# darker. The door is on the middle tile of the bottom row.

HOUSE_WIDTH = 80
HOUSE_HEIGHT = 96
HOUSE_RIDGE_Y = 14
HOUSE_EAVES_Y = 58
HOUSE_WALL_LEFT = 3
HOUSE_WALL_RIGHT = 76
# Top left corner of the 10x10 frame of each window. The same places are in
# game/state/building_types.gd, where each gets a light.
HOUSE_WINDOWS = ((10, 70), (60, 70))
THATCH_DARKER = {"straw": "sand_light", "sand_light": "sand", "sand": "mud", "gold": "straw"}


def thatch_roof(canvas, rng):
    """A trapezoid of straw courses 4 rows high, with a dark line under each course."""
    rows = HOUSE_EAVES_Y - HOUSE_RIDGE_Y + 1
    for y in range(HOUSE_RIDGE_Y, HOUSE_EAVES_Y + 1):
        reach = 1 - (y - HOUSE_RIDGE_Y) / (rows - 1)
        left = round(18 * reach)
        right = HOUSE_WIDTH - 1 - round(18 * reach)
        line = (y - HOUSE_RIDGE_Y) % 4
        for x in range(left, right + 1):
            colour = ("straw", "sand_light", "straw", "sand")[line]
            if line == 0 and rng.random() < 0.16:
                colour = "gold"
            if line == 1 and rng.random() < 0.1:
                colour = "dry_light"
            # Light from the left: the right of the roof is in shade, with a ragged edge.
            if x > 50 + rng.random() * 12:
                colour = THATCH_DARKER.get(colour, colour)
            canvas[y][x] = colour
    for x in range(HOUSE_WIDTH):
        if canvas[HOUSE_EAVES_Y][x] is not None:
            canvas[HOUSE_EAVES_Y - 1][x] = "mud"
            canvas[HOUSE_EAVES_Y][x] = "soil_dark"
    # The ridge: a cap of bundled straw.
    fill_rect(canvas, 18, HOUSE_RIDGE_Y, 61, HOUSE_RIDGE_Y + 1, "gold")
    fill_rect(canvas, 18, HOUSE_RIDGE_Y + 1, 61, HOUSE_RIDGE_Y + 1, "straw")
    fill_rect(canvas, 18, HOUSE_RIDGE_Y + 2, 61, HOUSE_RIDGE_Y + 2, "sand")


def house_window(canvas, left, top, is_lit):
    fill_rect(canvas, left, top, left + 9, top + 9, "soil_dark")
    if is_lit:
        fill_rect(canvas, left + 1, top + 1, left + 8, top + 8, "gold")
        fill_rect(canvas, left + 2, top + 2, left + 4, top + 4, "cream")
        fill_rect(canvas, left + 5, top + 5, left + 7, top + 7, "flame")
    else:
        fill_rect(canvas, left + 1, top + 1, left + 8, top + 8, "water")
        fill_rect(canvas, left + 1, top + 1, left + 3, top + 3, "water_light")
    fill_rect(canvas, left + 4, top + 1, left + 4, top + 8, "soil_dark")
    fill_rect(canvas, left + 1, top + 4, left + 8, top + 4, "soil_dark")
    fill_rect(canvas, left - 2, top + 10, left + 11, top + 10, "soil_light")
    fill_rect(canvas, left - 2, top + 11, left + 11, top + 11, "soil_mid")
    fill_rect(canvas, left - 1, top + 12, left + 10, top + 12, "mud")


def small_house(is_lit=False):
    rng = random.Random(121)
    canvas = sprite_canvas(HOUSE_WIDTH, HOUSE_HEIGHT)
    wall_top = HOUSE_EAVES_Y + 1
    wall_bottom = 93

    # Chimney first, so the roof covers its foot: 8 px wide, 12 px above the ridge.
    fill_rect(canvas, 52, 2, 59, 24, "stone")
    fill_rect(canvas, 52, 4, 53, 24, "stone_light")
    fill_rect(canvas, 58, 4, 59, 24, "stone_dark")
    for y in range(6, 25, 4):
        fill_rect(canvas, 52, y, 59, y, "stone_dark")
    fill_rect(canvas, 51, 2, 60, 3, "stone_light")
    fill_rect(canvas, 51, 3, 60, 3, "stone_dark")

    # Walls: plaster between timber, the right side in shade, on a stone foundation.
    fill_rect(canvas, HOUSE_WALL_LEFT, wall_top, HOUSE_WALL_RIGHT, wall_bottom, "sand_light")
    for _ in range(60):
        x = rng.randrange(HOUSE_WALL_LEFT + 2, HOUSE_WALL_RIGHT - 1)
        canvas[rng.randrange(wall_top + 4, 86)][x] = "sand"
    fill_rect(canvas, 64, wall_top, HOUSE_WALL_RIGHT, wall_bottom, "sand")
    for _ in range(14):
        canvas[rng.randrange(wall_top + 4, 86)][rng.randrange(64, HOUSE_WALL_RIGHT - 1)] = "mud"
    for left, colour in ((HOUSE_WALL_LEFT, "soil_mid"), (HOUSE_WALL_RIGHT - 1, "soil")):
        fill_rect(canvas, left, wall_top, left + 1, wall_bottom, colour)
    fill_rect(canvas, HOUSE_WALL_LEFT, 84, HOUSE_WALL_RIGHT, 85, "soil")
    fill_rect(canvas, HOUSE_WALL_LEFT, 84, HOUSE_WALL_RIGHT, 84, "soil_mid")
    fill_rect(canvas, HOUSE_WALL_LEFT, 90, HOUSE_WALL_RIGHT, wall_bottom, "stone")
    for x in range(HOUSE_WALL_LEFT, HOUSE_WALL_RIGHT + 1, 8):
        fill_rect(canvas, x, 91, min(x + 3, HOUSE_WALL_RIGHT), 92, "stone_light")
    fill_rect(canvas, HOUSE_WALL_LEFT, 90, HOUSE_WALL_RIGHT, 90, "stone_light")
    fill_rect(canvas, HOUSE_WALL_LEFT, wall_bottom, HOUSE_WALL_RIGHT, wall_bottom, "stone_dark")

    for left, top in HOUSE_WINDOWS:
        house_window(canvas, left, top, is_lit)

    # Door on the middle tile (x 32..47): frame, 14x26 planks, hinges, handle, stone step.
    fill_rect(canvas, 32, 63, 47, 90, "soil_dark")
    fill_rect(canvas, 33, 65, 46, 90, "soil_mid")
    fill_rect(canvas, 33, 65, 46, 65, "soil")
    fill_rect(canvas, 33, 65, 33, 90, "soil_light")
    for x in (37, 41, 45):
        fill_rect(canvas, x, 66, x, 90, "soil")
    for y in (69, 85):
        fill_rect(canvas, 34, y, 39, y, "soil_dark")
    fill_rect(canvas, 43, 78, 44, 79, "gold")
    fill_rect(canvas, 30, 91, 49, 93, "stone")
    fill_rect(canvas, 30, 91, 49, 91, "stone_light")
    fill_rect(canvas, 30, 93, 49, 93, "stone_dark")

    # The shadow of the eaves on the wall, then the roof.
    for y, colour in ((wall_top, "mud"), (wall_top + 1, "mud"), (wall_top + 2, "sand"), (wall_top + 3, "sand")):
        for x in range(HOUSE_WALL_LEFT, HOUSE_WALL_RIGHT + 1):
            if canvas[y][x] in ("sand_light", "sand"):
                canvas[y][x] = colour
    thatch_roof(canvas, rng)
    outline(canvas, "soil_dark")

    # A contact shadow on the ground in front, on the bottom 2 rows.
    for x in range(1, HOUSE_WIDTH - 1):
        canvas[HOUSE_HEIGHT - 2][x] = "green_deep"
        if x % 2 == 0 and 2 < x < HOUSE_WIDTH - 3:
            canvas[HOUSE_HEIGHT - 1][x] = "green_deep"
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
    to_image(
        OBJECTS + CAMP_OBJECTS + vegetation() + [TURNIP_STAGES] + BOULDERS + STUMPS,
        OBJECT_CELL_WIDTH,
        OBJECT_CELL_HEIGHT,
    ).save(
        ASSETS / "objects.png"
    )
    (ASSETS / "character").mkdir(exist_ok=True)
    for name, rows in CHARACTER_SHEETS.items():
        to_image(rows, CHARACTER_WIDTH, CHARACTER_HEIGHT).save(ASSETS / "character" / f"{name}.png")
    (ASSETS / "buildings").mkdir(exist_ok=True)
    for name, is_lit in (("small_house", False), ("small_house_lit", True)):
        to_image([[small_house(is_lit)]], HOUSE_WIDTH, HOUSE_HEIGHT).save(
            ASSETS / "buildings" / f"{name}.png"
        )
    to_image([INTERIOR_TILES]).save(ASSETS / "interior.png")
    (ASSETS / "interior").mkdir(exist_ok=True)
    for name, (picture, _footprint) in FURNITURE.items():
        to_image([[picture]], len(picture[0]), len(picture)).save(ASSETS / "interior" / f"{name}.png")
    for directory, pictures in (("items", items.ICONS), ("ui", items.SLOTS | items.SLOT_HINTS)):
        (ASSETS / directory).mkdir(exist_ok=True)
        for name, picture in pictures.items():
            to_image([[picture]], len(picture)).save(ASSETS / directory / f"{name}.png")
    ui.write_ui_assets(ASSETS / "ui", PALETTE)
    write_palette()
    check_palette()
    print("Wrote terrain.png, decorations.png, objects.png, character/*.png, interior.png, interior/*.png, buildings/*.png, items/*.png, ui/*, palette.png and palette.gpl to assets/; palette check passed.")


if __name__ == "__main__":
    main()
