extends EnergyCase
## Passing out and sleeping.


## Walks into a new house, sleeps in its bed (making it home) and walks out again.
func _make_a_house_home() -> WorldObject:
	var house: Building
	for y in range(-12, 13):
		for x in range(-12, 13):
			house = (
				house
				if house != null
				else _world.place_building(
					BuildingTypes.SMALL_HOUSE, _state.player.tile() + Vector2i(x, y)
				)
			)
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	var bed: WorldObject = house.interior.object_at(Vector2i(1, 2))
	_state.player.position = Vector2(2.5, 3.5)
	_state.sleep_in(bed)
	_state.player.position = Vector2(house.interior.exit_tile) + Vector2(0.5, 0.5)
	_state.pass_door()
	return bed


# --- Passing out ---


func test_passing_out_wakes_in_the_home_bed_at_six_the_next_day() -> void:
	_state.clock.set_time(20, 30)
	_state.player.position += Vector2(5, 0)
	_state.pass_out()
	assert_eq(_state.clock.day, 2)
	assert_eq(_state.clock.minute_of_day, GameState.WAKE_UP_MINUTE)
	assert_eq(_state.player.tile(), _state.player.home_bed)
	assert_eq(_state.current_map, _world)


func test_passing_out_before_six_wakes_the_same_morning() -> void:
	_state.clock.set_time(2, 0)
	_state.pass_out()
	assert_eq(_state.clock.day, 1)
	assert_eq(_state.clock.minute_of_day, GameState.WAKE_UP_MINUTE)


func test_passing_out_at_six_sharp_wakes_the_next_day() -> void:
	_state.clock.set_time(6, 0)
	_state.pass_out()
	assert_eq(_state.clock.day, 2)
	assert_eq(_state.clock.minute_of_day, GameState.WAKE_UP_MINUTE)


func test_passing_out_gives_the_debuff_values() -> void:
	_state.player.energy = 0.0
	_state.pass_out()
	assert_true(_state.player.is_debuffed)
	assert_eq(_state.player.energy, 40.0)
	assert_eq(_state.player.health, 20.0)
	assert_eq(_state.walk_speed_factor(), 0.6)
	assert_eq(_state.energy_cap(), 40.0)


func test_passing_out_keeps_the_items() -> void:
	_state.player.inventory.add(ItemTypes.LOGS, 7)
	_state.pass_out()
	assert_eq(_state.player.inventory.count_of(ItemTypes.LOGS), 7)


func test_the_debuff_ends_at_the_next_new_day() -> void:
	_state.pass_out()
	_state.clock.advance(GameClock.MINUTES_PER_DAY - GameState.WAKE_UP_MINUTE - 1)
	assert_true(_state.player.is_debuffed, "still the same day")
	_state.clock.advance(1)
	assert_false(_state.player.is_debuffed)
	assert_eq(_state.energy_cap(), PlayerState.MAX_ENERGY)


func test_passing_out_wakes_beside_a_home_bed_inside_a_house() -> void:
	var bed := _make_a_house_home()
	assert_false(_state.is_inside())
	_state.pass_out()
	assert_true(_state.is_inside())
	assert_eq(_state.current_map, _state.player.home_map)
	assert_true(PlayerState.can_stand_at(_state.current_map, _state.player.position))
	assert_eq(_state.bed_in_reach(), bed)


func test_eating_works_inside_a_house() -> void:
	_make_a_house_home()
	_state.pass_out()
	assert_true(_state.is_inside())
	_state.player.energy = 30.0
	_state.player.inventory.add(ItemTypes.TURNIP, 1)
	_hold(ItemTypes.TURNIP)
	assert_true(_state.eat_held())
	assert_eq(_state.player.energy, 38.0)


# --- Sleeping ---


func test_sleeping_fills_energy_and_health_up_to_the_beds_value() -> void:
	_state.player.energy = 10.0
	_state.player.health = 50.0
	_state.sleep_in(_bed())
	assert_eq(_state.player.energy, 80.0)
	assert_eq(_state.player.health, 80.0)


func test_sleeping_never_lowers_energy() -> void:
	_state.player.energy = 90.0
	_state.sleep_in(_bed())
	assert_eq(_state.player.energy, 90.0)


func test_sleeping_during_a_debuff_day_fills_energy_only_to_the_cap() -> void:
	_state.pass_out()
	_state.clock.set_time(7, 0)
	_state.sleep_in(_bed())
	assert_true(_state.player.is_debuffed, "an 8 h sleep from 07:00 ends before midnight")
	assert_eq(_state.player.energy, 40.0)


func test_sleeping_through_midnight_ends_the_debuff() -> void:
	_state.pass_out()
	_state.clock.set_time(20, 0)
	_state.sleep_in(_bed())
	assert_false(_state.player.is_debuffed)
	assert_eq(_state.player.energy, 80.0)
