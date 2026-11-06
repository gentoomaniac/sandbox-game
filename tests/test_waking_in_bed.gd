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


func test_every_bed_blocks_walking_but_the_bedroll() -> void:
	for type: StringName in WorldObjectTypes.TYPES:
		if WorldObjectTypes.TYPES[type].has("bed"):
			var is_bedroll := type == WorldObjectTypes.SLEEPING_BAG
			assert_eq(WorldObjectTypes.TYPES[type]["blocks_walking"], not is_bedroll, type)


func test_the_player_cannot_walk_into_a_bed() -> void:
	var bed := _make_a_house_home()
	_state.pass_out()
	var map := _state.current_map
	_state.player.bed_lying_in = null
	_state.player.position = Vector2(2.5, 3.5)
	_state.player.move(map, Vector2.LEFT, 0.5)
	assert_gt(_state.player.position.x, 2.0, "stopped at the bed")
	assert_true(PlayerState.can_stand_at(map, _state.player.position))
	assert_eq(map.object_at(Vector2i(1, 2)), bed)


func test_getting_out_of_bed_goes_to_the_side_pressed() -> void:
	_make_a_house_home()
	_state.pass_out()
	_state.player.move(_state.current_map, Vector2.RIGHT, 0.0)
	assert_eq(_state.player.tile().x, 2)
	assert_null(_state.player.bed_lying_in)
	_state.player.move(_state.current_map, Vector2.RIGHT, 0.2)
	assert_gt(_state.player.position.x, 2.5, "walking on")


func test_getting_out_of_bed_towards_a_wall_goes_to_the_front() -> void:
	_make_a_house_home()
	for direction in [Vector2.LEFT, Vector2.UP]:
		_state.pass_out()
		_state.player.move(_state.current_map, direction, 0.0)
		assert_eq(_state.player.tile(), Vector2i(1, 4), "in front of the foot of the bed")


func test_getting_out_of_any_house_bed_never_goes_behind_it_or_into_a_wall() -> void:
	for type: StringName in BuildingTypes.ids():
		if type == BuildingTypes.BARN:
			continue
		var interior := InteriorLoader.load_interior(BuildingTypes.TYPES[type]["interior_map"])
		var beds := interior.objects().filter(func(o: WorldObject) -> bool: return o.is_bed())
		var bed: WorldObject = beds[0]
		var head := Vector2(bed.type_data()["bed"])
		var footprint := Vector2(bed.type_data()["footprint"])
		var middle := Vector2(bed.pos) + footprint / 2.0
		var half_length := (absf(head.x) * footprint.x + absf(head.y) * footprint.y) / 2.0
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var player := PlayerState.new()
			player.position = middle
			player.bed_lying_in = bed
			player.move(interior, direction, 0.0)
			var label := "%s %s" % [type, direction]
			assert_null(player.bed_lying_in, label)
			assert_true(PlayerState.can_stand_at(interior, player.position), label)
			assert_lt((player.position - middle).dot(head), half_length, "%s: not behind" % label)


func test_reset_and_then_a_move_works() -> void:
	_make_a_house_home()
	_state.player.position = Vector2(3.5, 3.5)
	_state.go_to_home_bed()
	_state.player.move(_state.current_map, Vector2.DOWN, 0.5)
	assert_gt(_state.player.position.y, 4.0)


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
	assert_true(PlayerState.can_stand_at(loaded.current_map, loaded.player.position))
