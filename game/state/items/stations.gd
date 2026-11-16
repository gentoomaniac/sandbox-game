class_name ItemStations
extends RefCounted
## The stations the player places, as data in ItemTypes `TYPES` (see there).

const TYPES := {
	&"workbench":
	{
		"name": "Workbench",
		"description": "A joiner's bench. Wood is worked here, and clay moulded.",
		"weight": 8.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.WORKBENCH,
	},
	&"kiln":
	{
		"name": "Kiln",
		"description": "A small clay kiln that fires bricks overnight. It stands outdoors.",
		"weight": 15.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.KILN,
	},
	&"oven":
	{
		"name": "Bake oven",
		"description": "A brick oven for bread. It stands outdoors or in a house.",
		"weight": 15.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.OVEN,
	},
	&"fireplace":
	{
		"name": "Campfire",
		"description":
		"A ring of stones round a fire; cook at it. It stands outdoors; the hammer takes it down.",
		"weight": 6.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.FIREPLACE,
	},
}
