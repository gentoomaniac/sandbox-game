class_name ItemFood
extends RefCounted
## What the player cooks and bakes as data, loaded into ItemTypes `TYPES` (see there).

const TYPES := {
	&"roast_turnip":
	{
		"name": "Roast turnip",
		"description": "A turnip roasted in the embers. Sweeter than raw.",
		"weight": 0.4,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"pottage":
	{
		"name": "Pottage",
		"description": "Cabbage, carrot and onion stewed in the pot over the fire.",
		"weight": 0.5,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"pea_soup":
	{
		"name": "Pea soup",
		"description": "Thick soup of peas and onion, the coast's daily fare.",
		"weight": 0.5,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"buckwheat_pancakes":
	{
		"name": "Buckwheat pancakes",
		"description": "Buckwheat ground and fried thin in the pan, the Geest's pancakes.",
		"weight": 0.3,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"flour":
	{
		"name": "Flour",
		"description": "Grain ground in a hand quern. Bread needs it.",
		"weight": 0.5,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"bread":
	{
		"name": "Bread",
		"description": "A round loaf from the oven, the daily bread of the coast.",
		"weight": 0.5,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"berry_tart":
	{
		"name": "Berry tart",
		"description": "Berries baked in pastry, a treat for a feast day.",
		"weight": 0.4,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"feast_cake":
	{
		"name": "Feast cake",
		"description": "A tall cake with strawberries, baked for a wedding or the harvest feast.",
		"weight": 0.8,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
}
