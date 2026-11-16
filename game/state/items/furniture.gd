class_name ItemFurniture
extends RefCounted
## The chests, beds and fittings the player places, as data in ItemTypes `TYPES` (see there).

const TYPES := {
	&"chest":
	{
		"name": "Chest",
		"description": "Stores items. Place it outside or in a house; the axe takes it down.",
		"weight": 4.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.CHEST,
	},
	&"carved_chest":
	{
		"name": "Carved chest",
		"description": "A painted chest in the Frisian way, roomier than a plain one.",
		"weight": 6.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.CARVED_CHEST,
	},
	&"sleeping_bag":
	{
		"name": "Bedroll",
		"description":
		"A straw sack and a wool blanket to sleep on. It lies outdoors; the hammer takes it down.",
		"weight": 3.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.SLEEPING_BAG,
	},
	&"stool":
	{
		"name": "Stool",
		"description": "A three-legged stool. It stands in a house.",
		"weight": 1.5,
		"stack_limit": 10,
		"places": WorldObjectTypes.STOOL,
	},
	&"cupboard":
	{
		"name": "Joined cupboard",
		"description":
		"An oak cupboard with panelled doors, a master's piece. It stands in a house.",
		"weight": 10.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.CUPBOARD,
	},
	&"sales_cart":
	{
		"name": "Sales cart",
		"description":
		"A hand cart with a board. Stock it and set a price, and the neighbours buy.",
		"weight": 12.0,
		"stack_limit": 1,
		"places": WorldObjectStall.SALES_CART,
	},
}
