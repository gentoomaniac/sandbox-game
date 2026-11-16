class_name WorldObjectRocks
extends RefCounted
## The stones of the land as data, loaded into WorldObjectTypes `TYPES` (see there for the
## entries): the pickaxe breaks them for stone.

const TYPES := {
	&"stone":
	{
		"hp": 3,
		"tool": &"pickaxe",
		"drops": {&"stone": 2},
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 1,
		"variants": 2,
	},
	&"boulder":
	{
		"hp": 6,
		"tool": &"pickaxe",
		"drops": {&"stone": 5},
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 2,
		"atlas_row": 11,
		"variants": 2,
	},
}
