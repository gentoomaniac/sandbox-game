class_name QuestRows
extends RefCounted
## What the player's list of quests shows (the quests tab of the character window): a row for each
## quest they have taken, the oldest first, with who gave it, what it asks, how far they are, the
## days left and the reward. A quest that is only posted, not taken, is not in it. Plain state: the
## panel only draws these.

const LAST_DAY_TEXT := "last day"
const DAYS_LEFT_TEXT := "%d days left"
const REWARD_TEXT := "Reward: %s"
const GOODWILL_TEXT := "goodwill in the village"


## The rows, each `{giver, what, progress, days_left, reward}` of texts.
static func of(state: GameState) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var quests := state.quests
	for entry in quests.open_entries():
		if entry["is_taken"]:
			rows.append(_row_of(entry, state))
	return rows


## Who a villager is, for the player's list and the notice board: "Antje Boysen, a farmer's wife".
static func giver_text(state: GameState, villager: String) -> String:
	var npc := state.npcs.find(villager)
	return villager if npc == null else "%s, %s" % [npc.name, npc.trade]


static func _row_of(entry: Dictionary, state: GameState) -> Dictionary:
	var quests := state.quests
	var quest := quests.rules.quest(entry["id"])
	var objective: Dictionary = quest["objective"]
	var kind := quests.rules.objective_of(entry["id"])
	var days_left := quests.rules.last_day_of(entry) - state.clock.day + 1
	return {
		"giver": giver_text(state, entry["giver"]),
		"what": kind.what(objective),
		"progress": kind.status(objective, kind.progress(objective, entry, quests)),
		"days_left": LAST_DAY_TEXT if days_left <= 1 else DAYS_LEFT_TEXT % days_left,
		"reward": REWARD_TEXT % _reward_text(quest["reward"]),
	}


static func _reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	var items: Dictionary = reward.get("items", {})
	for item: String in items:
		parts.append("%d %s" % [items[item], ItemTypes.TYPES[StringName(item)]["name"].to_lower()])
	if reward.get("opinion_steps", 0) > 0:
		parts.append(GOODWILL_TEXT)
	return " and ".join(parts)
