extends EnergyCase
## The console's `skip` command.

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


func test_skip_lets_minutes_hours_and_days_pass() -> void:
	var clock := _state.clock
	clock.set_time(10, 0)
	var day := clock.day
	_console.run("skip 30m")
	assert_eq(clock.minute_of_day, 10 * 60 + 30)
	_console.run("skip 2h")
	assert_eq(clock.minute_of_day, 12 * 60 + 30)
	var lines := _console.run("skip 3d")
	assert_eq(clock.day, day + 3)
	assert_eq(clock.minute_of_day, 12 * 60 + 30)
	assert_string_contains(lines[0], clock.date_text())


func test_skipping_past_midnight_passes_the_night() -> void:
	_state.player.is_debuffed = true
	_state.clock.set_time(23, 0)
	_console.run("skip 2h")
	assert_false(_state.player.is_debuffed, "a new day ends the debuff")


func test_skip_rejects_bad_amounts() -> void:
	var clock := _state.clock
	var before := [clock.day, clock.minute_of_day]
	for line in ["skip", "skip 2", "skip h", "skip 0h", "skip -1d", "skip 2x", "skip 1h 2h"]:
		assert_string_starts_with(_console.run(line)[0], "Usage", line)
	assert_string_starts_with(_console.run("skip 121d")[0], "At most a year")
	assert_eq([clock.day, clock.minute_of_day], before)
