extends RefCounted
## Version 51 had no quests (#12): none is posted or taken, and none was done.


static func upgrade(game: Dictionary) -> void:
	game["quests"] = {"open": [], "done": {}, "ended": {}}
