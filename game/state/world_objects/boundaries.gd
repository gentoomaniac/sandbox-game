class_name WorldObjectBoundaries
extends RefCounted
## The hedges, fences and walls between fields as data, loaded into WorldObjectTypes `TYPES` (see
## there for the entries): lines across the land that the axe or pickaxe takes down. The dyke is
## WorldObjectDyke.

const _KNICK_ROW := 27
const _WATTLE_FENCE_ROW := 28
const _STONE_WALL_ROW := 29

const TYPES := {
	# A hedge of hazel and hawthorn on an earth bank, between fields. The axe cuts it down to
	# the ground for its wood.
	&"knick":
	{
		"hp": 4,
		"tool": &"axe",
		"drops": {&"logs": 1, &"fibre": 2},
		"connects": &"field_boundary",
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _KNICK_ROW,
		"variants": 3,
	},
	# Hazel rods woven between stakes: a light fence, cut down with the axe for its fibre. The
	# player makes and places it too (task 203); what it gives back is what its recipe took.
	&"wattle_fence":
	{
		"hp": 2,
		"tool": &"axe",
		"drops": {&"fibre": 2},
		"connects": &"field_boundary",
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _WATTLE_FENCE_ROW,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	# Fieldstones stacked dry: the pickaxe takes it apart for the stone a piece is made of
	# (task 203).
	&"stone_wall":
	{
		"hp": 5,
		"tool": &"pickaxe",
		"drops": {&"stone": 3},
		"connects": &"field_boundary",
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _STONE_WALL_ROW,
		"variants": 3,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
}
