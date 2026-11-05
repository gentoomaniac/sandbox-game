extends GutTest
## The snow cover: it builds while it snows, melts above 0 degrees (faster in sunshine), is gone
## by the first day of spring and is a pure function of the weather. And the frost.

const ORIGIN := Vector2i.ZERO
const WINTER_START := 91
const YEAR := GameClock.DAYS_PER_YEAR


## A weather that answers every question with the sample a callable makes from (day, minute).
class FakeWeather:
	extends Weather
	var sample_at: Callable

	func at(_position: Vector2i, day: int, minute: int) -> WeatherSample:
		return sample_at.call(day, minute)


func _sample(snow: float, temperature: float, sunlight := 0.0) -> WeatherSample:
	var sample := WeatherSample.new()
	sample.snow = snow
	sample.temperature = temperature
	sample.sunlight = sunlight
	return sample


func _cover_with(sample_at: Callable) -> SnowCover:
	var weather := FakeWeather.new(1)
	weather.sample_at = sample_at
	return SnowCover.new(weather)


func _snowing(intensity: float) -> SnowCover:
	return _cover_with(
		func(_day: int, _minute: int) -> WeatherSample: return _sample(intensity, -3.0)
	)


## Snow until day 72, then no snow and `temperature` with `sunlight`.
func _thawing(temperature: float, sunlight: float) -> SnowCover:
	return _cover_with(
		func(day: int, _minute: int) -> WeatherSample:
			return _sample(1.0, -3.0) if day < 72 else _sample(0.0, temperature, sunlight)
	)


func test_it_builds_while_it_snows() -> void:
	var cover := _snowing(1.0)
	var after_five_hours := cover.at(ORIGIN, 61, 5 * 60)
	assert_gt(after_five_hours, 0.0)
	assert_gt(cover.at(ORIGIN, 61, 10 * 60), after_five_hours)
	assert_eq(cover.at(ORIGIN, 75, 0), 1.0, "it tops out at 1")


func test_a_light_snowfall_adds_less() -> void:
	assert_lt(_snowing(0.2).at(ORIGIN, 61, 600), _snowing(1.0).at(ORIGIN, 61, 600))


func test_it_melts_above_freezing_and_faster_in_sunshine() -> void:
	var dull := _thawing(4.0, 0.0)
	var sunny := _thawing(4.0, 100.0)
	assert_eq(dull.at(ORIGIN, 72, 0), 1.0)
	assert_lt(dull.at(ORIGIN, 72, 12 * 60), 1.0)
	assert_lt(sunny.at(ORIGIN, 72, 12 * 60), dull.at(ORIGIN, 72, 12 * 60))


func test_it_melts_faster_the_warmer_it_is() -> void:
	assert_lt(_thawing(8.0, 0.0).at(ORIGIN, 72, 600), _thawing(2.0, 0.0).at(ORIGIN, 72, 600))


func test_nothing_melts_at_zero_degrees() -> void:
	assert_eq(_thawing(0.0, 100.0).at(ORIGIN, 74, 0), 1.0)


func test_with_the_real_weather_it_only_grows_in_the_cold_and_only_shrinks_in_the_warm() -> void:
	var weather := Weather.new(2)
	var cover := SnowCover.new(weather)
	var grew := false
	for hour in range((WINTER_START - 1) * 24, 118 * 24):
		var day := hour / 24 + 1
		var sample := weather.at(ORIGIN, day, hour % 24 * 60 + 30)
		var before := cover.at(ORIGIN, day, hour % 24 * 60)
		var after := cover.at(ORIGIN, (hour + 1) / 24 + 1, (hour + 1) % 24 * 60)
		if sample.temperature <= 0.0:
			assert_gte(after, before - 0.0001, "no melting in the cold, hour %d" % hour)
		else:
			assert_lte(after, before + sample.snow * 0.1, "no growing in the warm, hour %d" % hour)
		grew = grew or after > before
	assert_true(grew, "it snowed in that winter")


func test_it_is_gone_by_the_first_day_of_spring_over_seeds_and_years() -> void:
	for world_seed in range(1, 21):
		var cover := SnowCover.new(Weather.new(world_seed))
		for year in 3:
			var last_moment := cover.at(ORIGIN, year * YEAR + YEAR, GameClock.MINUTES_PER_DAY - 1)
			assert_eq(last_moment, 0.0, "seed %d, year %d" % [world_seed, year])
			assert_eq(cover.at(ORIGIN, (year + 1) * YEAR + 1, 12 * 60), 0.0)


func test_a_thaw_clears_the_ground_within_a_few_days() -> void:
	var durations: Array[float] = []
	for world_seed in range(1, 11):
		var cover := SnowCover.new(Weather.new(world_seed))
		var last_deep := -1
		var first_bare := -1
		for hour in range(100 * 24, 120 * 24):
			var value := cover.at(ORIGIN, hour / 24 + 1, hour % 24 * 60)
			if value >= 0.9:
				last_deep = hour
				first_bare = -1
			elif value == 0.0 and last_deep >= 0 and first_bare < 0:
				first_bare = hour
		if last_deep >= 0:
			assert_gt(first_bare, 0, "seed %d clears" % world_seed)
			durations.append((first_bare - last_deep) / 24.0)
	assert_false(durations.is_empty(), "some winter had deep snow")
	for duration in durations:
		assert_between(duration, 0.5, 3.0)


func test_there_is_no_snow_in_spring_and_summer() -> void:
	var cover := SnowCover.new(Weather.new(4))
	for day in range(1, 61):
		assert_eq(cover.at(ORIGIN, day, 12 * 60), 0.0)


func test_asking_in_any_order_gives_the_same_answers() -> void:
	var forwards := SnowCover.new(Weather.new(5))
	var backwards := SnowCover.new(Weather.new(5))
	var days := [95, 100, 105, 110, 115]
	var expected := {}
	for day: int in days:
		expected[day] = forwards.at(ORIGIN, day, 700)
	days.reverse()
	for day: int in days:
		assert_eq(backwards.at(ORIGIN, day, 700), expected[day])


func test_a_forced_cover_replaces_the_simulated_one() -> void:
	var cover := SnowCover.new(Weather.new(5))
	cover.forced = 0.4
	assert_eq(cover.at(ORIGIN, 20, 0), 0.4)
	cover.forced = -1.0
	assert_eq(cover.at(ORIGIN, 20, 0), 0.0)


# --- Frost ---


func test_frost_needs_cold_and_grows_with_it() -> void:
	var cover := SnowCover.new(Weather.new(5))
	assert_eq(cover.frost_at(0.0), 0.0)
	assert_eq(cover.frost_at(5.0), 0.0)
	assert_gt(cover.frost_at(-2.0), 0.0)
	assert_gt(cover.frost_at(-4.0), cover.frost_at(-2.0))
	assert_eq(cover.frost_at(-30.0), 1.0)


func test_there_is_only_frost_in_winter() -> void:
	var weather := Weather.new(6)
	var cover := SnowCover.new(weather)
	for day in range(1, WINTER_START):
		for hour in range(0, 24, 3):
			assert_eq(cover.frost_at(weather.at(ORIGIN, day, hour * 60).temperature), 0.0)
