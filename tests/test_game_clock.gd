extends GutTest

var _clock := GameClock.new()
var _new_days: Array[int] = []


func before_each() -> void:
	_clock = GameClock.new()
	_new_days = []
	_clock.new_day.connect(func(day: int) -> void: _new_days.append(day))


func test_starts_on_day_one_at_six() -> void:
	assert_eq(_clock.day, 1)
	assert_eq(_clock.time_text(), "06:00")


func test_advance_within_a_day() -> void:
	_clock.advance(95)
	assert_eq(_clock.day, 1)
	assert_eq(_clock.time_text(), "07:35")
	assert_eq(_new_days, [])


func test_advance_to_exactly_midnight_starts_the_next_day() -> void:
	_clock.advance(18 * 60)
	assert_eq(_clock.day, 2)
	assert_eq(_clock.time_text(), "00:00")
	assert_eq(_new_days, [2])


func test_advance_across_midnight() -> void:
	_clock.advance(18 * 60 + 30)
	assert_eq(_clock.day, 2)
	assert_eq(_clock.time_text(), "00:30")
	assert_eq(_new_days, [2])


func test_advance_several_days_emits_once_per_day() -> void:
	_clock.advance(3 * GameClock.MINUTES_PER_DAY + 60)
	assert_eq(_clock.day, 4)
	assert_eq(_clock.time_text(), "07:00")
	assert_eq(_new_days, [2, 3, 4])


func test_many_small_steps_match_one_big_step() -> void:
	for _i in 2 * GameClock.MINUTES_PER_DAY:
		_clock.advance(1)
	assert_eq(_clock.day, 3)
	assert_eq(_clock.time_text(), "06:00")
	assert_eq(_new_days, [2, 3])
