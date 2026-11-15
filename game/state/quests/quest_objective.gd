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


## How many of `goal` the player has of it now (a number the quest's list shows), for the quest of
## `entry`.
func progress(_fields: Dictionary, _entry: Dictionary, _quests: Quests) -> int:
	return 0


## What `progress` has to reach for the quest to be done.
func goal(_fields: Dictionary) -> int:
	return 1


## Whether the player shows the giver what is asked for, so that speaking to them hands it in: a
## kind that counts what is in the world is always offered.
func is_offered(_fields: Dictionary, _quests: Quests) -> bool:
	return true


## Takes what the quest asks for from the player, once `progress` has reached `goal`.
func hand_over(_fields: Dictionary, _quests: Quests) -> void:
	pass
