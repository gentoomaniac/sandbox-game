class_name ItemClothing
extends RefCounted
## What the player wears as data, loaded into ItemTypes `TYPES` (see there for the entries).

const TYPES := {
	&"waistcoat":
	{
		"name": "Waistcoat",
		"description": "A red wool waistcoat with tin buttons, over a linen shirt.",
		"weight": 0.6,
		"stack_limit": 1,
		"equip_slot": Equipment.BODY,
		"layer_variant": "0",
	},
	&"shirt":
	{
		"name": "Linen shirt",
		"description": "A plain linen shirt, cool in the summer sun.",
		"weight": 0.3,
		"stack_limit": 1,
		"equip_slot": Equipment.BODY,
		"layer_variant": "1",
	},
	&"breeches":
	{
		"name": "Breeches",
		"description": "Brown wool knee breeches, with white knitted stockings.",
		"weight": 0.5,
		"stack_limit": 1,
		"equip_slot": Equipment.LEGS,
		"layer_variant": "0",
	},
	&"straw_hat":
	{
		"name": "Straw hat",
		"description": "Keeps the sun off your head.",
		"weight": 0.3,
		"stack_limit": 1,
		"equip_slot": Equipment.HEAD,
		"layer_variant": "straw_hat",
	},
	&"knitted_cap":
	{
		"name": "Knitted cap",
		"description": "A red wool stocking cap, warm in the wind.",
		"weight": 0.1,
		"stack_limit": 1,
		"equip_slot": Equipment.HEAD,
		"layer_variant": "knitted_cap",
	},
	&"jacket":
	{
		"name": "Jacket",
		"description": "A short jacket of blue wool, worn open over the waistcoat.",
		"weight": 0.5,
		"stack_limit": 1,
		"equip_slot": Equipment.COAT,
		"layer_variant": "jacket",
	},
	&"clogs":
	{
		"name": "Clogs",
		"description": "Wooden clogs, for the fields and the mud.",
		"weight": 0.3,
		"stack_limit": 1,
		"equip_slot": Equipment.FEET,
		"layer_variant": "clogs",
	},
}
