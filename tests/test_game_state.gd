extends GutTest

const SEED := 7

var _state: GameState


func before_each() -> void:
	_state = GameState.new_game(SEED)


func _bed() -> WorldObject:
	return _state.world.object_at(_state.player.home_bed)


func test_new_game_starts_at_the_camp_with_home_at_the_sleeping_bag() -> void:
	assert_eq(_bed().type, WorldObjectTypes.SLEEPING_BAG)
	assert_true(_state.world.is_walkable(_state.player.tile()))
	assert_eq(_state.clock.minute_of_day, GameClock.START_MINUTE)


func test_new_game_is_deterministic() -> void:
	var other := GameState.new_game(SEED)
	assert_eq(other.player.position, _state.player.position)
	assert_eq(other.player.home_bed, _state.player.home_bed)


func test_a_bed_is_in_reach_at_the_camp() -> void:
	assert_eq(_state.bed_in_reach(), _bed())


func test_no_bed_in_reach_far_away() -> void:
	_state.player.position += Vector2(5, 5)
	assert_null(_state.bed_in_reach())


func test_sleeping_wakes_at_half_past_six_the_next_morning() -> void:
	_state.clock.set_time(22, 0)
	_state.sleep_in(_bed())
	assert_eq(_state.clock.day, 2)
	assert_eq(_state.clock.time_text(), "06:30")


func test_sleeping_after_midnight_wakes_the_same_morning() -> void:
	_state.clock.set_time(3, 15)
	_state.sleep_in(_bed())
	assert_eq(_state.clock.day, 1)
	assert_eq(_state.clock.time_text(), "06:30")


func test_sleeping_at_half_past_six_sharp_wakes_the_next_morning() -> void:
	_state.clock.set_time(6, 30)
	_state.sleep_in(_bed())
	assert_eq(_state.clock.day, 2)
	assert_eq(_state.clock.time_text(), "06:30")


func test_every_bed_wakes_at_the_same_time() -> void:
	for bed_type in [WorldObjectTypes.SLEEPING_BAG, WorldObjectTypes.SMALL_BED]:
		_state.clock.set_time(21, 0)
		var bed := WorldObject.new(bed_type, _state.player.tile())
		assert_true(bed.is_bed(), bed_type)
		_state.sleep_in(bed)
		assert_eq(_state.clock.time_text(), "06:30", bed_type)


func test_sleeping_sets_home() -> void:
	var other_bed := WorldObject.new(
		WorldObjectTypes.SLEEPING_BAG, _state.player.tile() + Vector2i(0, 2)
	)
	_state.world.add_object(other_bed)
	_state.sleep_in(other_bed)
	assert_eq(_state.player.home_bed, other_bed.pos)


func test_a_fireplace_is_no_bed() -> void:
	var fireplace := WorldObject.new(WorldObjectTypes.FIREPLACE, Vector2i.ZERO)
	assert_false(fireplace.is_bed())
