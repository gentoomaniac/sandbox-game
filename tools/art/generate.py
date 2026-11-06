"""Generates every PNG under assets/ (run it with `make assets`).

Each topic has its module: terrain.py, trees.py, camp.py, character.py, interior.py and the
others listed in tools/README.md. This file puts the objects together into the atlas, and
`main` writes every file under assets/ (terrain, decorations, objects, character, interior,
fire, buildings, wildlife, crops, items, ui and the palette), then checks them against the
palette.

assets/objects.png: world objects, 48x80 cells (OBJECT_CELL_WIDTH x OBJECT_CELL_HEIGHT), one row per
kind (the table above `object_atlas`).
An object stands on one tile: the bottom centre 16x16 of its cell (x 16..31, y 64..79). A tree's
crown rises above that, over the tiles around it. An object on several tiles (boulder 2x1,
bedroll 1x2) is centred on its footprint, with the cell's bottom on the footprint's bottom.

Terrain, decorations and objects also exist per look (see seasons.py: spring, summer, autumn,
bare, frost, snow, dusting), the objects also in the steps of the spring leaf-out (buds, young
leaves), the building pictures in summer and snow: summer under the names above, the others
with the look added, e.g. assets/terrain_snow.png, assets/objects_young_leaves.png and
assets/buildings/kate_lit_snow.png.

assets/character/<slot>_<variant>.png: one sheet per layer of the player character, 16x32 cells
with the feet on the bottom row. One row per facing (down, up, left, right), columns: idle,
walk 1 to 4 (see game/state/appearance.gd and game/scenes/player_view.gd).
assets/character/collapse/<slot>_<variant>.png: the same layers passing out, one row of 32x32
cells facing right: kneeling, tipping over, lying and asleep (see `collapse_sheet`).
assets/effects/sleep_z.png: the "z" that rises from a sleeping figure.

assets/buildings/<type>.png: one picture per building type (drawn in buildings.py), as wide as
its footprint (16 px per tile) and as tall as the footprint plus the roof rising above it. The
bottom edge is the footprint's bottom edge. <type>_lit.png is the same with lit windows, for the
night. Each also comes in the house looks of seasons.HOUSE_LOOKS (kate_autumn.png,
kate_lit_snow.png). Sizes and door tiles are in data/buildings.cfg.

assets/fire/<type>.png: the flame of the fireplace and of the hearth, burning (see fire.py and
game/scenes/fire.gdshader). Cells the size of the box the flame burns in: what is behind the
flame, what is in front of it, then the frames of the flame. The atlas cell and the hearth's
picture show the first frame, for where the fire does not move.

assets/wildlife/<kind>.png: one sheet per animal kind, one row per action and one column per frame
(see animals.py and game/scenes/wildlife/wildlife_sprites.gd). The farm animals have one sheet per
species and look, assets/wildlife/<species>_<look>.png (see livestock.py).

assets/crops/<crop>.png: one sheet per crop, its four growth stages and the dead one side by side, 16 px
wide cells and as tall as the sheet (see crops.py and data/crops.cfg). They have no seasonal variants.

assets/soil_wet.png: the damp and the wet look of tilled soil, two 16x16 tiles (see crop_icons.py).

assets/clay_hint.png: the faint hint of a clay spot, one 16x16 tile (see meadow.py).

assets/items/<item id>.png (16x16) and assets/ui/slot.png, slot_selected.png (20x20): drawn in
items.py, for tools in tool_icons.py and for crops in crop_icons.py. assets/ground_items/<item
id>.png are their 8x8 versions for items lying on the ground (items.small), made for every icon
(the tools too).
"""

import alder
import animals
import beech
import birch
import boundaries
import buildings
import camp
import character
import chest
import crafts
import crop_icons
import crops
import fire
import flowers
import interior
import items
import livestock
import meadow
import reeds
import seasons
import terrain
import tool_icons
import trees
import trunks
import ui
import willow
from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, TILE, blank
from palette import ASSETS, PALETTE, check_palette, save, save_picture, write_palette


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


# The rows of assets/objects.png, as (kind, looks). `atlas_row` of each type in
# game/state/world_object_types.gd is its number here, and tests/test_object_atlas.gd checks
# it against assets/objects_rows.txt, which is written from the list below. A tree's trunks are
# two rows, the long trunk and then the short one; its `trunk` in world_object_types.gd names the
# first.
#
#  0 oak (3)
#  1 stone (2)
#  2 fireplace (1)
#  3 sleeping_bag (1)
#  4 spruce (3)
#  5 pine (3)
#  6 dead_tree (3)
#  7 berry_bush (3, then the same 3 picked)
#  8 shrub (3)
#  9 sapling (3)
# 10 fern (3; the game type is fern_bush, the art kind keeps its old name)
# 11 boulder (2)
# 12 stump (2)
# 13 tall_grass (3, then the same 3 mown)
# 14 oak_trunk (2)
# 15 oak_short_trunk (2)
# 16 spruce_trunk (2)
# 17 spruce_short_trunk (2)
# 18 pine_trunk (2)
# 19 pine_short_trunk (2)
# 20 dead_tree_trunk (2)
# 21 dead_tree_short_trunk (2)
# 22 willow_trunk (2)
# 23 willow_short_trunk (2)
# 24 reeds (3, then the same 3 cut)
# 25 dead_stump (2)
# 26 chest (1)
# 27 knick (3 variants of 16, one per connection mask, see boundaries.py)
# 28 wattle_fence (16, one per connection mask)
# 29 stone_wall (3 variants of 16)
# 30 dyke (16)
# 31 willow (3)
# 32 beech (3)
# 33 beech_trunk (2)
# 34 beech_short_trunk (2)
# 35 birch (3)
# 36 birch_trunk (2)
# 37 birch_short_trunk (2)
# 38 alder (3)
# 39 alder_trunk (2)
# 40 alder_short_trunk (2)
# 41 workbench (1)
# 42 carved_chest (1)
# 43 kiln (1)
def object_atlas():
    """The rows of assets/objects.png in order, each as (kind, its variants). The seasons
    treat every kind alike, so kind and row come from one list."""
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
    ]


def write_object_rows(objects):
    """assets/objects_rows.txt: `row kind looks` per row of objects.png, which the test of the
    object atlas compares with the types of world_object_types.gd."""
    lines = [f"{row} {kind} {len(looks)}" for row, (kind, looks) in enumerate(objects)]
    (ASSETS / "objects_rows.txt").write_text("\n".join(lines) + "\n")


def write_seasonal_art():
    """The art that has a file per look: terrain, decorations, objects and buildings. Summer
    keeps the plain names; the other looks add theirs, e.g. terrain_snow.png."""
    terrain_rows = []
    decoration_rows = []
    for layer in terrain.LAYERS:
        tiles, decorations = layer()
        # Full tiles hide the layers below them, so they must be opaque.
        for tile in tiles[terrain.EDGE_VARIANTS * terrain.FULL :]:
            assert all(None not in line for line in tile), f"{layer.__name__}: full tile has holes"
        terrain_rows.append(tiles)
        decoration_rows.append(decorations)
    # The meadow flowers have a row of their own, below the layers' (see flowers.py).
    decoration_rows.append(flowers.flower_row())
    objects = object_atlas()
    write_object_rows(objects)
    redraws = {
        "oak": lambda variant: trees.bare_oak(trees.OAK_SEEDS[variant]),
        "willow": lambda variant: willow.bare_willow(willow.WILLOW_SEEDS[variant]),
        "beech": lambda variant: beech.bare_beech(beech.BEECH_SEEDS[variant]),
        "birch": lambda variant: birch.bare_birch(birch.BIRCH_SEEDS[variant]),
        "alder": lambda variant: alder.bare_alder(alder.ALDER_SEEDS[variant]),
    }
    houses = {}
    for name, draw in buildings.PICTURES.items():
        houses[name] = draw(is_lit=False)
        houses[f"{name}_lit"] = draw(is_lit=True)
    for look in seasons.LOOKS:
        suffix = "" if look == "summer" else f"_{look}"
        if look in seasons.GROUND_LOOKS:
            save(seasons.terrain_rows(look, terrain_rows), f"terrain{suffix}.png")
            save(seasons.ground_rows(look, decoration_rows, seasons.STANDING.get(look)), f"decorations{suffix}.png")
        save(seasons.object_rows(look, objects, redraws), f"objects{suffix}.png", OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
        if look in seasons.HOUSE_LOOKS:
            for name, (picture, snowy) in houses.items():
                save_picture(seasons.house(look, picture, snowy), f"buildings/{name}{suffix}.png")


def write_character():
    layers = character.layers()
    for name, layer in layers.items():
        save(character.character_sheet(*layer), f"character/{name}.png", character.CHARACTER_WIDTH, character.CHARACTER_HEIGHT)
        save(character.collapse_sheet(*layer), f"character/collapse/{name}.png", character.COLLAPSE_SIZE)
    held_hoe = character.character_sheet(character.draw_held_hoe, {})
    save(held_hoe, "character/held_hoe.png", character.CHARACTER_WIDTH, character.CHARACTER_HEIGHT)
    save_picture(character.sleep_z(), "effects/sleep_z.png")


def write_interior():
    furniture = interior.furniture()
    save([interior.atlas_tiles(furniture)], "interior.png")
    for name, (picture, _footprint) in furniture.items():
        save_picture(picture, f"interior/{name}.png")
    for name, picture in interior.covers(furniture).items():
        save_picture(picture, f"interior/{name}.png")
    # The stations the player places are no furniture of the maps: they have no marker tile.
    for name, picture in crafts.stations().items():
        save_picture(picture, f"interior/{name}.png")


def write_bedroll_cover():
    save_picture(camp.bedroll_cover(), "bedroll_cover.png")


def write_fire():
    for name, (behind, front), (box, half_width, tall) in (
        ("fireplace", camp.fireplace_layers(), camp.FIREPLACE_FLAME),
        ("hearth", interior.hearth_layers(), interior.HEARTH_FLAME),
    ):
        strip = fire.strip(behind, front, box, half_width, tall)
        save([strip], f"fire/{name}.png", box[2], box[3])


def write_wildlife():
    for kind in animals.SHEETS:
        save(animals.sheet_rows(kind), f"wildlife/{kind}.png", *animals.cell_size(kind))
    for name, size, rows in livestock.sheets():
        save(rows, f"wildlife/{name}.png", *size)


def write_crops():
    for crop, cells in crops.sheets().items():
        save([cells], f"crops/{crop}.png", TILE, len(cells[0]))
    save([crop_icons.soil_wet()], "soil_wet.png")
    save_picture(meadow.clay_hint(), "clay_hint.png")


def write_items():
    icons = items.ICONS | crop_icons.icons() | meadow.icons() | reeds.icons() | tool_icons.icons() | crafts.icons()
    for name, picture in icons.items():
        save_picture(picture, f"items/{name}.png")
        # The same icon at half size, for items lying on the ground.
        save_picture(items.small(picture), f"ground_items/{name}.png")
    for name, picture in (items.SLOTS | items.SLOT_HINTS).items():
        save_picture(picture, f"ui/{name}.png")


def main():
    write_seasonal_art()
    write_character()
    write_interior()
    write_bedroll_cover()
    write_fire()
    write_wildlife()
    write_crops()
    write_items()
    ui.write_ui_assets(ASSETS / "ui", PALETTE)
    write_palette()
    check_palette()
    print("Wrote every file under assets/ (palette check passed).")


if __name__ == "__main__":
    main()
