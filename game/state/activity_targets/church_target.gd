class_name ChurchTarget
extends ActivityTarget
## The yard of the nearest church within `search_tiles` of the villager's home.


func kind() -> String:
	return "church"


func is_searched() -> bool:
	return true


func has_door() -> bool:
	return true


func spot_of(npc: Npc, _day: int, places: ActivityPlaces) -> Vector2:
	return places.church_yard_near(npc, places.rules.search_tiles(kind()))
