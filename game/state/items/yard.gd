class_name ItemYard
extends RefCounted
## What the player puts up in a yard, as data in ItemTypes `TYPES` (see there): well, troughs, pig
## pen, scarecrow, notice board and grave marker.

const TYPES := {
	&"draw_well":
	{
		"name": "Draw well",
		"description": "A fieldstone well with a sweep and a bucket. It stands outdoors.",
		"weight": 40.0,
		"stack_limit": 1,
		"places": WorldObjectTypes.DRAW_WELL,
	},
	&"trough":
	{
		"name": "Trough",
		"description": "An oak plank trough for the animals' water. It stands outdoors.",
		"weight": 25.0,
		"stack_limit": 2,
		"places": WorldObjectTypes.TROUGH,
	},
	&"hay_rack":
	{
		"name": "Hay rack",
		"description": "Oak posts with slats to keep hay for the animals. It stands outdoors.",
		"weight": 25.0,
		"stack_limit": 2,
		"places": WorldObjectTypes.HAY_RACK,
	},
	&"feed_trough":
	{
		"name": "Feeding trough",
		"description": "An oak plank trough for the animals' feed. It stands outdoors.",
		"weight": 25.0,
		"stack_limit": 2,
		"places": WorldObjectTypes.FEED_TROUGH,
	},
	&"pen_fence":
	{
		"name": "Pen fence",
		"description": "Split oak rails on a post, a piece of fence for a pig pen.",
		"weight": 4.0,
		"stack_limit": 20,
		"places": WorldObjectTypes.PEN_FENCE,
	},
	&"pen_gate":
	{
		"name": "Pen gate",
		"description": "A gate for a pig pen. Shut, it lets you through and keeps the animals in.",
		"weight": 10.0,
		"stack_limit": 4,
		"places": WorldObjectTypes.PEN_GATE,
	},
	&"pig_shelter":
	{
		"name": "Pig shelter",
		"description": "A lean-to of boards under reed thatch for the pigs. It stands outdoors.",
		"weight": 40.0,
		"stack_limit": 1,
		"places": WorldObjectTypes.PIG_SHELTER,
	},
	&"scarecrow":
	{
		"name": "Scarecrow",
		"description":
		"Stakes dressed in straw to keep the crows off the crops. They get used to it.",
		"weight": 6.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.SCARECROW,
	},
	&"notice_board":
	{
		"name": "Notice board",
		"description": "A board under a little roof for the village's notices. It stands outdoors.",
		"weight": 12.0,
		"stack_limit": 1,
		"places": WorldObjectTypes.NOTICE_BOARD,
	},
	&"grave_marker":
	{
		"name": "Grave marker",
		"description": "An oak cross for a grave. It stands outdoors.",
		"weight": 10.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.GRAVE,
	},
}
