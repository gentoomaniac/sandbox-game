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


func test_set_time() -> void:
	_clock.set_time(23, 5)
	assert_eq(_clock.minute_of_day, 23 * 60 + 5)
	assert_eq(_clock.day, 1)


func test_advance_zero_changes_nothing() -> void:
	_clock.advance(0)
	assert_eq(_clock.day, 1)
	assert_eq(_clock.minute_of_day, GameClock.START_MINUTE)
	assert_eq(_new_days, [])


func test_time_text_pads_digits() -> void:
	_clock.set_time(0, 7)
	assert_eq(_clock.time_text(), "00:07")
	_clock.set_time(23, 59)
	assert_eq(_clock.time_text(), "23:59")


func _clock_on(day: int) -> GameClock:
	var clock := GameClock.new()
	clock.day = day
	return clock


func test_the_first_day_is_the_1st_day_of_spring_year_1() -> void:
	assert_eq(_clock_on(1).date_text(), "1st day of Spring Year 1")


func test_day_130_is_the_10th_day_of_spring_year_2() -> void:
	var clock := _clock_on(130)
	assert_eq(clock.season(), GameClock.Season.SPRING)
	assert_eq(clock.day_of_season(), 10)
	assert_eq(clock.year(), 2)
	assert_eq(clock.date_text(), "10th day of Spring Year 2")


func test_seasons_change_every_30_days() -> void:
	assert_eq(_clock_on(30).date_text(), "30th day of Spring Year 1")
	assert_eq(_clock_on(31).date_text(), "1st day of Summer Year 1")
	assert_eq(_clock_on(61).season(), GameClock.Season.AUTUMN)
	assert_eq(_clock_on(120).date_text(), "30th day of Winter Year 1")
	assert_eq(_clock_on(121).date_text(), "1st day of Spring Year 2")


func test_ordinals() -> void:
	var expected := {
		1: "1st",
		2: "2nd",
		3: "3rd",
		4: "4th",
		11: "11th",
		12: "12th",
		13: "13th",
		21: "21st",
		22: "22nd",
		23: "23rd",
		30: "30th"
	}
	for day: int in expected:
		assert_eq(_clock_on(day).date_text().split(" ")[0], expected[day])
