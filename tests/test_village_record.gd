extends SaveValidationCase
## The village's record in the world: saved and loaded with it, old saves have none, and a damaged
## record is refused (design/world/wehlsbuell.md, section 12).


## A shack of the world, which the record names.
func _state_with_a_village() -> GameState:
	var state := GameState.new_game(7)
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
	village.kept_worn_tiles = [Vector2i(0, 12), Vector2i(1, 12)]
	village.field_spots = [Vector2i(20, 20)]
	village.building_origins = [origin]
	state.world.village = village
	return state


func _saved_village() -> Dictionary:
	return JSON.parse_string(JSON.stringify(_state_with_a_village().to_dict()))


func test_a_world_without_a_village_saves_null_and_loads_without_one() -> void:
	var state := GameState.new_game(7)
	assert_null(state.world.village)
	assert_null(state.to_dict()["world"]["village"])
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
	assert_eq(village.kept_worn_tiles, state.world.village.kept_worn_tiles)
	assert_eq(village.field_spots, [Vector2i(20, 20)] as Array[Vector2i])
	assert_true(village.is_populated)


func test_a_version_45_save_loads_with_no_village() -> void:
	var game := _current_game()
	game["world"].erase("village")
	_write_save(45, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_null(restored.world.village)


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
	game["world"]["village"].erase("kept_worn_tiles")

	var reason := _refusal_of(game).reason

	assert_string_contains(reason, "world village name: should be text")
	assert_string_contains(reason, "world village: no kept_worn_tiles")


func test_field_spots_that_are_not_tiles_are_named() -> void:
	var game := _saved_village()
	game["world"]["village"]["field_spots"] = [[1, 2], "far"]

	assert_string_contains(_refusal_of(game).reason, "field_spots should be a list of [x, y]")
