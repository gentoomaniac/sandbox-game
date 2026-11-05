extends GutTest
## The moderate climate: frost only in winter, moderate means, a mild start.

const ORIGIN := Vector2i.ZERO
const MIDSUMMER := 45
const MIDWINTER := 105

var _sun := Sun.new()
var _weather := Weather.new(3, _sun)


func _mean_temperature(first_day: int, days: int) -> float:
	var total := 0.0
	var count := 0
	for year in 6:
		for day in range(first_day, first_day + days):
			for minute in range(0, GameClock.MINUTES_PER_DAY, 60):
				var sample := _weather.at(ORIGIN, day + year * GameClock.DAYS_PER_YEAR, minute)
				total += sample.temperature
				count += 1
	return total / count


func test_it_is_never_below_freezing_and_never_snows_outside_winter() -> void:
	# The first 90 days of the year are spring, summer and autumn.
	for seed_value in range(1, 9):
		var weather := Weather.new(seed_value, _sun)
		for year in 3:
			for day in range(1, 3 * GameClock.DAYS_PER_SEASON + 1):
				for minute in range(0, GameClock.MINUTES_PER_DAY, 120):
					var sample := weather.at(ORIGIN, day + year * GameClock.DAYS_PER_YEAR, minute)
					assert_gte(sample.temperature, 0.0, "seed %d day %d" % [seed_value, day])
					assert_eq(sample.snow, 0.0, "seed %d day %d" % [seed_value, day])


func test_the_temperature_means_are_moderate() -> void:
	var summer := _mean_temperature(MIDSUMMER - 15, 30)
	var winter := _mean_temperature(MIDWINTER - 15, 30)
	assert_between(summer, 15.0, 25.0)
	assert_lt(winter, 0.0)
	assert_gt(winter, -10.0)


func test_a_new_game_starts_mild() -> void:
	for seed_value in range(1, 9):
		var weather := Weather.new(seed_value, _sun)
		assert_gt(weather.at(ORIGIN, 1, 14 * 60).temperature, 3.0, "seed %d" % seed_value)
		assert_eq(weather.at(ORIGIN, 1, 14 * 60).snow, 0.0)


func test_frost_comes_gradually_into_winter() -> void:
	var last_autumn := _weather.at(ORIGIN, 90, 5 * 60).temperature
	var first_winter := _weather.at(ORIGIN, 91, 5 * 60).temperature
	assert_lt(absf(first_winter - last_autumn), 4.0)
