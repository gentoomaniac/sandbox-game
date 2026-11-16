extends GutTest
## Whether a high water is a storm surge, and how high (SurgeRoll, #103).

const SEED := 7
## A tide in autumn, one in winter and one in summer.
const AUTUMN_TIDE := 100 * 1440 / 745
## The tides of autumn, days 71 to 105 of the year.
const FIRST_AUTUMN_TIDE := 70 * 1440 / 745 + 1
const LAST_AUTUMN_TIDE := 105 * 1440 / 745
const SUMMER_TIDE := 20 * 1440 / 745
const WINTER_TIDE := 120 * 1440 / 745

var _weather := StormyWeather.new(SEED)
var _roll := SurgeRoll.new(SEED, _weather)


func test_a_full_storm_in_autumn_always_makes_a_surge_of_the_greatest_level() -> void:
	_weather.storm = 0.35
	assert_eq(_roll.chance_for(AUTUMN_TIDE), 1.0)
	assert_between(_roll.level_for(AUTUMN_TIDE), 3.0, 3.4)


func test_nothing_comes_in_summer_whatever_the_storm() -> void:
	_weather.storm = 0.35
	assert_eq(_roll.chance_for(SUMMER_TIDE), 0.0)
	assert_eq(_roll.level_for(SUMMER_TIDE), 0.0)


func test_a_light_storm_makes_no_surge() -> void:
	_weather.storm = 0.05
	assert_eq(_roll.chance_for(AUTUMN_TIDE), 0.0)


func test_winter_has_half_the_chance_of_autumn() -> void:
	_weather.storm = 0.25
	assert_almost_eq(_roll.chance_for(WINTER_TIDE), _roll.chance_for(AUTUMN_TIDE) / 2.0, 0.0001)


func test_a_stronger_storm_is_likelier_and_makes_a_higher_surge() -> void:
	_weather.storm = 0.2
	var weaker_chance := _roll.chance_for(AUTUMN_TIDE)
	_weather.storm = 0.3
	assert_gt(_roll.chance_for(AUTUMN_TIDE), weaker_chance)
	var weak_levels: Array[float] = []
	var strong_levels: Array[float] = []
	for tide in range(FIRST_AUTUMN_TIDE, LAST_AUTUMN_TIDE):
		_weather.storm = 0.15
		weak_levels.append(_roll.level_for(tide))
		_weather.storm = 0.35
		strong_levels.append(_roll.level_for(tide))
	var weak_surges := weak_levels.filter(func(level: float) -> bool: return level > 0.0)
	assert_gt(weak_surges.size(), 0, "a weak storm makes some surges")
	assert_lt(weak_surges.max(), strong_levels.min())


func test_the_same_world_rolls_the_same_surges() -> void:
	_weather.storm = 0.2
	var again := SurgeRoll.new(SEED, _weather)
	for tide in range(AUTUMN_TIDE, AUTUMN_TIDE + 50):
		assert_eq(_roll.level_for(tide), again.level_for(tide))


func test_another_world_rolls_other_surges() -> void:
	_weather.storm = 0.2
	var other := SurgeRoll.new(SEED + 1, _weather)
	var differ := false
	for tide in range(AUTUMN_TIDE, AUTUMN_TIDE + 50):
		differ = differ or _roll.level_for(tide) != other.level_for(tide)
	assert_true(differ)


func test_the_tide_numbers_count_the_high_waters() -> void:
	assert_eq(SurgeRoll.tide_number_at(0.0), 0)
	assert_eq(SurgeRoll.tide_number_at(Tide.PERIOD_MINUTES * 3.0 + 100.0), 3)
	assert_eq(SurgeRoll.peak_minute(2), roundi(2 * Tide.PERIOD_MINUTES))
	assert_almost_eq(Tide.level(SurgeRoll.peak_minute(5)), 1.0, 0.001)


func test_about_one_surge_a_year_comes_with_the_real_weather() -> void:
	var weather := Weather.new(SEED)
	var roll := SurgeRoll.new(SEED, weather)
	var years := 4
	var expected := 0.0
	for tide in range(0, int(years * GameClock.DAYS_PER_YEAR * 1440 / Tide.PERIOD_MINUTES)):
		expected += roll.chance_for(tide)
	assert_between(expected / years, 0.2, 3.0, "surges a year at the first values")
