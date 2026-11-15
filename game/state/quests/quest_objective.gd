class_name QuestObjective
extends RefCounted
## What a quest asks of the player. One kind is one script in game/state/quests/objectives that
## extends this (see QuestKinds); the quest file names it by `type` and gives the fields it needs.


## The word the quest file names the kind by.
func kind() -> String:
	return ""


## What is wrong with the quest's `objective` dictionary for this kind.
func problems(_fields: Dictionary) -> Array[String]:
	return []


## What the quest asks for, in words for "X no longer needs the ...".
func thing(_fields: Dictionary) -> String:
	return ""
