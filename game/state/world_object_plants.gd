class_name WorldObjectPlants
extends RefCounted
## The plants of the world as data, merged into WorldObjectTypes `TYPES` (see there for the
## entries): the bushes, the sapling, the tall grass and the reeds. They are picked or mown by
## hand or scythe, and follow the seasons.

const TYPES := {
	WorldObjectTypes.BERRY_BUSH:
	{
		"drops": {&"berries": 3},
		"regrow_days": 3,
		"seasonal": WorldObjectTypes.FRUIT,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"atlas_row": 7,
		"variants": 3,
	},
	WorldObjectTypes.SHRUB:
	{
		"drops": {&"fibre": 2},
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 8,
		"variants": 3,
	},
	WorldObjectTypes.SAPLING:
	{
		"drops": {&"acorn": 1},
		"matures_after_days": 4,
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 9,
		"variants": 3,
	},
	WorldObjectTypes.FERN_BUSH:
	{
		"drops": {&"fibre": 2},
		"seasonal": WorldObjectTypes.DORMANCY,
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 10,
		"variants": 3,
	},
	WorldObjectTypes.TALL_GRASS:
	{
		"drops": {&"hay": 2},
		"tool": &"scythe",
		"clearable": true,
		"regrow_days": 4,
		"seasonal": WorldObjectTypes.DORMANCY,
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 13,
		"variants": 3,
	},
	WorldObjectTypes.REEDS:
	{
		"drops": {&"reeds": 2},
		"tool": &"scythe",
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": WorldObjectTypes.REEDS_ROW,
		"variants": 3,
	},
}
