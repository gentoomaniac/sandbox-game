extends ActivityTarget
## A kind added as a file: an inn with a door, at one spot, for the test of ActivityTargets.

const SPOT := Vector2(70.5, 70.5)


func kind() -> String:
	return "inn"


func has_door() -> bool:
	return true


func spot_of(_npc: Npc, _day: int, _places: ActivityPlaces) -> Vector2:
	return SPOT
