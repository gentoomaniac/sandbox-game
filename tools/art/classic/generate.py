"""The classic art: the art of the groups that are drawn at 32 px per tile now, as it was drawn at
16 px per tile, for the game's art setting (see game/scenes/art_set.gd).

The modules here are the old generators of those groups, copied from git history unchanged (the
commit is in each group's comment below); they share canvas.py and palette.py with the new art.
`main` writes their files under assets/classic/, under the names the new art has under assets/,
and scales the world's up to the game's tile as tools/art/generate.py did then. The game shows a
classic file where there is one and the new file where there is none.

An art group that goes native moves its old generator here (see tools/README.md).
"""

import sys
from pathlib import Path

# The old modules here come first, the new art's shared basics (canvas, palette) after them.
sys.path.append(str(Path(__file__).resolve().parents[1]))

import animals  # noqa: E402
import birds  # noqa: E402
import bubbles  # noqa: E402
import camp  # noqa: E402
import character  # noqa: E402
import fire  # noqa: E402
import flowers  # noqa: E402
import ground_looks  # noqa: E402
import ground_overlays  # noqa: E402
import interior  # noqa: E402
import livestock  # noqa: E402
import sea_birds  # noqa: E402
import terrain  # noqa: E402
import portraits  # noqa: E402
import villagers  # noqa: E402
from canvas import GAME_TILE, TILE  # noqa: E402
from palette import ASSETS, PALETTE, save, save_picture  # noqa: E402
from PIL import Image  # noqa: E402

CLASSIC = "classic"

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
    # The wild animals and the flames (task 116; animals.py, birds.py, sea_birds.py and fire.py
    # of commit 2793065; the fireplace and the hearth around the flames are the shared camp.py
    # and interior.py, still drawn at 16 px).
    "wildlife/bee.png",
    "wildlife/bird.png",
    "wildlife/butterfly.png",
    "wildlife/deer.png",
    "wildlife/dunlin.png",
    "wildlife/frog.png",
    "wildlife/goose.png",
    "wildlife/gull.png",
    "wildlife/mouse.png",
    "wildlife/oystercatcher.png",
    "wildlife/rabbit.png",
    "wildlife/squirrel.png",
    "wildlife/stork.png",
    "wildlife/tern.png",
    "fire/*.png",
    # The ground (task 107; terrain.py, the ground looks of seasons.py, crop_icons.soil_wet and
    # meadow.clay_hint of commit acf236e; the meadow flowers of its decorations are the shared
    # flowers.py, still drawn at 16 px).
    "terrain*.png",
    "decorations*.png",
    "soil_wet.png",
    "clay_hint.png",
)
# The animals whose cells grew at 32 px per tile: the classic sheets, doubled, are set in
# the new cells (bottom centre, as the animal stands in its cell), so that the game reads both
# sets with the same frame sizes (WildlifeSprites). Their old and new cell sizes.
GROWN_CELLS = {
    "wildlife/cow_*.png": ((64, 48), (72, 54)),
    "wildlife/horse_*.png": ((88, 72), (88, 76)),
    # The small wild animals drawn larger than life at 32 px.
    "wildlife/bird.png": ((16, 16), (22, 18)),
    "wildlife/rabbit.png": ((24, 20), (26, 22)),
    "wildlife/bee.png": ((8, 8), (10, 10)),
    "wildlife/butterfly.png": ((12, 12), (14, 14)),
    "wildlife/dunlin.png": ((20, 16), (22, 16)),
}


def write_character():
    layers = character.layers() | villagers.layers()
    for name, layer in layers.items():
        save(character.character_sheet(*layer), f"{CLASSIC}/character/{name}.png", character.CHARACTER_WIDTH, character.CHARACTER_HEIGHT)
        save(character.collapse_sheet(*layer), f"{CLASSIC}/character/collapse/{name}.png", character.COLLAPSE_SIZE)
    for name, picture in portraits.portraits(layers).items():
        save_picture(picture, f"{CLASSIC}/character/portrait/{name}.png")
    # Only the player rides, so only the player's layers sit on a horse.
    for name, layer in character.layers().items():
        save(character.riding_sheet(*layer), f"{CLASSIC}/character/riding/{name}.png", character.CHARACTER_WIDTH, character.CHARACTER_HEIGHT)
    held_hoe = character.character_sheet(character.draw_held_hoe, {})
    save(held_hoe, f"{CLASSIC}/character/held_hoe.png", character.CHARACTER_WIDTH, character.CHARACTER_HEIGHT)
    save_picture(character.sleep_z(), f"{CLASSIC}/effects/sleep_z.png")


def write_bubbles():
    (ASSETS / CLASSIC / "ui").mkdir(parents=True, exist_ok=True)
    for name, rows in bubbles.BUBBLE_ICONS.items():
        bubbles.bubble(PALETTE, rows).save(ASSETS / CLASSIC / "ui" / f"bubble_{name}.png")


def write_livestock():
    for name, size, rows in livestock.sheets():
        save(rows, f"{CLASSIC}/wildlife/{name}.png", *size)


def write_wildlife():
    for kind in animals.SHEETS:
        save(animals.sheet_rows(kind), f"{CLASSIC}/wildlife/{kind}.png", *animals.cell_size(kind))
    for name, size, rows in [*birds.sheets(), *sea_birds.sheets()]:
        save(rows, f"{CLASSIC}/wildlife/{name}.png", *size)


def write_fire():
    for name, (behind, front), (box, half_width, tall) in (
        ("fireplace", camp.fireplace_layers(), camp.FIREPLACE_FLAME),
        ("hearth", interior.hearth_layers(), interior.HEARTH_FLAME),
    ):
        strip = fire.strip(behind, front, box, half_width, tall)
        save([strip], f"{CLASSIC}/fire/{name}.png", box[2], box[3])


def write_ground():
    terrain_rows = []
    decoration_rows = []
    for layer in terrain.LAYERS:
        tiles, decorations = layer()
        terrain_rows.append(tiles)
        decoration_rows.append(decorations)
    decoration_rows.append(flowers.flower_row())
    for look in ground_looks.GROUND_LOOKS:
        suffix = "" if look == "summer" else f"_{look}"
        save(ground_looks.terrain_rows(look, terrain_rows), f"{CLASSIC}/terrain{suffix}.png")
        decorations = ground_looks.ground_rows(look, decoration_rows, ground_looks.STANDING.get(look))
        save(decorations, f"{CLASSIC}/decorations{suffix}.png")
    save([ground_overlays.soil_wet()], f"{CLASSIC}/soil_wet.png")
    save_picture(ground_overlays.clay_hint(), f"{CLASSIC}/clay_hint.png")


def set_in_grown_cells():
    """Sets each cell of the sheets of GROWN_CELLS in the bottom centre of a cell of the new size."""
    for pattern, ((width, height), (new_width, new_height)) in GROWN_CELLS.items():
        for path in sorted((ASSETS / CLASSIC).glob(pattern)):
            sheet = Image.open(path)
            columns, rows = sheet.width // width, sheet.height // height
            grown = Image.new("RGBA", (columns * new_width, rows * new_height), (0, 0, 0, 0))
            for row in range(rows):
                for column in range(columns):
                    cell = sheet.crop((column * width, row * height, (column + 1) * width, (row + 1) * height))
                    left = column * new_width + (new_width - width) // 2
                    grown.paste(cell, (left, row * new_height + new_height - height))
            grown.save(path)


def scale_up_16_px_art():
    """Scales the files of DOUBLED up from the art's tile to the game's, pixel for pixel."""
    factor = GAME_TILE // TILE
    for pattern in DOUBLED:
        paths = sorted((ASSETS / CLASSIC).glob(pattern))
        assert paths, f"DOUBLED: no file matches {CLASSIC}/{pattern}"
        for path in paths:
            image = Image.open(path)
            image.resize((image.width * factor, image.height * factor), Image.Resampling.NEAREST).save(path)


def main():
    write_character()
    write_bubbles()
    write_livestock()
    write_wildlife()
    write_fire()
    write_ground()
    scale_up_16_px_art()
    set_in_grown_cells()
    print("Wrote every file under assets/classic/.")


if __name__ == "__main__":
    main()
