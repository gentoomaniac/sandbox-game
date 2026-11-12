extends EnergyCase
## Passing out and sleeping.

# --- Passing out ---


func test_passing_out_wakes_in_the_home_bed_the_next_morning() -> void:
	_state.clock.set_time(19, 0)
	_state.player.position += Vector2(5, 0)
	assert_eq(_state.pass_out(), 11 * GameClock.MINUTES_PER_HOUR + 30)
	assert_eq(_state.clock.day, 2)
	assert_eq(_state.clock.minute_of_day, GameState.WAKE_UP_MINUTE)
	assert_true(_bed().covers(_state.player.tile()))
	assert_eq(_state.current_map, _world)


func test_passing_out_late_in_the_evening_sleeps_at_least_ten_hours() -> void:
	_state.clock.set_time(22, 0)
	assert_eq(_state.pass_out(), 10 * GameClock.MINUTES_PER_HOUR)
	assert_eq(_state.clock.day, 2)
	assert_eq(_state.clock.time_text(), "08:00")


func test_passing_out_in_the_afternoon_wakes_at_half_past_six() -> void:
	_state.clock.set_time(15, 0)
	assert_eq(_state.pass_out(), 15 * GameClock.MINUTES_PER_HOUR + 30)
	assert_eq(_state.clock.day, 2)
	assert_eq(_state.clock.time_text(), "06:30")


func test_passing_out_after_midnight_wakes_ten_hours_later_the_same_day() -> void:
	_state.clock.set_time(2, 0)
	_state.pass_out()
	assert_eq(_state.clock.day, 1)
	assert_eq(_state.clock.time_text(), "12:00")


func test_passing_out_at_half_past_six_sharp_sleeps_a_whole_day() -> void:
	_state.clock.set_time(6, 30)
	assert_eq(_state.pass_out(), GameClock.MINUTES_PER_DAY)
	assert_eq(_state.clock.day, 2)
	assert_eq(_state.clock.time_text(), "06:30")


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
	_state.clock.set_time(20, 0)
	_state.pass_out()
	_state.pass_awake_time(GameClock.MINUTES_PER_DAY - _state.clock.minute_of_day - 1)
	assert_true(_state.player.is_debuffed, "still the same day")
	_state.pass_awake_time(1)
	assert_false(_state.player.is_debuffed)
	assert_eq(_state.energy_cap(), _state.player.attributes.max_energy())


func test_passing_out_after_midnight_keeps_the_debuff_until_the_next_midnight() -> void:
	_state.clock.set_time(1, 0)
	_state.pass_out()
	assert_eq(_state.clock.time_text(), "11:00")
	assert_true(_state.player.is_debuffed)
	_state.pass_awake_time(_state.clock.minutes_until(0) - 1)
	assert_true(_state.player.is_debuffed, "23:59")
	_state.pass_awake_time(1)
	assert_false(_state.player.is_debuffed)


func test_passing_out_wakes_in_a_home_bed_inside_a_house() -> void:
	var bed := _make_a_house_home()
	assert_false(_state.is_inside())
	_state.pass_out()
	assert_true(_state.is_inside())
	assert_eq(_state.current_map, _state.player.home_map)
	assert_eq(_state.player.bed_lying_in, bed)
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


func test_sleeping_after_midnight_wakes_the_same_morning() -> void:
	_state.pass_out()
	_state.clock.set_time(2, 0)
	_state.sleep_in(_bed())
	assert_true(_state.player.is_debuffed, "a sleep from 02:00 crosses no midnight")
	assert_eq(_state.clock.time_text(), "06:30")
	assert_eq(_state.player.energy, 40.0, "only up to the debuff's cap")


func test_sleeping_through_midnight_ends_the_debuff() -> void:
	_state.pass_out()
	_state.clock.set_time(20, 0)
	_state.sleep_in(_bed())
	assert_false(_state.player.is_debuffed)
	assert_eq(_state.player.energy, 80.0)


# --- The message after passing out ---


func test_the_message_says_what_happened_how_long_where_and_the_debuff() -> void:
	_state.clock.set_time(22, 0)
	var minutes := _state.pass_out()
	assert_eq(
		PassOutMessage.text(_state, false, minutes),
		(
			"You collapsed from exhaustion. You slept 10 hours and wake at the camp, still worn"
			+ " out: slow, weak and with 40 % of your energy until midnight."
		)
	)


func test_the_message_after_staying_up_too_late_with_home_in_a_house() -> void:
	_make_a_house_home()
	_state.energy_rules = EnergyRules.new(
		RULES.merged({"debuff": {"walk_speed": 0.5, "energy_max": 50.0, "health": 25.0}}, true)
	)
	_state.clock.set_time(15, 0)
	var minutes := _state.pass_out()
	assert_eq(
		PassOutMessage.text(_state, true, minutes),
		(
			"You stayed up far too late and collapsed. You slept 16 hours and wake at home, still"
			+ " worn out: slow, weak and with half your energy until midnight."
		)
	)
