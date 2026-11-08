"""The looks of the terrain, decoration, object and house art.

Summer is the art as terrain.py, trees.py and the other drawing modules draw it. The other
looks are made from it: colour remaps (grass turns fresher, yellower, brown-grey, rimed or snowy; leaves change colour) plus a few
overlays (snow caps, blossom). So an art change in those modules carries over to every look.
The game picks a look per tile and per object (see game/state/season_blend.gd): spring,
summer and autumn are the seasons' foliage, "bare" is winter without snow, "frost" a cold
morning without snow, "snow" the ground under snow and "dusting" the thin edge of the snow:
sparse flecks over whatever lies beneath. Objects have two more looks, the steps of the
spring leaf-out between bare and spring: "buds" and "young_leaves", drawn over the bare tree
or bush where its summer leaves are.

The drawing modules draw the ground shadow of objects and houses in the logical colour "shadow",
which every season maps to a palette colour here.
"""

import math
import random

from canvas import copy

# The looks of grass and ground, which every picture has.
GROUND_LOOKS = ("spring", "summer", "autumn", "bare", "frost", "snow", "dusting")
# The steps of the leaf-out between bare and spring, in order: only objects have them.
LEAF_OUT_LOOKS = ("buds", "young_leaves")
LOOKS = GROUND_LOOKS + LEAF_OUT_LOOKS

# Palette colours the seasons add to palette.PALETTE.
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
}

_SPRING_GREENS = {
    "green_bright": "spring_pale",
    "green_light": "spring_light",
    "green": "spring",
    "green_dark": "spring_dark",
}
_AUTUMN_GRASS = {
    "green_bright": "straw",
    "green_light": "autumn_light",
    "green": "reed",
    "green_dark": "olive",
    "dry": "autumn_light",
    "dry_light": "straw",
    "meadow": "olive",
    "meadow_light": "reed",
    # Flowers wither to dry heads and fallen leaves.
    "cream": "ochre",
    "gold": "flame",
    "petal": "rust",
}
_WINTER_GROUND = {
    "green_bright": "snow_light",
    "green_light": "snow_light",
    "green": "snow",
    # The dark greens only soften by one step, so where layers meet (grass rims and blades
    # showing through the dithered edge of lush or dry grass) no lines stand out on the snow.
    "green_dark": "snow",
    "green_deep": "snow_shadow",
    "olive": "snow_shadow",
    "dry": "snow",
    "dry_light": "snow_light",
    "meadow": "snow",
    "meadow_light": "snow_light",
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
# Tall grass in winter and autumn keeps a dark foot: its green_deep and green_dark are what stands
# out from the ground there (the dry stalks above are light).
_DARK_FOOT = {"green_dark": "olive", "green_deep": "umber"}
# Winter without snow: brown-grey ground, dry stalks, withered flowers.
_BARE_GROUND = {
    "green_bright": "bare_light",
    "green_light": "bare_light",
    "green": "bare",
    "green_dark": "mud_dark",
    "green_deep": "soil_dark",
    "olive": "mud_dark",
    "dry": "bare",
    "dry_light": "bare_light",
    "meadow": "bare",
    "meadow_light": "bare_light",
    "cream": "straw",
    "gold": "straw",
    "petal": "sand",
    # Desire paths lie dark and damp in the brown-grey of winter.
    "mud": "mud_dark",
}
# A frost: the grass keeps its shapes but turns a cold pale blue-green, with white rims on the
# tips (see also `sparkle`).
_FROST_GROUND = {
    "green_bright": "snow_light",
    "green_light": "snow_shadow",
    "green": "frost",
    "green_dark": "snow_deep",
    "green_deep": "snow_deep",
    "olive": "frost",
    "dry": "frost",
    "dry_light": "snow_shadow",
    "meadow": "frost",
    "meadow_light": "snow_shadow",
    "bog": "snow_deep",
    "bog_dark": "snow_deep",
    "cream": "snow_light",
    "gold": "snow_shadow",
    "petal": "snow_shadow",
}
# Plants stay green-shaped under a frost, with white rims.
_FROST_STALKS = {"green_bright": "snow_light", "green_light": "snow_shadow", "green_dark": "frost", "green_deep": "snow_deep"}
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

# The salt marsh (terrain.salt_marsh) in its logical colours, per look: grey-green turf in patches
# with silvery sea purslane and green glasswort in summer, fresher in spring; in autumn the
# glasswort and the turf turn red-purple; brown-grey in winter, rimed in a frost, white under snow.
SALT_MARSH_LOOKS = {
    "spring": {"salt": "dry", "salt_patch": "olive", "salt_light": "spring_light",
               "salt_dark": "green_dark", "glasswort": "spring", "glasswort_dark": "spring_dark"},
    "summer": {"salt": "olive", "salt_patch": "dry", "salt_light": "frost",
               "salt_dark": "green_dark", "glasswort": "green_bright", "glasswort_dark": "green_light"},
    "autumn": {"salt": "heather_dark", "salt_patch": "rust_dark", "salt_light": "heather",
               "salt_dark": "russet_deep", "glasswort": "red_light", "glasswort_dark": "rust_dark"},
    "bare": {"salt": "bare", "salt_patch": "mud", "salt_light": "bare_light",
             "salt_dark": "mud_dark", "glasswort": "umber", "glasswort_dark": "soil_dark"},
    "frost": {"salt": "frost", "salt_patch": "snow_shadow", "salt_light": "snow_shadow",
              "salt_dark": "snow_deep", "glasswort": "snow_shadow", "glasswort_dark": "snow_deep"},
    "snow": {"salt": "snow", "salt_patch": "snow", "salt_light": "snow_light",
             "salt_dark": "snow_shadow", "glasswort": "snow_shadow", "glasswort_dark": "snow_shadow"},
}
SALT_MARSH_LOOKS["dusting"] = SALT_MARSH_LOOKS["frost"]

# Snow on a desire path is trodden: the game draws the trodden grass in its snow look over the
# snow, and its bare earth shows as blue-grey footprints.
_TRODDEN_SNOW = {"mud": "snow_shadow", "mud_dark": "snow_shadow"}

_SHADOW_REMAPS = {
    "spring": "green_deep", "summer": "green_deep", "autumn": "green_deep",
    "bare": "mud_dark", "frost": "mud_dark", "snow": "snow_shadow", "dusting": "mud_dark",
    "buds": "green_deep", "young_leaves": "green_deep",
}

# Leaf ramps for autumn trees and bushes, replacing the greens of summer. North Sea autumn is
# brown, ochre, copper and yellow; red (rowan, cherry) is rare, and none of our trees has it.
_BROWN = {
    "green_bright": "ochre_dark", "green_light": "soil_light", "green": "soil_mid", "green_dark": "soil",
    "green_deep": "soil_dark", "olive": "soil", "dry_light": "ochre_dark", "dry": "soil_light",
}
_OCHRE = {
    "green_bright": "ochre", "green_light": "ochre_dark", "green": "umber", "green_dark": "umber",
    "green_deep": "russet_deep", "olive": "umber", "dry_light": "ochre", "dry": "ochre_dark",
}
# The beech's colour; an oak in its last leaves has it too.
_COPPER = {
    "green_bright": "ochre", "green_light": "soil_light", "green": "rust_dark", "green_dark": "russet_deep",
    "green_deep": "soil_dark", "olive": "russet_deep", "dry_light": "ochre", "dry": "soil_light",
}
# The alder stays green late and drops its leaves a dull green-brown.
_GREEN_BROWN = {
    "green_bright": "dry_light", "green_light": "dry", "green": "olive", "green_dark": "mud_dark",
    "green_deep": "soil_dark", "olive": "mud_dark", "dry_light": "dry", "dry": "olive",
}
_YELLOW = {
    "green_bright": "gold", "green_light": "ochre", "green": "ochre", "green_dark": "ochre_dark",
    "green_deep": "umber", "olive": "ochre_dark", "dry_light": "gold", "dry": "ochre",
}
# One look per variant, so a forest of oaks has all of them.
_AUTUMN_OAK = (_BROWN, _OCHRE, _COPPER)
# Bushes turn yellow and ochre: the red berries must stand out.
_AUTUMN_BUSH = (_YELLOW, _OCHRE, _YELLOW)

# Bare twigs in winter, under the snow.
_BARE_BUSH = {
    "green_bright": "mud", "green_light": "mud", "green": "mud_dark", "green_dark": "soil_dark", "green_deep": "soil_dark",
    "olive": "mud_dark", "dry_light": "mud", "dry": "mud",
}
# A berry bush under snow: a clean mound, the berries peeking out.
_SNOW_MOUND = {
    "green_light": "snow_light", "green": "snow", "green_dark": "snow_shadow", "green_deep": "snow_deep",
}
_DRY_FERN = {"green_bright": "straw", "green_light": "straw", "green": "reed", "green_dark": "olive", "green_deep": "umber"}

# How the snow cap of each object is drawn: (surfaces, edges, depth in px).
_SNOW_CONIFER = ({"green_light", "green", "green_dark", "olive"}, {"green_deep"}, 2)
_SNOW_PINE = ({"meadow_light", "meadow", "green_deep"}, {"bog_dark"}, 2)
_SNOW_BUSH = ({"mud", "mud_dark", "soil_dark"}, {"green_deep"}, 5)
_SNOW_STONE = ({"stone_light", "stone"}, set(), 2)
_SNOW_BOULDER = ({"stone_light", "stone", "green_light", "green", "olive"}, set(), 3)
_SNOW_STUMP = ({"sand_light", "sand", "straw"}, set(), 3)
_SNOW_TRUNK = ({"soil_light", "soil_mid", "sand", "stone_light", "sand_light", "straw", "bare_light"}, set(), 2)
_SNOW_DEADWOOD = ({"stone_light", "stone", "bare_light"}, set(), 2)
_SNOW_DEAD_STUMP = ({"stone_light", "stone", "bare_light"}, set(), 3)
# Snow lies on the lid of the chest (its first rows), not on top of the box under the iron rim.
_SNOW_BEDROLL = {
    "sand_light": "snow_light", "sand": "snow", "stone_light": "snow_light", "stone": "snow",
    "straw": "snow_shadow", "gold": "snow", "mud": "snow_shadow",
}
_SNOW_CHEST = ({"soil_light", "sand", "soil_mid"}, set(), 3)
_CHEST_LID_ROWS = 5


def _chest_lid_bottom(canvas):
    """The row under the lid of a chest picture: its first drawn row and the lid's height on."""
    return next(y for y, row in enumerate(canvas) if any(row)) + _CHEST_LID_ROWS

_SPRING_KINDS = {"oak", "beech", "birch", "alder", "berry_bush", "shrub", "sapling", "fern", "boulder", "tall_grass", "dyke"}
_BLOSSOM_KINDS = {"berry_bush", "shrub"}
# The deciduous trees and bushes: they leaf out in steps (LEAF_OUT_LOOKS).
_LEAF_OUT_KINDS = {"oak", "beech", "birch", "alder", "berry_bush", "shrub", "sapling", "willow"}
# What the summer leaves of a picture are drawn in: where they are is where the new leaves come.
_SUMMER_LEAVES = {"green_bright", "green_light", "green", "green_dark", "green_deep", "olive", "dry_light", "dry", "frost"}
# Young leaves are light and thin; their summer shade picks how light.
_YOUNG_LEAVES = {
    "green_bright": "spring_pale", "green_light": "spring_pale", "dry_light": "spring_pale", "frost": "spring_pale",
    "green": "spring_light", "olive": "spring_light", "dry": "spring_light",
    "green_dark": "spring", "green_deep": "spring",
}


def buds(bare, summer, rng):
    """The bare picture with a haze of pale green dots where the summer leaves will be, most of
    them on and around the twigs."""
    canvas = copy(bare)
    height, width = len(bare), len(bare[0])
    for y, row in enumerate(summer):
        for x, name in enumerate(row):
            if name not in _SUMMER_LEAVES:
                continue
            is_by_twig = any(
                bare[y + dy][x + dx] not in (None, "shadow")
                for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                if 0 <= y + dy < height and 0 <= x + dx < width
            )
            if rng.random() < (0.3 if is_by_twig else 0.04):
                canvas[y][x] = "spring_pale" if rng.random() < 0.7 else "spring_light"
    return canvas


def young_leaves(bare, summer, rng):
    """The bare picture with a thin crown of small light leaves: the summer leaves in clumps of
    2x2 pixels, about half of them, in light greens, with the branches showing through."""
    canvas = copy(bare)
    clumps = {}
    for y, row in enumerate(summer):
        for x, name in enumerate(row):
            if name not in _SUMMER_LEAVES:
                continue
            if clumps.setdefault((x // 2, y // 2), rng.random() < 0.5):
                canvas[y][x] = _YOUNG_LEAVES[name]
    return canvas


def remap(canvas, mapping):
    """A copy of a picture with colours replaced by name."""
    return [[mapping.get(name, name) for name in row] for row in canvas]


def ground_rows(look, rows, extra_remap=None):
    """Terrain or decoration rows (the layers bottom to top) in a look, with `extra_remap`
    applied over the look's own and the salt marsh's logical colours made real. Water stays as it
    is: freezing it belongs to the weather."""
    mapping = {**GROUND_REMAPS[look], **SALT_MARSH_LOOKS[look], **(extra_remap or {})}
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
            sheet = math.sin(x * 0.35 + phase) * math.sin(y * 0.3 - phase) > 0.45 and (x + y) % 2 == 0
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
    out; the rest is `ground_rows`. Under snow, the bare patches of trodden grass are footprints
    (see `_TRODDEN_SNOW`)."""
    if look == "dusting":
        snowy = ground_rows("snow", rows)
        return [snowy[0]] + [
            [dust(tile, random.Random(f"dust-{r}-{c}")) for c, tile in enumerate(row)]
            for r, row in enumerate(snowy[1:])
        ]
    result = ground_rows(look, rows, _TRODDEN_SNOW if look == "snow" else None)
    if look == "frost":
        for r, row in enumerate(result[1:]):
            for c, tile in enumerate(row):
                sparkle(tile, random.Random(f"rime-{r}-{c}"), 8)
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
    "green_dark": "reed", "green_deep": "umber",
}
_SNOW_REEDS = ({"sand_light", "straw", "reed"}, set(), 2)


# Evergreens and rocks in a frost: the greens go pale and bluish, as if rimed.
_FROST_CONIFER = {"green_light": "snow_shadow", "green": "green_light", "green_dark": "green"}
_FROST_PINE = {"meadow_light": "snow_shadow", "meadow": "meadow_light", "green_deep": "meadow"}
_FROST_BUSH = {"green_light": "snow_light", "green": "snow_shadow", "green_dark": "mud_dark", "green_bright": "snow_light"}
_FROST_FERN = {"green_bright": "snow_light", "green_light": "snow_light", "green": "straw", "green_dark": "reed", "green_deep": "umber"}
_FROST_STONE = {"green_light": "snow", "green": "snow_shadow", "olive": "snow_shadow"}


# The Knick: hazel (the green ramp), hawthorn (the meadow ramp) and the turf of its bank (dry
# greens) each turn on their own. Hawthorn flowers white in spring and bears red haws in autumn;
# in winter the hedge is twigs, thinned out where the summer leaves were darkest.
_KNICK_SPRING = {
    "green_bright": "spring_pale", "green_light": "spring_light", "green": "spring", "green_dark": "spring_dark",
    "meadow_light": "spring", "meadow": "spring_dark", "dry_light": "spring", "dry": "spring_dark",
    "olive": "green_dark",
}
_KNICK_AUTUMN = {
    "green_bright": "gold", "green_light": "ochre", "green": "ochre_dark", "green_dark": "umber",
    "meadow_light": "soil_light", "meadow": "soil_mid", "green_deep": "soil", "bog_dark": "russet_deep",
    "dry_light": "autumn_light", "dry": "reed",
}
_KNICK_TWIGS = {
    "green_bright": "mud", "green_light": "mud", "green": "mud_dark", "green_dark": None,
    "meadow_light": "soil_mid", "meadow": "soil", "green_deep": "soil_dark", "bog_dark": None,
    "dry_light": "bare_light", "dry": "bare", "olive": "mud_dark",
}
_KNICK_FROST = {"dry_light": "snow_shadow", "dry": "frost", "olive": "snow_deep"}
_KNICK_SNOW = ({"mud", "mud_dark", "soil_mid", "soil", "bare_light", "bare"}, set(), 3)
_KNICK_BLOSSOM = {"spring", "spring_dark"}
_KNICK_HAWS = {"soil_light", "soil_mid"}


# The pollard willow's silver-green leaves: fresh in spring, yellow in autumn. In winter it is
# drawn again, bare (see generate.py), with a little snow on its head (_WINTER_LOOKS).
# Its rods and the dark leaves low in the crown stay darker than the grass, so the crown sits on
# the head and not apart from it.
_WILLOW_SPRING = {"frost": "spring_pale", "dry_light": "spring_light", "dry": "spring"}
_WILLOW_AUTUMN = {"frost": "ochre", "dry_light": "ochre_dark", "dry": "reed", "olive": "umber", "green_dark": "umber"}


def _dot(canvas, rng, surfaces, count, colour):
    """Single pixels of `colour` (haws, blossom) on pixels of `surfaces`."""
    spots = [(x, y) for y, row in enumerate(canvas) for x, name in enumerate(row) if name in surfaces]
    for x, y in rng.sample(spots, min(count, len(spots))):
        canvas[y][x] = colour


# What winter does to each kind of object (the kinds of the object atlas), with these keys, all
# optional. The leafless art is the summer art with colours remapped:
# - "bare": the remap of every winter look;
# - "frost": a further remap in the frost and dusting looks, "frost_only" one in the frost look
#   alone (under a dusting, the snow caps stand in for it);
# - "specks": the colours that a frost rimes in specks;
# - "snow": (surfaces, edges, depth) of the snow caps that lie on it in the snow look, and one
#   pixel deep in the dusting look;
# - "snow_remap": a remap in place of the caps, in the snow look (a mound of snow, a bedroll).
# Planks lying flat (a jetty's deck, a boat's floor) under snow.
_SNOWED_PLANKS = {"bare_light": "snow_light", "bare": "snow", "mud_dark": "snow_shadow"}
_TRUNK_WINTER = {"frost_only": _FROST_STONE, "snow": _SNOW_TRUNK}
_WINTER_LOOKS = {
    "spruce": {"frost": _FROST_CONIFER, "snow": _SNOW_CONIFER},
    "pine": {"frost": _FROST_PINE, "snow": _SNOW_PINE},
    "dead_tree": {"snow": _SNOW_DEADWOOD},
    "berry_bush": {"bare": _BARE_BUSH, "frost": _FROST_BUSH, "snow_remap": _SNOW_MOUND},
    "shrub": {"bare": _BARE_BUSH, "frost": _FROST_BUSH, "snow": _SNOW_BUSH},
    "sapling": {"bare": _BARE_BUSH, "frost": _FROST_BUSH, "snow": _SNOW_BUSH},
    "fern": {"bare": _DRY_FERN, "frost": _FROST_FERN, "snow": ({"straw", "reed", "olive"}, set(), 1)},
    "tall_grass": {"bare": WINTER_STALKS | _DARK_FOOT, "frost": _FROST_STALKS | _DARK_FOOT},
    "reeds": {"bare": _GOLDEN_REEDS, "snow": _SNOW_REEDS},
    "stone": {"frost_only": _FROST_STONE, "snow": _SNOW_STONE},
    "boulder": {"frost_only": _FROST_STONE, "snow": _SNOW_BOULDER},
    "stump": {"frost_only": _FROST_STONE, "snow": _SNOW_STUMP},
    "dead_stump": {"frost_only": _FROST_STONE, "snow": _SNOW_DEAD_STUMP},
    "chest": {"frost_only": _FROST_STONE, "snow": _SNOW_CHEST},
    "carved_chest": {"frost_only": _FROST_STONE, "snow": ({"water_light", "foam", "paint_teal"}, set(), 3)},
    "kiln": {"frost_only": _FROST_STONE, "snow": ({"sand", "mud", "stone", "stone_light"}, set(), 2)},
    "oven": {"frost_only": _FROST_STONE, "snow": ({"rust", "red_light", "rust_dark"}, set(), 2)},
    "workbench": {"frost_only": _FROST_STONE, "snow": ({"sand_light", "sand"}, set(), 2)},
    # The Ewer: snow on its deck and on the furled sail, a frost rimes the deck in specks.
    "ewer": {"specks": {"bare_light", "bare"}, "snow": ({"bare_light", "bare", "umber", "rust_dark"}, set(), 2)},
    # Snow on the arms of a cross and the tops of the stones.
    "grave": {"frost_only": _FROST_STONE, "snow": ({"soil_light", "soil_mid", "sand_light", "sand", "stone_light", "stone"}, set(), 2)},
    # The landing: snow covers the jetty's deck and the boat's floor boards (a dusting only caps
    # them), and lies on the net frame's pole and on the traps.
    "jetty": {
        "specks": {"bare_light", "bare"},
        "snow": ({"bare_light", "bare", "mud_dark"}, set(), 1),
        "snow_remap": _SNOWED_PLANKS,
    },
    "rowing_boat": {
        "specks": {"bare_light", "bare"},
        "snow": ({"bare_light", "bare"}, set(), 1),
        "snow_remap": _SNOWED_PLANKS,
    },
    "net_frame": {"frost_only": _FROST_STONE, "snow": ({"soil_light", "umber"}, set(), 1)},
    "eel_traps": {"specks": {"sand_light", "sand"}, "snow": ({"sand_light", "sand"}, set(), 2)},
    "oak_trunk": _TRUNK_WINTER,
    "oak_short_trunk": _TRUNK_WINTER,
    "spruce_trunk": _TRUNK_WINTER,
    "spruce_short_trunk": _TRUNK_WINTER,
    "pine_trunk": _TRUNK_WINTER,
    "pine_short_trunk": _TRUNK_WINTER,
    "dead_tree_trunk": _TRUNK_WINTER,
    "dead_tree_short_trunk": _TRUNK_WINTER,
    "willow_trunk": _TRUNK_WINTER,
    "willow_short_trunk": _TRUNK_WINTER,
    "beech_trunk": _TRUNK_WINTER,
    "beech_short_trunk": _TRUNK_WINTER,
    "birch_trunk": _TRUNK_WINTER,
    "birch_short_trunk": _TRUNK_WINTER,
    "alder_trunk": _TRUNK_WINTER,
    "alder_short_trunk": _TRUNK_WINTER,
    # The bedroll: snow lies over the cloth, a frost rimes it in specks.
    "sleeping_bag": {
        "specks": {"sand_light", "stone_light"},
        "snow": ({"sand_light", "sand", "stone_light", "stone"}, set(), 1),
        "snow_remap": _SNOW_BEDROLL,
    },
    "fireplace": {},
    # The willow is drawn again for winter (see generate.py); a little snow lies on its head.
    "willow": {"snow": ({"sand", "mud"}, set(), 2)},
    "knick": {"bare": _KNICK_TWIGS, "frost": _KNICK_FROST, "specks": {"mud", "soil_mid"}, "snow": _KNICK_SNOW},
    "wattle_fence": {
        "frost_only": _FROST_STONE,
        "specks": {"sand_light", "sand"},
        "snow": ({"sand_light", "sand", "mud", "soil_light", "soil_mid"}, set(), 1),
    },
    # The dyke is turf and turns like the grass on the ground.
    "dyke": {
        "bare": _BARE_GROUND,
        "frost": _FROST_GROUND,
        "snow_remap": _WINTER_GROUND,
        "snow": ({"frost", "snow_shadow", "snow_light", "snow_deep"}, set(), 1),
    },
    "stone_wall": {
        "frost_only": _FROST_STONE,
        "snow": ({"stone_light", "stone", "sand_light", "bare_light", "bare", "olive"}, set(), 2),
    },
}


def _season_object(look, kind, variant, canvas, redraw):
    """One object cell in a look. `variant` is its column in the atlas row (picked bushes
    repeat their bush's variants)."""
    rng = random.Random(f"{look}-{kind}-{variant}")
    centre = len(canvas[0]) // 2
    if look in LEAF_OUT_LOOKS:
        if kind not in _LEAF_OUT_KINDS:
            # Everything else is as in spring meanwhile.
            return _season_object("spring", kind, variant, canvas, redraw)
        bare = _winter_object("bare", kind, variant, canvas, redraw, rng, centre)
        canvas = buds(bare, canvas, rng) if look == "buds" else young_leaves(bare, canvas, rng)
    elif look == "spring" and kind == "knick":
        canvas = remap(canvas, _KNICK_SPRING)
        _dot(canvas, rng, _KNICK_BLOSSOM, 12, "blossom")
    elif look == "autumn" and kind == "knick":
        canvas = remap(canvas, _KNICK_AUTUMN)
        _dot(canvas, rng, _KNICK_HAWS, 8, "red_light")
    elif look in ("spring", "autumn") and kind == "willow":
        canvas = remap(canvas, _WILLOW_SPRING if look == "spring" else _WILLOW_AUTUMN)
    elif look == "spring" and kind in _SPRING_KINDS:
        canvas = remap(canvas, _SPRING_GREENS)
        if kind in _BLOSSOM_KINDS:
            blossoms(canvas, rng, {"spring_light", "spring", "spring_pale"}, 7)
    elif look == "autumn":
        if kind == "oak":
            canvas = remap(canvas, _AUTUMN_OAK[variant])
        elif kind == "beech":
            canvas = remap(canvas, _COPPER)
        elif kind == "birch":
            canvas = remap(canvas, _YELLOW)
        elif kind == "alder":
            canvas = remap(canvas, _GREEN_BROWN)
        elif kind in ("berry_bush", "shrub", "sapling", "fern"):
            canvas = remap(canvas, _AUTUMN_BUSH[variant % 3])
        elif kind == "dyke":
            canvas = remap(canvas, _AUTUMN_GRASS)
        elif kind == "tall_grass":
            canvas = remap(canvas, _AUTUMN_GRASS | _DARK_FOOT)
        elif kind == "reeds":
            canvas = remap(canvas, _GOLDEN_REEDS)
    elif look in ("bare", "frost", "snow", "dusting"):
        canvas = _winter_object(look, kind, variant, canvas, redraw, rng, centre)
    return remap(canvas, {"shadow": _SHADOW_REMAPS[look]})


def _winter_object(look, kind, variant, canvas, redraw, rng, centre):
    """An object without leaves: bare, rimed with frost, under snow or under a dusting (frost
    with a thin snow cap)."""
    if kind in redraw:
        # A redrawn kind gets the frost and snow of _WINTER_LOOKS too, if it has an entry there.
        canvas = redraw[kind](variant)
        if kind not in _WINTER_LOOKS:
            return canvas
    elif kind not in _WINTER_LOOKS:
        raise KeyError(f"no winter look for the object kind {kind!r}: add it to seasons._WINTER_LOOKS")
    winter = _WINTER_LOOKS[kind]
    is_frosty = look in ("frost", "dusting")
    has_snow = look in ("snow", "dusting")
    if look == "snow" and "snow_remap" in winter:
        return remap(canvas, winter["snow_remap"])

    colours = dict(winter.get("bare", {}))
    if is_frosty:
        colours.update(winter.get("frost", {}))
    if look == "frost":
        colours.update(winter.get("frost_only", {}))
    # remap copies, so the specks and caps below never touch the summer art.
    canvas = remap(canvas, colours)
    if is_frosty:
        for row in canvas:
            for x, name in enumerate(row):
                if name in winter.get("specks", ()) and rng.random() < 0.15:
                    row[x] = "snow_light"
    if has_snow and "snow" in winter:
        surfaces, edges, depth = winter["snow"]
        # The chest's snow lies on its lid only.
        bottom = _chest_lid_bottom(canvas) if kind == "chest" else None
        snow_caps(canvas, rng, surfaces, edges, depth if look == "snow" else 1, centre, bottom)
    return canvas


def object_rows(look, atlas, redraw):
    """The object atlas rows in a look. `atlas` lists (kind, variants) per row; `redraw` maps a kind to a
    function that draws a variant from scratch where a remap is not enough (the bare oak)."""
    return [
        [_season_object(look, kind, variant, canvas, redraw) for variant, canvas in enumerate(row)]
        for kind, row in atlas
    ]


# The looks of a house (SeasonalArt.HOUSE_LOOKS in the game): the grass on a roof follows the
# season, and the roof is snowed over under snow.
HOUSE_LOOKS = ("spring", "summer", "autumn", "bare", "snow")
# The grass of a turf roof or ridge in the seasons: fresh in spring, yellowing to brown in
# autumn, brown-grey in winter, its flowers gone to seed. The dark grass at the foot of the
# clumps and the moss on a thatch stay green all year.
_ROOF_GRASS = {
    "spring": {"green_bright": "spring_pale", "green_light": "spring_light", "green": "spring"},
    "autumn": {
        "green_bright": "autumn_light", "green_light": "reed", "green": "olive", "dry_light": "straw",
        "cream": "straw", "gold": "ochre", "petal": "olive",
    },
    "bare": {
        "green_bright": "bare_light", "green_light": "bare", "green": "mud_dark", "dry_light": "bare_light",
        "cream": "bare_light", "gold": "bare", "petal": "mud_dark",
    },
}
# What each colour of a roof turns into under snow: the snow keeps the roof's light and shade.
_SNOW_ON_ROOF = {
    "sand": "snow_light", "bare_light": "snow_light", "bare": "snow", "mud_dark": "snow_shadow",
    "soil_dark": "snow_deep", "umber": "snow_shadow", "dry_light": "snow_light", "dry": "snow",
    "olive": "snow", "green_dark": "snow", "green_deep": "snow_shadow",
    "green_bright": "snow_light", "green_light": "snow_light", "green": "snow",
    "cream": "snow_light", "snow_light": "snow_light", "stone_light": "snow_light", "stone": "snow",
    "soil_mid": "snow", "soil": "snow_shadow",
    "rust": "snow_light", "rust_dark": "snow", "russet_deep": "snow_shadow",
}
# The colours of snow on a roof, lit to deep.
_SNOW_DEPTH = ("snow_light", "snow", "snow_shadow", "snow_deep")
# Rows of the eaves left showing under the snow: the dark underside of the rolled edge.
_EAVES_UNDER_SNOW = 3


def house(look, canvas, snowy):
    """A house picture in one of HOUSE_LOOKS: the grass on its roof in the season, or snow on
    its roof under snow. `snowy` are the pixels of the roof, which snow covers (see
    buildings.py); in each column the lowest rows of them, the underside of the eaves, stay
    clear, along a ragged edge. The snow fills the dents between the reeds of a thatch or the
    clumps of a turf roof, and most of the lines between its courses, so the roof's planes show
    through it but no stripes."""
    canvas = remap(canvas, {"shadow": _SHADOW_REMAPS[look]})
    grass = _ROOF_GRASS.get(look, {})
    for x, y in snowy:
        canvas[y][x] = grass.get(canvas[y][x], canvas[y][x])
    if look != "snow":
        return canvas
    rng = random.Random("house")
    columns = {}
    for x, y in snowy:
        columns.setdefault(x, []).append(y)
    edge = 0
    covered = set()
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
            covered.add((x, y))
        if keep:
            canvas[rows[len(rows) - keep - 1]][x] = "snow_shadow"
    dents = []
    for x, y in covered:
        if (x - 1, y) in covered and (x + 1, y) in covered:
            left, right = canvas[y][x - 1], canvas[y][x + 1]
            if left == right and _SNOW_DEPTH.index(left) < _SNOW_DEPTH.index(canvas[y][x]):
                dents.append((x, y, left))
    for x, y, colour in dents:
        canvas[y][x] = colour
    # It also smooths over the thin lines between the courses: a pixel unlike both its
    # neighbours above and below, which agree, takes their colour, except in a few short runs.
    lines = []
    kept = 0
    for y, x in sorted((y, x) for x, y in covered):
        if kept == 0 and rng.random() < 0.03:
            kept = rng.randint(3, 7)
        if kept:
            kept -= 1
            continue
        if (x, y - 1) in covered and (x, y + 1) in covered and canvas[y - 1][x] == canvas[y + 1][x]:
            lines.append((x, y, canvas[y - 1][x]))
    for x, y, colour in lines:
        canvas[y][x] = colour
    return canvas
