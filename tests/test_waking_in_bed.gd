extends EnergyCase
## Waking after sleeping or passing out puts the player in the middle of the bed.


func _middle_of(bed: WorldObject) -> Vector2:
	return Vector2(bed.pos) + Vector2(bed.type_data()["footprint"]) / 2.0


func test_passing_out_wakes_in_the_middle_of_the_camp_bed() -> void:
	var bed := _bed()
	_state.player.position += Vector2(5, 0)
	_state.pass_out()
	assert_eq(_state.player.position, _middle_of(bed))
	assert_eq(_state.player.bed_lying_in, bed)


func test_sleeping_wakes_in_the_middle_of_the_bed() -> void:
	var bed := _bed()
	_state.sleep_in(bed)
	assert_eq(_state.player.position, _middle_of(bed))
	assert_eq(_state.player.bed_lying_in, bed)


func test_passing_out_wakes_in_the_middle_of_a_bed_in_a_house() -> void:
	var bed := _make_a_house_home()
	_state.pass_out()
	assert_true(_state.is_inside())
	assert_eq(_state.player.position, _middle_of(bed))
	assert_eq(_state.player.bed_lying_in, bed)


func test_the_player_gets_up_on_the_first_move() -> void:
	_state.sleep_in(_bed())
	_state.player.move(_state.current_map, Vector2.ZERO, 0.1)
	assert_not_null(_state.player.bed_lying_in, "standing still keeps them in bed")
	_state.player.move(_state.current_map, Vector2.RIGHT, 0.1)
	assert_null(_state.player.bed_lying_in)


func test_every_bed_can_be_walked_on() -> void:
	for type: StringName in WorldObjectTypes.TYPES:
		if WorldObjectTypes.TYPES[type].has("bed"):
			assert_false(WorldObjectTypes.TYPES[type]["blocks_walking"], type)


func test_the_player_can_walk_out_of_a_bed_in_a_house() -> void:
	_make_a_house_home()
	_state.pass_out()
	var start := _state.player.position
	_state.player.move(_state.current_map, Vector2.DOWN, 0.5)
	assert_gt(_state.player.position.y, start.y + 1.0)


func test_a_home_bed_that_is_gone_leaves_the_player_standing_on_its_tile() -> void:
	_world.remove_object(_state.player.home_bed)
	_state.pass_out()
	assert_eq(_state.player.tile(), _state.player.home_bed)
	assert_null(_state.player.bed_lying_in)


func test_a_game_saved_with_the_player_on_the_bed_loads_and_they_can_walk() -> void:
	_make_a_house_home()
	_state.pass_out()
	_state.player.position = Vector2(1.5, 2.5)
	var loaded := GameState.from_dict(_state.to_dict())
	assert_true(loaded.is_inside())
	loaded.player.move(loaded.current_map, Vector2.DOWN, 0.5)
	assert_gt(loaded.player.position.y, 4.0)
