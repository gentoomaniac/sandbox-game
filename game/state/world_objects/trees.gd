class_name WorldObjectTrees
extends RefCounted
## The trees and their stumps as data, loaded into WorldObjectTypes `TYPES` (see there for the
## entries): what the axe fells, what it leaves and what grows back. The trunks a felled tree leaves
## are derived from `trunk` there; the dead and half-dead kinds from WorldObjectSnags.

## The atlas rows of the long trunks; the short one is the row after each. They follow the order
## in which tools/art/generate.py lays out the object atlas (assets/objects_rows.txt, checked by a
## test), so a new tree gets the next free rows there and here.
const _OAK_TRUNK_ROW := 14
const _SPRUCE_TRUNK_ROW := 16
const _PINE_TRUNK_ROW := 18
const _DEAD_TREE_TRUNK_ROW := 20
const _WILLOW_TRUNK_ROW := 22
## The atlas row of the dead tree's stump, after the reeds.
const _DEAD_STUMP_ROW := 25
const _WILLOW_ROW := 31
const _BEECH_ROW := 32
const _BEECH_TRUNK_ROW := 33
const _BIRCH_ROW := 35
const _BIRCH_TRUNK_ROW := 36
const _ALDER_ROW := 38
const _ALDER_TRUNK_ROW := 39

const TYPES := {
	&"oak":
	{
		"hp": 5,
		"tool": &"axe",
		"seed": &"acorn",
		"seed_chance": 0.25,
		"trunk": {"logs": 3, "hp": 4, "atlas_row": _OAK_TRUNK_ROW},
		"leaves": &"stump",
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 0,
		"sprite_height": 130,
		"variants": 3,
	},
	&"spruce":
	{
		"hp": 4,
		"tool": &"axe",
		"seed": &"spruce_cone",
		"seed_chance": 0.25,
		"trunk": {"logs": 3, "hp": 3, "atlas_row": _SPRUCE_TRUNK_ROW},
		"leaves": &"stump",
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 4,
		"sprite_height": 140,
		"variants": 3,
	},
	&"pine":
	{
		"hp": 7,
		"tool": &"axe",
		"seed": &"pine_cone",
		"seed_chance": 0.25,
		"trunk": {"logs": 4, "hp": 5, "atlas_row": _PINE_TRUNK_ROW},
		"leaves": &"stump",
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 2,
		"atlas_row": 5,
		"sprite_height": 156,
		"variants": 3,
	},
	&"dead_tree":
	{
		"hp": 3,
		"tool": &"axe",
		"trunk": {"logs": 2, "hp": 2, "atlas_row": _DEAD_TREE_TRUNK_ROW},
		"leaves": &"dead_stump",
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 6,
		"sprite_height": 110,
		"variants": 3,
	},
	# The pollard willow of the ditches, cut back to a head that sprouts rods.
	&"willow":
	{
		"hp": 4,
		"tool": &"axe",
		"seed": &"willow_cutting",
		"seed_chance": 0.25,
		"trunk": {"logs": 2, "hp": 3, "atlas_row": _WILLOW_TRUNK_ROW},
		"leaves": &"stump",
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _WILLOW_ROW,
		"sprite_height": 118,
		"variants": 3,
	},
	# The beech of the woods: smooth grey bark, a dense dome of a crown.
	&"beech":
	{
		"hp": 5,
		"tool": &"axe",
		"seed": &"beechnut",
		"seed_chance": 0.25,
		"trunk": {"logs": 3, "hp": 4, "atlas_row": _BEECH_TRUNK_ROW},
		"leaves": &"stump",
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _BEECH_ROW,
		"sprite_height": 126,
		"variants": 3,
	},
	# The birch of the Geest and the wet woods: white bark, a light, open crown, soft wood.
	&"birch":
	{
		"hp": 3,
		"tool": &"axe",
		"seed": &"birch_catkin",
		"seed_chance": 0.25,
		"trunk": {"logs": 2, "hp": 2, "atlas_row": _BIRCH_TRUNK_ROW},
		"leaves": &"stump",
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _BIRCH_ROW,
		"sprite_height": 136,
		"variants": 3,
	},
	# The black alder of wet ground: dark bark, a narrow cone of dark leaves, cones in winter.
	&"alder":
	{
		"hp": 4,
		"tool": &"axe",
		"seed": &"alder_cone",
		"seed_chance": 0.25,
		"trunk": {"logs": 2, "hp": 3, "atlas_row": _ALDER_TRUNK_ROW},
		"leaves": &"stump",
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _ALDER_ROW,
		"sprite_height": 134,
		"variants": 3,
	},
	&"stump":
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 12,
		"variants": 2,
		"hp": 2,
		"tool": &"axe",
		"drops": {&"logs": 1},
		"rots_after_days": 14,
		"rots_into_sapling_chance": 0.3,
	},
	&"dead_stump":
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _DEAD_STUMP_ROW,
		"variants": 2,
		"hp": 2,
		"tool": &"axe",
		"drops": {&"logs": 1},
		"rots_after_days": 14,
	},
}
