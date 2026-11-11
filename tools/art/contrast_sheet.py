"""A contrast sheet: plants over the ground of every look, to check by eye that they stand out.

Reads the generated assets (run `make assets` first) and writes build/contrast_sheet.png: one
block per look (each season, frost, snow, and the summer art under the night tint), one row per
kind of ground (grass, lush grass, dry grass, floodplain), and the first variants of the chosen
atlas rows side by side on it. Run it as `make contrast-sheet`, or
`.venv/bin/python tools/art/contrast_sheet.py [atlas row names ...]` (default: the tall grass,
the fern and the reeds).
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

from canvas import GAME_OBJECT_CELL_HEIGHT, GAME_OBJECT_CELL_WIDTH, GAME_TILE
from palette import ASSETS
from seasons import GROUND_LOOKS

OUTPUT = Path(__file__).resolve().parents[2] / "build" / "contrast_sheet.png"
DEFAULT_KINDS = ("tall_grass", "fern", "reeds")
VARIANTS = 3
# The assets are in the game's pixels. The sheet shows them as a 1080p screen does.
CELL_WIDTH = GAME_OBJECT_CELL_WIDTH
CELL_HEIGHT = GAME_OBJECT_CELL_HEIGHT
SCALE = 3
GAP = 4
LABEL_HEIGHT = 12
# The rows of assets/terrain.png (terrain.LAYERS) that plants stand on.
GROUNDS = {"grass": 4, "lush_grass": 7, "dry_grass": 8, "floodplain": 2}
# Where the full tiles start in a terrain row: after the edge shapes (terrain.EDGE_VARIANTS
# variants of each of the 15 masks).
FULL_TILE_COLUMN = 45
# The game's night tint (data/lighting.cfg [day_and_night] night), which multiplies every colour.
NIGHT_TINT = (0.13, 0.16, 0.3)
# Without the dusting: it is only the edge of the snow. Night is the summer look, tinted.
LOOKS = tuple(look for look in GROUND_LOOKS if look != "dusting") + ("night",)


def look_file(name, look):
    """The generated PNG of an atlas for a look: summer has the plain name."""
    suffix = "" if look in ("summer", "night") else f"_{look}"
    return Image.open(ASSETS / f"{name}{suffix}.png").convert("RGBA")


def atlas_rows():
    """The atlas row of each kind, from assets/objects_rows.txt."""
    lines = (line.split() for line in (ASSETS / "objects_rows.txt").read_text().splitlines())
    return {kind: int(row) for row, kind, _ in lines}


def ground_tile(terrain, ground):
    left, top = FULL_TILE_COLUMN * GAME_TILE, GROUNDS[ground] * GAME_TILE
    return terrain.crop((left, top, left + GAME_TILE, top + GAME_TILE))


def drawn_height(cells):
    """How many rows from the cells' bottom reach the highest drawn pixel in any of them, so
    the sheet leaves out the empty top of the tall cells."""
    top = min(cell.getchannel("A").getbbox()[1] for cell in cells)
    return CELL_HEIGHT - top + 2


def look_block(look, kinds, rows):
    """One look: a strip of every ground with the plants on it, scaled up."""
    objects = look_file("objects", look)
    terrain = look_file("terrain", look)
    cells = []
    for kind in kinds:
        top = rows[kind] * CELL_HEIGHT
        for variant in range(VARIANTS):
            left = variant * CELL_WIDTH
            cells.append(objects.crop((left, top, left + CELL_WIDTH, top + CELL_HEIGHT)))
    height = drawn_height(cells)
    width = CELL_WIDTH * len(cells)
    block = Image.new("RGBA", (width, height * len(GROUNDS)))
    for row, ground in enumerate(GROUNDS):
        tile = ground_tile(terrain, ground)
        for x in range(0, width, GAME_TILE):
            for y in range(0, height, GAME_TILE):
                block.paste(tile, (x, row * height + y))
        for column, cell in enumerate(cells):
            bottom = cell.crop((0, CELL_HEIGHT - height, CELL_WIDTH, CELL_HEIGHT))
            block.alpha_composite(bottom, (column * CELL_WIDTH, row * height))
    if look == "night":
        *colours, alpha = block.split()
        tinted = [channel.point(lambda value, tint=tint: round(value * tint)) for channel, tint in zip(colours, NIGHT_TINT)]
        block = Image.merge("RGBA", (*tinted, alpha))
    return block.resize((block.width * SCALE, block.height * SCALE), Image.NEAREST)


def main():
    kinds = tuple(sys.argv[1:]) or DEFAULT_KINDS
    rows = atlas_rows()
    blocks = [look_block(look, kinds, rows) for look in LOOKS]
    height = sum(block.height + LABEL_HEIGHT + GAP for block in blocks)
    sheet = Image.new("RGBA", (blocks[0].width, height), "#1d1b26")
    draw = ImageDraw.Draw(sheet)
    y = 0
    for look, block in zip(LOOKS, blocks):
        draw.text((2, y), look, fill="white")
        sheet.paste(block, (0, y + LABEL_HEIGHT))
        y += block.height + LABEL_HEIGHT + GAP
    OUTPUT.parent.mkdir(exist_ok=True)
    sheet.save(OUTPUT)
    print(f"Wrote {OUTPUT.relative_to(OUTPUT.parents[1])}")


if __name__ == "__main__":
    main()
