extends GutTest
## The tide: high water twice a day, a little later each day.


func test_high_water_comes_back_every_twelve_hours_and_a_quarter() -> void:
	assert_almost_eq(Tide.level(0.0), 1.0, 0.0001)
	assert_almost_eq(Tide.level(Tide.PERIOD_MINUTES), 1.0, 0.0001)
	assert_almost_eq(Tide.level(Tide.PERIOD_MINUTES / 2.0), 0.0, 0.0001)


func test_the_water_stands_between_low_and_high() -> void:
	for minute in range(0, GameClock.MINUTES_PER_DAY * 3, 17):
		var level := Tide.level(minute)
		assert_between(level, 0.0, 1.0, str(minute))


func test_high_water_is_later_each_day() -> void:
	var first_day := Tide.level(GameClock.MINUTES_PER_DAY)
	var next_day := Tide.level(2 * GameClock.MINUTES_PER_DAY)
	assert_ne(first_day, next_day, "the same time of day, another tide")
