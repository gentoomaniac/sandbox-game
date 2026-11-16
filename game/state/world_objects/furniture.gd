class_name WorldObjectFurniture
extends RefCounted
## The beds, tables, chests and fittings of the houses as data, loaded into WorldObjectTypes `TYPES`
## (see there for the entries): most of them stand only inside a house (`interior_sprite`).

## The atlas row of the chest, after the dead tree's stump.
const _CHEST_ROW := 26
const _CARVED_CHEST_ROW := 42

const TYPES := {
	&"sleeping_bag":
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 3,
		"variants": 1,
		"object_cover": "res://assets/bedroll_cover.png",
		"bed": Vector2i.UP,
		"interior_sprite": "res://assets/interior/sleeping_bag.png",
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	&"small_bed":
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/bed.png",
		"interior_cover": "res://assets/interior/bed_cover.png",
		"bed": Vector2i.UP,
	},
	&"table":
	{
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/table.png",
	},
	# The woodworker makes stools too, so a stool can be taken down; it only stands inside.
	&"stool":
	{
		"hp": 1,
		"tool": &"axe",
		"drops": {&"stool": 1},
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/stool.png",
		"placeable_in": WorldObjectTypes.INSIDE,
	},
	&"chest":
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"chest": 1},
		"storage_slots": 15,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _CHEST_ROW,
		"variants": 1,
		"interior_sprite": "res://assets/interior/chest.png",
		"placeable_in": WorldObjectTypes.ANYWHERE,
	},
	&"carved_chest":
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"carved_chest": 1},
		"storage_slots": 20,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _CARVED_CHEST_ROW,
		"variants": 1,
		"interior_sprite": "res://assets/interior/carved_chest.png",
		"placeable_in": WorldObjectTypes.ANYWHERE,
	},
	&"cupboard":
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"cupboard": 1},
		"storage_slots": 25,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"interior_sprite": "res://assets/interior/cupboard.png",
		"placeable_in": WorldObjectTypes.INSIDE,
	},
	&"hearth":
	{
		"footprint": Vector2i(2, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/hearth.png",
		"light": {"color": Color(1.0, 0.5, 0.22), "energy": 1.2, "radius_tiles": 5.0},
	},
	&"sleeping_mat":
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/sleeping_mat.png",
		"interior_cover": "res://assets/interior/sleeping_mat_cover.png",
		"bed": Vector2i.UP,
	},
	&"box_bed":
	{
		"footprint": Vector2i(2, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/box_bed.png",
		"interior_cover": "res://assets/interior/box_bed_cover.png",
		"bed": Vector2i.LEFT,
	},
	&"bench":
	{
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/bench.png",
	},
	&"stall_partition":
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/stall_partition.png",
	},
	&"hay_pile":
	{
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/hay_pile.png",
	},
	&"barrel":
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/barrel.png",
	},
	&"sacks":
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/sacks.png",
	},
	&"crate":
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/crate.png",
	},
	# A bench against the back wall: its backboard stands on the wall above its footprint.
	&"wall_bench":
	{
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/wall_bench.png",
	},
	# Wall pieces: they stand on the wall tiles of the back wall face.
	&"window":
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/window.png",
	},
	&"plate_rack":
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/plate_rack.png",
	},
}
