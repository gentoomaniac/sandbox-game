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
		var total := 0.0
		for hour in 24:
			var sample := weather.at(ORIGIN, 1, hour * 60)
			assert_gt(sample.temperature, 1.0, "seed %d hour %d" % [seed_value, hour])
			assert_eq(sample.snow, 0.0)
			total += sample.temperature / 24.0
		assert_gt(total, 4.0, "mean of day 1, seed %d" % seed_value)


func test_frost_comes_gradually_into_winter() -> void:
	var last_autumn := _weather.at(ORIGIN, 90, 5 * 60).temperature
	var first_winter := _weather.at(ORIGIN, 91, 5 * 60).temperature
	assert_lt(absf(first_winter - last_autumn), 4.0)


func test_winter_keeps_its_cold_until_late_and_still_snows() -> void:
	var snowy_hours := 0
	var total := 0.0
	var count := 0
	for seed_value in range(1, 9):
		var weather := Weather.new(seed_value, _sun)
		for day in range(91, 116):
			for hour in range(0, 24, 2):
				var sample := weather.at(ORIGIN, day, hour * 60)
				total += sample.temperature
				count += 1
				if day > 105 and sample.snow > 0.1:
					snowy_hours += 1
	assert_lt(total / count, 0.0, "days 91 to 115")
	assert_gt(snowy_hours, 0, "snow in late winter")


func test_the_thaw_at_the_end_of_winter_is_smooth_and_quick() -> void:
	var previous := _weather.at(ORIGIN, 110, 0).temperature
	for step in range(1, 16 * GameClock.MINUTES_PER_DAY, 30):
		var day := 110 + step / GameClock.MINUTES_PER_DAY
		var temperature := _weather.at(ORIGIN, day, step % GameClock.MINUTES_PER_DAY).temperature
		assert_lt(absf(temperature - previous), 1.0)
		previous = temperature
