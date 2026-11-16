extends RefCounted
## Version 55 had no storm surge or water on the land (#103): none is expected, and no tile is wet,
## salty or muddy.


static func upgrade(game: Dictionary) -> void:
	var world: Dictionary = game["world"]
	world["surge"] = {"level_cm": 0, "peak_minute": 0, "hold_minutes": 0, "last_rolled_tide": -1}
	world["flood"] = {"phase": "idle", "level_cm": 0, "drain_minute": 0}
	for key in ["flood_wet", "flood_salt", "flood_mud", "flood_repairs", "flood_met_chunks"]:
		world[key] = []
