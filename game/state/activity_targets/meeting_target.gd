class_name MeetingTarget
extends ActivityTarget
## The meeting spot of the village if it is within `search_tiles` of the villager's home; else,
## where the world has no village, the yard of the church.


func kind() -> String:
	return "meeting"


func is_searched() -> bool:
	return true


func spot_of(npc: Npc, _day: int, places: ActivityPlaces) -> Vector2:
	var search := places.rules.search_tiles(kind())
	if places.world.village == null:
		return places.church_yard_near(npc, search)
	var spot := Vector2(places.world.village.meeting_spot) + Vector2(0.5, 0.5)
	return spot if spot.distance_to(places.home_point(npc)) <= search else ActivityPlaces.NOWHERE
