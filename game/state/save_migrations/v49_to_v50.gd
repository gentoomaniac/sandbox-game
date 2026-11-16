extends RefCounted
## Version 49 had no record of the land the player has seen (#104): none is explored, but the land
## about the player, which they see where they stand.


static func upgrade(game: Dictionary) -> void:
	game["explored"] = []
