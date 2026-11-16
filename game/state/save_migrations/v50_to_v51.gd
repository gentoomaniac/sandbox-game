extends RefCounted
## Version 50 had no shops (#10): none has been looked at, so each starts full when it is.


static func upgrade(game: Dictionary) -> void:
	game["shops"] = {}
