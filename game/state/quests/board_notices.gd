class_name BoardNotices
extends RefCounted
## What the notice board says (E on it, design/villagers/quests.md): the rough line of each quest
## that is posted and not taken yet, with whom to see, the oldest first. It does not give the quest:
## the villager does, when the player speaks to them.

const NOTHING_NEW_TEXT := "Nothing new on the board."


## The lines, one per posted quest ("Fibre is wanted for the bean rows. Go and see Antje Boysen, a
## farmer's wife."), or the line that says there is nothing.
static func lines(state: GameState) -> Array[String]:
	var found: Array[String] = []
	for entry in state.quests.open_entries():
		if not entry["is_taken"]:
			var notice: String = state.quests.rules.quest(entry["id"])["notice"]
			found.append(notice.format({"giver": QuestRows.giver_text(state, entry["giver"])}))
	if found.is_empty():
		found.append(NOTHING_NEW_TEXT)
	return found


## Whether any quest is posted that the player has not taken: what the "!" over the board shows.
static func has_news(state: GameState) -> bool:
	return state.quests.open_entries().any(
		func(entry: Dictionary) -> bool: return not entry["is_taken"]
	)
