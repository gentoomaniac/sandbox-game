class_name QuestCondition
extends RefCounted
## What must hold for a quest to be posted. One kind is one script in
## game/state/quests/conditions that extends this (see KindFolder); the quest file names it by
## `type` in its `requires` and gives the fields it needs.


## The word the quest file names the kind by.
func kind() -> String:
	return ""


## What is wrong with an entry of the quest's `requires` for this kind. `quest_ids` are the quests
## there are.
func problems(_fields: Dictionary, _quest_ids: Array[String]) -> Array[String]:
	return []


## Whether it holds for a quest that `giver` (a villager id) would give.
func is_met(_fields: Dictionary, _giver: String, _quests: Quests) -> bool:
	return false
