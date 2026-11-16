extends RefCounted
## Version 47 had no villagers inside buildings (#8): they were all in the open, as they stand.


static func upgrade(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		npc["inside"] = null
