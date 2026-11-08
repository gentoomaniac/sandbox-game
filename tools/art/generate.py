"""Generates every PNG under assets/ (run it with `make assets`).

Each topic has its module: terrain.py, trees.py, camp.py, character.py, interior.py and the
others listed in tools/README.md. This file puts the objects together into the atlas, and
`main` writes every file under assets/ (terrain, decorations, objects, character, interior,
fire, buildings, wildlife, crops, items, ui and the palette), scales the art drawn at 16 px per
tile up to the game's tile (`scale_up_16_px_art`), then checks them against the palette.

The sizes below are those of the art as drawn, at canvas.TILE = 16 px per tile, unless they
say otherwise. The files of DOUBLED are written GAME_TILE / TILE times as big.

assets/objects.png: world objects, 96x160 cells (GAME_OBJECT_CELL_WIDTH x
GAME_OBJECT_CELL_HEIGHT), one row per kind (the table above `object_atlas`). The rows of
DOUBLED_ROWS are drawn in 48x80 cells at 16 px per tile and scaled up; the others at 32 px.
An object stands on one tile: the bottom centre 32x32 of its cell (x 32..63, y 128..159). A
tree's crown rises above that, over the tiles around it. An object on several tiles (boulder 2x1,
bedroll 1x2) is centred on its footprint, with the cell's bottom on the footprint's bottom.

Terrain, decorations and objects also exist per look (see seasons.py: spring, summer, autumn,
bare, frost, snow, dusting), the objects also in the steps of the spring leaf-out (buds, young
leaves), the building pictures in summer and snow: summer under the names above, the others
with the look added, e.g. assets/terrain_snow.png, assets/objects_young_leaves.png and
assets/buildings/kate_lit_snow.png.

assets/character/<slot>_<variant>.png: one sheet per layer of the player character, 32x64 cells
with the feet on the bottom row, drawn at the game's tile (not doubled). One row per facing
(down, up, left, right), columns: idle, walk 1 to 4 (see game/state/appearance.gd and
game/scenes/player_view.gd).
assets/character/collapse/<slot>_<variant>.png: the same layers passing out, one row of 64x64
cells facing right: kneeling, tipping over, lying and asleep (see `collapse_sheet`).
The villagers' layers (villagers.py) are drawn the same way, under the same names.
assets/character/riding/<slot>_<variant>.png: the player's layers sitting on a horse, one 32x64
cell per facing in the rows above (see `riding_sheet`).
assets/character/portrait/<slot>_<variant>.png: a 32x32 head-and-shoulders portrait of each
layer that shows in a bust, for the chat: the top of its frame facing the viewer (see
portraits.py).
assets/character/held_<tool>.png: each tool in the hand, a layer in the same cells (see
`HELD_TOOLS`).
assets/effects/sleep_z.png: the "z" that rises from a sleeping figure.

assets/buildings/<type>.png: one picture per building type (drawn in buildings.py, the church and
its bell frame in church.py) at the game's tile (not doubled), as wide as its footprint and as
tall as the footprint plus the roof rising above it. The bottom edge is the footprint's bottom edge.
<type>_lit.png is the same with lit windows, for the night. Each also comes in the house looks
of seasons.HOUSE_LOOKS (kate_autumn.png, kate_lit_snow.png). Sizes and door tiles are in
data/buildings.cfg.

assets/fire/<type>.png: the flame of the fireplace and of the hearth, burning (see fire.py and
game/scenes/fire.gdshader), at the game's tile (not doubled). Cells the size of the box the
flame burns in: what is behind the flame, what is in front of it (the fireplace's 16 px art
scaled up in `fire.strip`, the hearth's drawn at the game's tile), then the frames of the flame.
The atlas cell and the hearth's picture show the first frame, for where the fire does not move.

assets/interior.png and assets/interior/<name>.png: the tiles of the rooms and the furniture,
drawn at the game's tile (see interior.py); the stations and the grave marker placed indoors
are still 16 px art, scaled up in `write_interior`.

assets/wildlife/<kind>.png: one sheet per animal kind, one row per action and one column per frame
(see animals.py, birds.py for the stork and the goose, sea_birds.py for the birds of the coast, and
game/scenes/wildlife/wildlife_sprites.gd).
The farm animals have one sheet per species and look, assets/wildlife/<species>_<look>.png (see
livestock.py), drawn at the game's tile (not doubled); a horse also has horse_<look>_saddled.png,
and horse_<look>_ridden.png and horse_<look>_ridden_over.png, the ridden horse behind and in front
of the rider in the rows of the player's sheets (see `ridden_sheets`).

assets/crops/<crop>.png: one sheet per crop, its four growth stages and the dead one side by side, cells a
tile wide (32 px) and as tall as the sheet (see crops.py and data/crops.cfg), drawn at the game's tile. They
have no seasonal variants.

assets/soil_wet.png: the damp and the wet look of tilled soil, two tiles at the game's tile (see
terrain.py).

assets/clay_hint.png: the faint hint of a clay spot, one tile at the game's tile (see meadow.py).

assets/items/<item id>.png (16x16) and assets/ui/slot.png, slot_selected.png (20x20): drawn in
items.py, for tools in tool_icons.py and for crops in crop_icons.py. assets/ground_items/<item
id>.png are their 8x8 versions for items lying on the ground (items.small), made for every icon
(the tools too).
"""

import alder
import animals
import beech
import birch
import birds
import boundaries
import buildings
import camp
import character
import church
import chest
import coast
import crafts
import crop_icons
import crops
import fire
import flowers
import interior
import items
import landing
import livestock
import meadow
import portraits
import reeds
import sea_birds
import seasons
import terrain
import tool_icons
import trees
import trunks
import ui
import villagers
import willow
from canvas import GAME_OBJECT_CELL_HEIGHT, GAME_OBJECT_CELL_WIDTH, GAME_TILE, OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, TILE, blank
from PIL import Image
from palette import ASSETS, PALETTE, check_palette, save, save_picture, write_palette

# The files under assets/ that the world draws and that are still drawn at 16 px per tile:
# `scale_up_16_px_art` scales them up to the game's tile, pixel for pixel. Each task that
# redraws a group at 32 px (tasks 107 to 116) takes its files out of here. The UI's pictures
# (items/ and ui/) are drawn for the UI's own scale and stay as they are; the thought bubbles in
# ui/ are drawn at 32 px like the people.
DOUBLED = (
    # The bedroll (task 111); the object atlas doubles its rows itself (DOUBLED_ROWS).
    "bedroll_cover.png",
    # Items on the ground (task 115).
    "ground_items/*.png",
)


def standing_outdoors(picture):
    """A picture that stands on the ground (the chest, a station) in its cell of the object atlas,
    on a ground shadow, its bottom a pixel above the cell's."""
    canvas = blank(OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    # The ground shadow of the 16 px art, three rows with a dithered rim.
    for y, reach in ((OBJECT_BOTTOM - 2, 5), (OBJECT_BOTTOM - 1, 8), (OBJECT_BOTTOM, 6)):
        for x in range(OBJECT_CENTRE - reach, OBJECT_CENTRE + reach):
            if abs(x - OBJECT_CENTRE) < reach - 1 or (x + y) % 2 == 0:
                canvas[y][x] = "shadow"
    top = OBJECT_BOTTOM - len(picture)
    for y, row in enumerate(picture):
        for x, name in enumerate(row):
            if name is not None:
                canvas[top + y][OBJECT_CENTRE - len(row) // 2 + x] = name
    return canvas


# The rows of the object atlas still drawn at 16 px per tile: write_seasonal_art scales them up
# to the game's tile in every look, after the looks are made from them, so they look as they did.
# The plants are drawn at 32 px; task 111 draws the rest anew: the camp, the walls, fences, the
# dyke and the placed objects.
DOUBLED_ROWS = {
    "fireplace", "sleeping_bag", "chest", "knick", "wattle_fence", "stone_wall", "dyke", "workbench",
    "carved_chest", "kiln", "oven", "ewer", "grave", "jetty", "rowing_boat", "net_frame", "eel_traps",
}


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
# 44 oven (1)
# 45 ewer (1)
# 46 grave (3)
# 47 jetty (16, one per connection mask, see landing.py)
# 48 rowing_boat (1)
# 49 net_frame (1)
# 50 eel_traps (1)
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
        ("oven", [standing_outdoors(crafts.oven())]),
        ("ewer", coast.ewer_row()),
        ("grave", [standing_outdoors(picture) for picture in church.graves()]),
        ("jetty", landing.jetty_row()),
        ("rowing_boat", landing.rowing_boat_row()),
        ("net_frame", landing.net_frame_row()),
        ("eel_traps", landing.eel_traps_row()),
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
    layers = [layer.__name__ for layer in terrain.LAYERS]
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
    for name, draw in (buildings.PICTURES | church.PICTURES).items():
        houses[name] = draw(is_lit=False)
        houses[f"{name}_lit"] = draw(is_lit=True)
    for look in seasons.LOOKS:
        suffix = "" if look == "summer" else f"_{look}"
        if look in seasons.GROUND_LOOKS:
            save(seasons.terrain_rows(look, terrain_rows, layers), f"terrain{suffix}.png", GAME_TILE)
            decorations = seasons.ground_rows(look, decoration_rows, layers, seasons.STANDING.get(look))
            save(decorations, f"decorations{suffix}.png", GAME_TILE)
        rows = seasons.object_rows(look, objects, redraws)
        rows = [
            [doubled(cell) for cell in row] if kind in DOUBLED_ROWS else row
            for (kind, _looks), row in zip(objects, rows)
        ]
        save(rows, f"objects{suffix}.png", GAME_OBJECT_CELL_WIDTH, GAME_OBJECT_CELL_HEIGHT)
        if look in seasons.HOUSE_LOOKS:
            for name, (picture, snowy) in houses.items():
                save_picture(seasons.house(look, picture, snowy), f"buildings/{name}{suffix}.png")


def write_character():
    layers = character.layers() | villagers.layers()
    for name, layer in layers.items():
        save(character.character_sheet(*layer), f"character/{name}.png", character.CHARACTER_WIDTH, character.CHARACTER_HEIGHT)
        save(character.collapse_sheet(*layer), f"character/collapse/{name}.png", character.COLLAPSE_SIZE)
    for name, picture in portraits.portraits(layers).items():
        save_picture(picture, f"character/portrait/{name}.png")
    # Only the player rides, so only the player's layers sit on a horse.
    for name, layer in character.layers().items():
        save(character.riding_sheet(*layer), f"character/riding/{name}.png", character.CHARACTER_WIDTH, character.CHARACTER_HEIGHT)
    for tool, draw in character.HELD_TOOLS.items():
        save(character.character_sheet(draw, {}), f"character/held_{tool}.png", character.CHARACTER_WIDTH, character.CHARACTER_HEIGHT)
    save_picture(character.sleep_z(), "effects/sleep_z.png")


def write_interior():
    furniture = interior.furniture()
    save([interior.atlas_tiles(furniture)], "interior.png", GAME_TILE)
    for name, (picture, _footprint) in furniture.items():
        save_picture(picture, f"interior/{name}.png")
    for name, picture in interior.covers(furniture).items():
        save_picture(picture, f"interior/{name}.png")
    # The stations the player places are no furniture of the maps: they have no marker tile.
    # They are still drawn at 16 px per tile (task 111), so they are scaled up here.
    for name, picture in crafts.stations().items():
        save_picture(doubled(picture), f"interior/{name}.png")
    # The ghost of the grave marker while it is placed (a grave stands only outdoors).
    save_picture(doubled(church.graves()[0]), "interior/grave.png")


def write_bedroll_cover():
    save_picture(camp.bedroll_cover(), "bedroll_cover.png")


def write_fire():
    for name, (behind, front), (box, half_width, tall), scale in (
        ("fireplace", camp.fireplace_layers(), camp.FIREPLACE_FLAME, 1),
        ("hearth", interior.hearth_layers(), interior.HEARTH_FLAME, GAME_TILE // TILE),
    ):
        strip = fire.strip(behind, front, box, half_width, tall, scale)
        save([strip], f"fire/{name}.png", len(strip[0][0]), len(strip[0]))


def write_wildlife():
    for name, size, rows in [*animals.sheets(), *birds.sheets(), *sea_birds.sheets(), *livestock.sheets()]:
        save(rows, f"wildlife/{name}.png", *size)


def write_crops():
    for crop, cells in crops.sheets().items():
        save([cells], f"crops/{crop}.png", crops.WIDTH, len(cells[0]))
    save([terrain.soil_wet()], "soil_wet.png", GAME_TILE)
    save_picture(meadow.clay_hint(), "clay_hint.png")


def write_items():
    icons = items.ICONS | crop_icons.icons() | meadow.icons() | reeds.icons() | tool_icons.icons() | crafts.icons() | church.icons() | landing.icons()
    for name, picture in icons.items():
        save_picture(picture, f"items/{name}.png")
        # The same icon at half size, for items lying on the ground.
        save_picture(items.small(picture), f"ground_items/{name}.png")
    for name, picture in (items.SLOTS | items.SLOT_HINTS).items():
        save_picture(picture, f"ui/{name}.png")


def doubled(picture):
    """A picture drawn at 16 px per tile scaled up to the game's tile, pixel for pixel."""
    factor = GAME_TILE // TILE
    return [[colour for colour in row for _ in range(factor)] for row in picture for _ in range(factor)]


def scale_up_16_px_art():
    """Scales the files of DOUBLED up from the art's tile to the game's, pixel for pixel."""
    factor = GAME_TILE // TILE
    for pattern in DOUBLED:
        paths = sorted(ASSETS.glob(pattern))
        assert paths, f"DOUBLED: no file matches {pattern}"
        for path in paths:
            image = Image.open(path)
            image.resize((image.width * factor, image.height * factor), Image.Resampling.NEAREST).save(path)


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
    scale_up_16_px_art()
    write_palette()
    check_palette()
    print("Wrote every file under assets/ (palette check passed).")


if __name__ == "__main__":
    main()
