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

import alder  # noqa: E402
import animals  # noqa: E402
import beech  # noqa: E402
import birch  # noqa: E402
import birds  # noqa: E402
import boundaries  # noqa: E402
import bubbles  # noqa: E402
import buildings  # noqa: E402
import camp  # noqa: E402
import character  # noqa: E402
import chest  # noqa: E402
import church  # noqa: E402
import coast  # noqa: E402
import crafts  # noqa: E402
import craft_icons  # noqa: E402
import crop_icons  # noqa: E402
import crops  # noqa: E402
import fire  # noqa: E402
import flowers  # noqa: E402
import graves  # noqa: E402
import ground_looks  # noqa: E402
import ground_overlays  # noqa: E402
import interior  # noqa: E402
import item_icons  # noqa: E402
import landing  # noqa: E402
import livestock  # noqa: E402
import meadow  # noqa: E402
import object_looks  # noqa: E402
import reeds  # noqa: E402
import sea_birds  # noqa: E402
import seasons  # noqa: E402
import terrain  # noqa: E402
import tool_icons  # noqa: E402
import portraits  # noqa: E402
import trees  # noqa: E402
import trunks  # noqa: E402
import villagers  # noqa: E402
import willow  # noqa: E402
from canvas import GAME_TILE, OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, TILE, blank  # noqa: E402
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
    "wildlife/tern.png",
    "fire/*.png",
    # The ground (task 107; terrain.py, the ground looks of seasons.py, crop_icons.soil_wet and
    # meadow.clay_hint of commit acf236e; the meadow flowers of its decorations are flowers.py of
    # commit e303759).
    "terrain*.png",
    "decorations*.png",
    "soil_wet.png",
    "clay_hint.png",
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
    # The small wild animals drawn larger than life at 32 px.
    "wildlife/bird.png": ((16, 16), (22, 18)),
    "wildlife/rabbit.png": ((24, 20), (26, 22)),
    "wildlife/bee.png": ((8, 8), (10, 10)),
    "wildlife/butterfly.png": ((12, 12), (14, 14)),
    "wildlife/firefly.png": ((3, 3), (6, 6)),
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


def write_buildings():
    for name, draw in (buildings.PICTURES | church.PICTURES).items():
        for lit_suffix, is_lit in (("", False), ("_lit", True)):
            picture, snowy = draw(is_lit=is_lit)
            for look in seasons.HOUSE_LOOKS:
                look_suffix = "" if look == "summer" else f"_{look}"
                save_picture(seasons.house(look, picture, snowy), f"{CLASSIC}/buildings/{name}{lit_suffix}{look_suffix}.png")


def standing_outdoors(picture):
    """A picture that stands on the ground (the chest, a station) in its cell of the object atlas,
    on a ground shadow, its bottom a pixel above the cell's."""
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    trees.ground_shadow(canvas, 8)
    top = OBJECT_BOTTOM - len(picture)
    for y, row in enumerate(picture):
        for x, name in enumerate(row):
            if name is not None:
                canvas[top + y][OBJECT_CENTRE - len(row) // 2 + x] = name
    return canvas


def object_atlas():
    """The rows of assets/objects.png in order, each as (kind, its variants), as
    tools/art/generate.py draws them (see the numbered table there)."""
    spruces, pines, dead_trees, berry_bushes, shrubs, saplings, ferns = trees.vegetation()
    return [
        ("oak", [trees.oak(seed) for seed in trees.OAK_SEEDS]),
        ("stone", [trees.stone(seed) for seed in (111, 112)]),
        ("fireplace", [camp.fireplace()]),
        ("sleeping_bag", [camp.bedroll()]),
        ("spruce", spruces),
        ("pine", pines),
        ("dead_tree", dead_trees),
        ("berry_bush", berry_bushes),
        ("shrub", shrubs),
        ("sapling", saplings),
        ("fern", ferns),
        ("boulder", [trees.boulder(seed) for seed in (191, 192)]),
        ("stump", [trees.stump(seed) for seed in (201, 202)]),
        ("tall_grass", meadow.tall_grass_row()),
        *trunks.rows("oak"),
        *trunks.rows("spruce"),
        *trunks.rows("pine"),
        *trunks.rows("dead_tree"),
        *trunks.rows("willow"),
        ("reeds", reeds.reeds_row()),
        ("dead_stump", [trees.dead_stump(seed) for seed in (211, 212)]),
        ("chest", [standing_outdoors(chest.chest())]),
        ("knick", boundaries.knick_row()),
        ("wattle_fence", boundaries.wattle_fence_row()),
        ("stone_wall", boundaries.stone_wall_row()),
        ("dyke", boundaries.dyke_row()),
        ("willow", willow.willow_row()),
        ("beech", beech.beech_row()),
        *trunks.rows("beech"),
        ("birch", birch.birch_row()),
        *trunks.rows("birch"),
        ("alder", alder.alder_row()),
        *trunks.rows("alder"),
        ("workbench", [standing_outdoors(crafts.workbench())]),
        ("carved_chest", [standing_outdoors(crafts.carved_chest())]),
        ("kiln", [standing_outdoors(crafts.kiln())]),
        ("oven", [standing_outdoors(crafts.oven())]),
        # The new Ewer's picture is three cells wide: the classic one lies in the middle one.
        ("ewer", [blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT), *coast.ewer_row(), blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)]),
        ("grave", [standing_outdoors(picture) for picture in graves.graves()]),
        ("jetty", landing.jetty_row()),
        ("rowing_boat", landing.rowing_boat_row()),
        ("net_frame", landing.net_frame_row()),
        ("eel_traps", landing.eel_traps_row()),
    ]


def write_objects():
    """The object atlas in every look, the bare trees drawn anew for winter."""
    objects = object_atlas()
    redraws = {
        "oak": lambda variant: trees.bare_oak(trees.OAK_SEEDS[variant]),
        "willow": lambda variant: willow.bare_willow(willow.WILLOW_SEEDS[variant]),
        "beech": lambda variant: beech.bare_beech(beech.BEECH_SEEDS[variant]),
        "birch": lambda variant: birch.bare_birch(birch.BIRCH_SEEDS[variant]),
        "alder": lambda variant: alder.bare_alder(alder.ALDER_SEEDS[variant]),
    }
    for look in object_looks.LOOKS:
        suffix = "" if look == "summer" else f"_{look}"
        rows = object_looks.object_rows(look, objects, redraws)
        save(rows, f"{CLASSIC}/objects{suffix}.png", OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    save_picture(camp.bedroll_cover(), f"{CLASSIC}/bedroll_cover.png")


def write_crops():
    for crop, cells in crops.sheets().items():
        save([cells], f"{CLASSIC}/crops/{crop}.png", TILE, len(cells[0]))


def write_interior():
    furniture = interior.furniture()
    save([interior.atlas_tiles(furniture)], f"{CLASSIC}/interior.png")
    for name, (picture, _footprint) in furniture.items():
        save_picture(picture, f"{CLASSIC}/interior/{name}.png")
    for name, picture in interior.covers(furniture).items():
        save_picture(picture, f"{CLASSIC}/interior/{name}.png")
    for name, picture in crafts.stations().items():
        save_picture(picture, f"{CLASSIC}/interior/{name}.png")
    save_picture(camp.ghost(camp.fireplace(), 25, 26), f"{CLASSIC}/interior/fireplace.png")
    save_picture(camp.ghost(camp.bedroll(), 18, 30), f"{CLASSIC}/interior/sleeping_bag.png")
    save_picture(graves.graves()[0], f"{CLASSIC}/interior/grave.png")


def write_items():
    icons = item_icons.ICONS | crop_icons.icons() | tool_icons.icons() | craft_icons.icons()
    for name, picture in icons.items():
        save_picture(picture, f"{CLASSIC}/items/{name}.png")
        # The same icon at half size, for items lying on the ground.
        save_picture(item_icons.small(picture), f"{CLASSIC}/ground_items/{name}.png")


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
    write_buildings()
    write_objects()
    write_crops()
    write_interior()
    write_items()
    scale_up_16_px_art()
    set_in_grown_cells()
    print("Wrote every file under assets/classic/.")


if __name__ == "__main__":
    main()
