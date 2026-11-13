extends GutTest
## The rules of the ambience: the loop levels the weather gives, and the
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
	assert_true(_rules.is_valid(), "missing: %s" % [_rules.problems()])


func test_every_missing_key_is_reported() -> void:
	var rules := AmbienceRules.new({"loops": {"min_level": 0.02}})
	var missing := rules.problems()
	assert_true(missing.has("[loops] no fade_seconds"))
	assert_true(missing.has("[frogs] no croak_chance"))
	assert_true(missing.has("[bees] no level"))
	assert_false(missing.has("[loops] no min_level"))


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


func test_gusts_are_louder_in_stronger_wind_and_never_silent() -> void:
	var soft := _rules.gust_level(0.01)
	assert_gt(soft, 0.0)
	assert_lt(soft, _rules.gust_level(0.5))
	assert_lt(_rules.gust_level(0.5), _rules.gust_level(1.0))
	assert_almost_eq(_rules.gust_level(1.0), 1.0, 0.0001, "a storm's gust is at full volume")


func test_a_gust_is_heard_from_the_brightness_of_the_front_given_in_the_data() -> void:
	var from := _rules.value("loops", "gust_front_from")
	assert_false(_rules.is_gust(from - 0.01))
	assert_true(_rules.is_gust(from))


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


func test_deer_rabbits_squirrels_and_crows_have_a_chance_of_their_own() -> void:
	for kind in [
		WildlifeRules.DEER, WildlifeRules.RABBIT, WildlifeRules.SQUIRREL, WildlifeRules.CROWS
	]:
		assert_gt(_rules.idle_chance(kind), 0.0, str(kind))


func test_the_frogs_chorus_swells_with_the_frogs_on_spring_and_summer_evenings() -> void:
	var full := _rules.value("frog_chorus", "level")
	var frogs := int(_rules.value("frog_chorus", "full_frogs"))
	assert_almost_eq(_rules.chorus_level(SUMMER, DUSK, 18.0, frogs), full, 0.001)
	assert_almost_eq(_rules.chorus_level(SPRING, DUSK, 18.0, frogs * 2), full, 0.001, "at most")
	assert_between(_rules.chorus_level(SUMMER, DUSK, 18.0, 1), 0.01, full - 0.01, "a few frogs")
	assert_gt(_rules.chorus_level(SUMMER, NIGHT, 18.0, frogs), 0.0)
	assert_eq(_rules.chorus_level(SUMMER, DUSK, 18.0, 0), 0.0, "no frogs, no chorus")
	assert_eq(_rules.chorus_level(SUMMER, DAY, 18.0, frogs), 0.0, "not by day")
	assert_eq(_rules.chorus_level(AUTUMN, DUSK, 18.0, frogs), 0.0)
	var cold := _rules.value("frogs", "cold_temperature")
	assert_eq(_rules.chorus_level(SUMMER, DUSK, cold, frogs), 0.0, "not in the cold")
