class_name HomeTarget
extends ActivityTarget
## The yard of the villager's house; nowhere for one without a house.


func kind() -> String:
	return "home"


func has_door() -> bool:
	return true


func spot_of(npc: Npc, _day: int, _places: ActivityPlaces) -> Vector2:
	return ActivityPlaces.NOWHERE if npc.house == null else npc.house.yard()
