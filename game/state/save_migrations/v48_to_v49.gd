extends RefCounted
## Version 48 kept the village's lane tiles worn in its record (`kept_worn_tiles`). The lanes are
## cobbled now (#9), so the list goes; the cobbles are not laid in a village that stands: its lanes
## stay as they were.


static func upgrade(game: Dictionary) -> void:
	var village: Variant = game["world"]["village"]
	if village != null:
		village.erase("kept_worn_tiles")
