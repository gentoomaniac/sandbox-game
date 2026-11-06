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
row 3 the bedroll (the sleeping_bag object; 1 variant each), then the vegetation rows from 4 (see vegetation()),
row 11 the boulder, row 12 the stump, row 13 the tall grass (3 tufts, then the same 3 mown;
see meadow.py) and rows 14 to 21 the trunks (see trunks.py) and row 22 the reeds (3 stands, then the same 3 cut;
see reeds.py) and row 23 the dead tree's stump (2 variants). The rows and
counts are in game/state/world_object_types.gd.
An object stands on one tile: the bottom centre 16x16 of its cell (x 16..31, y 64..79). A tree's
crown rises above that, over the tiles around it. An object on several tiles (boulder 2x1,
bedroll 1x2) is centred on its footprint, with the cell's bottom on the footprint's bottom.

Terrain, decorations and objects also exist per look (see seasons.py: spring, summer, autumn,
bare, frost, snow, dusting), the objects also in the steps of the spring leaf-out (buds, young
leaves), the building pictures in summer and snow: summer under the names above, the others
with the look added, e.g. assets/terrain_snow.png, assets/objects_young_leaves.png and
assets/buildings/kate_lit_snow.png.

assets/character/<slot>_<variant>.png: one sheet per layer of the player character, 16x32 cells
with the feet on the bottom row. One row per facing (down, up, left, right), columns: idle,
walk 1 to 4 (see game/state/appearance.gd and game/scenes/player_view.gd).
assets/character/collapse/<slot>_<variant>.png: the same layers passing out, one row of 32x32
cells facing right: kneeling, tipping over, lying and asleep (see `collapse_sheet`).
assets/effects/sleep_z.png: the "z" that rises from a sleeping figure.

assets/buildings/<type>.png: one picture per building type (drawn in buildings.py), as wide as
its footprint (16 px per tile) and as tall as the footprint plus the roof rising above it. The
bottom edge is the footprint's bottom edge. <type>_lit.png is the same with lit windows, for the
night. Sizes and door tiles are in data/buildings.cfg.

assets/fire/<type>.png: the flame of the fireplace and of the hearth, burning (see fire.py and
game/scenes/fire.gdshader). Cells the size of the box the flame burns in: what is behind the
flame, what is in front of it, then the frames of the flame. The atlas cell and the hearth's
picture show the first frame, for where the fire does not move.

assets/wildlife/<kind>.png: one sheet per animal kind, one row per action and one column per frame
(see animals.py and game/scenes/wildlife/wildlife_sprites.gd).

assets/crops/<crop>.png: one sheet per crop, its four growth stages and the dead one side by side, 16 px
wide cells and as tall as the sheet (see crops.py and data/crops.cfg). They have no seasonal variants.

assets/soil_wet.png: the damp and the wet look of tilled soil, two 16x16 tiles (see crop_icons.py).

assets/clay_hint.png: the faint hint of a clay spot, one 16x16 tile (see meadow.py).

assets/items/<item id>.png (16x16) and assets/ui/slot.png, slot_selected.png (20x20): drawn in
items.py, for tools in tool_icons.py and for crops in crop_icons.py. assets/ground_items/<item
id>.png are their 8x8 versions for items lying on the ground (items.small), made for every icon
(the tools too).
"""

import math
import random

import animals
import buildings
import chest
import crop_icons
import crops
import fire
import items
import meadow
import reeds
import seasons
import tool_icons
import trunks
import ui
from canvas import (
    OBJECT_BOTTOM,
    OBJECT_CELL_HEIGHT,
    OBJECT_CELL_WIDTH,
    OBJECT_CENTRE,
    TILE,
    blank,
    copy,
    rect,
)
from palette import ASSETS, PALETTE, check_palette, to_image, write_palette

# Dual-grid corner bits, shared with game/scenes/terrain_tileset.gd.
TL, TR, BL, BR = 1, 2, 4, 8
FULL = TL | TR | BL | BR
# Edge-shape variants per mask, shared with game/scenes/terrain_tileset.gd.
EDGE_VARIANTS = 3

NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def filled(colour):
    return [[colour] * TILE for _ in range(TILE)]


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


# Dots in flower colours, which autumn turns into leaf colours (see seasons.py). The
# game shows them only in autumn (see data/vegetation.cfg).
fallen_leaves = sprite({"a": "gold", "b": "petal", "c": "cream"}, "aa..b", "..c.b", ".b..a", "c.aa.")


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
        decoration(67, fallen_leaves),
    ]
    return tinted_grass(("green", "green", "green_deep"), 60, tufts, decorations)


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
        decoration(76, fallen_leaves),
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
# What shade_under_crown takes for foliage: the ground shadow (once drawn in green_deep)
# too, which keeps the summer art as it was.
FOLIAGE = LEAVES + ("shadow",)


def ground_shadow(canvas, half_width, centre=OBJECT_CENTRE):
    """A soft dark ellipse on the ground under an object, 3 rows high, with a dithered
    rim; it is drawn first so the object covers its middle."""
    bottom = OBJECT_BOTTOM
    for y, reach in ((bottom - 2, half_width - 3), (bottom - 1, half_width), (bottom, half_width - 2)):
        for x in range(centre - reach, centre + reach):
            if abs(x - centre) < reach - 1 or (x + y) % 2 == 0:
                canvas[y][x] = "shadow"


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
                y - up >= 0 and canvas[y - up][x] in FOLIAGE for up in (1, 2, 3, 4)
            ):
                canvas[y][x] = dark
    for x in range(OBJECT_CELL_WIDTH):
        lowest = max((y for y in range(len(canvas)) if canvas[y][x] in FOLIAGE), default=None)
        if lowest is not None and canvas[lowest - 1][x] in ("green_bright", "green_light", "green"):
            canvas[lowest - 1][x] = "green_dark"


def oak(seed):
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
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


def bare_oak(seed):
    """The oak in winter: the trunk of the same seed, bare branches instead of the crown."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 13)
    tree_trunk(canvas, rng, 46, 7)
    branches = (
        (22, 46, -1, 20),
        (26, 46, 1, 20),
        (24, 46, rng.choice((-1, 1)), 22),
        (23, 54, -1, 14),
        (27, 52, 1, 14),
    )
    # Fewer branches on some variants, so a forest is not a wall of twigs.
    for x, y, direction, length in branches[: 5 - seed % 3]:
        draw_branch(canvas, rng, x, y, direction, length + rng.randint(-2, 2), "soil_mid")
    outline_in_bark(canvas)
    return canvas


def stone(seed):
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 8)
    # A small stone of 13x12 px, and for the second variant a pebble beside it.
    blobs = [(24, 73, 6)] if seed % 2 else [(22, 73, 5.5), (29, 76, 2.5)]
    shaded_blob(canvas, rng, blobs, ("stone_light", "stone", "stone_dark"), "stone_dark")
    return canvas


def boulder(seed):
    """A boulder on 2x1 tiles: the cell is centred on the footprint, which is 32 px wide."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
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
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 10)
    tree_trunk(canvas, rng, 66, 5)
    # Tall and narrow: six tiers, the widest at the bottom, each overlapping the next.
    tiers = [(55, 70, 14), (46, 61, 12.5), (37, 53, 11), (28, 45, 9), (20, 37, 7), (13 + rng.randint(0, 2), 29, 5)]
    for top, bottom, half_width in tiers:
        conifer_tier(canvas, rng, top, bottom, half_width + rng.uniform(-0.5, 0.5))
    shade_under_crown(canvas)
    return canvas


# A Scots pine: the trunk's bark, grey-brown and furrowed below, thin and reddish-orange in the
# crown (each lit to dark, then its outline), and the dark blue-green needles (lit top to dark
# underside, then the outline).
PINE_BARK = ("mud", "mud_dark", "soil_dark", "soil_dark")
PINE_RED_BARK = ("flame", "rust", "rust_dark", "russet_deep")
PINE_NEEDLES = ("meadow_light", "meadow", "green_deep", "bog_dark")
# Where the bark turns from grey-brown to red, in rows from the top of the cell.
PINE_RED_FROM = 56


def pine(seed):
    """A Scots pine: a tall, slightly crooked bare trunk, reddish-orange up in the crown, with
    a few flat layered clumps of dark blue-green needles high up, each on a branch of its own,
    and an irregular outline."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 9)
    top = 16 + rng.randint(0, 3)
    # The trunk wanders a little from side to side as it rises, and leans as a whole.
    lean = rng.choice((-1.5, 1.5, 2.5, -2.5))
    bend = rng.uniform(0, 6.3)
    centres = {}
    for y in range(top, OBJECT_BOTTOM + 1):
        rise = (OBJECT_BOTTOM - y) / (OBJECT_BOTTOM - top)
        centres[y] = OBJECT_CENTRE + lean * rise * rise + math.sin(rise * 5 + bend) * 0.8
    for y, centre in centres.items():
        width = 5 if y > OBJECT_BOTTOM - 26 else 4 if y > PINE_RED_FROM - 8 else 3
        flare = 2 if y == OBJECT_BOTTOM else 1 if y > OBJECT_BOTTOM - 3 else 0
        left = round(centre - width / 2) - flare
        # The red bark peels off into the grey-brown below over a few rows.
        shades = PINE_RED_BARK if y < PINE_RED_FROM + rng.randint(-3, 3) else PINE_BARK
        for x in range(left, left + width + 2 * flare):
            index = x - left
            canvas[y][x] = shades[0] if index == 1 else shades[2] if index == width + 2 * flare - 2 else shades[1]
        canvas[y][left - 1] = canvas[y][left + width + 2 * flare] = shades[3]
    # Furrows in the grey-brown bark below.
    for _ in range(7):
        y = rng.randint(PINE_RED_FROM + 2, OBJECT_BOTTOM - 4)
        x = round(centres[y]) + rng.choice((-1, 0, 1))
        canvas[y][x] = canvas[y + 1][x] = "soil_dark"
    # The needle clumps, high up and in layers: each is flat and wide, made of a few smaller
    # flat ovals so its outline is ragged, on a branch reaching out from the trunk.
    heights = [top - 1, top + 8, top + 16, top + 24][: 3 + seed % 2]
    side = rng.choice((-1, 1))
    clumps = []
    for index, cy in enumerate(heights):
        cy += rng.randint(-1, 1)
        reach = 0 if index == 0 else side * rng.randint(4, 8)
        side = -side
        cx = centres[min(max(cy, top), OBJECT_BOTTOM)] + reach
        width = 8 + rng.uniform(0, 3) + index * 1.0
        clumps.append((cx, cy, width))
        branch_y = min(max(cy + 3, top), OBJECT_BOTTOM)
        for step in range(abs(round(reach))):
            x = round(centres[branch_y]) + (step + 1) * (1 if reach > 0 else -1)
            y = branch_y - step // 2
            canvas[y][x] = "rust_dark"
    # The lowest clump is drawn first, so the ones above overlap it like layers.
    for cx, cy, width in sorted(clumps, key=lambda clump: -clump[1]):
        needle_clump(canvas, rng, cx, cy, width)
    return canvas


def needle_clump(canvas, rng, cx, cy, half_width):
    """A flat cloud of needles, lit on top and dark underneath, ragged at its rim."""
    ovals = [(cx, cy, half_width, 3.5)]
    for _ in range(5):
        ovals.append((cx + rng.uniform(-0.75, 0.75) * half_width, cy + rng.uniform(-2.5, 1.0), rng.uniform(3, 5.5), rng.uniform(2.5, 3.5)))
    covered = set()
    for y in range(max(0, math.floor(cy - 6)), math.ceil(cy + 6)):
        for x in range(math.floor(cx - half_width - 5), math.ceil(cx + half_width + 5)):
            if not 0 <= x < OBJECT_CELL_WIDTH:
                continue
            inside = min(((x + 0.5 - ox) / rx) ** 2 + ((y + 0.5 - oy) / ry) ** 2 for ox, oy, rx, ry in ovals)
            if inside < 1 + rng.uniform(-0.25, 0.25):
                covered.add((x, y))
    for x, y in sorted(covered):
        if (x, y - 1) not in covered or (x, y + 1) not in covered or (x - 1, y) not in covered or (x + 1, y) not in covered:
            canvas[y][x] = PINE_NEEDLES[3]
            continue
        # Lit where there is open sky a row or two above, dark where the clump ends below.
        lit = (x, y - 2) not in covered
        dark = (x, y + 2) not in covered or rng.random() < 0.15
        canvas[y][x] = PINE_NEEDLES[2] if dark else PINE_NEEDLES[0] if lit else PINE_NEEDLES[1]
    # Tufts of needles stick out of the rim, so it is not a smooth oval.
    rim = sorted(covered)
    for x, y in rng.sample(rim, min(len(rim), 10)):
        dx, dy = rng.choice(((0, -1), (1, -1), (-1, -1), (1, 0), (-1, 0)))
        if (x + dx, y + dy) not in covered and 0 <= x + dx < OBJECT_CELL_WIDTH and canvas[y + dy][x + dx] is None:
            canvas[y + dy][x + dx] = PINE_NEEDLES[3]


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
    """A long-dead tree: a solid, weathered grey trunk, snapped off at the top, with a few
    thick, gnarled limbs broken off short. Lit from the left, outlined in ink."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 12)
    # The trunk leans a little and bends once; it is thick at the foot, flaring into roots.
    top = 27 + rng.randint(0, 4)
    lean = rng.choice((-2, -1, 1, 2))
    trunk = []
    for y in range(OBJECT_BOTTOM, top - 1, -1):
        rise = (OBJECT_BOTTOM - y) / (OBJECT_BOTTOM - top)
        x = OBJECT_CENTRE + lean * rise + math.sin(rise * math.pi * 1.5) * 1.2
        radius = 5 - 1.8 * rise + max(0, 3 - (OBJECT_BOTTOM - y)) * 0.9
        trunk.append((x, y, radius))
    for x, y, radius in trunk:
        deadwood_disc(canvas, x, y, radius)
    # Limbs from the upper half, each curving upwards and broken off.
    first_side = rng.choice((-1, 1))
    for index, height in enumerate((0.4, 0.62, 0.8)[: 2 + seed % 2]):
        side = first_side * (-1) ** index
        x, y, radius = trunk[round(len(trunk) * (height + rng.uniform(-0.05, 0.05)))]
        angle = math.radians(side * rng.uniform(62, 78))
        thickness = 2.5 - index * 0.4
        for step in range(rng.randint(11, 15)):
            x += math.sin(angle)
            y -= math.cos(angle)
            angle -= side * math.radians(3)
            deadwood_disc(canvas, x, y, thickness - step * 0.06)
        broken_end(canvas, round(x), round(y))
    # The trunk snapped off at a slant, its high point on the left.
    tip_x = round(trunk[-1][0])
    for y in range(top - 4, top + 5):
        for x in range(tip_x - 4, tip_x + 5):
            if y - top < (x - tip_x) * 1.2 + 1:
                canvas[y][x] = None
    broken_end(canvas, tip_x - 2, top + 1)
    # Cracks in the bark, and a knothole.
    for _ in range(9):
        x, y = rng.randint(OBJECT_CENTRE - 3, OBJECT_CENTRE + 3), rng.randint(top + 4, OBJECT_BOTTOM - 4)
        if canvas[y][x] in ("stone", "stone_light") and canvas[y + 3][x] in ("stone", "stone_light"):
            for step in range(rng.randint(2, 4)):
                canvas[y + step][x] = "stone_dark"
    hole_x, hole_y = round(trunk[len(trunk) // 2][0]), OBJECT_BOTTOM - len(trunk) // 2
    canvas[hole_y][hole_x] = canvas[hole_y + 1][hole_x] = "ink"
    canvas[hole_y - 1][hole_x] = "stone_dark"
    canvas[hole_y][hole_x + 1] = "bare_light"
    outline_in_bark(canvas, "ink")
    return canvas


def deadwood_disc(canvas, cx, cy, radius):
    """A disc of weathered grey wood, lit on its upper left: one stamp of a trunk or limb."""
    for y in range(math.floor(cy - radius), min(OBJECT_BOTTOM, math.ceil(cy + radius)) + 1):
        for x in range(math.floor(cx - radius), math.ceil(cx + radius) + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if dx * dx + dy * dy > radius * radius:
                continue
            light = (dx * 0.85 + dy * 0.5) / radius
            canvas[y][x] = "stone_light" if light < -0.45 else "stone" if light < 0.2 else "bare" if light < 0.6 else "stone_dark"


def broken_end(canvas, x, y):
    """The splintered end of a limb or of the trunk: pale bare wood with a jagged tip."""
    for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1)):
        if canvas[y + dy][x + dx] is not None:
            canvas[y + dy][x + dx] = "bare_light"
    canvas[y - 2][x - 1] = canvas[y - 1][x - 1] = "bare_light"


def berry_bush(seed, is_picked=False):
    """With berries, or picked: the same bush without them."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 14)
    blobs = [(24, 68, 8.5), (17, 70, 5.5), (31, 70, 5.5), (20, 64, 5.5), (28, 64, 5.5)]
    shaded_blob(canvas, rng, blobs, ("green_light", "green", "green", "green_dark"), "green_deep")
    # Berries on the leaves: red, purple or both, with a pale glint.
    berries = {0: ("ember",), 1: ("heather",)}.get(seed % 3, ("ember", "heather", "petal"))
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
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
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
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
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
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
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
    """What is left of a felled tree: a short trunk about 16 px wide, its cut top with year rings
    and a crack, bark lit on the left, and roots spreading into the ground."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 13)
    centre_x, top_y, radius_x, radius_y = OBJECT_CENTRE, 67, 7.5, 4
    ground = OBJECT_BOTTOM - 1
    left, right = round(centre_x - radius_x), round(centre_x + radius_x) - 1
    bark = ("soil_light", "soil_mid", "soil", "soil_dark")
    # The sides of the trunk down to the ground, lit on the left, with bark furrows.
    for y in range(top_y, ground + 1):
        for x in range(left, right + 1):
            across = (x + 0.5 - centre_x) / radius_x
            canvas[y][x] = bark[0] if across < -0.55 else bark[1] if across < 0.1 else bark[2] if across < 0.7 else bark[3]
    for _ in range(5):
        x = rng.randint(left + 2, right - 2)
        y = rng.randint(top_y + 4, ground - 3)
        canvas[y][x] = canvas[y + 1][x] = bark[3]
    # Roots: wedges running out from the foot and dipping into the ground, a long one to each
    # side and on some stumps a short one in front.
    roots = [(left - 1, -1, 5, 4), (right + 1, 1, 4, 4)]
    if seed % 2:
        roots.append((centre_x - 3, -1, 2, 2))
    for start, direction, length, height in roots:
        for step in range(length):
            x = start + direction * step
            for y in range(ground - height + 1 + step * height // length, ground + 1):
                canvas[y][x] = bark[1] if direction < 0 else bark[2]
            canvas[ground - height + 1 + step * height // length][x] = bark[0] if direction < 0 else bark[1]
    # The cut top: year rings round the pith, a darker rim of bark, a crack from the middle.
    rings = ("sand_light", "straw", "sand_light", "sand")
    for y in range(round(top_y - radius_y), round(top_y + radius_y)):
        for x in range(left, right + 1):
            distance = math.hypot((x + 0.5 - centre_x) / radius_x, (y + 0.5 - top_y) / radius_y)
            if distance > 1:
                continue
            if distance > 0.82:
                canvas[y][x] = bark[1] if x < centre_x else bark[2]
            else:
                canvas[y][x] = rings[min(len(rings) - 1, int(distance / 0.82 * len(rings)))]
    canvas[top_y][centre_x - 1] = "soil_mid"
    for step in range(1, 4):
        canvas[top_y + (step > 2)][centre_x - 1 + step] = "soil"
    outline_in_bark(canvas)
    return canvas


def dead_stump(seed):
    """What is left of a felled dead tree: a short stub of weathered grey wood like the dead
    tree's, its top snapped off into a ragged crown of pale splinters round a dark rotten
    heart, split by cracks, with roots; odd seeds wear moss on the left, even ones a bracket
    fungus on the right."""
    rng = random.Random(seed)
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 13)
    centre_x, top_y, radius_x = OBJECT_CENTRE, 63, 7
    ground = OBJECT_BOTTOM - 1
    left, right = centre_x - radius_x, centre_x + radius_x - 1
    wood = ("stone_light", "stone", "bare", "stone_dark")
    # The splinters: each column is broken off at its own height, a few stand up as spikes.
    tops = {}
    for x in range(left, right + 1):
        tops[x] = top_y + rng.randint(0, 2) - (3 if rng.random() < 0.2 else 0)
        if abs(x - centre_x) < 3:
            tops[x] += 2
    for x, top in tops.items():
        across = (x + 0.5 - centre_x) / radius_x
        shade = wood[0] if across < -0.55 else wood[1] if across < 0.1 else wood[2] if across < 0.7 else wood[3]
        for y in range(top, ground + 1):
            canvas[y][x] = shade
        canvas[top][x] = canvas[top + 1][x] = "bare_light"
        if abs(x - centre_x) < 3:
            canvas[top][x] = "ink"
            canvas[top + 1][x] = canvas[top + 2][x] = "stone_dark"
    # Cracks running down the grey wood from the broken top.
    for _ in range(3):
        x = rng.randint(left + 2, right - 2)
        for y in range(tops[x] + 3, min(ground - 2, tops[x] + 3 + rng.randint(3, 8))):
            canvas[y][x] = "stone_dark"
    # Roots: wedges running out from the foot, in the same grey.
    roots = [(left - 1, -1, 5, 4), (right + 1, 1, 4, 4)]
    if seed % 2:
        roots.append((centre_x - 3, -1, 2, 2))
    for start, direction, length, height in roots:
        for step in range(length):
            x = start + direction * step
            first_row = ground - height + 1 + step * height // length
            for y in range(first_row, ground + 1):
                canvas[y][x] = wood[1] if direction < 0 else wood[2]
            canvas[first_row][x] = wood[0] if direction < 0 else wood[1]
    if seed % 2:
        for _ in range(14):
            x, y = rng.randint(left, left + 4), rng.randint(ground - 9, ground - 1)
            canvas[y][x] = rng.choice(("green_dark", "green", "green_light"))
    else:
        for x, y in ((right - 3, ground - 6), (right - 2, ground - 6), (right - 1, ground - 6), (right - 2, ground - 5)):
            canvas[y][x] = "sand_light" if y < ground - 5 else "soil_mid"
    outline_in_bark(canvas, "ink")
    return canvas


def outline_in_bark(canvas, colour="soil_dark"):
    """A one pixel outline round everything drawn except the ground shadow, by default in the
    darkest bark colour."""
    height = len(canvas)
    marked = []
    for y in range(height):
        for x in range(OBJECT_CELL_WIDTH):
            if canvas[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < OBJECT_CELL_WIDTH and 0 <= ny < height and canvas[ny][nx] not in (None, "shadow"):
                    marked.append((x, y))
                    break
    for x, y in marked:
        canvas[y][x] = colour


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


OAK_SEEDS = (101, 102, 103)
OBJECTS = [[oak(seed) for seed in OAK_SEEDS], [stone(seed) for seed in (111, 112)]]
BOULDERS = [[boulder(seed) for seed in (191, 192)]]
STUMPS = [[stump(seed) for seed in (201, 202)]]
DEAD_STUMPS = [[dead_stump(seed) for seed in (211, 212)]]


# Camp site objects (assets/objects.png rows 2 and 3).


def fire_stone(canvas, x, y):
    rect(canvas, x - 1, y - 1, x + 1, y, "stone")
    rect(canvas, x - 1, y - 1, x, y - 1, "stone_light")
    rect(canvas, x + 1, y, x + 1, y, "stone_dark")


# The box of the fireplace's cell that its flame burns in (x, y, width, height; the flame stands
# on its bottom row), and the flame's half width and height.
FIREPLACE_FLAME = ((OBJECT_CENTRE - 8, 51, 16, 20), 5.5, 15)


def fireplace_layers():
    """The fireplace without its flame: what is behind the flame (the ash bed and three logs on
    it, laid like the spokes of a wheel) and what is in front of it (the ring of stones)."""
    behind, front = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT), blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    centre, ground = OBJECT_CENTRE, 71
    for y in range(ground - 4, ground + 5):
        for x in range(centre - 10, centre + 10):
            if ((x - centre) / 9.5) ** 2 + ((y - ground) / 4.2) ** 2 <= 1:
                behind[y][x] = "soil_dark"
    for dx, dy, shades in ((-7, -2, ("soil_mid", "soil")), (7, -2, ("soil", "soil_dark")), (0, 3, ("soil_mid", "soil"))):
        for i in range(9):
            x, y = round(centre + dx * i / 8), round(ground + dy * i / 8)
            behind[y][x] = behind[y + 1][x] = shades[0]
            behind[y + 2][x] = shades[1]
    ring = [
        (round(centre + 10.5 * math.cos(step / 14 * 2 * math.pi)), round(ground + 3 + 4 * math.sin(step / 14 * 2 * math.pi)), math.sin(step / 14 * 2 * math.pi))
        for step in range(14)
    ]
    for x, y, depth in sorted(ring, key=lambda stone: stone[2]):
        fire_stone(front, x, y)
    return behind, front


def fireplace():
    return fire.burning(*fireplace_layers(), *FIREPLACE_FLAME)


def bedroll():
    """14x26 px, lying vertically on 1x2 tiles (the cell's bottom edge is the footprint's): a
    sack of linen ticking stuffed with straw, quilted across, straw poking out at its seams, and
    a grey wool blanket rolled up and tied at its head end. The object's id stays sleeping_bag."""
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    left, top, bottom = OBJECT_CENTRE - 7, 51, 76
    right = left + 13
    # The straw sack: lit linen, shaded down its right side, quilted in rows.
    rect(canvas, left, top + 3, right, bottom, "mud_dark")
    rect(canvas, left + 1, top + 4, right - 1, bottom - 1, "sand_light")
    rect(canvas, right - 3, top + 4, right - 1, bottom - 1, "sand")
    rect(canvas, left + 1, bottom - 1, right - 1, bottom - 1, "sand")
    for y in range(top + 12, bottom - 2, 5):
        rect(canvas, left + 1, y, right - 1, y, "sand")
        rect(canvas, right - 3, y, right - 1, y, "mud")
    for x, y in ((left, bottom), (right, bottom), (left, top + 3), (right, top + 3)):
        canvas[y][x] = None
    rect(canvas, left + 2, bottom + 1, right, bottom + 2, "shadow")
    # Straw sticking out of the seams.
    for x, y, colour in ((left - 1, top + 13, "straw"), (left - 1, top + 14, "gold"), (left - 2, top + 14, "straw"),
                         (right + 1, top + 20, "straw"), (right + 1, top + 21, "straw"), (right + 2, top + 20, "gold"),
                         (left + 3, bottom + 1, "straw"), (left + 4, bottom + 1, "gold"), (left + 4, bottom + 2, "straw")):
        canvas[y][x] = colour
    # The rolled blanket across the head end: lit on top, its rolled-up ends showing a spiral.
    rect(canvas, left - 1, top, right + 1, top + 8, "stone_dark")
    rect(canvas, left, top + 1, right, top + 7, "stone")
    rect(canvas, left, top + 1, right, top + 3, "stone_light")
    rect(canvas, left, top + 7, right, top + 7, "stone_dark")
    for x in (left - 1, right + 1):
        canvas[top][x] = canvas[top + 8][x] = None
    for x in (left, right):
        rect(canvas, x, top + 3, x, top + 5, "stone_dark")
    canvas[top + 4][left + 1] = "stone_dark"
    canvas[top + 4][right - 1] = "stone_dark"
    # Two cords round the roll.
    for x in (left + 3, right - 3):
        rect(canvas, x, top + 1, x, top + 7, "soil")
        canvas[top + 1][x] = "soil_light"
    return canvas


CAMP_OBJECTS = [[fireplace()], [bedroll()]]


def world_chest():
    """The chest outdoors, on a ground shadow, its bottom a pixel above the cell's."""
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    ground_shadow(canvas, 8)
    picture = chest.chest()
    top = OBJECT_BOTTOM - len(picture)
    for y, row in enumerate(picture):
        for x, name in enumerate(row):
            if name is not None:
                canvas[top + y][OBJECT_CENTRE - len(row) // 2 + x] = name
    return canvas


def object_atlas():
    """The rows of assets/objects.png in order, each as (kind, its variants). The seasons
    treat every kind alike, so kind and row come from one list."""
    spruces, pines, dead_trees, berry_bushes, shrubs, saplings, ferns = vegetation()
    return [
        ("oak", OBJECTS[0]),
        ("stone", OBJECTS[1]),
        ("fireplace", CAMP_OBJECTS[0]),
        ("sleeping_bag", CAMP_OBJECTS[1]),
        ("spruce", spruces),
        ("pine", pines),
        ("dead_tree", dead_trees),
        ("berry_bush", berry_bushes),
        ("shrub", shrubs),
        ("sapling", saplings),
        ("fern", ferns),
        ("boulder", BOULDERS[0]),
        ("stump", STUMPS[0]),
        ("tall_grass", meadow.tall_grass_row()),
    ] + trunks.rows() + [("reeds", reeds.reeds_row()), ("dead_stump", DEAD_STUMPS[0]), ("chest", [world_chest()])]


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
# Passing out (see `collapse_sheet`): kneeling, the figure sinks onto its folded legs (see
# `draw_kneeling_legs`); asleep, its eye is shut.
KNEEL = {"sink": 6, "lift": (0, 0), "stride": 0, "swing": 0, "kneel": True}
ASLEEP = POSES["idle"] | {"asleep": True}


def leg_boxes(facing, pose):
    """The columns, top row and bottom row of each leg, back leg first. None for a kneeling
    figure, whose legs are folded (see `draw_kneeling_legs`)."""
    if pose.get("kneel"):
        return []
    stride = pose["stride"]
    if facing in ("down", "up"):
        columns = ((5, 7), (9, 11))
    else:
        columns = ((6 - stride, 8 - stride), (7 + stride, 9 + stride))
    return [(x0, x1, 23 + pose["sink"], 30 - lift) for (x0, x1), lift in zip(columns, pose["lift"])]


def draw_body(facing, pose, skin="skin", shade="skin_shade", **_):
    """The figure in a linen undershirt and shorts: head, arms with hands, and legs. Worn
    clothes cover most of it, so this layer is also the silhouette that the outline follows."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink, swing = pose["sink"], pose["swing"]
    # The head, with its top corners cut.
    rect(canvas, 4, 6 + sink, 12, 12 + sink, skin)
    rect(canvas, 5, 5 + sink, 11, 5 + sink, skin)
    rect(canvas, 5, 12 + sink, 11, 12 + sink, shade)
    boxes = leg_boxes(facing, pose)
    for x0, x1, top, bottom in boxes:
        rect(canvas, x0, top, x1, bottom, skin)
        rect(canvas, x0, bottom - 1, x1, bottom, shade)
    if facing in ("down", "up"):
        rect(canvas, 6, 13 + sink, 10, 22 + sink, shade)
        rect(canvas, 8, boxes[0][2], 8, boxes[0][3] - 3, shade)
        # The right arm swings; the left one holds the tool.
        rect(canvas, 4, 14 + sink, 5, 20 + sink, skin)
        rect(canvas, 11, 14 + sink + swing // 2, 12, 20 + sink + swing // 2, skin)
        if facing == "down":
            for x in (6, 10):
                rect(canvas, x, 9 + sink, x, 10 + sink, "soil_dark")
            canvas[11 + sink][5] = canvas[11 + sink][11] = "petal"
        # The undershirt, with short sleeves, and the shorts down to the thighs.
        rect(canvas, 6, 13 + sink, 10, 20 + sink, UNDERSHIRT)
        rect(canvas, 10, 15 + sink, 10, 20 + sink, UNDERSHIRT_SHADE)
        for x0, dy in ((4, 0), (11, swing // 2)):
            rect(canvas, x0, 14 + sink + dy, x0 + 1, 15 + sink + dy, UNDERSHIRT)
        rect(canvas, 6, 21 + sink, 10, 22 + sink, SHORTS)
    else:
        rect(canvas, 5, 13 + sink, 10, 22 + sink, shade)
        canvas[10 + sink][13] = skin
        # A shut eye is only its lid line, low on the eye.
        if pose.get("asleep"):
            canvas[10 + sink][11] = "soil_dark"
        else:
            rect(canvas, 11, 9 + sink, 11, 10 + sink, "soil_dark")
        rect(canvas, 7 + swing // 2, 14 + sink, 8 + swing // 2, 17 + sink, skin)
        rect(canvas, 7 + swing, 18 + sink, 8 + swing, 20 + sink, skin)
        rect(canvas, 5, 13 + sink, 10, 20 + sink, UNDERSHIRT)
        rect(canvas, 5, 15 + sink, 5, 20 + sink, UNDERSHIRT_SHADE)
        rect(canvas, 7 + swing // 2, 14 + sink, 8 + swing // 2, 15 + sink, UNDERSHIRT)
        rect(canvas, 5, 21 + sink, 10, 22 + sink, SHORTS)
    for x0, x1, top, _bottom in boxes:
        rect(canvas, x0, top, x1, top + 2, SHORTS)
    if pose.get("kneel"):
        draw_kneeling_legs(canvas, (SHORTS, skin), (skin, shade), (shade, shade, shade))
    return canvas


def draw_kneeling_legs(canvas, thigh, shin, foot):
    """Legs folded under a kneeling figure seen from the side (facing right): the thigh
    forward to the knee, the shin back along the ground to the foot sticking out behind.
    `thigh` and `shin` are (colour, front colour), `foot` (top, middle, sole)."""
    rect(canvas, 5, 27, 9, 28, thigh[0])
    rect(canvas, 10, 27, 11, 28, thigh[1])
    rect(canvas, 4, 29, 11, 29, shin[0])
    rect(canvas, 4, 30, 11, 30, shin[1])
    rect(canvas, 1, 28, 3, 28, foot[0])
    rect(canvas, 1, 29, 3, 29, foot[1])
    rect(canvas, 1, 30, 3, 30, foot[2])


def draw_legs(facing, pose, **_):
    """Linen trousers and leather boots."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    boxes = leg_boxes(facing, pose)
    for index, (x0, x1, top, bottom) in enumerate(boxes):
        rect(canvas, x0, top, x1, bottom - 3, "sand")
        rect(canvas, x0, bottom - 2, x1, bottom, "soil")
        rect(canvas, x0, bottom - 2, x1, bottom - 2, "soil_light")
        rect(canvas, x0, bottom, x1, bottom, "soil_dark")
        # The inside of each leg is shaded, which also marks it against the other one.
        seam = x1 if index == 0 and facing in ("down", "up") else x0
        rect(canvas, seam, top, seam, bottom - 3, "mud")
        if facing in ("left", "right"):
            canvas[bottom][x1 + 1] = canvas[bottom - 1][x1 + 1] = "soil_dark"
    if facing in ("down", "up"):
        rect(canvas, 8, boxes[0][2], 8, boxes[0][3] - 3, "mud_dark")
    if pose.get("kneel"):
        draw_kneeling_legs(canvas, ("sand", "sand"), ("sand", "mud"), ("soil_light", "soil", "soil_dark"))
    return canvas


def draw_clothes(facing, pose, base, light, shade, **_):
    """A belted tunic with sleeves."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink, swing = pose["sink"], pose["swing"]
    if facing in ("down", "up"):
        rect(canvas, 6, 13 + sink, 10, 22 + sink, base)
        rect(canvas, 5, 21 + sink, 11, 22 + sink, base)
        rect(canvas, 6, 13 + sink, 10, 14 + sink, light)
        rect(canvas, 10, 15 + sink, 10, 20 + sink, shade)
        rect(canvas, 5, 22 + sink, 11, 22 + sink, shade)
        rect(canvas, 6, 19 + sink, 10, 19 + sink, "soil_dark")
        # Sleeves; the right one swings with the arm.
        for x0, dy in ((4, 0), (11, swing // 2)):
            rect(canvas, x0, 14 + sink + dy, x0 + 1, 18 + sink + dy, base)
            rect(canvas, x0, 14 + sink + dy, x0 + 1, 14 + sink + dy, light)
            rect(canvas, x0 + 1, 15 + sink + dy, x0 + 1, 17 + sink + dy, shade)
            rect(canvas, x0, 18 + sink + dy, x0 + 1, 18 + sink + dy, shade)
        if facing == "down":
            rect(canvas, 7, 13 + sink, 9, 13 + sink, "cream")
            canvas[14 + sink][8] = "cream"
            canvas[19 + sink][8] = "gold"
        else:
            rect(canvas, 6, 13 + sink, 10, 13 + sink, shade)
    else:
        rect(canvas, 5, 13 + sink, 10, 22 + sink, base)
        rect(canvas, 5, 21 + sink, 11, 22 + sink, base)
        rect(canvas, 5, 13 + sink, 10, 14 + sink, light)
        rect(canvas, 5, 15 + sink, 5, 21 + sink, shade)
        rect(canvas, 5, 22 + sink, 11, 22 + sink, shade)
        rect(canvas, 5, 19 + sink, 10, 19 + sink, "soil_dark")
        canvas[19 + sink][10] = "gold"
        rect(canvas, 8, 13 + sink, 10, 13 + sink, "cream")
        # The near sleeve over the torso: a shaded edge at the back, and the cuff.
        for y in range(14 + sink, 19 + sink):
            x = 7 + (swing // 2 if y < 17 + sink else swing)
            canvas[y][x], canvas[y][x + 1] = shade, base
        rect(canvas, 7 + swing // 2, 14 + sink, 8 + swing // 2, 14 + sink, light)
        rect(canvas, 7 + swing, 18 + sink, 8 + swing, 18 + sink, shade)
    return canvas


def draw_hair(facing, pose, base, light, shade, long, **_):
    """Short or long hair over the head (the same 9x8 block in every view), and from behind
    over the whole back of it. The darkest shade is the line to the face."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink = pose["sink"]
    rect(canvas, 5, 5 + sink, 11, 5 + sink, base)
    rect(canvas, 4, 6 + sink, 12, 7 + sink, base)
    rect(canvas, 5, 6 + sink, 7, 6 + sink, light)
    if facing == "down":
        rect(canvas, 6, 7 + sink, 10, 7 + sink, shade)
        for x in (4, 12):
            rect(canvas, x, 8 + sink, x, 9 + sink, base)
            canvas[9 + sink][x] = shade
        if long:
            for x in (4, 12):
                rect(canvas, x, 10 + sink, x, 14 + sink, base)
                rect(canvas, x, 13 + sink, x, 14 + sink, shade)
    elif facing == "up":
        rect(canvas, 4, 8 + sink, 12, 11 + sink, base)
        rect(canvas, 5, 12 + sink, 11, 12 + sink, shade)
        rect(canvas, 8, 7 + sink, 8, 11 + sink, shade)
        rect(canvas, 6, 8 + sink, 6, 9 + sink, light)
        if long:
            rect(canvas, 4, 12 + sink, 12, 16 + sink, base)
            rect(canvas, 5, 17 + sink, 11, 17 + sink, base)
            rect(canvas, 8, 12 + sink, 8, 16 + sink, shade)
            rect(canvas, 6, 13 + sink, 6, 15 + sink, light)
            rect(canvas, 5, 16 + sink, 11, 17 + sink, shade)
    else:
        rect(canvas, 10, 7 + sink, 12, 7 + sink, shade)
        rect(canvas, 4, 8 + sink, 8, 11 + sink, base)
        rect(canvas, 8, 8 + sink, 8, 11 + sink, shade)
        rect(canvas, 5, 12 + sink, 7, 12 + sink, shade)
        rect(canvas, 5, 8 + sink, 5, 9 + sink, light)
        if long:
            rect(canvas, 3, 8 + sink, 6, 16 + sink, base)
            rect(canvas, 3, 15 + sink, 6, 16 + sink, shade)
            rect(canvas, 4, 11 + sink, 4, 14 + sink, light)
    return canvas


def draw_rows(canvas, rows, keys, top):
    """Draws rows of characters, each mapped to a colour by `keys` ("." is clear), with the
    first row at `top`."""
    for dy, row in enumerate(rows):
        for x, char in enumerate(row):
            if char != ".":
                canvas[top + dy][x] = keys[char]


# Hats, from the front (also used from behind) and from the side, facing right. Row 0 is y 2
# of a standing figure; the hats sit on the head, which starts at y 5.
STRAW_HAT_KEYS = {"l": "sand_light", "b": "straw", "s": "reed", "d": "soil"}
STRAW_HAT_ROWS = {
    "front": (
        "................",
        "......llbbb.....",
        ".....lbbbbbs....",
        ".....ddddddd....",
        "..lllllbbbbbbs..",
        ".lbbbbbbbbbbbbs.",
        ".ss..........ss.",
    ),
    "side": (
        "................",
        "......lbbb......",
        ".....lbbbbbs....",
        ".....dddddds....",
        "..lllllbbbbbbbs.",
        ".sbbbbbbbbbbbbbs",
        ".s............ss",
    ),
}
KNITTED_CAP_KEYS = {"l": "red_light", "r": "rust", "d": "rust_dark", "c": "ember", "k": "russet_deep"}
KNITTED_CAP_ROWS = {
    "front": (
        "................",
        "......lrrr......",
        ".....lrrrrrd....",
        "....lrrrrrrrdrr.",
        "....ccccccccc.dd",
        "....dkdkdkdkd...",
    ),
    "side": (
        "................",
        ".....lrrrr......",
        "..rrlrrrrrrd....",
        ".ddrrrrrrrrrd...",
        ".d..cccccccccc..",
        "....kdkdkdkdkd..",
    ),
}


def draw_hat(rows, keys):
    """A hat layer from its front and side rows."""

    def draw(facing, pose, **_):
        canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
        draw_rows(canvas, rows["side" if facing in ("left", "right") else "front"], keys, 2 + pose["sink"])
        return canvas

    return draw


def draw_held_hoe(facing, pose, **_):
    """A hoe in the right hand, in dark soil colours with a light edge on the blade."""
    canvas = blank(CHARACTER_WIDTH, CHARACTER_HEIGHT)
    sink = pose["sink"]
    if facing in ("down", "up"):
        shaft = 3 if facing == "down" else 13
        top = 13 + sink
        rect(canvas, shaft, top, shaft, 30, "soil_dark")
        blade = (shaft - 2, shaft) if facing == "down" else (shaft, shaft + 2)
        rect(canvas, blade[0], top - 1, blade[1], top, "soil_dark")
        rect(canvas, blade[0], top - 1, blade[1], top - 1, "soil_light")
        if facing == "down":
            rect(canvas, shaft, 19, shaft, 20, "skin")
    else:
        top = 13 + sink
        rect(canvas, 12, top, 12, 30, "soil_dark")
        rect(canvas, 12, top + 1, 14, top + 2, "soil_dark")
        rect(canvas, 12, top + 1, 14, top + 1, "soil_light")
        rect(canvas, 11, 19, 12, 20, "skin")
    return canvas


def mirrored(canvas):
    return [row[::-1] for row in canvas]


def outlined(canvas, skip):
    """Adds a 1 px ink outline around the drawing, except on pixels covered by `skip`: the
    body already outlines itself, and a layer drawn over it must not cut lines into it."""
    width, height = len(canvas[0]), len(canvas)
    covered = pixels_of(canvas)
    for x, y in covered:
        for dx, dy in NEIGHBOURS:
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in covered and (nx, ny) not in skip:
                canvas[ny][nx] = "ink"
    return canvas


def pixels_of(canvas):
    return {(x, y) for y, row in enumerate(canvas) for x, colour in enumerate(row) if colour is not None}


def character_sheet(draw, variant_colours):
    """One layer's sheet: the layer drawn in every facing and frame, with its outline."""
    rows = []
    for facing in PLAYER_FACINGS:
        drawn_facing = "right" if facing == "left" else facing
        row = []
        for frame in PLAYER_FRAMES:
            pose = POSES[frame]
            body_pixels = pixels_of(draw_body(drawn_facing, pose))
            canvas = draw(drawn_facing, pose, **variant_colours)
            canvas = outlined(canvas, set() if draw is draw_body else body_pixels)
            row.append(mirrored(canvas) if facing == "left" else canvas)
        rows.append(row)
    return rows


# Passing out (assets/character/collapse/<name>.png, one per layer sheet but the held tool,
# which is let go): one row of 32x32 frames, facing right (the game mirrors them for left),
# with the feet or the body on the bottom row: kneeling, tipping over forward, lying and
# asleep. Lying is the side view of the standing figure laid down head first, face up.
COLLAPSE_SIZE = 32
# How far each row of the kneeling figure leans forward, per row above the ground: slumped
# while kneeling, then tipping over.
SLUMP_LEAN = 0.12
TIP_LEAN = 0.45


def leaning(lean):
    """Places the 16x32 figure in the middle of the frame, each row moved forward by its
    height above the ground times `lean`. Whole pixel steps keep the art crisp."""

    def place(canvas):
        frame = blank(COLLAPSE_SIZE)
        left = (COLLAPSE_SIZE - CHARACTER_WIDTH) // 2
        ground = CHARACTER_HEIGHT - 1
        for y, row in enumerate(canvas):
            shift = left + round((ground - y) * lean)
            for x, colour in enumerate(row):
                if colour is not None:
                    frame[y][x + shift] = colour
        return frame

    return place


def lying(canvas):
    """The standing figure laid down on the bottom half of the frame: its head to the right
    (forward), its front (face and toes) up."""
    frame = blank(COLLAPSE_SIZE)
    for y, row in enumerate(canvas):
        for x, colour in enumerate(row):
            if colour is not None:
                frame[COLLAPSE_SIZE - 1 - x][CHARACTER_HEIGHT - 1 - y] = colour
    return frame


COLLAPSE_FRAMES = (
    (KNEEL, leaning(SLUMP_LEAN)),
    (KNEEL, leaning(TIP_LEAN)),
    (POSES["idle"], lying),
    (ASLEEP, lying),
)


def collapse_sheet(draw, variant_colours):
    """One layer's passing-out frames, outlined after they are placed, like `character_sheet`."""
    row = []
    for pose, place in COLLAPSE_FRAMES:
        body_pixels = pixels_of(place(draw_body("right", pose)))
        canvas = place(draw("right", pose, **variant_colours))
        row.append(outlined(canvas, set() if draw is draw_body else body_pixels))
    return [row]


# Layer sheets by file name (assets/character/<name>.png), and their passing-out frames
# (assets/character/collapse/<name>.png).
CHARACTER_LAYERS = {"body_0": (draw_body, {})}
for _variant, _colours in CLOTHES_COLOURS.items():
    CHARACTER_LAYERS[f"clothes_{_variant}"] = (draw_clothes, _colours)
for _variant, _colours in HAIR_COLOURS.items():
    CHARACTER_LAYERS[f"hair_{_variant}"] = (draw_hair, _colours)
CHARACTER_LAYERS["legs_0"] = (draw_legs, {})
CHARACTER_LAYERS["head_straw_hat"] = (draw_hat(STRAW_HAT_ROWS, STRAW_HAT_KEYS), {})
CHARACTER_LAYERS["head_knitted_cap"] = (draw_hat(KNITTED_CAP_ROWS, KNITTED_CAP_KEYS), {})
CHARACTER_SHEETS = {name: character_sheet(*layer) for name, layer in CHARACTER_LAYERS.items()}
CHARACTER_SHEETS["held_hoe"] = character_sheet(draw_held_hoe, {})
COLLAPSE_SHEETS = {name: collapse_sheet(*layer) for name, layer in CHARACTER_LAYERS.items()}

# A "z" that rises from a sleeping figure (assets/effects/sleep_z.png): a cream glyph with
# the ink outline around its strokes.
SLEEP_Z = outlined(
    [
        [{"c": "cream"}.get(key) for key in line]
        for line in ("......", ".cccc.", "...cc.", "..cc..", ".cc...", ".cccc.", "......")
    ],
    set(),
)



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


def planks(canvas, light, dark):
    for y in range(TILE):
        for x in range(TILE):
            canvas[y][x] = light if (y // 4) % 2 == 0 else dark
    for y in range(3, TILE, 4):
        rect(canvas, 0, y, TILE - 1, y, "soil")
    # Board ends, staggered row by row.
    for row, x in enumerate((5, 12, 8, 2)):
        rect(canvas, x, row * 4, x, row * 4 + 2, "soil")
    return canvas


def interior_floor():
    return planks(blank(), "soil_light", "soil_mid")


def interior_floor_shaded():
    """The floor row along the back wall, in its shadow."""
    canvas = planks(blank(), "soil_mid", "soil")
    rect(canvas, 0, 0, TILE - 1, 1, "soil_dark")
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
        rect(canvas, x, 0, x, TILE - 1, colour)
    return canvas


def rim_front():
    """The top of the front wall: its 8 px next to the room are the top half of the tile."""
    canvas = blank()
    for y, colour in zip(range(RIM), WALL_TOP_SHADES[::-1]):
        rect(canvas, 0, y, TILE - 1, y, colour)
    return canvas


def mirrored_tile(canvas):
    return [row[::-1] for row in canvas]


def interior_doormat():
    """The exit: a woven mat 16x8 across the gap in the front wall."""
    canvas = blank()
    rect(canvas, 0, 0, TILE - 1, 7, "soil_dark")
    rect(canvas, 1, 1, TILE - 2, 6, "straw")
    for y in (2, 4):
        rect(canvas, 1, y, TILE - 2, y, "dry_light")
    rect(canvas, 1, 6, TILE - 2, 6, "reed")
    return canvas


def back_wall_top():
    """The upper tile of the back wall: a beam over plaster."""
    canvas = filled("sand_light")
    rng = random.Random(131)
    for _ in range(9):
        canvas[rng.randrange(5, TILE)][rng.randrange(TILE)] = "sand"
    rect(canvas, 0, 0, TILE - 1, 0, "soil_mid")
    rect(canvas, 0, 1, TILE - 1, 2, "soil")
    rect(canvas, 0, 2, TILE - 1, 2, "soil_dark")
    rect(canvas, 0, 3, TILE - 1, 3, "mud")
    return canvas


def back_wall_bottom():
    """The lower tile of the back wall: plaster over a wainscot of panels."""
    canvas = filled("sand_light")
    rng = random.Random(132)
    for _ in range(5):
        canvas[rng.randrange(0, 5)][rng.randrange(TILE)] = "sand"
    rect(canvas, 0, 5, TILE - 1, 5, "soil_light")
    rect(canvas, 0, 6, TILE - 1, 6, "soil")
    rect(canvas, 0, 7, TILE - 1, 13, "soil_mid")
    rect(canvas, 0, 14, TILE - 1, 15, "soil_dark")
    for x in (0, 7, 8, 15):
        rect(canvas, x, 7, x, 13, "soil")
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
    """A 10x10 window with a sill, 16x32: drawn over the plaster of the back wall face. Nine
    small panes of daylight in wooden glazing bars."""
    canvas = blank(TILE, 2 * TILE)
    rect(canvas, 3, 7, 12, 16, "soil_dark")
    rect(canvas, 4, 8, 11, 15, "water_light")
    rect(canvas, 4, 8, 8, 9, "foam")
    rect(canvas, 4, 8, 5, 12, "foam")
    rect(canvas, 4, 14, 11, 15, "water")
    for offset in (3, 6):
        rect(canvas, 3 + offset, 8, 3 + offset, 15, "soil_mid")
        rect(canvas, 4, 7 + offset, 11, 7 + offset, "soil_mid")
    rect(canvas, 2, 17, 13, 17, "soil_light")
    rect(canvas, 2, 18, 13, 18, "soil_mid")
    rect(canvas, 3, 19, 12, 19, "mud")
    return canvas


def bed():
    """A bed 1x2 tiles, head to the north: frame, pillow and a blanket with a folded edge."""
    canvas = blank(TILE, 2 * TILE)
    rect(canvas, 0, 0, 15, 31, "soil_mid")
    rect(canvas, 0, 0, 15, 5, "soil")
    rect(canvas, 1, 1, 14, 1, "soil_light")
    rect(canvas, 2, 6, 13, 12, "cream")
    rect(canvas, 2, 12, 13, 12, "sand_light")
    rect(canvas, 2, 13, 13, 28, "ember")
    rect(canvas, 2, 13, 13, 15, "flame")
    rect(canvas, 2, 15, 13, 15, "ember")
    rect(canvas, 11, 16, 13, 28, "soil")
    rect(canvas, 5, 20, 7, 21, "soil")
    rect(canvas, 2, 29, 13, 31, "soil")
    rect(canvas, 0, 29, 15, 29, "soil_light")
    outline(canvas, "soil_dark")
    return canvas


def table():
    """A table 2x1 tiles: a plank top, an apron and two legs; a candle and a bowl on it."""
    canvas = blank(2 * TILE, 24)
    rect(canvas, 0, 0, 31, 15, "soil_light")
    for y in (4, 9, 14):
        rect(canvas, 0, y, 31, y, "soil_mid")
    rect(canvas, 0, 16, 31, 17, "soil_mid")
    rect(canvas, 0, 18, 31, 18, "soil_dark")
    for x in (2, 27):
        rect(canvas, x, 19, x + 2, 23, "soil")
        rect(canvas, x, 19, x, 23, "soil_mid")
    rect(canvas, 23, 5, 24, 9, "cream")
    rect(canvas, 23, 3, 24, 4, "gold")
    rect(canvas, 7, 6, 12, 9, "stone_light")
    rect(canvas, 8, 7, 11, 8, "stone_dark")
    return outline(canvas, "soil_dark", keep_bottom=True)


def stool():
    """A stool, 10x10 on its 16x16 tile."""
    canvas = blank(10, 10)
    rect(canvas, 0, 0, 9, 4, "soil_light")
    rect(canvas, 0, 4, 9, 4, "soil_mid")
    for x in (1, 7):
        rect(canvas, x, 5, x + 1, 9, "soil")
    rect(canvas, 4, 5, 5, 8, "soil_dark")
    return outline(canvas, "soil_dark", keep_bottom=True)


# The box of the hearth's picture that its flame burns in (x, y, width, height; the flame stands
# on its bottom row, over the logs), and the flame's half width and height.
HEARTH_FLAME = ((8, 10, 16, 16), 5.0, 12)


def hearth_without_flame():
    """A stone hearth 2x2 tiles with two logs in its firebox."""
    canvas = blank(2 * TILE, 2 * TILE)
    rect(canvas, 0, 0, 31, 29, "stone")
    for y in range(4, 30, 4):
        rect(canvas, 0, y, 31, y, "stone_dark")
        for x in range(2 + (y // 4 % 2) * 4, 32, 8):
            rect(canvas, x, y - 3, x, y - 1, "stone_dark")
    rect(canvas, 0, 0, 31, 2, "stone_light")
    rect(canvas, 0, 3, 31, 3, "stone_dark")
    rect(canvas, 7, 9, 24, 28, "stone_dark")
    rect(canvas, 8, 10, 23, 28, "soil_dark")
    rect(canvas, 9, 25, 22, 27, "soil")
    rect(canvas, 9, 25, 22, 25, "soil_mid")
    # Hearthstone in front.
    rect(canvas, 2, 29, 29, 31, "stone_light")
    rect(canvas, 2, 31, 29, 31, "stone")
    return outline(canvas, "soil_dark", keep_bottom=True)


def hearth():
    """A stone hearth 2x2 tiles with a fire in it."""
    return fire.burning(hearth_without_flame(), blank(2 * TILE, 2 * TILE), *HEARTH_FLAME)


# Furniture by name: its picture and its footprint in tiles. The marker tiles and the files
# follow this order.
FURNITURE = {
    "bed": (bed(), (1, 2)),
    "table": (table(), (2, 1)),
    "stool": (stool(), (1, 1)),
    "chest": (chest.chest(), (1, 1)),
    "hearth": (hearth(), (2, 2)),
    "window": (window_picture(), (1, 2)),
}


# More furniture, for the shack, the longhouse and the barn (task 39). They come after the first
# six so that the tile ids of the tileset stay as they were.


def sleeping_mat():
    """A straw sleeping mat 1x2 tiles, head to the north, with a cream pillow."""
    canvas = blank(TILE, 2 * TILE)
    rect(canvas, 1, 1, 14, 30, "straw")
    for y in range(4, 30, 3):
        rect(canvas, 1, y, 14, y, "sand")
    rect(canvas, 1, 1, 1, 30, "sand_light")
    rect(canvas, 3, 2, 12, 8, "cream")
    rect(canvas, 3, 8, 12, 8, "sand_light")
    return outline(canvas, "soil_dark")


def box_bed():
    """A box bed 2x2 tiles, head to the north: a timber box with a straw mattress, a pillow
    and a red blanket, a front board in front."""
    canvas = blank(2 * TILE, 2 * TILE)
    rect(canvas, 0, 0, 31, 31, "soil_mid")
    rect(canvas, 1, 1, 30, 1, "soil_light")
    rect(canvas, 2, 5, 29, 24, "soil_dark")
    rect(canvas, 3, 6, 28, 24, "straw")
    rect(canvas, 4, 7, 14, 12, "cream")
    rect(canvas, 4, 12, 14, 12, "sand_light")
    rect(canvas, 4, 13, 28, 24, "ember")
    rect(canvas, 4, 13, 28, 15, "flame")
    rect(canvas, 4, 15, 28, 15, "ember")
    rect(canvas, 0, 25, 31, 31, "soil")
    rect(canvas, 0, 25, 31, 25, "soil_light")
    rect(canvas, 0, 28, 31, 28, "soil_mid")
    return outline(canvas, "soil_dark")


def bench():
    """A bench 2x1 tiles: a plank seat on two legs."""
    canvas = blank(2 * TILE, TILE)
    rect(canvas, 0, 3, 31, 7, "soil_light")
    rect(canvas, 0, 5, 31, 5, "soil_mid")
    rect(canvas, 0, 8, 31, 9, "soil_mid")
    rect(canvas, 0, 10, 31, 10, "soil_dark")
    for x in (2, 27):
        rect(canvas, x, 11, x + 2, 15, "soil")
        rect(canvas, x, 11, x, 15, "soil_mid")
    return outline(canvas, "soil_dark", keep_bottom=True)


def stall_partition():
    """A stall partition 1x2 tiles: a post with two rails that run on into the next stall."""
    canvas = blank(TILE, 2 * TILE)
    for top in (6, 16):
        rect(canvas, 0, top, 15, top + 3, "soil")
        rect(canvas, 0, top, 15, top, "soil_light")
        rect(canvas, 0, top + 3, 15, top + 3, "soil_dark")
    rect(canvas, 5, 0, 10, 31, "soil_mid")
    rect(canvas, 5, 0, 6, 31, "soil_light")
    rect(canvas, 5, 28, 10, 31, "soil_dark")
    return outline(canvas, "soil_dark", keep_bottom=True)


def hay_pile():
    """A pile of hay 2x1 tiles: a mound of straw with gold and darker wisps."""
    rng = random.Random(391)
    canvas = blank(2 * TILE, TILE)
    for x in range(2 * TILE):
        top = 2 + round(6 * (1 - math.sin(math.pi * (x + 0.5) / (2 * TILE))))
        for y in range(top, TILE):
            colour = rng.choice(("straw", "straw", "gold", "dry_light"))
            if y >= TILE - 3:
                colour = rng.choice(("sand", "sand_light", "sand"))
            canvas[y][x] = colour
    return outline(canvas, "soil_dark", keep_bottom=True)


def barrel():
    """A barrel, 1x1 tiles: staves, a lid and two iron hoops."""
    canvas = blank(TILE, TILE)
    rect(canvas, 2, 3, 13, 15, "soil_mid")
    rect(canvas, 3, 0, 12, 3, "soil_light")
    for x in (5, 9):
        rect(canvas, x, 4, x, 15, "soil")
    rect(canvas, 12, 4, 13, 15, "soil")
    for y in (5, 12):
        rect(canvas, 2, y, 13, y, "stone")
        rect(canvas, 2, y, 6, y, "stone_light")
    return outline(canvas, "soil_dark", keep_bottom=True)


def sacks():
    """Two sacks of grain, 1x1 tiles, tied at the neck."""
    canvas = blank(TILE, TILE)
    rect(canvas, 1, 5, 8, 15, "sand_light")
    rect(canvas, 7, 5, 8, 15, "sand")
    rect(canvas, 3, 3, 6, 4, "sand_light")
    rect(canvas, 3, 5, 6, 5, "mud")
    rect(canvas, 8, 8, 14, 15, "straw")
    rect(canvas, 13, 8, 14, 15, "sand")
    rect(canvas, 10, 6, 12, 7, "straw")
    rect(canvas, 10, 8, 12, 8, "mud")
    return outline(canvas, "soil_dark", keep_bottom=True)


def crate():
    """A wooden crate, 1x1 tiles, with a cross of boards."""
    canvas = blank(TILE, TILE)
    rect(canvas, 0, 1, 15, 15, "soil_light")
    for i in range(2, 14):
        canvas[1 + i][i] = "soil_mid"
        canvas[1 + i][15 - i] = "soil_mid"
    rect(canvas, 0, 1, 15, 2, "soil_mid")
    rect(canvas, 0, 14, 15, 15, "soil_mid")
    rect(canvas, 0, 1, 1, 15, "soil_mid")
    rect(canvas, 14, 1, 15, 15, "soil_mid")
    return outline(canvas, "soil_dark", keep_bottom=True)


FURNITURE.update(
    {
        "sleeping_mat": (sleeping_mat(), (1, 2)),
        "box_bed": (box_bed(), (2, 2)),
        "bench": (bench(), (2, 1)),
        "stall_partition": (stall_partition(), (1, 2)),
        "hay_pile": (hay_pile(), (2, 1)),
        "barrel": (barrel(), (1, 1)),
        "sacks": (sacks(), (1, 1)),
        "crate": (crate(), (1, 1)),
    }
)


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
    objects = object_atlas()
    houses = {}
    for name, draw in buildings.PICTURES.items():
        houses[name] = draw(is_lit=False)
        houses[f"{name}_lit"] = draw(is_lit=True)
    redraws = {"oak": lambda variant: bare_oak(OAK_SEEDS[variant])}
    (ASSETS / "buildings").mkdir(exist_ok=True)
    # Summer keeps the plain names; the other looks add theirs, e.g. terrain_snow.png.
    for look in seasons.LOOKS:
        suffix = "" if look == "summer" else f"_{look}"
        if look in seasons.GROUND_LOOKS:
            to_image(seasons.terrain_rows(look, terrain_rows)).save(ASSETS / f"terrain{suffix}.png")
            to_image(seasons.ground_rows(look, decoration_rows, seasons.STANDING.get(look))).save(ASSETS / f"decorations{suffix}.png")
        to_image(
            seasons.object_rows(look, objects, redraws),
            OBJECT_CELL_WIDTH,
            OBJECT_CELL_HEIGHT,
        ).save(ASSETS / f"objects{suffix}.png")
        # Houses only change under snow.
        if look in ("summer", "snow"):
            for name, (picture, snowy) in houses.items():
                seasonal = seasons.house(look, picture, snowy)
                to_image([[seasonal]], len(seasonal[0]), len(seasonal)).save(ASSETS / "buildings" / f"{name}{suffix}.png")
    (ASSETS / "character").mkdir(exist_ok=True)
    for name, rows in CHARACTER_SHEETS.items():
        to_image(rows, CHARACTER_WIDTH, CHARACTER_HEIGHT).save(ASSETS / "character" / f"{name}.png")
    (ASSETS / "character" / "collapse").mkdir(exist_ok=True)
    for name, rows in COLLAPSE_SHEETS.items():
        to_image(rows, COLLAPSE_SIZE).save(ASSETS / "character" / "collapse" / f"{name}.png")
    (ASSETS / "effects").mkdir(exist_ok=True)
    to_image([[SLEEP_Z]], len(SLEEP_Z[0]), len(SLEEP_Z)).save(ASSETS / "effects" / "sleep_z.png")
    to_image([INTERIOR_TILES]).save(ASSETS / "interior.png")
    (ASSETS / "interior").mkdir(exist_ok=True)
    for name, (picture, _footprint) in FURNITURE.items():
        to_image([[picture]], len(picture[0]), len(picture)).save(ASSETS / "interior" / f"{name}.png")
    (ASSETS / "fire").mkdir(exist_ok=True)
    for name, (behind, front), (box, half_width, tall) in (
        ("fireplace", fireplace_layers(), FIREPLACE_FLAME),
        ("hearth", (hearth_without_flame(), blank(2 * TILE, 2 * TILE)), HEARTH_FLAME),
    ):
        strip = fire.strip(behind, front, box, half_width, tall)
        to_image([strip], box[2], box[3]).save(ASSETS / "fire" / f"{name}.png")
    (ASSETS / "wildlife").mkdir(exist_ok=True)
    for kind in animals.SHEETS:
        to_image(animals.sheet_rows(kind), *animals.cell_size(kind)).save(ASSETS / "wildlife" / f"{kind}.png")
    (ASSETS / "crops").mkdir(exist_ok=True)
    for crop, cells in crops.sheets().items():
        to_image([cells], TILE, len(cells[0])).save(ASSETS / "crops" / f"{crop}.png")
    to_image([crop_icons.soil_wet()]).save(ASSETS / "soil_wet.png")
    to_image([[meadow.clay_hint()]]).save(ASSETS / "clay_hint.png")
    for directory, pictures in (
        ("items", items.ICONS | crop_icons.icons() | meadow.icons() | reeds.icons() | tool_icons.icons()),
        ("ui", items.SLOTS | items.SLOT_HINTS),
    ):
        (ASSETS / directory).mkdir(exist_ok=True)
        for name, picture in pictures.items():
            to_image([[picture]], len(picture)).save(ASSETS / directory / f"{name}.png")
        if directory == "items":
            (ASSETS / "ground_items").mkdir(exist_ok=True)
            for name, picture in pictures.items():
                small = items.small(picture)
                to_image([[small]], len(small)).save(ASSETS / "ground_items" / f"{name}.png")
    ui.write_ui_assets(ASSETS / "ui", PALETTE)
    write_palette()
    check_palette()
    print("Wrote terrain*.png, decorations*.png, objects*.png (one per look), character/*.png, character/collapse/*.png, effects/sleep_z.png, interior.png, interior/*.png, fire/*.png, buildings/*.png, items/*.png, wildlife/*.png, crops/*.png, soil_wet.png, clay_hint.png, ui/*, palette.png and palette.gpl to assets/; palette check passed.")


if __name__ == "__main__":
    main()
