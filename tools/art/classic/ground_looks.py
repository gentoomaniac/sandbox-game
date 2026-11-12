"""The looks of the ground (terrain and decorations) of seasons.py as they were made for the classic
16 px ground (commit acf236e): its colour remaps and `terrain_rows` and `ground_rows`, unchanged."""

import math
import random

from seasons import AUTUMN_GROUND, BARE_GROUND

# The looks of grass and ground, which every picture has.
GROUND_LOOKS = ("spring", "summer", "autumn", "bare", "frost", "snow", "dusting")

_SPRING_GREENS = {
    "green_bright": "spring_pale",
    "green_light": "spring_light",
    "green": "spring",
    "green_dark": "spring_dark",
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
    "autumn": AUTUMN_GROUND,
    "bare": BARE_GROUND,
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
                sparkle(tile, random.Random(f"rime-{r}-{c}"), 3)
    return result
