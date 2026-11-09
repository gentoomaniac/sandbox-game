"""The palette: every colour of the game's art, by name.

Pictures hold colour names, never RGB values, so this file and `seasons.COLOURS` are the only
source of colours. `to_image` turns pictures into PNGs, and `check_palette` fails if any PNG
under art/generated/ strays from the palette.
"""

import math
from pathlib import Path

from PIL import Image

import seasons
from canvas import TILE

ROOT = Path(__file__).resolve().parents[2]
# What the generators write (`make art`) and what `make assets` builds for Godot out of it and out
# of the hand-drawn art in art/hand/ (see pack.py).
GENERATED = ROOT / "art" / "generated"
# What artists drop in, with the paths of the generated files and a postfix (see pack.py).
HAND = ROOT / "art" / "hand"
ASSETS = ROOT / "assets"
# The sheets saved by this process, by their path under GENERATED: their cell size, which
# `write_cell_sizes` records so that pack.py can fill the empty cells of a hand-drawn sheet.
CELL_SIZES = {}
CELL_SIZES_FILE = "cell_sizes.txt"

# The darkest colour of each ramp, which outlines it (see the style rules in design/presentation/art-pipeline.md).
DARKEST_OF = {
    "soil": "soil_dark",
    "soil_mid": "soil_dark",
    "soil_light": "soil_dark",
    "stone": "stone_dark",
    "stone_light": "stone_dark",
    "sand": "mud_dark",
    "sand_light": "mud_dark",
    "straw": "mud_dark",
    "mud": "mud_dark",
}
# What anything else is outlined in.
DEFAULT_OUTLINE = "ink"

# fmt: off
BASE_COLOURS = {
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
    # Dry grass, straw, reeds.
    "dry":            "68743e",
    "dry_light":      "8a9250",
    "reed":           "807a40",
    "straw":          "b0a05e",
    # Damp floodplain meadow, also the Scots pine's needles.
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
    # Lime-wash, chalky and slightly warm, and the teal paint of doors and shutters.
    "lime":           "e8e4d8",
    "paint_teal":     "3f7f86",
    # Heather on the Geest, and hand-dyed cloth.
    "heather":        "8c5c86",
    "heather_dark":   "5a3a5c",
    # Kept for magic only: spirits, wisps, spells.
    "arcane":         "6f4c91",
    "spirit":         "4e9e9b",
}
# fmt: on
PALETTE = dict(BASE_COLOURS)
for name, hex_colour in seasons.COLOURS.items():
    assert name not in PALETTE, f"colour {name} is in both palette.py and seasons.COLOURS"
    PALETTE[name] = hex_colour
MAX_PALETTE_COLOURS = 64


def darkest_of(colour):
    """The outline colour of a pixel of `colour`: the darkest of its ramp, or ink."""
    return DARKEST_OF.get(colour, DEFAULT_OUTLINE)


def rgba(name, asset):
    """The palette colour `name` as an RGBA tuple. `asset` is what is being drawn, for the error."""
    if name not in PALETTE:
        raise KeyError(f"unknown colour {name!r} in {asset}")
    return (*bytes.fromhex(PALETTE[name]), 255)


def to_image(rows, size=TILE, height=None, *, asset):
    """Lays out rows of tiles as one image. Tiles are size wide and `height` high (default
    size); a tile with fewer rows of pixels sits at the bottom of its cell. `asset` names what
    is drawn, for the error of an unknown colour."""
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
                        pixels[column * size + x, row_index * height + top + y] = rgba(name, asset)
    return image


def save(rows, relative_path, size=TILE, height=None):
    """Draws rows of tiles (see `to_image`) into `relative_path` under art/generated/, making
    its directories."""
    path = GENERATED / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    to_image(rows, size, height, asset=relative_path).save(path)
    if len(rows) > 1 or len(rows[0]) > 1:
        CELL_SIZES[relative_path] = (size, height or size)


def save_picture(picture, relative_path):
    """Saves one picture of any size as a PNG of its own."""
    save([[picture]], relative_path, len(picture[0]), len(picture))


def write_cell_sizes(folder):
    """`cell_sizes.txt` in `folder` (under GENERATED): `path width height` of every sheet saved so
    far, for the files in `folder`."""
    lines = [f"{path} {width} {height}" for path, (width, height) in sorted(CELL_SIZES.items())]
    (folder / CELL_SIZES_FILE).write_text("\n".join(lines) + "\n")


def write_palette():
    swatch = 8
    per_row = 8
    names = list(PALETTE)
    rows = math.ceil(len(names) / per_row)
    image = Image.new("RGBA", (per_row * swatch, rows * swatch), (0, 0, 0, 0))
    for index, name in enumerate(names):
        x, y = index % per_row * swatch, index // per_row * swatch
        image.paste((*bytes.fromhex(PALETTE[name]), 255), (x, y, x + swatch, y + swatch))
    image.save(GENERATED / "palette.png")

    lines = ["GIMP Palette", "Name: Sandbox Game", f"Columns: {per_row}", "#"]
    for name, hex_colour in PALETTE.items():
        r, g, b = bytes.fromhex(hex_colour)
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    (GENERATED / "palette.gpl").write_text("\n".join(lines) + "\n")


def stray_colours(image):
    """The visible colours of `image` that are not in the palette."""
    allowed = {(*bytes.fromhex(hex_colour), 255) for hex_colour in PALETTE.values()}
    colours = {colour for _, colour in image.convert("RGBA").getcolors(1 << 24)}
    return {colour for colour in colours if colour[3] != 0 and colour not in allowed}


def check_palette():
    """Fails if any PNG under art/generated/ has a pixel that is neither transparent nor a
    palette colour (hand-drawn art is only warned about, see pack.py)."""
    assert len(PALETTE) <= MAX_PALETTE_COLOURS, f"{len(PALETTE)} palette colours, at most {MAX_PALETTE_COLOURS}"
    bad = []
    for path in sorted(GENERATED.rglob("*.png")):
        stray = stray_colours(Image.open(path))
        if stray:
            bad.append(f"{path.relative_to(GENERATED)}: {len(stray)} colours not in the palette")
    if bad:
        raise SystemExit("Palette check failed:\n" + "\n".join(bad))

