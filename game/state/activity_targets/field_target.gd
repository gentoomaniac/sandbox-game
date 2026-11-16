class_name FieldTarget
extends ActivityTarget
## The nearest tilled tile or field of the village within `search_tiles` of the villager's home;
## with none, a workplace that is a spot (the fields have no building); with none, nowhere.


func kind() -> String:
	return "field"


func is_searched() -> bool:
	return true


func spot_of(npc: Npc, _day: int, places: ActivityPlaces) -> Vector2:
	var home := places.home_point(npc)
	var nearest := ActivityPlaces.NOWHERE
	var nearest_distance := places.rules.search_tiles(kind())
	var tiles := places.world.tilled_tiles()
	if places.world.village != null:
		tiles.append_array(places.world.village.field_spots)
	for tile in tiles:
		var centre := Vector2(tile) + Vector2(0.5, 0.5)
		if centre.distance_to(home) <= nearest_distance:
			nearest = centre
			nearest_distance = centre.distance_to(home)
	if (
		nearest == ActivityPlaces.NOWHERE
		and npc.workplace != null
		and npc.workplace.building == null
	):
		return npc.workplace.spot()
	return nearest
