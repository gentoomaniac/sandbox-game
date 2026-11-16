class_name ItemBoundaries
extends RefCounted
## The fences, walls and ways the player lays, as data in ItemTypes `TYPES` (see there).

const TYPES := {
	&"wattle_fence":
	{
		"name": "Wattle fence",
		"description": "Hazel rods woven between stakes, a light fence for a field or a yard.",
		"weight": 1.0,
		"stack_limit": 20,
		"places": WorldObjectTypes.WATTLE_FENCE,
	},
	&"stone_wall":
	{
		"name": "Stone wall",
		"description": "A piece of dry stone wall, fieldstones stacked without mortar.",
		"weight": 4.5,
		"stack_limit": 10,
		"places": WorldObjectTypes.STONE_WALL,
	},
	&"plank_walk":
	{
		"name": "Plank walk",
		"description":
		"A piece of boardwalk. Laid on grass or mud, it never wears or turns to mud.",
		"weight": 1.0,
		"stack_limit": 20,
		"places": WorldObjectTypes.PLANK_WALK,
	},
	&"stone_path":
	{
		"name": "Stone path",
		"description": "Cobbles set in the earth. Laid on grass, it never wears or turns to mud.",
		"weight": 3.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.STONE_PATH,
	},
}
