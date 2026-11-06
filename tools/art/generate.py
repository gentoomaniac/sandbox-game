"""Generates every PNG under assets/ (run it with `make assets`).

Each topic has its module: terrain.py, trees.py, camp.py, character.py, interior.py and the
others listed in tools/README.md. This file puts the objects together into the atlas, and
`main` writes every file under assets/ (terrain, decorations, objects, character, interior,
fire, buildings, wildlife, crops, items, ui and the palette), then checks them against the
palette.

assets/objects.png: world objects, 48x80 cells (OBJECT_CELL_WIDTH x OBJECT_CELL_HEIGHT). Row 0
is the oak (3 variants), row 1 the stone (2 variants), then the camp site: row 2 the fireplace,
row 3 the bedroll (the sleeping_bag object; 1 variant each), then the vegetation rows from 4 (see vegetation()),
row 11 the boulder, row 12 the stump, row 13 the tall grass (3 tufts, then the same 3 mown;
see meadow.py) and rows 14 to 21 the trunks (see trunks.py) and row 22 the reeds (3 stands, then the same 3 cut;
see reeds.py) and row 23 the dead tree's stump (2 variants). The rows and
counts are in game/state/world_object_types.gd.
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
night. Sizes and door tiles are in data/buildings.cfg.

assets/fire/<type>.png: the flame of the fireplace and of the hearth, burning (see fire.py and
game/scenes/fire.gdshader). Cells the size of the box the flame burns in: what is behind the
flame, what is in front of it, then the frames of the flame. The atlas cell and the hearth's
picture show the first frame, for where the fire does not move.

assets/wildlife/<kind>.png: one sheet per animal kind, one row per action and one column per frame
(see animals.py and game/scenes/wildlife/wildlife_sprites.gd).

assets/crops/<crop>.png: one sheet per crop, its four growth stages and the dead one side by side, 16 px
wide cells and as tall as the sheet (see crops.py and data/crops.cfg). They have no seasonal variants.

assets/soil_wet.png: the damp and the wet look of tilled soil, two 16x16 tiles (see crop_icons.py).

assets/clay_hint.png: the faint hint of a clay spot, one 16x16 tile (see meadow.py).

assets/items/<item id>.png (16x16) and assets/ui/slot.png, slot_selected.png (20x20): drawn in
items.py, for tools in tool_icons.py and for crops in crop_icons.py. assets/ground_items/<item
id>.png are their 8x8 versions for items lying on the ground (items.small), made for every icon
(the tools too).
"""

import animals
import buildings
import camp
import character
import chest
import crop_icons
import crops
import fire
import interior
import items
import meadow
import reeds
import seasons
import terrain
import tool_icons
import trees
import trunks
import ui
from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, TILE, blank
from palette import ASSETS, PALETTE, check_palette, save, save_picture, write_palette


def world_chest():
    """The chest outdoors, on a ground shadow, its bottom a pixel above the cell's."""
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    trees.ground_shadow(canvas, 8)
    picture = chest.chest()
    top = OBJECT_BOTTOM - len(picture)
    for y, row in enumerate(picture):
        for x, name in enumerate(row):
            if name is not None:
                canvas[top + y][OBJECT_CENTRE - len(row) // 2 + x] = name
    return canvas


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
    ] + trunks.rows() + [
        ("reeds", reeds.reeds_row()),
        ("dead_stump", [trees.dead_stump(seed) for seed in (211, 212)]),
        ("chest", [world_chest()]),
    ]


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
    objects = object_atlas()
    redraws = {"oak": lambda variant: trees.bare_oak(trees.OAK_SEEDS[variant])}
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
        # Houses only change under snow.
        if look in ("summer", "snow"):
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


def write_fire():
    for name, (behind, front), (box, half_width, tall) in (
        ("fireplace", camp.fireplace_layers(), camp.FIREPLACE_FLAME),
        ("hearth", (interior.hearth_without_flame(), blank(2 * TILE, 2 * TILE)), interior.HEARTH_FLAME),
    ):
        strip = fire.strip(behind, front, box, half_width, tall)
        save([strip], f"fire/{name}.png", box[2], box[3])


def write_wildlife():
    for kind in animals.SHEETS:
        save(animals.sheet_rows(kind), f"wildlife/{kind}.png", *animals.cell_size(kind))


def write_crops():
    for crop, cells in crops.sheets().items():
        save([cells], f"crops/{crop}.png", TILE, len(cells[0]))
    save([crop_icons.soil_wet()], "soil_wet.png")
    save_picture(meadow.clay_hint(), "clay_hint.png")


def write_items():
    icons = items.ICONS | crop_icons.icons() | meadow.icons() | reeds.icons() | tool_icons.icons()
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
