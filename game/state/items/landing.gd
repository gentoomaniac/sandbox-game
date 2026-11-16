class_name ItemLanding
extends RefCounted
## The fisherman landing, as data in ItemTypes `TYPES` (see there): jetty, boat, net frame, traps.

const TYPES := {
	&"jetty":
	{
		"name": "Jetty",
		"description":
		"A piece of plank jetty on oak piles. Laid over water or mud, it is walked on.",
		"weight": 6.0,
		"stack_limit": 20,
		"places": WorldObjectTypes.JETTY,
	},
	&"rowing_boat":
	{
		"name": "Rowing boat",
		"description": "A flat-bottomed boat for the tideways. It lies on water or mud.",
		"weight": 40.0,
		"stack_limit": 1,
		"places": WorldObjectTypes.ROWING_BOAT,
	},
	&"net_frame":
	{
		"name": "Net frame",
		"description": "Two forked posts and a pole, with a fishing net hung on it to dry.",
		"weight": 8.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.NET_FRAME,
	},
	&"eel_traps":
	{
		"name": "Eel traps",
		"description": "Wicker traps for eels, laid in the tideways at night.",
		"weight": 2.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.EEL_TRAPS,
	},
}
