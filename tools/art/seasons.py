"""The looks of the terrain, decoration, object and house art.

Summer is the art as generate.py draws it. The other looks are made from it: colour remaps
(grass turns fresher, yellower, brown-grey, rimed or snowy; leaves change colour) plus a few
overlays (snow caps, blossom). So an art change in generate.py carries over to every look.
The game picks a look per tile and per object (see game/state/season_blend.gd): spring,
summer and autumn are the seasons' foliage, "bare" is winter without snow, "frost" a cold
morning without snow, "snow" the ground under snow and "dusting" the thin edge of the snow:
sparse flecks over whatever lies beneath.

generate.py draws the ground shadow of objects and houses in the logical colour "shadow",
which every season maps to a palette colour here. Pictures are grids of palette colour names,
as in generate.py.
"""

import math
import random

LOOKS = ("spring", "summer", "autumn", "bare", "frost", "snow", "dusting")

# Palette colours the seasons add to generate.PALETTE.
COLOURS = {
    # Spring greens and blossom.
    "spring_pale":    "a8d070",
    "spring_light":   "86b85a",
    "spring":         "5a9048",
    "spring_dark":    "3f6e3d",
    "blossom":        "efc3d0",
    # Yellow grass of autumn.
    "autumn_light":   "a89a4c",
    # Autumn leaves: orange, red and yellow ramps, light to dark.
    "maple_light":    "e8a244",
    "rust":           "b4532b",
    "rust_dark":      "7a3424",
    "russet_deep":    "4c2a22",
    "red_light":      "c8503a",
    "crimson":        "86302f",
    "ochre":          "cc9d3e",
    "ochre_dark":     "9a7430",
    "umber":          "5a4426",
    # Bare ground of a winter without snow: brown-grey.
    "bare_light":     "8a8270",
    "bare":           "6a6354",
    # Snow, lit to shaded; the shades are blue-grey so they stay calm under the night tint.
    "snow_light":     "e6eef2",
    "snow":           "cddae3",
    "snow_shadow":    "a3b4c6",
    "snow_deep":      "7a8ea8",
    # A calm pale blue-green for rimed grass.
    "frost":          "86a094",
    "frost_light":    "aec4ba",
}

_SPRING_GREENS = {
    "green_bright": "spring_pale",
    "green_light": "spring_light",
    "green": "spring",
    "lush": "spring",
    "green_dark": "spring_dark",
}
_AUTUMN_GRASS = {
    "green_bright": "straw",
    "green_light": "autumn_light",
    "green": "reed",
    "lush": "olive",
    "green_dark": "olive",
    "dry": "autumn_light",
    "dry_light": "straw",
    "meadow": "olive",
    "meadow_light": "reed",
    "meadow_dark": "green_dark",
    # Flowers wither to dry heads and fallen leaves.
    "cream": "ochre",
    "gold": "flame",
    "petal": "rust",
}
_WINTER_GROUND = {
    "green_bright": "snow_light",
    "green_light": "snow_light",
    "green": "snow",
    "lush": "snow",
    # The dark greens only soften by one step, so where layers meet (grass rims and blades
    # showing through the dithered edge of lush or dry grass) no lines stand out on the snow.
    "green_dark": "snow",
    "green_deep": "snow_shadow",
    "olive": "snow_shadow",
    "dry": "snow",
    "dry_light": "snow_light",
    "meadow": "snow",
    "meadow_light": "snow_light",
    "meadow_dark": "snow_shadow",
    "bog": "snow_shadow",
    "bog_dark": "snow_shadow",
    # Flowers are frosted.
    "cream": "snow_light",
    "gold": "snow",
    "petal": "snow_shadow",
}
# What still stands in winter is dry stalks poking through the snow, not frosted green.
WINTER_STALKS = {
    "green_bright": "straw", "green_light": "straw", "green_dark": "reed", "green_deep": "reed",
}
# Winter without snow: brown-grey ground, dry stalks, withered flowers.
_BARE_GROUND = {
    "green_bright": "bare_light",
    "green_light": "bare_light",
    "green": "bare",
    "lush": "bare",
    "green_dark": "mud_dark",
    "green_deep": "soil_dark",
    "olive": "mud_dark",
    "dry": "bare",
    "dry_light": "bare_light",
    "meadow": "bare",
    "meadow_light": "bare_light",
    "meadow_dark": "mud_dark",
    "cream": "straw",
    "gold": "straw",
    "petal": "sand",
}
# A frost: the grass keeps its shapes but turns a cold pale blue-green, with white rims on the
# tips (see also `sparkle`).
_FROST_GROUND = {
    "green_bright": "snow_light",
    "green_light": "frost_light",
    "green": "frost",
    "lush": "frost",
    "green_dark": "snow_deep",
    "green_deep": "snow_deep",
    "olive": "frost",
    "dry": "frost",
    "dry_light": "frost_light",
    "meadow": "frost",
    "meadow_light": "frost_light",
    "meadow_dark": "snow_deep",
    "bog": "snow_deep",
    "bog_dark": "snow_deep",
    "cream": "snow_light",
    "gold": "frost_light",
    "petal": "snow_shadow",
}
# Plants stay green-shaped under a frost, with white rims.
_FROST_STALKS = {"green_bright": "snow_light", "green_light": "frost_light", "green_dark": "frost", "green_deep": "snow_deep"}
GROUND_REMAPS = {
    "spring": _SPRING_GREENS,
    "summer": {},
    "autumn": _AUTUMN_GRASS,
    "bare": _BARE_GROUND,
    "frost": _FROST_GROUND,
    "snow": _WINTER_GROUND,
    # Only its decorations use this; see terrain_rows.
    "dusting": _FROST_GROUND,
}
# What decoration tufts and plants turn into: dry stalks from the bare look on.
STANDING = {"bare": WINTER_STALKS, "frost": _FROST_STALKS, "snow": WINTER_STALKS, "dusting": _FROST_STALKS}

_SHADOW_REMAPS = {
    "spring": "green_deep", "summer": "green_deep", "autumn": "green_deep",
    "bare": "mud_dark", "frost": "mud_dark", "snow": "snow_shadow", "dusting": "mud_dark",
}

# Leaf ramps for autumn trees and bushes, replacing the greens of summer.
_ORANGE = {
    "green_bright": "maple_light", "green_light": "flame", "green": "rust", "green_dark": "rust_dark",
    "green_deep": "russet_deep", "olive": "rust_dark", "dry_light": "maple_light", "dry": "flame",
}
_RED = {
    "green_bright": "red_light", "green_light": "ember", "green": "crimson", "green_dark": "rust_dark",
    "green_deep": "russet_deep", "olive": "rust_dark", "dry_light": "red_light", "dry": "ember",
}
_YELLOW = {
    "green_bright": "gold", "green_light": "ochre", "green": "ochre", "green_dark": "ochre_dark",
    "green_deep": "umber", "olive": "ochre_dark", "dry_light": "gold", "dry": "ochre",
}
# One look per variant, so a forest of oaks has all of them.
_AUTUMN_OAK = (_ORANGE, _RED, _YELLOW)
# Bushes have yellow and orange only: red berries must stand out.
_AUTUMN_BUSH = (_YELLOW, _ORANGE, _YELLOW)

# Bare twigs in winter, under the snow.
_BARE_BUSH = {
    "green_bright": "mud", "green_light": "mud", "green": "mud_dark", "green_dark": "soil_dark", "green_deep": "soil_dark",
    "olive": "mud_dark", "dry_light": "mud", "dry": "mud",
}
# A berry bush under snow: a clean mound, the berries peeking out.
_SNOW_MOUND = {
    "green_light": "snow_light", "green": "snow", "green_dark": "snow_shadow", "green_deep": "snow_deep",
}
_DRY_FERN = {"green_light": "straw", "green": "reed", "green_dark": "olive"}

# How the snow cap of each object is drawn: (surfaces, edges, depth in px).
_SNOW_CONIFER = ({"green_light", "green", "green_dark", "olive"}, {"green_deep"}, 2)
_SNOW_PINE = ({"green_light", "green", "green_dark", "olive"}, {"green_deep"}, 3)
_SNOW_BUSH = ({"mud", "mud_dark", "soil_dark"}, {"green_deep"}, 5)
_SNOW_STONE = ({"stone_light", "stone"}, set(), 2)
_SNOW_BOULDER = ({"stone_light", "stone", "green_light", "green", "olive"}, set(), 3)
_SNOW_STUMP = ({"sand_light", "sand", "straw"}, set(), 3)
_SNOW_TRUNK = ({"soil_light", "soil_mid", "sand", "stone_light", "sand_light", "straw"}, set(), 2)
_SNOW_DEADWOOD = ({"stone_light", "stone", "bare_light"}, set(), 2)
_SNOW_DEAD_STUMP = ({"stone_light", "stone", "bare_light"}, set(), 3)

_SPRING_KINDS = {"oak", "berry_bush", "shrub", "sapling", "fern", "boulder", "tall_grass"}
_BLOSSOM_KINDS = {"berry_bush", "shrub"}


def remap(canvas, mapping):
    """A copy of a picture with colours replaced by name."""
    return [[mapping.get(name, name) for name in row] for row in canvas]


def copy(canvas):
    return [row[:] for row in canvas]


def ground_rows(look, rows, extra_remap=None):
    """Terrain or decoration rows (the layers bottom to top) in a look, with `extra_remap`
    applied over the look's own. Water stays as it is: freezing it belongs to the weather."""
    mapping = {**GROUND_REMAPS[look], **(extra_remap or {})}
    return [rows[0]] + [[remap(tile, mapping) for tile in row] for row in rows[1:]]


def sparkle(tile, rng, count):
    """A few single white pixels of rime on a terrain tile, on pixels that are drawn."""
    spots = [(x, y) for y, row in enumerate(tile) for x, name in enumerate(row) if name]
    for x, y in rng.sample(spots, min(count, len(spots))):
        tile[y][x] = "snow_light"


def dust(tile, rng):
    """Thins a snow tile to a dusting: flecks of snow and, in patches, a thin dithered sheet,
    with the rest left clear so the ground and its grass tips show through."""
    phase = rng.uniform(0, 6.3)
    keep = [[False] * len(row) for row in tile]
    for y, row in enumerate(tile):
        for x, name in enumerate(row):
            if name is None:
                continue
            sheet = math.sin(x * 0.7 + phase) * math.sin(y * 0.6 - phase) > 0.45 and (x + y) % 2 == 0
            fleck_chance = 0.4 if (x and keep[y][x - 1]) or (y and keep[y - 1][x]) else 0.07
            keep[y][x] = sheet or rng.random() < fleck_chance
    # A tile that was drawn keeps at least a flake, so every look has the same tiles (the game
    # makes a tile for every atlas cell that is not clear).
    if not any(map(any, keep)):
        spots = [(x, y) for y, row in enumerate(tile) for x, name in enumerate(row) if name]
        if spots:
            x, y = rng.choice(spots)
            keep[y][x] = True
    return [
        [("snow_light" if (x + y) % 3 else "snow") if keep[y][x] else None for x in range(len(row))]
        for y, row in enumerate(tile)
    ]


def terrain_rows(look, rows):
    """The terrain rows in a look. A frost gets a sprinkle of rime, a dusting is the snow thinned
    out; the rest is `ground_rows`."""
    if look == "dusting":
        snowy = ground_rows("snow", rows)
        return [snowy[0]] + [
            [dust(tile, random.Random(f"dust-{r}-{c}")) for c, tile in enumerate(row)]
            for r, row in enumerate(snowy[1:])
        ]
    result = ground_rows(look, rows)
    if look == "frost":
        for r, row in enumerate(result[1:]):
            for c, tile in enumerate(row):
                sparkle(tile, random.Random(f"rime-{r}-{c}"), 3)
    return result


def snow_caps(canvas, rng, surfaces, edges, depth, centre, bottom=None):
    """Lays snow on every top of a picture: where a `surfaces` or `edges` pixel has no
    surface above it (so also on the ledge under an overhang), a column of snow `depth` px
    deep, ragged, lit on the left of `centre` and shaded below. Only rows above `bottom`."""
    snowable = surfaces | edges
    height, width = bottom or len(canvas), len(canvas[0])
    for x in range(width):
        y = 0
        while y < height:
            above = canvas[y - 1][x] if y else None
            if canvas[y][x] in snowable and above not in surfaces and not (above or "").startswith("snow"):
                column_depth = depth + rng.choice((-1, 0, 0, 1))
                k = 0
                while k < column_depth and y + k < height and canvas[y + k][x] in snowable:
                    last = k == column_depth - 1 and column_depth > 1
                    lit = "snow_light" if x < centre else "snow"
                    canvas[y + k][x] = "snow_shadow" if last or canvas[y + k][x] in edges else lit
                    k += 1
                y += max(k, 1)
            else:
                y += 1


def blossoms(canvas, rng, surfaces, count):
    """Scatters 2 px blossoms over the leaves of a bush."""
    spots = [(x, y) for y, row in enumerate(canvas) for x, name in enumerate(row) if name in surfaces]
    for x, y in rng.sample(spots, min(count, len(spots))):
        canvas[y][x] = rng.choice(("blossom", "blossom", "cream", "petal"))
        if canvas[y][x + 1] in surfaces:
            canvas[y][x + 1] = "blossom"


# Reeds are green in spring and summer; from autumn on they stand golden.
_GOLDEN_REEDS = {
    "green_bright": "sand_light", "green_light": "sand_light", "green": "straw",
    "green_dark": "reed", "green_deep": "reed",
}
_SNOW_REEDS = ({"sand_light", "straw", "reed"}, set(), 2)


# Evergreens and rocks in a frost: the greens go pale and bluish, as if rimed.
_FROST_CONIFER = {"green_light": "snow_shadow", "green": "green_light", "green_dark": "green"}
_FROST_BUSH = {"green_light": "snow_light", "green": "snow_shadow", "green_dark": "mud_dark", "green_bright": "snow_light"}
_FROST_FERN = {"green_light": "snow_light", "green": "straw", "green_dark": "reed"}
_FROST_STONE = {"green_light": "snow", "green": "snow_shadow", "olive": "snow_shadow"}


def _season_object(look, kind, variant, canvas, redraw):
    """One object cell in a look. `variant` is its column in the atlas row (picked bushes
    repeat their bush's variants)."""
    rng = random.Random(f"{look}-{kind}-{variant}")
    centre = len(canvas[0]) // 2
    if look == "spring" and kind in _SPRING_KINDS:
        canvas = remap(canvas, _SPRING_GREENS)
        if kind in _BLOSSOM_KINDS:
            blossoms(canvas, rng, {"spring_light", "spring", "spring_pale"}, 7)
    elif look == "autumn":
        if kind == "oak":
            canvas = remap(canvas, _AUTUMN_OAK[variant])
        elif kind in ("berry_bush", "shrub", "sapling", "fern"):
            canvas = remap(canvas, _AUTUMN_BUSH[variant % 3])
        elif kind == "tall_grass":
            canvas = remap(canvas, _AUTUMN_GRASS)
        elif kind == "reeds":
            canvas = remap(canvas, _GOLDEN_REEDS)
    elif look in ("bare", "frost", "snow", "dusting"):
        canvas = _winter_object(look, kind, variant, canvas, redraw, rng, centre)
    return remap(canvas, {"shadow": _SHADOW_REMAPS[look]})


def _winter_object(look, kind, variant, canvas, redraw, rng, centre):
    """An object without leaves: bare, rimed with frost, under snow or under a dusting (frost
    with a thin snow cap)."""
    if kind in redraw:
        return redraw[kind](variant)
    is_frosty = look in ("frost", "dusting")
    has_snow = look in ("snow", "dusting")

    def cap(spec):
        surfaces, edges, depth = spec
        return surfaces, edges, depth if look == "snow" else 1

    if kind in ("spruce", "pine"):
        if look == "snow":
            canvas = copy(canvas)
            snow_caps(canvas, rng, *cap(_SNOW_CONIFER if kind == "spruce" else _SNOW_PINE), centre)
            return canvas
        if look == "dusting":
            canvas = remap(canvas, _FROST_CONIFER)
            snow_caps(canvas, rng, *cap(_SNOW_CONIFER if kind == "spruce" else _SNOW_PINE), centre)
            return canvas
        return remap(canvas, _FROST_CONIFER) if look == "frost" else canvas
    if kind == "tall_grass":
        stalks = {"bare": WINTER_STALKS, "snow": WINTER_STALKS, "frost": _FROST_STALKS, "dusting": _FROST_STALKS}
        return remap(canvas, stalks[look])
    if kind == "reeds":
        canvas = remap(canvas, _GOLDEN_REEDS)
        if has_snow:
            snow_caps(canvas, rng, *cap(_SNOW_REEDS), centre)
        return canvas
    if kind == "berry_bush":
        return remap(canvas, {"bare": _BARE_BUSH, "frost": {**_BARE_BUSH, **_FROST_BUSH}, "dusting": {**_BARE_BUSH, **_FROST_BUSH}, "snow": _SNOW_MOUND}[look])
    if kind in ("shrub", "sapling"):
        canvas = remap(canvas, {**_BARE_BUSH, **(_FROST_BUSH if is_frosty else {})})
        if has_snow:
            snow_caps(canvas, rng, *cap(_SNOW_BUSH), centre)
        return canvas
    if kind == "fern":
        canvas = remap(canvas, {**_DRY_FERN, **(_FROST_FERN if is_frosty else {})})
        if has_snow:
            snow_caps(canvas, rng, {"straw", "reed", "olive"}, set(), 1, centre)
        return canvas
    if kind == "dead_tree":
        if has_snow:
            canvas = copy(canvas)
            snow_caps(canvas, rng, *cap(_SNOW_DEADWOOD), centre)
        return canvas
    if kind in ("stone", "boulder", "stump", "dead_stump") or kind.endswith("trunk"):
        if has_snow:
            canvas = copy(canvas)
            spec = {"stone": _SNOW_STONE, "boulder": _SNOW_BOULDER, "stump": _SNOW_STUMP, "dead_stump": _SNOW_DEAD_STUMP}.get(kind, _SNOW_TRUNK)
            snow_caps(canvas, rng, *cap(spec), centre)
            return canvas
        return remap(canvas, _FROST_STONE) if is_frosty else canvas
    return canvas


def object_rows(look, atlas, redraw):
    """The object atlas rows in a look. `atlas` lists (kind, variants) per row; `redraw` maps a kind to a
    function that draws a variant from scratch where a remap is not enough (the bare oak)."""
    return [
        [_season_object(look, kind, variant, canvas, redraw) for variant, canvas in enumerate(row)]
        for kind, row in atlas
    ]


# What each colour of a roof turns into under snow: the snow keeps the roof's light and shade.
_SNOW_ON_ROOF = {
    "sand": "snow_light", "bare_light": "snow_light", "bare": "snow", "mud_dark": "snow_shadow",
    "soil_dark": "snow_deep", "umber": "snow_shadow", "dry_light": "snow_light", "dry": "snow",
    "olive": "snow", "green_dark": "snow_shadow", "green_deep": "snow_shadow",
    "cream": "snow_light", "snow_light": "snow_light", "stone_light": "snow_light", "stone": "snow",
    "soil_mid": "snow", "soil": "snow_shadow",
}
# Rows of the eaves left showing under the snow: the dark underside of the rolled edge.
_EAVES_UNDER_SNOW = 3


def house(look, canvas, snowy):
    """A house picture in a look: snow on its roof under snow, the plain house otherwise (the game
    only asks for "snow" and the summer picture). `snowy` are the pixels snow covers (see
    buildings.py); in each column the lowest rows of them, the underside of the eaves, stay
    clear, along a ragged edge."""
    canvas = remap(canvas, {"shadow": _SHADOW_REMAPS[look]})
    if look != "snow":
        return canvas
    rng = random.Random("house")
    columns = {}
    for x, y in snowy:
        columns.setdefault(x, []).append(y)
    edge = 0
    for x in sorted(columns):
        # Neighbouring columns share an edge height in runs, so the edge is ragged, not noisy.
        if x % 3 == 0:
            edge = rng.choice((-1, 0, 0, 1))
        rows = sorted(columns[x])
        # Only a long bottom run of a column ends in eaves; a chimney's cap is covered whole.
        run_start = len(rows) - 1
        while run_start > 0 and rows[run_start - 1] == rows[run_start] - 1:
            run_start -= 1
        keep = max(0, _EAVES_UNDER_SNOW + edge) if len(rows) - run_start > 6 else 0
        for y in rows[: len(rows) - keep]:
            canvas[y][x] = _SNOW_ON_ROOF.get(canvas[y][x], "snow")
        if keep:
            canvas[rows[len(rows) - keep - 1]][x] = "snow_shadow"
    return canvas
