"""The seasonal variants of the terrain, decoration, object and house art.

Summer is the art as generate.py draws it. The other seasons are made from it: colour remaps
(grass turns fresher, yellower or snowy; leaves change colour) plus a few overlays (snow caps,
blossom). So an art change in generate.py carries over to every season.

generate.py draws the ground shadow of objects and houses in the logical colour "shadow",
which every season maps to a palette colour here. Pictures are grids of palette colour names,
as in generate.py.
"""

import random

SEASONS = ("spring", "summer", "autumn", "winter")

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
    "autumn":         "7e7c3c",
    "autumn_dark":    "5e5a30",
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
    # Snow, lit to shaded; the shades are blue-grey so they stay calm under the night tint.
    "snow_light":     "e6eef2",
    "snow":           "cddae3",
    "snow_shadow":    "a3b4c6",
    "snow_deep":      "7a8ea8",
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
    "green": "autumn",
    "lush": "olive",
    "green_dark": "autumn_dark",
    "dry": "autumn_light",
    "dry_light": "straw",
    "olive": "autumn_dark",
    "meadow": "olive",
    "meadow_light": "autumn",
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
GROUND_REMAPS = {
    "spring": _SPRING_GREENS,
    "summer": {},
    "autumn": _AUTUMN_GRASS,
    "winter": _WINTER_GROUND,
}

_SHADOW_REMAPS = {"spring": "green_deep", "summer": "green_deep", "autumn": "green_deep", "winter": "snow_shadow"}

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
    "green_bright": "mud", "green_light": "mud", "green": "mud_dark", "green_dark": "soil_dark",
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
_THATCH = {"straw", "sand_light", "sand", "gold", "dry_light", "mud"}
# Thatch rows left showing under the snow at the eaves.
_THATCH_AT_EAVES = 4

_SPRING_KINDS = {"oak", "berry_bush", "shrub", "sapling", "fern", "boulder"}
_BLOSSOM_KINDS = {"berry_bush", "shrub"}


def remap(canvas, mapping):
    """A copy of a picture with colours replaced by name."""
    return [[mapping.get(name, name) for name in row] for row in canvas]


def copy(canvas):
    return [row[:] for row in canvas]


def ground_rows(season, rows):
    """Terrain or decoration rows (the layers bottom to top) in a season. Water stays as it
    is: freezing it belongs to the weather."""
    mapping = GROUND_REMAPS[season]
    return [rows[0]] + [[remap(tile, mapping) for tile in row] for row in rows[1:]]


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


def _season_object(season, kind, variant, canvas, redraw):
    """One object cell in a season. `variant` is its column in the atlas row (picked bushes
    repeat their bush's variants)."""
    rng = random.Random(f"{season}-{kind}-{variant}")
    centre = len(canvas[0]) // 2
    if season == "spring" and kind in _SPRING_KINDS:
        canvas = remap(canvas, _SPRING_GREENS)
        if kind in _BLOSSOM_KINDS:
            blossoms(canvas, rng, {"spring_light", "spring", "spring_pale"}, 7)
    elif season == "autumn":
        if kind == "oak":
            canvas = remap(canvas, _AUTUMN_OAK[variant])
        elif kind in ("berry_bush", "shrub", "sapling", "fern"):
            canvas = remap(canvas, _AUTUMN_BUSH[variant % 3])
    elif season == "winter":
        if kind in redraw:
            canvas = redraw[kind](variant)
        elif kind in ("spruce", "pine"):
            canvas = copy(canvas)
            snow_caps(canvas, rng, *(_SNOW_CONIFER if kind == "spruce" else _SNOW_PINE), centre)
        elif kind == "berry_bush":
            canvas = remap(canvas, _SNOW_MOUND)
        elif kind in ("shrub", "sapling"):
            canvas = remap(canvas, _BARE_BUSH)
            snow_caps(canvas, rng, *_SNOW_BUSH, centre)
        elif kind == "fern":
            canvas = remap(canvas, _DRY_FERN)
            snow_caps(canvas, rng, {"straw", "reed", "olive"}, set(), 1, centre)
        elif kind in ("stone", "boulder", "stump"):
            canvas = copy(canvas)
            snow_caps(canvas, rng, *{"stone": _SNOW_STONE, "boulder": _SNOW_BOULDER, "stump": _SNOW_STUMP}[kind], centre)
    return remap(canvas, {"shadow": _SHADOW_REMAPS[season]})


def object_rows(season, atlas, redraw):
    """The object atlas rows in a season. `atlas` lists (kind, variants) per row; `redraw` maps a kind to a
    function that draws a variant from scratch where a remap is not enough (the bare oak)."""
    return [
        [_season_object(season, kind, variant, canvas, redraw) for variant, canvas in enumerate(row)]
        for kind, row in atlas
    ]


def snow_roof(canvas, rng, ridge_y, eaves_y, shade_x):
    """Snow on a thatched roof between the rows `ridge_y` and `eaves_y`. Each column is
    covered from its top down to a ragged edge that leaves a little thatch at the eaves; the
    roof's own outline stays. Shading: a light band at the top, blue-grey towards the eaves,
    a lip at the edge with a darker underside, and one step darker right of `shade_x`."""
    # Snow shades from lit to dark; `shade` indexes them and the shaded right side goes one step on.
    lit = ("snow_light", "snow", "snow_shadow", "snow_deep")
    edge_of_snow = 0
    for x in range(len(canvas[0])):
        rows = [y for y in range(ridge_y, eaves_y - 1) if canvas[y][x] in _THATCH]
        if not rows:
            continue
        top, bottom = rows[0], rows[-1]
        # Neighbouring columns share a lip height in runs, so the edge is ragged, not noisy.
        if x % 3 == 0:
            edge_of_snow = rng.choice((-1, 0, 0, 1))
        last = bottom - _THATCH_AT_EAVES + edge_of_snow
        step = 1 if x > shade_x else 0
        for y in range(top, last + 1):
            from_top, from_edge = y - top, last - y
            if from_edge == 0:
                shade = 2
            elif from_edge == 1:
                shade = 0
            elif from_top < 3:
                shade = 0
            elif from_edge < 5:
                shade = 2
            else:
                shade = 1
            canvas[y][x] = lit[min(shade + step, 3)]


def house(season, canvas, ridge_y, eaves_y):
    """A house picture in a season: snow on the thatch in winter."""
    canvas = remap(canvas, {"shadow": _SHADOW_REMAPS[season]})
    if season == "winter":
        # The roof's right of x 50 is in shade; the chimney's top is x 51 to 60 at row 2
        # (see small_house in generate.py).
        snow_roof(canvas, random.Random("house"), ridge_y, eaves_y, 50)
        for x in range(51, 61):
            canvas[2][x] = "snow_light"
    return canvas
