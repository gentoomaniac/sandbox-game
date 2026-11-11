"""The classic art: the art of the groups that are drawn at 32 px per tile now, as it was drawn at
16 px per tile, for the game's art setting (see game/scenes/art_set.gd).

The modules here are the old generators of those groups, copied from git history unchanged (the
commit is in each group's comment below); they share canvas.py and palette.py with the new art.
`main` writes their files under art/generated/ with the postfix _16x16, where the new art has
_32x32 (items/axe_16x16.png), as drawn at 16 px; `make assets` (pack.py) scales the world's up to
the game's tile (scaling.py) into assets/classic/. The game shows a classic file where there is one
and the new file where there is none.

An art group that goes native moves its old generator here (see tools/README.md).
"""

import sys
from pathlib import Path

# The old modules here come first, the new art's shared basics (canvas, palette) after them.
sys.path.append(str(Path(__file__).resolve().parents[1]))

import alder  # noqa: E402
import atlas  # noqa: E402
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
import pen  # noqa: E402
import reeds  # noqa: E402
import sea_birds  # noqa: E402
import stork_nest  # noqa: E402
import seasons  # noqa: E402
import terrain  # noqa: E402
import tool_icons  # noqa: E402
import portraits  # noqa: E402
import trees  # noqa: E402
import trunks  # noqa: E402
import villagers  # noqa: E402
import willow  # noqa: E402
import yard  # noqa: E402
from canvas import OBJECT_BOTTOM, OBJECT_CELL_HEIGHT, OBJECT_CELL_WIDTH, OBJECT_CENTRE, TILE, blank  # noqa: E402
from palette import CLASSIC_ART, GENERATED, PALETTE, save, save_picture, set_file, use_art_set, write_cell_sizes  # noqa: E402


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
    held_hoe = character.character_sheet(character.draw_held_hoe, {})
    save(held_hoe, "character/held_hoe.png", character.CHARACTER_WIDTH, character.CHARACTER_HEIGHT)
    save_picture(character.sleep_z(), "effects/sleep_z.png")
    save_picture(character.pet_heart(), "effects/pet_heart.png")
    save_picture(character.pet_annoyed(), "effects/pet_annoyed.png")


def write_bubbles():
    (GENERATED / "ui").mkdir(parents=True, exist_ok=True)
    for name, rows in bubbles.BUBBLE_ICONS.items():
        bubbles.bubble(PALETTE, rows).save(GENERATED / "ui" / set_file(f"bubble_{name}.png"))


def write_livestock():
    for name, size, rows in livestock.sheets():
        save(rows, f"wildlife/{name}.png", *size)


def write_wildlife():
    for kind in animals.SHEETS:
        save(animals.sheet_rows(kind), f"wildlife/{kind}.png", *animals.cell_size(kind))
    for name, size, rows in [*birds.sheets(), *stork_nest.sheets(), *sea_birds.sheets()]:
        save(rows, f"wildlife/{name}.png", *size)


def write_fire():
    for name, (behind, front), (box, half_width, tall) in (
        ("fireplace", camp.fireplace_layers(), camp.FIREPLACE_FLAME),
        ("hearth", interior.hearth_layers(), interior.HEARTH_FLAME),
    ):
        strip = fire.strip(behind, front, box, half_width, tall)
        save([strip], f"fire/{name}.png", box[2], box[3])


def write_ground():
    terrain_rows = []
    decoration_rows = []
    for layer in terrain.LAYERS:
        tiles, decorations = layer()
        terrain_rows.append(tiles)
        decoration_rows.append(decorations)
    decoration_rows.append(flowers.flower_row())
    decorations_by_look = {}
    for look in ground_looks.GROUND_LOOKS:
        suffix = "" if look == "summer" else f"_{look}"
        save(ground_looks.terrain_rows(look, terrain_rows), f"terrain{suffix}.png")
        decorations_by_look[look] = ground_looks.ground_rows(look, decoration_rows, ground_looks.STANDING.get(look))
    layers = [layer.__name__ for layer in terrain.LAYERS]
    atlas.save_sheets("decorations", [*layers, "flowers"], ground_looks.GROUND_LOOKS, decorations_by_look, TILE, TILE)
    save(ground_overlays.soil_wet(), "soil_wet.png")
    save(ground_overlays.soil_fade(), "soil_fade.png")
    save_picture(ground_overlays.clay_hint(), "clay_hint.png")


def write_buildings():
    for name, draw in (buildings.PICTURES | church.PICTURES | yard.PICTURES).items():
        for lit_suffix, is_lit in (("", False), ("_lit", True)):
            picture, snowy = draw(is_lit=is_lit)
            for look in seasons.HOUSE_LOOKS:
                look_suffix = "" if look == "summer" else f"_{look}"
                save_picture(seasons.house(look, picture, snowy), f"buildings/{name}{lit_suffix}{look_suffix}.png")


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
        ("draw_well", [standing_outdoors(yard.draw_well())]),
        ("trough", [standing_outdoors(yard.trough(level)) for level in range(yard.STOCK_LOOKS)]),
        ("hay_rack", [standing_outdoors(yard.hay_rack(level)) for level in range(yard.STOCK_LOOKS)]),
        ("feed_trough", [standing_outdoors(yard.trough(level, "feed")) for level in range(yard.STOCK_LOOKS)]),
        ("pen_fence", pen.pen_fence_row()),
        ("pen_gate", pen.pen_gate_row()),
        ("pig_shelter", [standing_outdoors(pen.pig_shelter())]),
        ("pen_gate_open", pen.pen_gate_row(is_open=True)),
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
    objects_by_look = {look: object_looks.object_rows(look, objects, redraws) for look in object_looks.LOOKS}
    atlas.save_sheets("objects", [kind for kind, _ in objects], object_looks.LOOKS, objects_by_look, OBJECT_CELL_WIDTH, OBJECT_CELL_HEIGHT)
    save_picture(camp.bedroll_cover(), "bedroll_cover.png")


def write_crops():
    for crop, cells in crops.sheets().items():
        save([cells], f"crops/{crop}.png", TILE, len(cells[0]))


def write_interior():
    furniture = interior.furniture()
    save([interior.atlas_tiles(furniture)], "interior.png")
    for name, (picture, _footprint) in furniture.items():
        save_picture(picture, f"interior/{name}.png")
    for name, picture in interior.covers(furniture).items():
        save_picture(picture, f"interior/{name}.png")
    for name, picture in crafts.stations().items():
        save_picture(picture, f"interior/{name}.png")
    save_picture(camp.ghost(camp.fireplace(), 25, 26), "interior/fireplace.png")
    save_picture(camp.ghost(camp.bedroll(), 18, 30), "interior/sleeping_bag.png")
    save_picture(graves.graves()[0], "interior/grave.png")


def write_items():
    icons = item_icons.ICONS | crop_icons.icons() | tool_icons.icons() | craft_icons.icons() | yard.icons() | pen.icons()
    for name, picture in icons.items():
        save_picture(picture, f"items/{name}.png")
        # The same icon at half size, for items lying on the ground.
        save_picture(item_icons.small(picture), f"ground_items/{name}.png")


def main():
    use_art_set(CLASSIC_ART)
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
    write_cell_sizes()
    print("Wrote the classic art (the _16x16 files) under art/generated/.")


if __name__ == "__main__":
    main()
