class_name ActivityTarget
extends RefCounted
## A kind of place an activity of data/activities.cfg is done at (its `target`). One kind is one
## script in game/state/activity_targets that extends this (see ActivityTargets); a new kind is a
## new file there and no other code.


## The word data/activities.cfg names the kind by.
func kind() -> String:
	return ""


## Whether it is looked for within the `search_tiles` of the rules of the villager's home, so the
## file has to give those tiles.
func is_searched() -> bool:
	return false


## Whether it is a building with a door, so an activity there may be `inside`.
func has_door() -> bool:
	return false


## Whether its spot is only looked for when the entry is on (the land far from the player is not
## loaded), so a villager has the activity in their day, and is offered it, with no spot yet.
func is_found_when_on() -> bool:
	return false


## The spot of the target for `npc` on game day `day`, the middle of a tile, or
## `ActivityPlaces.NOWHERE` if they have none. `places` knows the world and the rules. The same day
## gives the same spot for the same villager.
func spot_of(_npc: Npc, _day: int, _places: ActivityPlaces) -> Vector2:
	return ActivityPlaces.NOWHERE
