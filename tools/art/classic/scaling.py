"""How the classic art's files become the sizes the game reads (run by pack.py, `make assets`).

The classic generators write the 16 px art as it was drawn, under art/generated/classic/. Of
those files, DOUBLED are scaled up to the game's tile pixel for pixel, and the sheets of
GROWN_CELLS are set in the larger cells their animals have at 32 px. Hand-drawn classic art
(`_16x16` files, see tools/README.md) is drawn at 16 px and goes through the same steps.
"""

from fnmatch import fnmatchcase

from canvas import GAME_TILE, TILE
from PIL import Image

# The files of the classic art that were drawn at 16 px per tile and doubled, as DOUBLED in
# tools/art/generate.py; the portraits are drawn for the UI and are not.
DOUBLED = (
    # The player and the villagers (task 113; the generators of commit 97e9736).
    "character/*.png",
    "character/collapse/*.png",
    "character/riding/*.png",
    "effects/*.png",
    "ui/bubble_*.png",
    # The farm animals (task 114; livestock.py and animals.py of commit 2793065).
    "wildlife/cow_*.png",
    "wildlife/sheep_*.png",
    "wildlife/chicken_*.png",
    "wildlife/rabbit_*.png",
    "wildlife/dog_*.png",
    "wildlife/cat_*.png",
    "wildlife/horse_*.png",
    # The pigs (task 165).
    "wildlife/pig_*.png",
    # The wild animals and the flames (task 116; animals.py, birds.py, sea_birds.py and fire.py
    # of commit 2793065; the fireplace around its flames is the classic camp.py, the hearth the
    # classic interior.py).
    "wildlife/bee.png",
    "wildlife/bird.png",
    "wildlife/butterfly.png",
    "wildlife/deer.png",
    "wildlife/dunlin.png",
    "wildlife/firefly.png",
    "wildlife/frog.png",
    "wildlife/goose.png",
    "wildlife/gull.png",
    "wildlife/mouse.png",
    "wildlife/oystercatcher.png",
    "wildlife/rabbit.png",
    "wildlife/squirrel.png",
    "wildlife/stork.png",
    # The stork nest and its young (task 152; stork_nest.py).
    "wildlife/stork_chick.png",
    "wildlife/stork_nest.png",
    "wildlife/tern.png",
    "fire/*.png",
    # The ground (task 107; terrain.py, the ground looks of seasons.py, crop_icons.soil_wet and
    # meadow.clay_hint of commit acf236e; the meadow flowers of its decorations are flowers.py of
    # commit e303759).
    "terrain*.png",
    "decorations*.png",
    "soil_wet.png",
    "soil_edge.png",
    "clay_hint.png",
    # The textures of the seasonal overlays (task 185; cover.py), drawn per 16 px art pixel.
    "cover/*.png",
    # The buildings (task 110; buildings.py and church.py of commit e303759, their looks drawn by
    # the shared seasons.house).
    "buildings/*.png",
    # The plants (task 108; trees.py, trunks.py, beech.py, birch.py, alder.py, willow.py, the
    # plant parts of meadow.py and reeds.py and the object looks of seasons.py of commit
    # e303759), and the other rows of the atlas (task 111): the walls, fences and the dyke
    # (boundaries.py), the camp (camp.py), the chest (chest.py), the stations (crafts.py), the
    # Ewer (coast.py), the landing (landing.py) of commit ec0b1af and the graves (graves.py).
    "objects*.png",
    # The crops (task 109; crops.py of commit f2c24f8).
    "crops/*.png",
    # The bedroll's cover, which matches the classic bedroll (camp.py of commit ec0b1af, before
    # task 112 made the bedroll longer).
    "bedroll_cover.png",
    # The interiors and their furniture (task 112; interior.py of commit f2c24f8), with the
    # chest of chest.py, and the stations and the grave marker placed indoors (task 111).
    "interior.png",
    "interior/*.png",
    # The items lying on the ground (task 115; items.py, tool_icons.py and crop_icons.py of
    # commit 91742f0, and the icon parts of meadow.py, reeds.py, crafts.py, church.py and
    # landing.py). The item icons are drawn for the UI and are not doubled.
    "ground_items/*.png",
)
# The animals whose cells grew at 32 px per tile: the classic sheets, doubled, are set in
# the new cells (bottom centre, as the animal stands in its cell), so that the game reads both
# sets with the same frame sizes (WildlifeSprites). Their old and new cell sizes.
GROWN_CELLS = {
    "wildlife/cow_*.png": ((64, 48), (72, 54)),
    "wildlife/horse_*.png": ((88, 72), (88, 76)),
    # The rooster, a head taller than his hens at 32 px (livestock.ROOSTER_SIZE).
    "wildlife/chicken_rooster.png": ((24, 24), (34, 32)),
    # The small wild animals drawn larger than life at 32 px.
    "wildlife/bird.png": ((16, 16), (22, 18)),
    "wildlife/rabbit.png": ((24, 20), (26, 22)),
    "wildlife/bee.png": ((8, 8), (10, 10)),
    "wildlife/butterfly.png": ((12, 12), (14, 14)),
    "wildlife/firefly.png": ((3, 3), (6, 6)),
    "wildlife/dunlin.png": ((20, 16), (22, 16)),
}


def _matches(relative_path, pattern):
    """Whether the path fits the glob pattern, whose `*` stays inside a folder."""
    names, patterns = relative_path.split("/"), pattern.split("/")
    return len(names) == len(patterns) and all(fnmatchcase(name, glob) for name, glob in zip(names, patterns))


def classic_size(relative_path, image):
    """`image`, the classic file `relative_path` (under classic/) as drawn, as the game reads it."""
    if any(_matches(relative_path, pattern) for pattern in DOUBLED):
        factor = GAME_TILE // TILE
        image = image.resize((image.width * factor, image.height * factor), Image.Resampling.NEAREST)
    for pattern, (cell_size, new_cell_size) in GROWN_CELLS.items():
        if _matches(relative_path, pattern):
            image = set_in_grown_cells(image, cell_size, new_cell_size)
    return image


def set_in_grown_cells(sheet, cell_size, new_cell_size):
    """The cells of `sheet`, each in the bottom centre of a cell of the new size."""
    (width, height), (new_width, new_height) = cell_size, new_cell_size
    columns, rows = sheet.width // width, sheet.height // height
    grown = Image.new("RGBA", (columns * new_width, rows * new_height), (0, 0, 0, 0))
    for row in range(rows):
        for column in range(columns):
            cell = sheet.crop((column * width, row * height, (column + 1) * width, (row + 1) * height))
            left = column * new_width + (new_width - width) // 2
            grown.paste(cell, (left, row * new_height + new_height - height))
    return grown
