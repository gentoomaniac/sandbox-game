extends GutTest
## The rules of the ambience: the loop levels the weather gives, the delay of thunder, and the
## chances of birdsong and frogs by season, part of the day, temperature and distance.

const SPRING := GameClock.Season.SPRING
const SUMMER := GameClock.Season.SUMMER
const AUTUMN := GameClock.Season.AUTUMN
const WINTER := GameClock.Season.WINTER
const DAY := WildlifeRules.Phase.DAY
const DUSK := WildlifeRules.Phase.TWILIGHT
const NIGHT := WildlifeRules.Phase.NIGHT

var _rules := AmbienceRules.default_rules()
var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 3


func _weather(rain := 0.0, wind_speed := 0.0) -> WeatherSample:
	var sample := WeatherSample.new()
	sample.rain = rain
	sample.wind_speed = wind_speed
	return sample


func test_the_data_file_holds_every_required_key() -> void:
	assert_true(_rules.is_valid(), "missing: %s" % [_rules.missing_keys()])


func test_every_missing_key_is_reported() -> void:
	var rules := AmbienceRules.new({"loops": {"min_level": 0.02}})
	var missing := rules.missing_keys()
	assert_true(missing.has("[loops] fade_seconds"))
	assert_true(missing.has("[frogs] croak_chance"))
	assert_true(missing.has("[bees] level"))
	assert_false(missing.has("[loops] min_level"))


func test_rain_is_as_loud_as_it_is_strong() -> void:
	assert_eq(_rules.rain_level(_weather(0.0)), 0.0)
	assert_gt(_rules.rain_level(_weather(0.8)), _rules.rain_level(_weather(0.3)))
	assert_almost_eq(
		_rules.rain_level(_weather(1.0)), _rules.value("loops", "rain_max_level"), 0.0001
	)


func test_wind_is_silent_when_calm_and_loudest_when_strong() -> void:
	var calm := _rules.value("loops", "wind_calm_speed")
	var full := _rules.value("loops", "wind_full_speed")
	assert_eq(_rules.wind_level(_weather(0.0, calm - 1.0)), 0.0)
	var breeze := _rules.wind_level(_weather(0.0, (calm + full) / 2.0))
	assert_between(breeze, 0.01, _rules.value("loops", "wind_max_level") - 0.01)
	assert_almost_eq(
		_rules.wind_level(_weather(0.0, full * 2.0)),
		_rules.value("loops", "wind_max_level"),
		0.0001
	)


func test_gusts_come_more_often_in_stronger_wind() -> void:
	var max_level := _rules.value("loops", "wind_max_level")
	assert_eq(_rules.gust_chance(0.0), 0.0)
	assert_gt(_rules.gust_chance(max_level), _rules.gust_chance(max_level / 2.0))


func test_thunder_comes_after_a_delay_within_the_range() -> void:
	var shortest := _rules.value("thunder", "min_delay_seconds")
	var longest := _rules.value("thunder", "max_delay_seconds")
	var delays: Array[float] = []
	for _i in 50:
		delays.append(_rules.thunder_delay(_rng))
	for delay in delays:
		assert_between(delay, shortest, longest)
	assert_gt(delays.max() - delays.min(), 1.0, "the delays differ")


func test_birds_sing_by_day_less_at_dusk_and_not_at_night() -> void:
	var clear := _weather()
	var by_day := _rules.bird_chance(SUMMER, DAY, clear)
	assert_gt(by_day, 0.0)
	assert_gt(by_day, _rules.bird_chance(SUMMER, DUSK, clear))
	assert_gt(_rules.bird_chance(SUMMER, DUSK, clear), 0.0)
	assert_eq(_rules.bird_chance(SUMMER, NIGHT, clear), 0.0)


func test_birds_sing_less_in_rain_and_in_winter() -> void:
	var by_day := _rules.bird_chance(SPRING, DAY, _weather())
	assert_lt(_rules.bird_chance(SPRING, DAY, _weather(0.3)), by_day)
	assert_eq(_rules.bird_chance(SPRING, DAY, _weather(1.0)), 0.0)
	assert_lt(_rules.bird_chance(WINTER, DAY, _weather()), by_day)
	assert_gt(_rules.bird_chance(WINTER, DAY, _weather()), 0.0)


func test_frogs_croak_in_spring_and_summer_never_in_winter() -> void:
	for phase in [DAY, DUSK, NIGHT]:
		assert_gt(_rules.frog_chance(SPRING, phase, 18.0, 4.0), 0.0)
		assert_gt(_rules.frog_chance(SUMMER, phase, 18.0, 4.0), 0.0)
		assert_eq(_rules.frog_chance(WINTER, phase, 18.0, 4.0), 0.0)
	assert_lt(
		_rules.frog_chance(AUTUMN, NIGHT, 18.0, 4.0), _rules.frog_chance(SUMMER, NIGHT, 18.0, 4.0)
	)


func test_frogs_croak_mostly_in_the_evening_and_at_night() -> void:
	var by_day := _rules.frog_chance(SUMMER, DAY, 18.0, 4.0)
	var at_dusk := _rules.frog_chance(SUMMER, DUSK, 18.0, 4.0)
	var at_night := _rules.frog_chance(SUMMER, NIGHT, 18.0, 4.0)
	assert_gt(at_night, at_dusk)
	assert_gt(at_dusk, by_day)


func test_frogs_need_warmth() -> void:
	var cold := _rules.value("frogs", "cold_temperature")
	var warm := _rules.value("frogs", "warm_temperature")
	assert_eq(_rules.frog_chance(SPRING, NIGHT, cold, 4.0), 0.0)
	var mild := _rules.frog_chance(SPRING, NIGHT, (cold + warm) / 2.0, 4.0)
	assert_gt(mild, 0.0)
	assert_gt(_rules.frog_chance(SPRING, NIGHT, warm, 4.0), mild)
	assert_eq(
		_rules.frog_chance(SPRING, NIGHT, warm + 10.0, 4.0),
		_rules.frog_chance(SPRING, NIGHT, warm, 4.0)
	)


func test_frogs_croak_more_near_the_player_and_not_beyond_the_radius() -> void:
	var radius := _rules.value("frogs", "radius_tiles")
	assert_gt(
		_rules.frog_chance(SUMMER, NIGHT, 18.0, 2.0), _rules.frog_chance(SUMMER, NIGHT, 18.0, 8.0)
	)
	assert_eq(_rules.frog_chance(SUMMER, NIGHT, 18.0, radius), 0.0)
	assert_eq(_rules.frog_chance(SUMMER, NIGHT, 18.0, radius * 2.0), 0.0)


func test_deer_rabbits_and_squirrels_have_a_chance_of_their_own() -> void:
	for kind in [WildlifeRules.DEER, WildlifeRules.RABBIT, WildlifeRules.SQUIRREL]:
		assert_gt(_rules.idle_chance(kind), 0.0, str(kind))
