extends GutTest
## The rules of ambient wildlife: how many animals of each kind there are by season, hour and
## weather, where they may appear, and when they react to the player.

const SEED := 1
const SPRING := 15
const SUMMER := 45
const AUTUMN := 75
const WINTER := 105
const NOON := 12 * 60
const MIDNIGHT := 0

var _rules := WildlifeRules.default_rules()
var _sun := Sun.new()


func _clear() -> WeatherSample:
	return WeatherSample.new()


func _dawn(day: int) -> int:
	return roundi(_sun.sunrise(day))


func test_the_data_file_holds_every_required_key() -> void:
	assert_true(_rules.is_valid(), "missing: %s" % [_rules.missing_keys()])


func test_every_missing_key_is_reported() -> void:
	var rules := WildlifeRules.new({"general": {"max_total": 12}, "bird": {"cap": 4}})
	var missing := rules.missing_keys()
	assert_true(missing.has("[general] tick_seconds"))
	assert_true(missing.has("[bird] spawn_chance"))
	assert_true(missing.has("[deer] cap"))
	assert_false(missing.has("[bird] cap"))


func test_no_insects_in_winter_or_autumn() -> void:
	for kind in [WildlifeRules.BEE, WildlifeRules.BUTTERFLY]:
		assert_gt(_rules.target_count(kind, SUMMER, NOON, _clear()), 0, "%s in summer" % kind)
		assert_gt(_rules.target_count(kind, SPRING, NOON, _clear()), 0, "%s in spring" % kind)
		assert_eq(_rules.target_count(kind, WINTER, NOON, _clear()), 0, "%s in winter" % kind)


func test_insects_hide_in_rain_but_birds_stand_a_drizzle() -> void:
	var drizzle := _clear()
	drizzle.rain = 0.2
	assert_eq(_rules.target_count(WildlifeRules.BUTTERFLY, SUMMER, NOON, drizzle), 0)
	assert_gt(_rules.target_count(WildlifeRules.BIRD, SUMMER, NOON, drizzle), 0)


func test_nothing_is_about_in_a_storm_or_dense_fog() -> void:
	var storm := _clear()
	storm.storm = 0.8
	var fog := _clear()
	fog.fog = 0.95
	for kind in WildlifeRules.KINDS:
		assert_eq(_rules.target_count(kind, SUMMER, NOON, storm), 0, "%s in a storm" % kind)
		assert_eq(_rules.target_count(kind, SUMMER, NOON, fog), 0, "%s in dense fog" % kind)


func test_birds_by_day_and_fewer_at_night() -> void:
	var by_day := _rules.target_count(WildlifeRules.BIRD, SUMMER, NOON, _clear())
	var by_night := _rules.target_count(WildlifeRules.BIRD, SUMMER, MIDNIGHT, _clear())
	assert_gt(by_day, by_night)
	assert_eq(by_night, 0)


func test_birds_are_fewer_in_winter() -> void:
	var summer := _rules.target_count(WildlifeRules.BIRD, SUMMER, NOON, _clear())
	var winter := _rules.target_count(WildlifeRules.BIRD, WINTER, NOON, _clear())
	assert_gt(winter, 0)
	assert_lt(winter, summer)


func test_rabbits_and_squirrels_stay_about_in_winter() -> void:
	for kind in [WildlifeRules.RABBIT, WildlifeRules.SQUIRREL]:
		assert_gt(_rules.target_count(kind, WINTER, NOON, _clear()), 0, "%s in winter" % kind)


func test_deer_come_out_at_dawn_and_dusk_not_at_noon() -> void:
	var at_dawn := _rules.target_count(WildlifeRules.DEER, SUMMER, _dawn(SUMMER), _clear())
	var at_dusk := _rules.target_count(
		WildlifeRules.DEER, SUMMER, roundi(_sun.sunset(SUMMER)), _clear()
	)
	var at_noon := _rules.target_count(WildlifeRules.DEER, SUMMER, NOON, _clear())
	assert_gt(at_dawn, 0)
	assert_gt(at_dusk, 0)
	assert_eq(at_noon, 0)


func test_the_count_never_passes_the_cap() -> void:
	for kind in WildlifeRules.KINDS:
		for day in [SPRING, SUMMER, AUTUMN, WINTER]:
			for minute in range(0, 24 * 60, 30):
				var count := _rules.target_count(kind, day, minute, _clear())
				assert_between(count, 0, _rules.cap(kind), "%s, day %d, %d" % [kind, day, minute])


func test_the_phases_follow_the_sun() -> void:
	assert_eq(_rules.phase(SUMMER, NOON), WildlifeRules.Phase.DAY)
	assert_eq(_rules.phase(SUMMER, MIDNIGHT), WildlifeRules.Phase.NIGHT)
	assert_eq(_rules.phase(SUMMER, _dawn(SUMMER)), WildlifeRules.Phase.TWILIGHT)


func test_rules_use_their_own_values() -> void:
	var values := {
		"general": {"twilight_minutes": 10},
		"owl":
		{
			"cap": 5,
			"season_factors": [1.0, 1.0, 1.0, 1.0],
			"phase_weights": [0.0, 0.0, 1.0],
			"rain_limit": 0.5,
			"fog_limit": 0.5,
			"storm_limit": 0.5,
		},
	}
	var rules := WildlifeRules.new(values)
	assert_eq(rules.target_count(&"owl", SUMMER, MIDNIGHT, _clear()), 5)
	assert_eq(rules.target_count(&"owl", SUMMER, NOON, _clear()), 0)
