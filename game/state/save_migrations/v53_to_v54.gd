extends RefCounted
## Version 53 had no money (#49): the player has the start purse, as in a new game. Written out, not
## read from data/prices.cfg, so a later change leaves old saves alone.


static func upgrade(game: Dictionary) -> void:
	game["player"]["money"] = 32
