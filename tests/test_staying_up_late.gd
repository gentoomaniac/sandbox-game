extends EnergyCase
## Staying up too late: a player still awake at 01:00 passes out.


func test_reaching_one_at_night_awake_is_staying_up_too_late() -> void:
	_state.clock.set_time(0, 58)
	_state.pass_awake_time(1)
	assert_false(_state.is_up_too_late, "00:59")
	_state.pass_awake_time(1)
	assert_true(_state.is_up_too_late, "01:00 sharp")


func test_time_that_passes_over_one_at_night_at_once_counts_too() -> void:
	_state.clock.set_time(23, 50)
	_state.pass_awake_time(90)
	assert_true(_state.is_up_too_late)


func test_time_awake_from_one_at_night_on_is_not_staying_up_again() -> void:
	_state.clock.set_time(1, 0)
	_state.pass_awake_time(10 * GameClock.MINUTES_PER_HOUR)
	assert_false(_state.is_up_too_late, "it was 01:00 already, not reached")


func test_sleeping_or_passing_out_ends_staying_up_too_late() -> void:
	_state.clock.set_time(0, 59)
	_state.pass_awake_time(1)
	_state.sleep_in(_bed())
	assert_false(_state.is_up_too_late)
	_state.clock.set_time(0, 59)
	_state.pass_awake_time(1)
	_state.pass_out()
	assert_false(_state.is_up_too_late)


func test_passing_out_at_one_at_night_wakes_at_eleven() -> void:
	_state.clock.set_time(0, 59)
	_state.pass_awake_time(1)
	assert_eq(_state.pass_out(), 10 * GameClock.MINUTES_PER_HOUR)
	assert_eq(_state.clock.day, 1)
	assert_eq(_state.clock.time_text(), "11:00")
	assert_true(_state.player.is_debuffed)


func test_sleeping_is_no_time_awake() -> void:
	_state.clock.set_time(0, 30)
	_state.sleep_in(_bed())
	assert_false(_state.is_up_too_late, "slept from 00:30 over 01:00")


func test_skipping_time_over_one_at_night_is_no_time_awake() -> void:
	_state.clock.set_time(23, 0)
	var console := Console.new(_state)
	console.run("skip 3h")
	assert_eq(_state.clock.time_text(), "02:00")
	assert_false(_state.is_up_too_late)


## Lets the awake player's time pass minute by minute, as Main does, until they have stayed up
## too late or `minutes` have passed. Returns the clock times (hh:mm) of the late bubbles.
func _stay_awake(signs: TirednessSigns, minutes: int) -> Array[String]:
	var bubbles: Array[String] = []
	for _minute in minutes:
		_state.pass_awake_time(1)
		var clock_minute := (_state.clock.day - 1) * GameClock.MINUTES_PER_DAY
		clock_minute += _state.clock.minute_of_day
		if signs.late_bubble_for(clock_minute, not _state.is_up_too_late) != &"":
			bubbles.append(_state.clock.time_text())
		if _state.is_up_too_late:
			break
	return bubbles


func test_both_late_bubbles_come_before_passing_out_at_one() -> void:
	var signs := TirednessSigns.new(_state.energy_rules)
	_state.clock.set_time(23, 50)
	# The test rules warn at 00:15 and 00:45 (see EnergyCase).
	assert_eq(_stay_awake(signs, 3 * GameClock.MINUTES_PER_HOUR), ["00:15", "00:45"])
	assert_true(_state.is_up_too_late)
	assert_eq(_state.clock.time_text(), "01:00")


func test_no_late_bubble_after_waking_from_passing_out_at_one() -> void:
	var signs := TirednessSigns.new(_state.energy_rules)
	_state.clock.set_time(0, 50)
	_stay_awake(signs, 3 * GameClock.MINUTES_PER_HOUR)
	_state.pass_out()
	assert_eq(_state.clock.time_text(), "11:00")
	assert_eq(_stay_awake(signs, 12 * GameClock.MINUTES_PER_HOUR), [] as Array[String])
