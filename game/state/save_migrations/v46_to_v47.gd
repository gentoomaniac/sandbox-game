extends RefCounted
## Version 46 had no plans of the villagers' days from the language model (#7): every villager has
## the default day until the planner asks.


static func upgrade(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		npc["day_plans"] = []
