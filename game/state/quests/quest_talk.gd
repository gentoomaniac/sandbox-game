class_name QuestTalk
extends RefCounted
## What a villager says when the player speaks to them and they have a quest to give or have given
## (design/villagers/quests.md): the lines of the quest's file, said as lines of their chat. The
## model's own words come on top of this (see NpcDialogue).

const LOG_FULL_TEXT := "Your quest log is full."


## The villager says what they have to say of their quest. A quest that is posted is taken, and its
## `dialogue` is said in full; one that is taken is recalled with the first line of it. Returns what
## the player is told instead when they can't take it, or "".
static func greet(state: GameState, giver: Npc) -> String:
	var entry := state.quests.entry_of_giver(giver.id)
	if entry.is_empty():
		return ""
	var lines: Array = state.quests.rules.quest(entry["id"])["dialogue"]
	if entry["is_taken"]:
		var history := giver.chat_history
		if history.is_empty() or history.back()["text"] != lines[0]:
			_say(state, giver, lines.slice(0, 1))
		return ""
	if state.quests.is_log_full():
		return LOG_FULL_TEXT
	state.quests.take(entry)
	_say(state, giver, lines)
	return ""


static func _say(state: GameState, giver: Npc, lines: Array) -> void:
	for line: String in lines:
		giver.add_chat_line(state.clock.day, state.clock.minute_of_day, false, line)
