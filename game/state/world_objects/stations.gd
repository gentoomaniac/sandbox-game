class_name WorldObjectStations
extends RefCounted
## The places the player cooks, burns and works at as data, loaded into WorldObjectTypes `TYPES`
## (see there for the entries): the fireplace, the workbench, the kiln, the oven and the
## millstone, which only stands in the windmill. What the
## stations make is in data/stations.cfg.

const _WORKBENCH_ROW := 41
const _KILN_ROW := 43
const _OVEN_ROW := 44

const TYPES := {
	&"fireplace":
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"atlas_row": 2,
		"variants": 1,
		# Deep orange at a moderate energy: brighter or paler turns the grass lime and
		# bleaches the player.
		"light": {"color": Color(1.0, 0.5, 0.22), "energy": 1.4, "radius_tiles": 7.0},
		"storage_slots": 1,
		"out_look": true,
		"interior_sprite": "res://assets/interior/fireplace.png",
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	&"workbench":
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"workbench": 1},
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _WORKBENCH_ROW,
		"variants": 1,
		"interior_sprite": "res://assets/interior/workbench.png",
		"placeable_in": WorldObjectTypes.ANYWHERE,
	},
	# Its interior picture is the ghost while it is placed: it stands only outdoors.
	&"kiln":
	{
		"hp": 4,
		"tool": &"pickaxe",
		"drops": {&"kiln": 1},
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _KILN_ROW,
		"variants": 1,
		"interior_sprite": "res://assets/interior/kiln.png",
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	&"oven":
	{
		"hp": 4,
		"tool": &"pickaxe",
		"drops": {&"oven": 1},
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _OVEN_ROW,
		"variants": 1,
		"interior_sprite": "res://assets/interior/oven.png",
		"placeable_in": WorldObjectTypes.ANYWHERE,
	},
	# Put in the windmill by its building (see data/buildings.cfg, `fixtures`), never placed or
	# taken. It has the oven's picture until a millstone is drawn.
	&"millstone":
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/oven.png",
	},
}
