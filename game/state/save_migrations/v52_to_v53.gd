extends RefCounted
## Version 52 had no friendship besides the opinion (#48): no villager has taken a gift, counted a
## chat, moved the opinion by an action or asked for a word rating, and none is bound to the player.


static func upgrade(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		npc["action_day"] = 0
		npc["action_moved_today"] = 0
		npc["last_gift_day"] = 0
		npc["chat_counted_day"] = 0
		npc["rating_day"] = 0
		npc["ratings_today"] = 0
		npc["rating_moved_today"] = 0
		npc["bond"] = "none"
