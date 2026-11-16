class_name ItemGear
extends RefCounted
## What the player gives, puts on an animal or carries, as data in ItemTypes `TYPES` (see there):
## the bone, the saddle and the lantern.

const TYPES := {
	&"bone":
	{
		"name": "Bone",
		"description": "A meaty bone. Give it to a dog, and it follows you for a while.",
		"weight": 0.3,
		"stack_limit": 20,
	},
	&"saddle":
	{
		"name": "Saddle",
		"description": "A riding saddle of leather. Put it on a horse, and you can ride it.",
		"weight": 8.0,
		"stack_limit": 1,
	},
	&"lantern":
	{
		"name": "Lantern",
		"description": "A horn lantern. Hold it and use it to fit a candle, then to light it.",
		"weight": 1.0,
		"stack_limit": 1,
		"held_sheet": "lantern",
	},
}
