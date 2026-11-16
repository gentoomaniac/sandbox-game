extends SaveValidationCase
## The village's record in the world: saved and loaded with it, old saves have none, and a damaged
## record is refused (design/world/wehlsbuell.md, section 12).


## A shack of the world, which the record names.
func _state_with_a_village() -> GameState:
	var state := GameFactory.new_game(7)
	var origin := Vector2i.ZERO
	for x in range(-10, 10):
		if state.world.placement_blockers(BuildingTypes.SHACK, Vector2i(x, 9)).is_empty():
			origin = Vector2i(x, 9)
			break
	assert_not_null(state.world.place_building(BuildingTypes.SHACK, origin))
	var village := Village.new()
	village.village_name = "Wehlsbüll"
	village.area = Rect2i(-20, -10, 80, 60)
	village.meeting_spot = Vector2i(10, 10)
	village.square = Rect2i(5, 5, 13, 6)
	village.mill_spot = Rect2i(30, 20, 7, 7)
	village.field_spots = [Vector2i(20, 20)]
	village.building_origins = [origin]
	state.world.village = village
	return state


func _saved_village() -> Dictionary:
	return JSON.parse_string(JSON.stringify(GameCodec.to_dict(_state_with_a_village())))


func test_a_world_without_a_village_saves_null_and_loads_without_one() -> void:
	var state := GameFactory.new_game(7)
	assert_null(state.world.village)
	assert_null(GameCodec.to_dict(state)["world"]["village"])
	assert_true(SaveFile.write(state, SAVE_PATH))

	assert_null(SaveFile.read(SAVE_PATH).world.village)


func test_the_record_survives_a_save_and_a_load() -> void:
	var state := _state_with_a_village()
	state.world.village.is_populated = true
	assert_true(SaveFile.write(state, SAVE_PATH))

	var village := SaveFile.read(SAVE_PATH).world.village

	assert_eq(village.to_dict(), state.world.village.to_dict())
	assert_eq(village.village_name, "Wehlsbüll")
	assert_eq(village.area, Rect2i(-20, -10, 80, 60))
	assert_eq(village.field_spots, [Vector2i(20, 20)] as Array[Vector2i])
	assert_true(village.is_populated)


func test_a_version_48_save_loses_the_worn_tiles_the_village_kept() -> void:
	var game := _saved_village()
	game["world"]["village"]["kept_worn_tiles"] = [[0, 12], [1, 12]]
	_write_save(48, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_eq(restored.world.village.village_name, "Wehlsbüll")


func test_a_version_48_save_with_no_village_loads_with_none() -> void:
	_write_save(48, _current_game())

	assert_null(SaveFile.read(SAVE_PATH).world.village)


func test_a_current_save_without_the_field_is_refused() -> void:
	var game := _current_game()
	game["world"].erase("village")

	assert_string_contains(_refusal_of(game).reason, "world: no village")


func test_an_area_with_nothing_in_it_is_named() -> void:
	var game := _saved_village()
	game["world"]["village"]["area"] = [0, 0, 0, 10]

	assert_string_contains(_refusal_of(game).reason, "world village: the area is empty")


func test_a_square_or_a_meeting_spot_outside_the_area_is_named() -> void:
	var game := _saved_village()
	game["world"]["village"]["square"] = [100, 100, 13, 6]
	game["world"]["village"]["meeting_spot"] = [-500, 0]

	var reason := _refusal_of(game).reason

	assert_string_contains(reason, "the square is not inside the area")
	assert_string_contains(reason, "the meeting spot is not inside the area")


func test_a_building_that_does_not_stand_is_named() -> void:
	var game := _saved_village()
	game["world"]["village"]["building_origins"].append([900, 900])

	assert_string_contains(
		_refusal_of(game).reason, "building_origins 1 is no building of the world"
	)


func test_a_record_of_the_wrong_shape_is_named() -> void:
	var game := _saved_village()
	game["world"]["village"]["name"] = 7
	game["world"]["village"].erase("field_spots")

	var reason := _refusal_of(game).reason

	assert_string_contains(reason, "world village name: should be text")
	assert_string_contains(reason, "world village: no field_spots")


func test_field_spots_that_are_not_tiles_are_named() -> void:
	var game := _saved_village()
	game["world"]["village"]["field_spots"] = [[1, 2], "far"]

	assert_string_contains(_refusal_of(game).reason, "field_spots should be a list of [x, y]")


func test_the_land_includes_its_edge_tiles_and_stops_there() -> void:
	var world := _state_with_a_village().world
	var area := world.village.area
	assert_true(world.is_village_land(area.position))
	assert_true(world.is_village_land(area.end - Vector2i.ONE))
	assert_false(world.is_village_land(area.end))
	assert_false(world.is_village_land(area.position - Vector2i.ONE))
	assert_false(
		GameFactory.new_game(7).world.is_village_land(Vector2i.ZERO), "no village, no land"
	)


func test_the_villages_buildings_are_the_ones_the_record_names() -> void:
	var world := _state_with_a_village().world
	var village_shack := world.building_at(world.village.building_origins[0])
	assert_true(world.is_village_building(village_shack))
	var own: Building
	for x in range(-40, 40, 6):
		own = world.place_building(BuildingTypes.SHACK, Vector2i(x, -20))
		if own != null:
			break
	assert_not_null(own)
	assert_false(world.is_village_building(own))
