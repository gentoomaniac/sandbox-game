class_name ItemPlants
extends RefCounted
## The dug-up bushes the player plants again, as data in ItemTypes `TYPES` (see there).

const TYPES := {
	&"berry_bush":
	{
		"name": "Berry bush",
		"description": "A dug-up berry bush. Plant it on grass; it bears again after a few days.",
		"weight": 5.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.BERRY_BUSH,
	},
	&"shrub":
	{
		"name": "Shrub",
		"description": "A dug-up shrub. Plant it on grass.",
		"weight": 4.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.SHRUB,
	},
	&"fern_bush":
	{
		"name": "Fern",
		"description": "A dug-up fern. Planted in winter, it stays hidden until spring.",
		"weight": 2.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.FERN_BUSH,
	},
}
