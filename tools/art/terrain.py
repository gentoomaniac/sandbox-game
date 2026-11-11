"""The ground: the terrain layers of assets/terrain.png and their decorations in
assets/decorations.png, and the moister looks of tilled soil in assets/soil_wet.png.

Tiles are drawn at the game's tile, 32x32 grids of palette colour names (None = transparent).
Each terrain layer has one function that returns its atlas row and its decorations; `LAYERS`
lists them bottom to top: water, mud, floodplain, wetland, grass, salt marsh, Warft, lush grass,
dry grass, trodden grass, path, soil. Both atlases are read by game/scenes/terrain_tileset.gd.

assets/terrain.png, per row:
- EDGE_VARIANTS blocks of 15 columns: the dual-grid edge shapes for masks 0..14 (mask 0
  stays empty). A mask bit is set when that corner's world tile is on this layer or above;
- then the full-tile variants (mask 15), at least one per row.

assets/decorations.png, per row: small visual-only sprites (pebbles, tufts, reeds...)
drawn on top of world tiles of that layer. A row may be empty. Under the layers' rows comes
one more, the meadow flowers of flowers.py.

The ground is what everything stands on, so it is calm: a base colour with marks in the shades
next to it, gathered in patches so the turf has quiet stretches and thick ones, and only a few
light tips. People, animals and crops read on it without an outline. No terrain has an outline
either; where one layer lies over another, its edge is a rim in its own dark shade.
"""

import math
import random

import numpy as np

import forms
import soil_beds
from canvas import GAME_TILE, NEIGHBOURS, blank, filled

# Dual-grid corner bits, shared with game/scenes/terrain_tileset.gd.
TL, TR, BL, BR = 1, 2, 4, 8
FULL = TL | TR | BL | BR
# Edge-shape variants per mask, shared with game/scenes/terrain_tileset.gd.
EDGE_VARIANTS = 3


def sprite(keys, *rows):
    """A small picture from rows of characters, each mapped to a colour by `keys` ("." is clear)."""
    width = max(len(row) for row in rows)
    return [[keys[char] if char != "." else None for char in row.ljust(width, ".")] for row in rows]


def shaded_sprite(width, height, shapes, ramp, shadow=None):
    """A small rounded thing (a pebble, a lily pad, a cap) from forms masks, shaded by the light
    from the top left in `ramp` (dark to light); `shadow`, a colour, is cast a pixel down and
    right of it onto the ground."""
    picture = blank(width, height)
    mask = np.zeros((height, width), bool)
    for shape in shapes:
        mask |= shape
    if shadow:
        cast = np.zeros_like(mask)
        cast[1:, 1:] = mask[:-1, :-1]
        forms.paint(picture, cast & ~mask, shadow)
    return forms.shade(picture, mask, ramp, radius=2)


def size_of(picture):
    return len(picture[0]), len(picture)


def stamp(tile, picture, x, y):
    """Draws a picture with its top left at (x, y), wrapping around the tile edges."""
    for dy, row in enumerate(picture):
        for dx, colour in enumerate(row):
            if colour is not None:
                tile[(y + dy) % GAME_TILE][(x + dx) % GAME_TILE] = colour


def scatter(tile, rng, pictures, count, where=lambda x, y: True):
    """Stamps `count` pictures picked from `pictures` at random spots inside the tile, so every
    variant can have its own scatter and still fit next to any other. `where(x, y)` (the
    picture's bottom middle) can turn a spot down: a patch where the turf is thick."""
    for _ in range(count):
        picture = rng.choice(pictures)
        width, height = size_of(picture)
        x = rng.randrange(GAME_TILE - width + 1)
        y = rng.randrange(GAME_TILE - height + 1)
        if where(x + width // 2, y + height - 1):
            stamp(tile, picture, x, y)


def details(texture, seed, *pictures):
    """A full-tile variant: its own scatter of the terrain's texture, plus a few pictures
    inside the tile, clear of the border. Nothing crosses the border, so any variant fits
    next to any other."""
    rng = random.Random(seed)
    tile = texture(seed)
    for picture in pictures:
        width, height = size_of(picture)
        stamp(tile, picture, rng.randrange(2, GAME_TILE - width - 1), rng.randrange(2, GAME_TILE - height - 1))
    return tile


def decoration(seed, *pictures):
    """A decoration: pictures on a clear tile, inside its middle so they stay on the
    terrain they belong to."""
    return details(lambda seed: blank(GAME_TILE), seed, *pictures)


def periodic_noise(seed, waves):
    """A smooth noise field that repeats every tile on both axes, so it lines up across
    neighbouring tiles. `waves` are (waves per tile, weight) pairs; result is about -1..1."""
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
        value = sum(w * math.sin(math.tau * (fx * x + fy * y) / GAME_TILE + p) for fx, fy, p, w in terms)
        return value / total

    return noise


def patch_noise(seed, cell):
    """A smooth noise of blobs about `cell` pixels across, about -1..1, that repeats every tile:
    patches of bare earth or salt turf. Unlike `periodic_noise` it has no direction, so its
    patches do not line up in stripes."""
    rng = random.Random(seed)
    count = GAME_TILE // cell
    values = [[rng.uniform(-1, 1) for _ in range(count)] for _ in range(count)]

    def smooth(t):
        return t * t * (3 - 2 * t)

    def noise(x, y):
        fx, fy = (x % GAME_TILE) / cell, (y % GAME_TILE) / cell
        ix, iy = int(fx), int(fy)
        tx, ty = smooth(fx - ix), smooth(fy - iy)

        def value(i, j):
            return values[j % count][i % count]

        top = value(ix, iy) * (1 - tx) + value(ix + 1, iy) * tx
        bottom = value(ix, iy + 1) * (1 - tx) + value(ix + 1, iy + 1) * tx
        return top * (1 - ty) + bottom * ty

    return noise


def edge_shapes(seed, waves, roughness, inset=0, ramp=None):
    """The coverage functions of a terrain's edge tiles: shapes[variant][mask](x, y).

    The cell's corners sit on the centres of its 4 world tiles. Corner coverage is blended
    bilinearly across the cell, so the edge runs along the tile border and rounds off at
    corners. A periodic noise shared by all variants bends it into an irregular line that
    meets the neighbouring cells' edges; each variant adds its own noise, faded out
    towards the cell border, so variants differ inside but still fit together.

    A `ramp` (in pixels) sharpens the blend: a corner's share falls from all to none only over
    that many pixels across the tile border, so the edge runs straight along the border and
    rounds off only near the tile's corner, over about a quarter of the ramp. The edge then lies
    `inset` pixels inside the tiles that are on the layer, all round.

    covered(x, y) also answers for pixels just outside the cell, by extrapolating, so rims
    and overhangs along the cell border match the neighbour's. It only grows as corners
    are added to the mask, so a layer cut with the same shapes never sticks out of them.
    """
    shared = periodic_noise(seed, waves)
    shapes = []
    for variant in range(EDGE_VARIANTS):
        own = periodic_noise(seed * 10 + variant, waves)
        shapes.append([coverage(mask, shared, own, roughness, inset, ramp) for mask in range(FULL)])
    return shapes


def coverage(mask, shared, own, roughness, inset=0, ramp=None):
    corners = [1.0 if mask & bit else 0.0 for bit in (TL, TR, BL, BR)]
    threshold = 0.5 + inset / (ramp or GAME_TILE)

    def share(t):
        """The share of the right or the bottom corners at `t` across the cell (0 to 1)."""
        if ramp is None:
            return t
        return min(1.0, max(0.0, 0.5 + (t - 0.5) * GAME_TILE / ramp))

    def covered(x, y):
        u = (x + 0.5) / GAME_TILE
        v = (y + 0.5) / GAME_TILE
        across, down = share(u), share(v)
        top = corners[0] * (1 - across) + corners[1] * across
        bottom = corners[2] * (1 - across) + corners[3] * across
        value = top * (1 - down) + bottom * down
        fade = math.sin(math.pi * u) * math.sin(math.pi * v)
        return value + roughness * (shared(x, y) + 1.5 * fade * own(x, y)) > threshold

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
            tile = [[full[y][x] if covered(x, y) else None for x in range(GAME_TILE)] for y in range(GAME_TILE)]
            if mask:
                decorate(tile, covered, random.Random(tile_seed))
            tiles.append(tile)
    return tiles


def blades(tile, covered, rng, colours, chance, direction, lengths):
    """Blades of grass sticking out of an edge, in `direction` (1 down, -1 up): uneven
    lengths, irregular spacing and the odd gap, so the edge does not look combed. A blade is
    drawn in `colours` from its root out, the last colour to its tip."""
    skip = 0
    for y in range(GAME_TILE):
        for x in range(GAME_TILE):
            if covered(x, y) or not covered(x, y - direction):
                continue
            if skip:
                skip -= 1
                continue
            if rng.random() > chance:
                continue
            for step in range(rng.choice(lengths)):
                ty = y + step * direction
                if not 0 <= ty < GAME_TILE or covered(x, ty):
                    break
                tile[ty][x] = colours[min(step, len(colours) - 1)]
            skip = rng.choice((0, 1, 1, 2, 3, 5))


def fade_out(tile, covered, rng, depth):
    """Thins a layer drawn over grass out towards its edge in a dither, `depth` pixels deep, so
    its colour shifts softly into the grass beneath."""
    for y in range(GAME_TILE):
        for x in range(GAME_TILE):
            if covered(x, y):
                distance = edge_distance(covered, x, y, depth)
                if distance == 1 or (distance < depth and rng.random() < 1 - distance / depth):
                    tile[y][x] = None


# Grass tufts: blades fanning up from a shaded root to lit tips (from the 32 px mockup).
# k root, d blade, l lit blade, b the brightest tip.
_TUFT_ROWS = (
    ("l...l", ".d.l.", ".d.d.", "..k.."),
    ("..b..", "l.l..", "d.l.l", ".dkd."),
    ("l..", ".l.", "dd.", "k.."),
    ("..l", "l.d", "dd.", ".k."),
    (".l.l.", ".l.d.", "d.ld.", "dkdk."),
    ("l.", "d.", ".k"),
)


def tufts(ramp):
    """The tufts in a ramp of (root, blade, lit blade, brightest tip)."""
    deep, dark, light, bright = ramp
    keys = {"k": deep, "d": dark, "l": light, "b": bright}
    return [sprite(keys, *rows) for rows in _TUFT_ROWS]


def big_tuft(ramp):
    """A thick tuft for a decoration: a fan of blades, longer in the middle."""
    deep, dark, light, bright = ramp
    return sprite(
        {"k": deep, "d": dark, "l": light, "b": bright},
        "...b.....",
        "l..l..b..",
        ".l.l.l..l",
        ".d.ld.l.d",
        "..dld.dd.",
        "..ddkdd..",
        "...kkk...",
    )


def grass_texture(base, ramp, tuft_count, root_count):
    """A grass texture: the base colour, single dark blade roots, and tufts gathered where a
    slow noise is high, so the turf has calm stretches and thick ones, never an even sprinkle."""
    shapes = tufts(ramp)
    dark = ramp[1]

    def texture(seed):
        rng = random.Random(seed)
        tile = filled(base, GAME_TILE)
        gather = patch_noise(seed, 8)
        for _ in range(root_count):
            x, y = rng.randrange(GAME_TILE), rng.randrange(GAME_TILE - 1)
            tile[y][x] = dark
            if rng.random() < 0.4:
                tile[y + 1][x] = dark
        scatter(tile, rng, shapes, tuft_count, lambda x, y: rng.random() < 0.2 + 0.8 * max(0.0, gather(x, y)))
        return tile

    return texture


# Water ----------------------------------------------------------------------------------------


def lily_pad(rx, ry, flower=False):
    """A floating leaf with its notch, lit on the top left, and a white flower if asked."""
    width, height = 2 * rx + 2, 2 * ry + 2
    pad = forms.ellipse(width, height, rx + 0.5, ry + 0.5, rx, ry)
    xs, ys = forms.grid(width, height)
    notch = (xs > rx + 0.5) & (np.abs(ys - (ry + 0.5) - (xs - rx - 0.5) * 0.3) < 0.9)
    picture = shaded_sprite(width, height, [pad & ~notch], ("green_dark", "green", "green_light"), shadow="water_deep")
    if flower:
        for x, y, colour in ((rx - 1, ry - 1, "cream"), (rx, ry - 2, "cream"), (rx + 1, ry - 1, "petal"),
                             (rx, ry - 1, "gold"), (rx - 1, ry, "petal"), (rx + 1, ry, "cream")):
            picture[y][x] = colour
    return picture


def water():
    """Calm water: the shader ripples its plain pixels (game/scenes/water.gdshader), so the tiles
    have only a few marks that stay, all in the variants, so they never line up in a grid."""
    ripple = sprite({"d": "water_deep", "l": "water_light"}, "..lll..", "ddddddd")
    short_ripple = sprite({"d": "water_deep"}, "dddd")
    glint = sprite({"l": "water_light"}, "lll")
    crest = sprite({"l": "water_light", "f": "foam", "d": "water_deep"}, "..lf", "lll.", ".dd.")
    eddy = sprite({"d": "water_deep", "l": "water_light"}, ".ddd..", "d...l.", ".lll..")

    def texture(seed):
        return filled("water", GAME_TILE)

    fulls = [
        details(texture, 11),
        details(texture, 12, ripple),
        details(texture, 13, short_ripple, glint),
        details(texture, 14, crest),
        details(texture, 15, ripple, short_ripple),
        details(texture, 16, glint),
        details(texture, 17, eddy),
        details(texture, 18, short_ripple),
    ]
    decorations = [
        decoration(19, lily_pad(5, 3)),
        decoration(20, lily_pad(4, 3), lily_pad(3, 2)),
        decoration(21, lily_pad(5, 3, flower=True)),
    ]
    # Water is the bottom layer and always full, so it needs no edge shapes.
    return [blank(GAME_TILE)] * (EDGE_VARIANTS * FULL) + fulls, decorations


# The tidal mud ----------------------------------------------------------------------------------

# The ripple marks of the tidal mud follow one wave for every mud tile, so they run on in step
# across tile borders: a trough every 6 rows, bent by a wave that repeats across the tile.
_RIPPLE_BEND = periodic_noise(51, [(1, 1.0), (2, 0.6), (3, 0.3)])
_RIPPLE_SPACING = 6


def _trough_row(x, ripple):
    """The row of a pixel column of the mud in which the trough of a ripple (0 at the top of the
    tile) lies."""
    top = ripple * _RIPPLE_SPACING + 3
    return (top - round(4 * _RIPPLE_BEND(x, top))) % GAME_TILE


def mud():
    """The tidal flats (Watt): wet grey-brown mud with ripple marks, the casts of lugworms,
    shells, a mussel bed and the water left in hollows at low tide. The tideways are the water
    beneath it; at their banks the mud is dark and soaked, with a glint on the water. All of
    it lies in the tiles, none in decorations. The dark troughs are where the tide's water
    stands first (game/scenes/mud.gdshader)."""
    cast = sprite({"l": "bare_light", "s": "sand", "d": "mud_dark"}, ".ls..", "l.sl.", ".s.ls", "..d..")
    coil = sprite({"l": "bare_light", "s": "sand"}, ".ls", "s.l", ".s.")
    hole = sprite({"d": "mud_dark", "m": "mud"}, "md")
    shells = [
        sprite({"c": "cream", "s": "sand_light", "d": "mud_dark"}, ".cs", "csd", ".d."),
        sprite({"c": "sand_light", "s": "stone_light", "d": "mud_dark"}, "cs", "sd"),
        sprite({"c": "cream", "d": "mud_dark"}, "c..c", "d..d"),
    ]
    puddle = shaded_sprite(
        12, 6, [forms.ellipse(12, 6, 6, 3, 5.5, 2.5)], ("water", "water", "water_light"), shadow=None
    )
    for x in range(12):
        column = [y for y in range(6) if puddle[y][x]]
        if column:
            puddle[column[0]][x] = "mud_dark"
    mussels = sprite(
        {"i": "ink", "d": "stone_dark", "l": "water_light", "m": "mud_dark"},
        "..dd..d...",
        ".dlid.dd..",
        "didd.dlid.",
        "mdidddidd.",
        ".mm.dlid..",
        "....mmm...",
    )
    wrack = sprite({"o": "olive", "b": "bog", "y": "reed"}, "o..b.", ".obyo", "boy..", ".b.o.")

    def texture(seed):
        # Ripples as wavy lines along the troughs, deeper and darker in stretches, broken where
        # the flats lie smooth, and lit here and there on the crest above; soaked patches between.
        rng = random.Random(seed)
        tile = filled("bare", GAME_TILE)
        damp = patch_noise(seed, 8)
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                if damp(x, y) > 0.45 and (x + y) % 2:
                    tile[y][x] = "mud"
        smooth = patch_noise(seed + 1, 8)
        deep = patch_noise(seed + 2, 8)
        for x in range(GAME_TILE):
            for ripple in range(GAME_TILE // _RIPPLE_SPACING):
                y = _trough_row(x, ripple)
                if smooth(x, y) < -0.35:
                    continue
                tile[y][x] = "mud_dark" if deep(x, y) > -0.2 else "mud"
                if rng.random() < 0.2:
                    tile[y - 1][x] = "bare_light"
        scatter(tile, rng, [hole, hole, coil], 4)
        return tile

    fulls = [
        details(texture, 111),
        details(texture, 112, cast),
        details(texture, 113, shells[0], hole),
        details(texture, 114, puddle),
        details(texture, 115, cast, shells[1]),
        details(texture, 116),
        details(texture, 117, mussels),
        details(texture, 118, shells[2], cast),
        details(texture, 119, wrack),
        details(texture, 120),
        details(texture, 121, coil),
        details(texture, 122),
        details(texture, 123, hole),
        details(texture, 124),
    ]
    shapes = edge_shapes(110, [(1, 1.0), (2, 0.7), (4, 0.3)], 0.16)

    def decorate(tile, covered, rng):
        # The bank of a tideway: soaked dark mud running down into a glint of shallow water.
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                if covered(x, y):
                    distance = edge_distance(covered, x, y, 5)
                    if distance <= 2:
                        tile[y][x] = "mud_dark"
                    elif distance <= 4 and (x + y) % 2:
                        tile[y][x] = "mud"
                elif is_rim(lambda x, y: not covered(x, y), x, y) and rng.random() < 0.5:
                    tile[y][x] = "water_light"

    return edge_tiles(texture, shapes, 110, decorate) + fulls, []


# The floodplain and the wetland ------------------------------------------------------------------


def reed_clump(seed, tall):
    """Reeds of the bank: thin stems from a dark foot, some with a straw tip, a few leaves."""
    rng = random.Random(seed)
    width, height = 9, tall
    picture = blank(width, height)
    for stem in range(5):
        x = 1 + stem * 2 - rng.randrange(2)
        top = rng.randrange(0, height // 2)
        lean = rng.choice((-1, 0, 0, 1))
        for y in range(top, height):
            column = x + (lean if y < top + (height - top) // 3 else 0)
            if 0 <= column < width:
                picture[y][column] = "straw" if y == top else "reed" if y < height - 3 else "olive"
    for x in range(2, 7):
        picture[height - 1][x] = "olive"
    return picture


def cattail(seed):
    """Reeds with the brown velvet heads of the bulrush."""
    picture = reed_clump(seed, 14)
    for x, top in ((2, 1), (5, 0)):
        for y in range(top, top + 4):
            picture[y][x] = "soil_mid" if y > top else "soil_light"
        picture[top + 4][x] = "reed"
    return picture


def floodplain():
    """A lush, damp meadow: fertile land, darker and richer than ordinary grass."""
    clover = sprite(
        {"b": "green_bright", "l": "green_light", "d": "green_deep"}, ".bl..", "lll.l", ".lldl", "..dd.", "...d."
    )
    puddle = shaded_sprite(10, 6, [forms.ellipse(10, 6, 5, 3, 4.5, 2.5)], ("water", "water", "water_light"))
    for x in range(10):
        column = [y for y in range(6) if puddle[y][x]]
        if column:
            puddle[column[0]][x] = "mud_dark"
            puddle[column[-1]][x] = "mud"
    flowers = [
        sprite({"c": "cream", "g": "gold", "d": "green_deep"}, ".c...", "cgc.c", ".d.cg", ".d..d"),
        sprite({"c": "gold", "d": "green_deep"}, ".c..", "cc.c", ".d.d", ".d.."),
        sprite({"c": "petal", "d": "green_deep"}, "c.c.", "d.dc", "d..d"),
    ]

    texture = grass_texture("meadow", ("green_deep", "green_deep", "meadow_light", "meadow_light"), 10, 12)
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
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                if covered(x, y):
                    distance = edge_distance(covered, x, y, 6)
                    if distance <= 2:
                        tile[y][x] = "mud_dark"
                    elif distance <= 3 or (distance <= 5 and (x + y) % 2):
                        tile[y][x] = "mud"
                elif is_rim(lambda x, y: not covered(x, y), x, y):
                    tile[y][x] = "foam" if foam_noise(x, y) > 0.3 else "water_light"

    decorations = [
        decoration(30, reed_clump(30, 16)),
        decoration(31, cattail(31)),
        decoration(34, clover, clover),
        decoration(35, puddle),
    ]
    return edge_tiles(texture, shapes, 20, decorate) + fulls, decorations


def wetland():
    """Bog: dark wet ground with sedge and moss, reeds and pools of black water."""
    sedge = sprite({"g": "green_dark", "o": "olive", "k": "bog_dark"}, "o.g", "g.g", ".k.")
    pool = shaded_sprite(
        14, 8, [forms.ellipse(14, 8, 7, 4, 6.5, 3.5)], ("water_deep", "water_deep", "water"), shadow=None
    )
    for x in range(14):
        column = [y for y in range(8) if pool[y][x]]
        if column:
            pool[column[0]][x] = "bog_dark"
            pool[column[-1]][x] = "green_dark"
    reeds = [reed_clump(32, 16), reed_clump(33, 11), cattail(34)]
    toadstool = shaded_sprite(
        7, 7, [forms.ellipse(7, 7, 3.5, 2.5, 3, 2)], ("rust_dark", "ember", "red_light"), shadow="bog_dark"
    )
    for x, y in ((2, 1), (4, 2)):
        toadstool[y][x] = "cream"
    for y in (4, 5):
        toadstool[y][3] = "stone_light"
    brown_caps = sprite(
        {"m": "soil_mid", "l": "soil_light", "s": "cream", "d": "soil_dark"}, ".ll....", "lmmd.l.", ".s..lmd", ".s...s.", ".....s."
    )

    texture = grass_texture("bog", ("bog_dark", "green_dark", "olive", "olive"), 8, 10)
    fulls = [
        details(texture, 31, reeds[0]),
        details(texture, 32, pool),
        details(texture, 33, reeds[1], sedge),
        details(texture, 34, sedge),
        details(texture, 35, sedge),
        details(texture, 36),
        details(texture, 37),
        details(texture, 38, sedge, sedge),
        details(texture, 39, reeds[2]),
        details(texture, 40, sedge),
    ]
    shapes = edge_shapes(30, [(2, 1.0), (3, 0.7), (4, 0.3)], 0.18)

    def decorate(tile, covered, rng):
        # A dark soaked rim, with sedge poking out on the north side and seeping mud on
        # the south side.
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                if is_rim(covered, x, y):
                    tile[y][x] = "bog_dark"
        blades(tile, covered, rng, ("bog_dark", "mud_dark"), 0.5, 1, (1, 2, 2, 3))
        blades(tile, covered, rng, ("green_dark", "olive"), 0.35, -1, (2, 3, 3, 4))

    decorations = [
        decoration(41, toadstool),
        decoration(42, brown_caps),
        decoration(43, reeds[0], reeds[1]),
        decoration(44, reeds[0]),
        decoration(45, reeds[2]),
        decoration(46, reeds[2], reeds[1]),
    ]
    return edge_tiles(texture, shapes, 30, decorate) + fulls, decorations


# Grass and what lies over it ---------------------------------------------------------------------

# All grass layers share their edge shapes, so the layers over ordinary grass never stick out of
# it.
GRASS_SHAPES = edge_shapes(40, [(2, 1.0), (3, 0.6), (5, 0.3)], 0.18)
GRASS_RAMP = ("green_deep", "green_dark", "green_light", "green_bright")

# Dots in flower colours, which autumn turns into leaf colours (see seasons.py). The
# game shows them only in autumn (see data/vegetation.cfg).
fallen_leaves = sprite(
    {"a": "gold", "b": "petal", "c": "cream"},
    "aa.....b.",
    ".a..c..bb",
    ".....c...",
    "b.......a",
    "bb..aa...",
    "....a..c.",
)


def clover_patch(ramp):
    """Clover: round leaflets in threes, lit on the top left, the far ones in shade."""
    deep, dark, light, bright = ramp
    return sprite(
        {"k": deep, "d": dark, "l": light, "b": bright},
        ".bl...bl.",
        "lll.l.lll",
        ".lldl.ld.",
        "..dd.lll.",
        "...d..d..",
        "......k..",
    )


def pebbles(shadow):
    """A few pebbles, each lit on top with its shadow under it."""
    ramp = ("stone_dark", "stone", "stone_light")
    width, height = 10, 6
    shapes = [forms.ellipse(width, height, 3, 2.5, 2.5, 2), forms.ellipse(width, height, 7.5, 3.5, 1.8, 1.5)]
    return shaded_sprite(width, height, shapes, ramp, shadow=shadow)


def fern_sprout(ramp):
    deep, dark, light, bright = ramp
    return sprite(
        {"k": deep, "d": dark, "l": light},
        "l.......l",
        ".l..l..l.",
        "l.l.l.l.l",
        ".ldldld..",
        "..dldd...",
        "...kk....",
    )


def grass():
    clover = clover_patch(GRASS_RAMP)
    texture = grass_texture("green", GRASS_RAMP, 12, 14)
    thick = big_tuft(GRASS_RAMP)
    shapes = tufts(GRASS_RAMP)
    fulls = [
        details(texture, 41),
        details(texture, 42),
        details(texture, 43, shapes[0]),
        details(texture, 44, shapes[1]),
        details(texture, 45, shapes[4]),
        details(texture, 46, shapes[0], shapes[4]),
        details(texture, 47, shapes[1]),
        details(texture, 48),
        details(texture, 49, shapes[2], shapes[3]),
        details(texture, 50, shapes[1], shapes[4]),
    ]

    def decorate(tile, covered, rng):
        # A dark rim, with blades of uneven length hanging over the lower terrain on the
        # south side and tips poking out on the north side.
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                if is_rim(covered, x, y):
                    tile[y][x] = "green_dark"
        blades(tile, covered, rng, ("green_deep", "green_dark"), 0.6, 1, (1, 2, 2, 3, 4))
        blades(tile, covered, rng, ("green_dark", "green_light"), 0.4, -1, (1, 2, 2, 3))

    decorations = [
        decoration(55, clover),
        decoration(56, pebbles("green_dark")),
        decoration(57, fern_sprout(GRASS_RAMP)),
        decoration(58, thick, shapes[1]),
        decoration(53, thick),
        decoration(59, fallen_leaves),
    ]
    return edge_tiles(texture, GRASS_SHAPES, 40, decorate) + fulls, decorations


def tinted_grass(texture, seed, picks, decorations):
    """A grass family (lush or dry) drawn over ordinary grass. Its edge leaves the grass
    rim showing and fades out in a dither, so the colour shifts softly."""
    fulls = [details(texture, seed + n, *pictures) for n, pictures in enumerate(picks)]
    return (
        edge_tiles(texture, GRASS_SHAPES, seed, lambda tile, covered, rng: fade_out(tile, covered, rng, 7))
        + fulls,
        decorations,
    )


def lush_grass():
    ramp = ("green_deep", "green_deep", "green_dark", "green_light")
    tuft = big_tuft(ramp)
    clover = clover_patch(("green_deep", "green_deep", "green_light", "green_bright"))
    brown_caps = sprite(
        {"m": "soil_mid", "l": "soil_light", "s": "cream", "d": "soil_dark"}, ".ll....", "lmmd.l.", ".s..lmd", ".s...s.", ".....s."
    )
    fern = fern_sprout(("green_deep", "green_dark", "green_light", "green_bright"))
    picks = [(), (tuft,), (clover,), (), (tuft, clover), (tuft,), (), (clover,)]
    decorations = [
        decoration(61, clover, clover),
        decoration(64, fern),
        decoration(65, brown_caps),
        decoration(66, fern, clover),
        decoration(67, fallen_leaves),
    ]
    return tinted_grass(grass_texture("green", ramp, 16, 18), 60, picks, decorations)


def dry_grass():
    ramp = ("olive", "olive", "dry_light", "straw")
    tuft = big_tuft(ramp)
    stalks = sprite({"s": "straw", "r": "reed", "o": "olive"}, "s..s.", "r.s.s", "r.r.r", ".rr.r", ".oro.")
    stones = pebbles("olive")
    picks = [(), (tuft,), (stalks,), (), (tuft, stalks), (stalks,), (), (tuft,)]
    decorations = [
        decoration(71, tuft, stalks),
        decoration(72, stones),
        decoration(74, stalks, stalks),
        decoration(75, stones, tuft),
        decoration(76, fallen_leaves),
    ]
    return tinted_grass(grass_texture("dry", ramp, 12, 14), 70, picks, decorations)


def salt_marsh():
    """The salt marsh (Salzwiese) between the dyke and the mud: low grey-green turf of salt grass
    and sea purslane, with glasswort (Queller) in the wetter patches, which turns red-purple in
    autumn. It is drawn in the logical colours `salt...` and `glasswort...`, which every look
    maps to the palette (seasons.SALT_MARSH_LOOKS). Like lush and dry grass it lies over ordinary
    grass and shares its edges: the grass's dark rim and blades are the low sod edge where it
    breaks off to the mud."""
    purslane = sprite({"l": "salt_light", "d": "salt_dark"}, ".l.l.", "llld.", ".dld.", "..d..")
    glasswort = sprite({"g": "glasswort", "d": "glasswort_dark"}, "g..g", "dg.g", ".dgd", "..d.")
    sprig = sprite({"g": "glasswort", "d": "glasswort_dark"}, "g", "g", "d")
    picks = [(), (purslane,), (glasswort,), (), (purslane, sprig), (glasswort, glasswort), (), (sprig,)]
    ramp = ("salt_dark", "salt_dark", "salt_light", "salt_light")
    turf = grass_texture("salt", ramp, 8, 12)

    def texture(seed):
        tile = turf(seed)
        patches = patch_noise(seed + 7, 8)
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                patch = patches(x, y)
                if tile[y][x] == "salt" and patch > 0.5:
                    tile[y][x] = "salt_patch"
        scatter(tile, random.Random(seed), [sprig], 3)
        return tile

    clump = sprite(
        {"g": "glasswort", "d": "glasswort_dark", "s": "salt_dark"},
        "g...g..",
        "dg.gd.g",
        ".dgd.gd",
        ".ddgdd.",
        "...s...",
    )
    bush = shaded_sprite(
        9, 6, [forms.ellipse(9, 6, 4.5, 3.5, 4, 2.5)], ("salt_dark", "salt", "salt_light"), shadow="salt_dark"
    )
    decorations = [
        decoration(141, clump),
        decoration(142, clump, sprig),
        decoration(143, bush),
        decoration(144, bush, clump),
    ]
    return tinted_grass(texture, 130, picks, decorations)


# How far down the slope of a Warft reaches from its edge, in pixels, and its shades from the
# foot up, lit where it faces the light and shaded where it does not.
_WARFT_SLOPE = 12
_WARFT_LIT = ("green_light",) * 3 + ("green_bright",) * 2 + ("green_light",) * 3 + ("green",) * 4
_WARFT_SHADED = ("green_deep",) * 4 + ("green_dark",) * 5 + ("green",) * 3


def warft():
    """A Warft, the dwelling mound of the marsh: its top is grass like any other, and its edges
    are the slope down to the low land, lit where it faces north and west and in shade where it
    faces south and east (the light comes from the top left), with a short shadow at its foot on
    the south side. Around a pond on top (the Fething) the same edges are the pond's banks, which
    face the other way and are lit and shaded the right way round by the same rule. It lies over
    ordinary grass and shares its edges, like lush and dry grass."""
    texture = grass_texture("green", GRASS_RAMP, 12, 14)
    tuft = big_tuft(GRASS_RAMP)
    fulls = [details(texture, 150 + n, *pictures) for n, pictures in enumerate([(), (tuft,), (), ()])]

    def decorate(tile, covered, rng):
        slope = []
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                if not covered(x, y):
                    continue
                # The nearest way down: to the north or west is a lit face, south or east shade.
                for step in range(1, _WARFT_SLOPE + 1):
                    downs = [(dx, dy) for dx, dy in NEIGHBOURS if not covered(x + dx * step, y + dy * step)]
                    if downs:
                        faces_light = any(dx < 0 or dy < 0 for dx, dy in downs)
                        slope.append((x, y, step, faces_light))
                        break
        for x, y, step, faces_light in slope:
            # The band thins out in a dither towards the top, so the slope has no hard line.
            if step > _WARFT_SLOPE - 3 and (x + y + step) % 2:
                continue
            tile[y][x] = (_WARFT_LIT if faces_light else _WARFT_SHADED)[step - 1]
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                # The shadow it casts on the low land at its southern foot.
                if not covered(x, y) and (
                    any(covered(x, y - up) for up in (1, 2, 3)) or covered(x, y - 4) and (x + y) % 2
                ):
                    tile[y][x] = "green_deep"

    decorations = [decoration(161, tuft), decoration(162, tuft, tufts(GRASS_RAMP)[1])]
    return edge_tiles(texture, GRASS_SHAPES, 150, decorate) + fulls, decorations


# Desire paths: grass that is walked often turns trodden, then a path of bare earth (see
# data/paths.cfg). Both are drawn over whatever grass they wore, so their edges fade into it.


# The share of pixels of worn ground that are a speck.
SPECK_CHANCE = 0.03


def worn_earth(base, specks):
    """The texture of worn ground: an even `base` colour with a few single pixels of `specks`,
    so that the full tiles, picked at random, show no shape of their own where they meet."""

    def texture(seed):
        rng = random.Random(seed)
        tile = filled(base, GAME_TILE)
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                if rng.random() < SPECK_CHANCE:
                    tile[y][x] = rng.choice(specks)
        return tile

    return texture


def trodden():
    """Flattened grass worn down to even dark earth, with the odd speck of dry blade or bare mud."""
    texture = worn_earth("mud_dark", ("mud", "mud", "dry"))
    fulls = [texture(90 + n) for n in range(4)]
    shapes = edge_shapes(90, [(2, 1.0), (3, 0.7), (5, 0.3)], 0.22)

    # A worn tile has no decorations: its flowers and tufts were trodden down.
    return edge_tiles(texture, shapes, 90, lambda tile, covered, rng: fade_out(tile, covered, rng, 7)) + fulls, []


def path():
    """Packed bare earth, an even colour with a few specks of grit. It lies a little below the
    turf: the grass beside it casts a dark line along its edge and leans in over it."""
    texture = worn_earth("mud", ("sand", "sand", "mud_dark"))
    fulls = [texture(101 + n) for n in range(6)]
    shapes = edge_shapes(100, [(2, 1.0), (3, 0.6), (4, 0.3)], 0.2)

    def decorate(tile, covered, rng):
        # The cut under the turf: dark where the grass beside it is to the north or west, which
        # the light comes over, and blades of the grass leaning in over it.
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                if not covered(x, y):
                    continue
                distance = edge_distance(covered, x, y, 4)
                if distance == 1:
                    tile[y][x] = "mud_dark"
                elif distance == 2 and not (covered(x - 2, y) and covered(x, y - 2)):
                    tile[y][x] = "mud_dark"
                elif distance == 3 and tile[y][x] == "sand":
                    tile[y][x] = "mud"
        blades(tile, lambda x, y: not covered(x, y), rng, ("green_dark", "green_dark", "green_light"), 0.35, -1, (1, 2, 3))
        blades(tile, lambda x, y: not covered(x, y), rng, ("green_dark", "green_deep"), 0.3, 1, (1, 2))

    return edge_tiles(texture, shapes, 100, decorate) + fulls, []


# Tilled soil --------------------------------------------------------------------------------------

# The furrows of tilled soil run straight along the field, every 8 pixels: a lit crest, the body of
# the ridge and two rows of furrow. Every pixel depends only on its place in the tile, which repeats
# on both axes, so a bed of any size is one pattern and the tiles show no seams, however the dual
# grid cuts them. The terrain is the dry soil; the moister steps are overlays (see soil_beds.py).
_FURROW_ROWS = (6, 7)
# Where the crest catches the light: along most of it, in broken stretches.
_CREST_LIGHT = periodic_noise(82, [(5, 1.0), (7, 0.7)])
# Crumbs: a few single pixels of crest on the ridge and of furrow on its foot, so the rows are
# earth and not stripes. 1 is a light one, -1 a dark one.
_CRUMBS = [[random.Random(83 * GAME_TILE * y + x).choice((-1, 0, 0, 0, 0, 0, 0, 0, 0, 1)) for x in range(GAME_TILE)]
           for y in range(GAME_TILE)]


def soil_pixel_of(ramp):
    """The function of the colour of the soil at a pixel of the tile, for a ramp of colours
    (furrow, body, crest) of one moisture step."""
    furrow, body, crest = ramp

    def pixel(x, y):
        row = y % 8
        if row == 0:
            return crest if _CREST_LIGHT(x, y) > -0.3 else body
        if row in _FURROW_ROWS:
            return furrow
        crumb = _CRUMBS[y % GAME_TILE][x % GAME_TILE]
        if crumb == 1 and row in (1, 2):
            return crest
        if crumb == -1 and row in (4, 5):
            return furrow
        return body

    return pixel


_DRY_SOIL = soil_pixel_of(soil_beds.RAMPS[0])
# A bed fills its tiles to a pixel or two of their edge, straight along the sides but ragged, and
# rounds off softly at its corners (task 174).
_SOIL_SHAPES = edge_shapes(80, [(1, 1.0), (2, 0.6), (4, 0.4)], 0.07, inset=1.5, ramp=22)


def _tilled(seed):
    return [[_DRY_SOIL(x, y) for x in range(GAME_TILE)] for y in range(GAME_TILE)]


def weed_rosette(ramp):
    """A young weed (a dandelion, a plantain) as it comes up on bare earth: a low rosette of
    leaves round a dark heart, lit on the top left, with its shadow on the soil."""
    deep, dark, light, bright = ramp
    return sprite(
        {"k": deep, "d": dark, "l": light, "b": bright, "s": "soil"},
        ".b....b..",
        ".lb..bl..",
        "..ll.ll.b",
        "bldlkldl.",
        ".lldkdll.",
        "dlkkkkddl",
        ".ddkdkdds",
        "..sddsss.",
    )


def seedlings(ramp):
    """A few seedlings of chickweed: pairs of round leaves on short stalks, each with a pixel of
    shadow."""
    deep, dark, light, bright = ramp
    return sprite(
        {"k": deep, "d": dark, "l": light, "b": bright, "s": "soil"},
        "bl.....",
        "dl..lb.",
        ".ks.dl.",
        ".....ks",
    )


def weeds():
    """What comes up on tilled soil left fallow (see game/state/fallow_soil.gd): a few weeds and
    tufts of grass. The decorations of the soil row, which the game draws only on soil nobody has
    tended for some days, never by the decoration noise. They stay on the bed even of a tile tilled
    alone."""
    rosette = weed_rosette(GRASS_RAMP)
    sprouts = seedlings(GRASS_RAMP)
    shapes = tufts(GRASS_RAMP)
    on_bed = soil_beds.inside_bed(GAME_TILE, 0, _SOIL_SHAPES)

    def weeds_on_bed(seed, *pictures):
        rng = random.Random(seed)
        tile = blank(GAME_TILE)
        for picture in pictures:
            drawn = [(x, y) for y, row in enumerate(picture) for x, colour in enumerate(row) if colour]
            stamp(tile, picture, *soil_beds.spot_on_bed(rng, on_bed, drawn))
        return tile

    return [
        weeds_on_bed(84, rosette, shapes[2], shapes[5], sprouts, shapes[0]),
        weeds_on_bed(85, shapes[0], sprouts, shapes[3], shapes[4], sprouts),
        weeds_on_bed(86, sprouts, rosette, shapes[4], shapes[1]),
        weeds_on_bed(87, shapes[1], shapes[5], sprouts, rosette, shapes[3]),
    ]


def soil():
    def decorate(tile, covered, rng):
        # The field lies a little below the turf: dark along its edge where the turf beside it is
        # to the north or west, a step of soil elsewhere.
        for y in range(GAME_TILE):
            for x in range(GAME_TILE):
                if not is_rim(covered, x, y):
                    continue
                tile[y][x] = "soil_dark" if not covered(x, y - 1) or not covered(x - 1, y) else "soil"

    # All the tiles of a tilled field are one: there is no variant to show where the tiles end.
    return edge_tiles(_tilled, _SOIL_SHAPES, 80, decorate) + [_tilled(0)], weeds()


def soil_wet():
    """The overlays of the moister steps of tilled soil (see soil_beds.py)."""
    return soil_beds.overlay_rows(GAME_TILE, _SOIL_SHAPES, soil_pixel_of)


# The line between wetter and drier soil wanders 9 pixels each way across the tile edge.
_PATCH_EDGE = soil_beds.PatchEdge(GAME_TILE, amplitude=9, blotch=2.2, blotch_cell=8, gap=3, convex=10, concave=8, taper=4)


def soil_edge():
    """The edges of wet patches of tilled soil (see soil_beds.py)."""
    return soil_beds.edge_rows(_PATCH_EDGE, _SOIL_SHAPES, soil_pixel_of)


LAYERS = [
    water, mud, floodplain, wetland, grass, salt_marsh, warft, lush_grass, dry_grass, trodden, path, soil
]
