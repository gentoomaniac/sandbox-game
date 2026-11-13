extends GutTest
## The weather: determinism, continuity, what each season brings, the conditions derived from
## the values and the sun's effect on sunlight and temperature.

const SEED := 3
const ORIGIN := Vector2i.ZERO
## Days of the year in the middle of summer and of winter.
const MIDSUMMER := 45
const MIDWINTER := 105

var _sun := Sun.new()
var _weather := Weather.new(SEED, _sun)


## The samples of a run of days at every `step` minutes, over several years.
func _samples(first_day_of_year: int, days: int, step := 60, years := 6) -> Array[WeatherSample]:
	var samples: Array[WeatherSample] = []
	for year in years:
		for day in range(first_day_of_year, first_day_of_year + days):
			for minute in range(0, GameClock.MINUTES_PER_DAY, step):
				samples.append(_weather.at(ORIGIN, day + year * GameClock.DAYS_PER_YEAR, minute))
	return samples


func _share(samples: Array[WeatherSample], is_true: Callable) -> float:
	return float(samples.filter(is_true).size()) / samples.size()


func _average(samples: Array[WeatherSample], property: String) -> float:
	var total := 0.0
	for sample in samples:
		total += sample.get(property)
	return total / samples.size()


# --- Determinism and continuity ---


func test_the_same_seed_and_time_give_the_same_weather() -> void:
	var first := _weather.at(ORIGIN, 17, 400)
	var again := Weather.new(SEED).at(ORIGIN, 17, 400)
	assert_eq(first.temperature, again.temperature)
	assert_eq(first.humidity, again.humidity)
	assert_eq(first.wind_speed, again.wind_speed)
	assert_eq(first.wind_direction, again.wind_direction)


func test_a_different_seed_gives_different_weather() -> void:
	var other := Weather.new(SEED + 1)
	var differing := 0
	for day in range(1, 30):
		if other.at(ORIGIN, day, 600).temperature != _weather.at(ORIGIN, day, 600).temperature:
			differing += 1
	assert_gt(differing, 25)


func test_the_values_change_little_from_minute_to_minute() -> void:
	var previous := _weather.at(ORIGIN, 1, 0)
	for step in range(1, 3 * GameClock.MINUTES_PER_DAY):
		var day := 1 + step / GameClock.MINUTES_PER_DAY
		var sample := _weather.at(ORIGIN, day, step % GameClock.MINUTES_PER_DAY)
		assert_lt(absf(sample.temperature - previous.temperature), 0.3)
		assert_lt(absf(sample.humidity - previous.humidity), 1.0)
		assert_lt(absf(sample.wind_speed - previous.wind_speed), 0.5)
		assert_lt(absf(sample.sunlight - previous.sunlight), 2.0)
		previous = sample


func test_the_weather_is_continuous_over_the_start_of_a_day_and_of_a_season() -> void:
	for day in [2, 30, 120]:
		var before := _weather.at(ORIGIN, day, GameClock.MINUTES_PER_DAY - 1)
		var after := _weather.at(ORIGIN, day + 1, 0)
		assert_lt(absf(before.temperature - after.temperature), 0.3, "day %d" % day)
		assert_lt(absf(before.humidity - after.humidity), 1.0, "day %d" % day)


func test_the_baselines_run_smoothly_through_the_seasons() -> void:
	# Daily averages never jump from one day to the next, not even at a season's boundary.
	var previous := 0.0
	for day in range(1, 240):
		var today := 0.0
		for minute in range(0, GameClock.MINUTES_PER_DAY, 60):
			today += _weather.at(ORIGIN, day, minute).temperature
		today /= 24.0
		if day > 1:
			assert_lt(absf(today - previous), 6.0, "day %d" % day)
		previous = today


# --- The seasons ---


func test_summer_is_warmer_than_winter() -> void:
	var summer := _average(_samples(MIDSUMMER - 10, 20), "temperature")
	var winter := _average(_samples(MIDWINTER - 10, 20), "temperature")
	assert_gt(summer, winter + 15.0)


func test_snow_falls_in_winter_and_never_in_midsummer() -> void:
	var is_snowing := func(sample: WeatherSample) -> bool: return sample.snow > 0.1
	# The share of midwinter hours with snow was 0.42 when humidity drifted for days (task 221) and
	# is 0.16 now that it comes in fronts of hours; 0.1 still means a snowy winter.
	assert_gt(_share(_samples(MIDWINTER - 15, 30), is_snowing), 0.1)
	assert_eq(_share(_samples(MIDSUMMER - 15, 30, 30, 12), is_snowing), 0.0)


func test_there_is_no_rain_below_freezing() -> void:
	for sample in _samples(1, 120, 120):
		if sample.temperature <= 0.0:
			assert_eq(sample.rain, 0.0)


func test_summer_is_mostly_sunny_with_some_thunderstorms() -> void:
	var samples := _samples(MIDSUMMER - 15, 30)
	var daylight := samples.filter(func(s: WeatherSample) -> bool: return s.sun_height > 0.3)
	var cloud_cover := 0.0
	for sample: WeatherSample in daylight:
		cloud_cover += sample.cloud_cover / daylight.size()
	assert_lt(cloud_cover, 0.35)
	var thundery := _share(samples, func(s: WeatherSample) -> bool: return s.thunder > 0.1)
	assert_gt(thundery, 0.0)
	assert_lt(thundery, 0.15)


func test_autumn_is_rainier_and_windier_than_summer() -> void:
	var autumn := _samples(MIDSUMMER + 30, 30)
	var summer := _samples(MIDSUMMER - 15, 30)
	var is_raining := func(s: WeatherSample) -> bool: return s.rain > 0.1
	assert_gt(_share(autumn, is_raining), _share(summer, is_raining) * 2.0)
	assert_gt(_average(autumn, "wind_speed"), _average(summer, "wind_speed"))


func test_fog_comes_mostly_around_sunrise() -> void:
	var foggy_mornings := 0
	var foggy_afternoons := 0
	for day in range(1, GameClock.DAYS_PER_YEAR * 4):
		var rise := roundi(_sun.sunrise(day))
		if _weather.at(ORIGIN, day, rise + 60).fog > 0.2:
			foggy_mornings += 1
		if _weather.at(ORIGIN, day, mini(rise + 600, 1439)).fog > 0.2:
			foggy_afternoons += 1
	assert_gt(foggy_mornings, 3)
	assert_gt(foggy_mornings, foggy_afternoons * 2)


# --- The sun ---


func test_sunlight_is_zero_at_night_and_follows_the_sun_by_day() -> void:
	assert_eq(_weather.at(ORIGIN, MIDWINTER, 60).sunlight, 0.0)
	assert_almost_eq(
		_weather.at(ORIGIN, MIDSUMMER, 720).sun_height, _sun.height(MIDSUMMER, 720), 0.0001
	)
	for sample in _samples(MIDSUMMER, 5, 60, 1):
		assert_lte(sample.sunlight, sample.sun_height * 100.0 + 0.001)


func test_the_temperature_follows_the_sun_through_the_day() -> void:
	# Averaged over weeks the noise is gone: coldest near sunrise, warmest in the afternoon.
	var by_hour: Array[float] = []
	by_hour.resize(24)
	by_hour.fill(0.0)
	for year in 6:
		for day in range(MIDSUMMER - 10, MIDSUMMER + 10):
			for hour in 24:
				var sample := _weather.at(ORIGIN, day + year * 120, hour * 60)
				by_hour[hour] += sample.temperature
	assert_between(by_hour.find(by_hour.min()), 1, 5, "the coldest hour of a midsummer day")
	assert_between(by_hour.find(by_hour.max()), 13, 18, "the warmest hour of a midsummer day")


func test_overcast_skies_let_less_sun_through() -> void:
	var base := _weather.at(ORIGIN, MIDSUMMER, 900)
	var clear := _weather.forced(base, &"clear")
	var overcast := _weather.forced(base, &"storm")
	assert_eq(clear.cloud_cover, 0.0)
	assert_gt(overcast.cloud_cover, 0.8)
	assert_lt(overcast.sunlight, clear.sunlight * 0.5)


# --- Conditions ---


func test_conditions_follow_the_thresholds_of_the_data_file() -> void:
	var rules := WeatherRules.default_rules()
	for sample in _samples(1, 120, 90, 2):
		if sample.humidity < rules.value("precipitation", "humidity_from"):
			assert_eq(sample.rain + sample.snow, 0.0)
		if sample.temperature >= rules.value("precipitation", "rain_from_temperature"):
			assert_eq(sample.snow, 0.0)
		if sample.temperature <= 0.0:
			assert_eq(sample.rain, 0.0)
		assert_lte(sample.storm, minf(sample.rain + sample.snow, sample.wind) + 0.0001)
		if sample.thunder > 0.0:
			assert_gt(sample.temperature, rules.value("thunder", "temperature_from"))
			assert_gt(sample.humidity, rules.value("thunder", "humidity_from"))
			assert_gt(sample.wind_speed, rules.value("thunder", "wind_from"))
		assert_almost_eq(
			sample.lightning_chance,
			sample.thunder * rules.value("thunder", "lightning_per_minute"),
			0.00001
		)


func test_the_region_is_the_same_everywhere_for_now() -> void:
	assert_eq(Weather.region_of(Vector2i(5, 9)), Weather.region_of(Vector2i(-200, 4000)))
	assert_eq(
		_weather.at(Vector2i(5, 9), 12, 300).temperature,
		_weather.at(Vector2i(900, 900), 12, 300).temperature
	)


func test_a_forced_condition_is_on_and_the_others_it_does_not_bring_are_off() -> void:
	var base := _weather.at(ORIGIN, MIDSUMMER, 600)
	var brings := {
		&"clear": [],
		&"cloudy": [],
		&"overcast": [],
		&"rain": [&"rain"],
		&"snow": [&"snow"],
		&"fog": [&"fog"],
		&"wind": [&"wind"],
		&"storm": [&"rain", &"wind", &"storm"],
		&"thunder": [&"rain", &"wind", &"storm", &"thunder"],
	}
	for condition in Weather.FORCEABLE:
		var sample := _weather.forced(base, condition)
		for name in WeatherSample.CONDITIONS:
			if brings[condition].has(name):
				assert_gt(sample.get(name), 0.0, "%s with %s forced" % [name, condition])
			else:
				assert_eq(sample.get(name), 0.0, "%s with %s forced" % [name, condition])
	assert_gt(_weather.forced(base, &"thunder").lightning_chance, 0.0)
	assert_eq(_weather.forced(base, &"clear").lightning_chance, 0.0)


func test_snow_forced_in_summer_is_cold_snow() -> void:
	var sample := _weather.forced(_weather.at(ORIGIN, MIDSUMMER, 600), &"snow")
	assert_lt(sample.temperature, 0.0)
	assert_gt(sample.snow, 0.0)
	assert_eq(sample.rain, 0.0)
