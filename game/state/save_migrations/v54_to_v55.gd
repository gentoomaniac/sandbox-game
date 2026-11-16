extends RefCounted
## Version 54 had no dyke values (#103): every dyke is as the generator lays it, and the dykes
## the game changes keep their height and strength in the state of their object, so nothing in the
## data changes.


static func upgrade(_game: Dictionary) -> void:
	pass
