class_name WorkplaceTarget
extends ActivityTarget
## The villager's workplace; with none, the yard of their home.


func kind() -> String:
	return "workplace"


func has_door() -> bool:
	return true


func spot_of(npc: Npc, day: int, places: ActivityPlaces) -> Vector2:
	return places.spot_of(npc, "home", day) if npc.workplace == null else npc.workplace.spot()
