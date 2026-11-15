class_name QuestTalk
extends RefCounted
## What a villager says when the player speaks to them and they have a quest to give or have given
## (design/villagers/quests.md), and what the player gets when they hand it in. The game decides
## it all here (`greet`): the lines are those of the quest's file. They are said as lines of the
## chat (`say`), either as the file has them or, when the profile has quest lines on and the model
## answers, in the villager's own words (see QuestVoice).

const LOG_FULL_TEXT := "Your quest log is full."
## Said when a quest's file has no `short` line: too little was brought.
const DEFAULT_SHORT_TEXT := "Not yet, neighbour. {have} of {count}."

## What the lines are for, which a model is told so that it voices them rightly.
const GIVE := &"give"
const REMIND := &"remind"
const SHORT := &"short"
const TURN_IN := &"turn_in"

## What a giver last had to say as a reminder or short line, kept on them (see `_unless_last`).
const LAST_MEANING_META := &"quest_last_meaning"


## What the villager has to say after the player spoke to them.
class Saying:
	## The fixed lines of the quest's file, in order; none if there is nothing to say.
	var lines: Array[String] = []
	## What they are for: GIVE, REMIND, SHORT or TURN_IN.
	var intent := &""
	## What the player is told instead when they can't take a quest, or "".
	var refusal := ""

	func _init(saying_intent := &"", saying_lines: Array[String] = []) -> void:
		intent = saying_intent
		lines = saying_lines


## The villager's part when the player speaks to them, with all it does to the game done. A quest
## that is posted is taken, and its `dialogue` is to be said in full. One that is taken and whose
## item is in the player's hand (see QuestObjective `is_offered`) is handed in when the player has
## enough (the `turn_in` lines are to be said, and the reward is the player's, see `complete`) and
## else answered with the `short` line; with no item in hand the first line of the `dialogue`
## recalls it. A quest the player can't take (the log is full) gives a `refusal` and no lines. A
## line that the villager said last is not said again.
static func greet(state: GameState, giver: Npc) -> Saying:
	var quests := state.quests
	var entry := quests.entry_of_giver(giver.id)
	if entry.is_empty():
		return Saying.new()
	var quest := quests.rules.quest(entry["id"])
	if not entry["is_taken"]:
		if quests.is_log_full():
			var refused := Saying.new()
			refused.refusal = LOG_FULL_TEXT
			return refused
		quests.take(entry)
		giver.remove_meta(LAST_MEANING_META)
		return Saying.new(GIVE, _strings(quest["dialogue"]))
	var objective: Dictionary = quest["objective"]
	var kind := quests.rules.objective_of(entry["id"])
	if not kind.is_offered(objective, quests):
		return _unless_last(giver, REMIND, quest["dialogue"][0])
	var have := kind.progress(objective, entry, quests)
	if have < kind.goal(objective):
		var short: String = quest.get("short", DEFAULT_SHORT_TEXT)
		return _unless_last(
			giver, SHORT, short.format({"have": have, "count": kind.goal(objective)})
		)
	kind.hand_over(objective, quests)
	giver.remove_meta(LAST_MEANING_META)
	return Saying.new(TURN_IN, complete(state, entry))


## `greet`, with the lines said at once as the file has them (what the villager says with no model
## to word them). Returns what the player is told instead of a quest they can't take, or "".
static func greet_and_say(state: GameState, giver: Npc) -> String:
	var saying := greet(state, giver)
	say(state, giver, saying.lines)
	return saying.refusal


## The villager says `lines` as lines of their chat, now.
static func say(state: GameState, giver: Npc, lines: Array[String]) -> void:
	for line in lines:
		giver.add_chat_line(state.clock.day, state.clock.minute_of_day, false, line)


## The quest is done: the player gets the reward, what does not fit in the bag at their feet, the
## village hears that they helped (see DeedLog `record_help`) and the quest is no longer open.
## Returns the `turn_in` lines its giver is to say.
static func complete(state: GameState, entry: Dictionary) -> Array[String]:
	var quests := state.quests
	var quest := quests.rules.quest(entry["id"])
	var giver := state.npcs.find(entry["giver"])
	quests.finish(entry["id"])
	var steps: int = quest["reward"].get("opinion_steps", 0)
	if giver != null and steps > 0:
		state.deeds.record_help(giver, steps, state.player.position)
	var items: Dictionary = quest["reward"].get("items", {})
	for item: String in items:
		var left := state.player.inventory.add(StringName(item), items[item])
		if left > 0:
			state.current_map.drop_items(state.player.tile(), {StringName(item): left})
	return _strings(quest["turn_in"])


## A reminder (or short line) is not said again while it is the last thing the giver said of the
## quest and the player has said nothing since. It is remembered by what it means, not by its
## words, which a model may have changed. Not saved.
static func _unless_last(giver: Npc, intent: StringName, line: String) -> Saying:
	var meaning := "%s|%s" % [intent, line]
	var history := giver.chat_history
	var is_repeat: bool = (
		giver.get_meta(LAST_MEANING_META, "") == meaning
		and not history.is_empty()
		and not history.back()["from_player"]
	)
	if is_repeat:
		return Saying.new()
	giver.set_meta(LAST_MEANING_META, meaning)
	return Saying.new(intent, [line] as Array[String])


static func _strings(lines: Array) -> Array[String]:
	var found: Array[String] = []
	found.assign(lines)
	return found
