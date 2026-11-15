class_name QuestTalk
extends RefCounted
## What a villager says when the player speaks to them and they have a quest to give or have given
## (design/villagers/quests.md): the lines of the quest's file, said as lines of their chat, and
## what the player gets when they hand it in. The model's own words come on top of this (see
## NpcDialogue).

const LOG_FULL_TEXT := "Your quest log is full."
## Said when a quest's file has no `short` line: too little was brought.
const DEFAULT_SHORT_TEXT := "Not yet, neighbour. {have} of {count}."


## The villager says what they have to say of their quest, and the player may hand it in. A quest
## that is posted is taken, and its `dialogue` is said in full. One that is taken and whose item is
## in the player's hand (see QuestObjective `is_offered`) is handed in when the player has enough
## (the `turn_in` lines and the reward follow, see `complete`) and else answered with the `short`
## line; with no item in hand the first line of the `dialogue` recalls it. Returns what the player
## is told instead when they can't take a quest, or "".
static func greet(state: GameState, giver: Npc) -> String:
	var quests := state.quests
	var entry := quests.entry_of_giver(giver.id)
	if entry.is_empty():
		return ""
	var quest := quests.rules.quest(entry["id"])
	if not entry["is_taken"]:
		if quests.is_log_full():
			return LOG_FULL_TEXT
		quests.take(entry)
		_say(state, giver, quest["dialogue"])
		return ""
	var objective: Dictionary = quest["objective"]
	var kind := quests.rules.objective_of(entry["id"])
	if not kind.is_offered(objective, quests):
		_say_unless_last(state, giver, quest["dialogue"][0])
		return ""
	var have := kind.progress(objective, entry, quests)
	if have < kind.goal(objective):
		var short: String = quest.get("short", DEFAULT_SHORT_TEXT)
		var line := short.format({"have": have, "count": kind.goal(objective)})
		_say_unless_last(state, giver, line)
		return ""
	kind.hand_over(objective, quests)
	complete(state, entry)
	return ""


## The quest is done: its giver says the `turn_in` lines and the player gets the reward, what does
## not fit in the bag at their feet.
static func complete(state: GameState, entry: Dictionary) -> void:
	var quests := state.quests
	var quest := quests.rules.quest(entry["id"])
	var giver := state.npcs.find(entry["giver"])
	quests.finish(entry["id"])
	if giver != null:
		_say(state, giver, quest["turn_in"])
	var items: Dictionary = quest["reward"].get("items", {})
	for item: String in items:
		var left := state.player.inventory.add(StringName(item), items[item])
		if left > 0:
			state.current_map.drop_items(state.player.tile(), {StringName(item): left})


static func _say(state: GameState, giver: Npc, lines: Array) -> void:
	for line: String in lines:
		giver.add_chat_line(state.clock.day, state.clock.minute_of_day, false, line)


## A reminder is not said again while it is the last thing said.
static func _say_unless_last(state: GameState, giver: Npc, line: String) -> void:
	var history := giver.chat_history
	if history.is_empty() or history.back()["text"] != line:
		_say(state, giver, [line])
