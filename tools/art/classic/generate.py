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

import bubbles  # noqa: E402
import character  # noqa: E402
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
)


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
    scale_up_16_px_art()
    print("Wrote every file under assets/classic/.")


if __name__ == "__main__":
    main()
