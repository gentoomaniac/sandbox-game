"""Generates every PNG under assets/ (run it with `make assets`).

Tiles are drawn as 16x16 grids of palette colour names (None = transparent), so the
palette is the only source of colours. Each terrain has one function that returns its
atlas row. After writing, every PNG under assets/ is checked against the palette.

Terrain atlas layout (assets/terrain.png), read by game/scenes/terrain_tileset.gd:
- one row per terrain layer, bottom to top: water, floodplain, wetland, grass, soil;
- columns 0..14: dual-grid edge shapes for masks 0..14 (mask 0 stays empty);
- columns 15..: full-tile variants (mask 15), at least one per row.
A mask bit is set when that corner's world tile is drawn on this layer or above.
"""

import math
import random
from pathlib import Path

from PIL import Image

ASSETS = Path(__file__).resolve().parents[2] / "assets"
TILE = 16

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
    "olive":          "5c6634",
    # Dry plants, straw, reeds.
    "reed":           "807a40",
    "straw":          "b0a05e",
    # Earth: tilled soil.
    "soil_dark":      "3a2920",
    "soil":           "573c2b",
    "soil_mid":       "6f4f37",
    "soil_light":     "8c6a4b",
    # Floodplain: damp mud and sand.
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
    # Spare colours for magic later.
    "arcane":         "6f4c91",
    "spirit":         "4e9e9b",
}
# fmt: on

# Dual-grid corner bits, shared with game/scenes/terrain_tileset.gd.
TL, TR, BL, BR = 1, 2, 4, 8
FULL = TL | TR | BL | BR

NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def blank():
    return [[None] * TILE for _ in range(TILE)]


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
    at a random spot inside it. Wraps, so the result tiles seamlessly."""
    for cell_y in range(0, TILE, spacing):
        for cell_x in range(0, TILE, spacing):
            if rng.random() < chance:
                x = cell_x + rng.randrange(spacing)
                y = cell_y + rng.randrange(spacing)
                stamp(tile, rng.choice(pictures), x, y)


def blob(tile, rng, colour, radius_x, radius_y):
    """Paints an irregular patch somewhere inside the tile, clear of its border."""
    cx = rng.uniform(radius_x + 1, TILE - 2 - radius_x)
    cy = rng.uniform(radius_y + 1, TILE - 2 - radius_y)
    ragged = periodic_noise(rng.random(), [(2, 1.0), (3, 0.5)])
    for y in range(1, TILE - 1):
        for x in range(1, TILE - 1):
            if math.hypot((x - cx) / radius_x, (y - cy) / radius_y) < 1 + 0.35 * ragged(x, y):
                tile[y][x] = colour


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


def edge_mask(mask, noise, roughness):
    """Which pixels of a dual-grid cell a terrain covers, for a corner mask.

    The cell's corners sit on the centres of its 4 world tiles. Corner coverage is blended
    bilinearly across the cell, so the edge runs along the tile border and rounds off at
    corners; the periodic noise bends it into an irregular, natural line that still meets
    the neighbouring cells' edges.

    Returns covered(x, y). It also answers for pixels just outside the cell, by
    extrapolating, so rims and overhangs along the cell border match the neighbour's.
    """
    corners = [1.0 if mask & bit else 0.0 for bit in (TL, TR, BL, BR)]

    def covered(x, y):
        u = (x + 0.5) / TILE
        v = (y + 0.5) / TILE
        top = corners[0] * (1 - u) + corners[1] * u
        bottom = corners[2] * (1 - u) + corners[3] * u
        value = top * (1 - v) + bottom * v
        return value + roughness * noise(x, y) > 0.5

    return covered


def is_rim(covered, x, y):
    """A covered pixel next to an uncovered one."""
    return covered(x, y) and not all(covered(x + dx, y + dy) for dx, dy in NEIGHBOURS)


def edge_tiles(full, noise, roughness, decorate):
    """The 15 masked tiles (masks 0..14) cut from a full texture, then decorated."""
    tiles = []
    for mask in range(FULL):
        covered = edge_mask(mask, noise, roughness)
        tile = [[full[y][x] if covered(x, y) else None for x in range(TILE)] for y in range(TILE)]
        decorate(tile, covered)
        tiles.append(tile)
    return tiles


# Terrains, bottom layer first. Each returns its atlas row: 15 edge tiles + full variants.
#
# Every terrain has one seamless base texture. Its full variants add a few details inside
# the tile, clear of the border, so any variant fits next to any other, and the edge tiles
# are cut from the plain base.


def copy(tile):
    return [row[:] for row in tile]


def water():
    ripple = sprite({"d": "water_deep"}, "dddd")
    short_ripple = sprite({"d": "water_deep"}, "dd")
    glint = sprite({"l": "water_light"}, "ll")
    crest = sprite({"l": "water_light", "f": "foam"}, ".lf", "l..")

    # Flat water: its few marks all sit in the variants, so they never line up in a grid.
    def variant(seed, *marks):
        rng = random.Random(seed)
        tile = filled("water")
        for mark in marks:
            stamp(tile, mark, rng.randrange(1, 11), rng.randrange(1, 14))
        return tile

    fulls = [
        variant(11),
        variant(12, ripple),
        variant(13, short_ripple, glint),
        variant(14, crest),
        variant(15, ripple, short_ripple),
        variant(16, glint),
    ]
    # Water is the bottom layer and always full, so it needs no edge shapes.
    return [blank()] * FULL + fulls


def floodplain():
    grain = sprite({"m": "mud"}, "m")
    light_grain = sprite({"s": "sand_light"}, "s")
    pebble = sprite({"s": "stone_light", "d": "mud_dark"}, "s", "d")
    sprig = sprite({"g": "green_light", "o": "olive"}, "g.g", "ogo")
    ripple = sprite({"s": "sand_light"}, "sss")

    base = filled("sand")
    sprinkle(base, random.Random(20), [grain, grain, light_grain], spacing=4, chance=0.5)
    sprinkle(base, random.Random(27), [ripple], spacing=8, chance=0.5)

    def variant(seed, *details):
        rng = random.Random(seed)
        tile = copy(base)
        for detail in details:
            stamp(tile, detail, rng.randrange(1, 10), rng.randrange(1, 11))
        return tile

    fulls = [
        variant(21),
        variant(22, sprig, sprig),
        variant(23, pebble, sprig),
        variant(24, sprig),
        variant(25, pebble, pebble),
        variant(26),
    ]
    edge_noise = periodic_noise(20, [(1, 1.0), (2, 0.6), (3, 0.3)])
    foam_noise = periodic_noise(25, [(3, 1.0), (5, 0.5)])

    def decorate(tile, covered):
        # A wet band along the bank, fading out in a dither, and a line of foam where it
        # meets the water below.
        for y in range(TILE):
            for x in range(TILE):
                if is_rim(covered, x, y):
                    tile[y][x] = "mud_dark"
                elif covered(x, y) and any(is_rim(covered, x + dx, y + dy) for dx, dy in NEIGHBOURS):
                    tile[y][x] = "mud"
                elif covered(x, y) and (x + y) % 2:
                    if any(is_rim(covered, x + 2 * dx, y + 2 * dy) for dx, dy in NEIGHBOURS):
                        tile[y][x] = "mud"
                elif is_rim(lambda x, y: not covered(x, y), x, y):
                    tile[y][x] = "foam" if foam_noise(x, y) > 0.3 else "water_light"

    return edge_tiles(base, edge_noise, 0.16, decorate) + fulls


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

    base = filled("bog")
    sprinkle(base, random.Random(30), [sedge, sedge, moss], spacing=4, chance=0.4)

    def variant(seed, pools, reed_count):
        rng = random.Random(seed)
        tile = copy(base)
        for _ in range(pools):
            stamp(tile, pool, rng.randrange(1, 10), rng.randrange(1, 12))
        for _ in range(reed_count):
            stamp(tile, rng.choice(reeds), rng.randrange(1, 12), rng.randrange(1, 11))
        return tile

    fulls = [
        variant(31, 0, 1),
        variant(32, 1, 0),
        variant(33, 0, 2),
        variant(34, 0, 1),
        variant(35, 0, 2),
        variant(36, 0, 0),
        variant(37, 0, 1),
        variant(38, 0, 0),
    ]
    edge_noise = periodic_noise(30, [(2, 1.0), (3, 0.7), (4, 0.3)])
    sedge_noise = periodic_noise(35, [(5, 1.0), (7, 0.6)])

    def decorate(tile, covered):
        # A dark soaked rim, with sedge poking out on the north side and seeping mud on
        # the south side.
        for y in range(TILE):
            for x in range(TILE):
                if is_rim(covered, x, y):
                    tile[y][x] = "bog_dark"
                elif covered(x, y):
                    continue
                elif covered(x, y - 1) and sedge_noise(x, y) > 0.2:
                    tile[y][x] = "mud_dark"
                elif covered(x, y + 1) and sedge_noise(x, y) > 0.3:
                    tile[y][x] = "olive"

    return edge_tiles(base, edge_noise, 0.18, decorate) + fulls


def grass():
    blade = sprite({"l": "green_light", "d": "green_dark"}, "l", "d")
    dark_blade = sprite({"d": "green_dark"}, "d.d", ".d.")
    tufts = [
        sprite({"b": "green_bright", "d": "green_dark"}, "b...b", ".d.d.", "..d.."),
        sprite({"b": "green_bright", "d": "green_dark"}, ".b.", "bdb", "d.d"),
    ]
    flowers = [
        sprite({"c": "cream", "d": "green_dark"}, "c...", "d.c.", "..d."),
        sprite({"c": "gold", "d": "green_dark"}, ".c..", ".d.c", "...d"),
    ]

    base = filled("green")
    sprinkle(base, random.Random(40), [blade, blade, dark_blade], spacing=4, chance=0.45)

    def variant(seed, tuft_count, flower_count=0):
        rng = random.Random(seed)
        tile = copy(base)
        for _ in range(tuft_count):
            stamp(tile, rng.choice(tufts), rng.randrange(1, 11), rng.randrange(1, 13))
        for _ in range(flower_count):
            stamp(tile, rng.choice(flowers), rng.randrange(1, 12), rng.randrange(1, 13))
        return tile

    fulls = [
        variant(41, 0),
        variant(42, 0),
        variant(43, 1),
        variant(44, 1),
        variant(45, 1),
        variant(46, 2),
        variant(47, 0, flower_count=1),
        variant(48, 0),
    ]
    edge_noise = periodic_noise(40, [(2, 1.0), (3, 0.6), (6, 0.5)])
    blade_noise = periodic_noise(45, [(4, 1.0), (7, 0.7)])

    def decorate(tile, covered):
        # A dark rim, with blades hanging over the lower terrain on the south side and
        # blade tips poking out on the north side.
        for y in range(TILE):
            for x in range(TILE):
                if is_rim(covered, x, y):
                    tile[y][x] = "green_dark"
                elif covered(x, y):
                    continue
                elif covered(x, y - 1) and blade_noise(x, y) > 0.1:
                    tile[y][x] = "green_deep"
                elif covered(x, y + 1) and blade_noise(x, y) > 0.5:
                    tile[y][x] = "green_dark"

    return edge_tiles(base, edge_noise, 0.18, decorate) + fulls


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

    fulls = [variant(seed) for seed in (51, 52, 53)]
    edge_noise = periodic_noise(50, [(1, 1.0), (2, 0.5)])

    def decorate(tile, covered):
        # A raised field border: dark on its south side, a lighter lip elsewhere.
        for y in range(TILE):
            for x in range(TILE):
                if covered(x, y) and not covered(x, y + 1):
                    tile[y][x] = "soil_dark"
                elif is_rim(covered, x, y):
                    tile[y][x] = "soil_mid"

    return edge_tiles(base, edge_noise, 0.08, decorate) + fulls


LAYERS = [water, floodplain, wetland, grass, soil]


def to_image(rows):
    """Lays out rows of tiles as one image."""
    width = max(len(row) for row in rows) * TILE
    image = Image.new("RGBA", (width, len(rows) * TILE), (0, 0, 0, 0))
    pixels = image.load()
    for row_index, row in enumerate(rows):
        for column, tile in enumerate(row):
            for y in range(TILE):
                for x in range(TILE):
                    name = tile[y][x]
                    if name is not None:
                        rgb = bytes.fromhex(PALETTE[name])
                        pixels[column * TILE + x, row_index * TILE + y] = (*rgb, 255)
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
    rows = [layer() for layer in LAYERS]
    for layer, row in zip(LAYERS, rows):
        # Full tiles hide the layers below them, so they must be opaque.
        for tile in row[FULL:]:
            assert all(None not in line for line in tile), f"{layer.__name__}: full tile has holes"
    to_image(rows).save(ASSETS / "terrain.png")
    write_palette()
    check_palette()
    print("Wrote terrain.png, palette.png and palette.gpl to assets/; palette check passed.")


if __name__ == "__main__":
    main()
