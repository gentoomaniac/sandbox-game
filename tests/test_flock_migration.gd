extends GutTest
## The migration of the sky flocks: south in autumn, north in spring, any way in summer, none in
## winter, more often in the migration weeks and fading at the season edges. The skeins of geese
## migrate the same way, but stay in winter and are not about in summer.

const SPRING := 15
const SUMMER := 45
const AUTUMN := 75
const WINTER := 105
const NOON := 12 * 60

var _rules := WildlifeRules.default_rules()


func _clear() -> WeatherSample:
	return WeatherSample.new()


func test_no_sky_flocks_in_winter() -> void:
	var flock := WildlifeRules.FLOCK
	assert_gt(_rules.target_count(flock, SUMMER, NOON, _clear()), 0, "in summer")
	assert_eq(_rules.activity(flock, WINTER, NOON, _clear()), 0.0)
	assert_eq(_rules.spawn_chance(flock, WINTER, NOON, _clear()), 0.0)


func test_sky_flocks_fly_south_in_autumn_and_north_in_spring_within_the_spread() -> void:
	var flock := WildlifeRules.FLOCK
	var rng := RandomNumberGenerator.new()
	var spread := deg_to_rad(float(_rules._value(flock, "migration_spread_degrees")))
	for _i in 50:
		var south := _rules.migration_heading(flock, AUTUMN, rng)
		assert_lte(south.angle_to(Vector2.DOWN), spread + 0.001, "autumn: %s" % south)
		assert_gt(south.y, 0.0, "autumn goes south")
		var north := _rules.migration_heading(flock, SPRING, rng)
		assert_lte(north.angle_to(Vector2.UP), spread + 0.001, "spring: %s" % north)
		assert_lt(north.y, 0.0, "spring goes north")


func test_sky_flocks_fly_any_way_in_summer() -> void:
	assert_eq(
		_rules.migration_heading(WildlifeRules.FLOCK, SUMMER, RandomNumberGenerator.new()),
		Vector2.ZERO
	)


func test_a_skein_of_geese_migrates_too_and_flies_any_way_in_winter() -> void:
	var geese := WildlifeRules.FLYING_GEESE
	var rng := RandomNumberGenerator.new()
	assert_gt(_rules.migration_heading(geese, AUTUMN, rng).y, 0.0, "autumn goes south")
	assert_lt(_rules.migration_heading(geese, SPRING, rng).y, 0.0, "spring goes north")
	assert_eq(_rules.migration_heading(geese, WINTER, rng), Vector2.ZERO, "winter: any way")
	assert_gt(_rules.activity(geese, WINTER, NOON, _clear()), 0.0, "geese stay in winter")


func test_skeins_of_geese_fade_in_from_the_empty_summer() -> void:
	var geese := WildlifeRules.FLYING_GEESE
	var last_of_summer := 60
	assert_eq(_rules.season_factor(geese, 45), 0.0, "none in high summer")
	assert_gt(_rules.season_factor(geese, last_of_summer), 0.0, "fading in before autumn")
	assert_lt(_rules.season_factor(geese, last_of_summer), 1.0)
	assert_eq(_rules.season_factor(geese, AUTUMN), 1.0, "full in autumn")


func test_sky_flocks_come_more_often_in_the_migration_weeks() -> void:
	var flock := WildlifeRules.FLOCK
	var first_day_of_autumn := 61
	assert_true(_rules.is_migrating(flock, AUTUMN))
	assert_false(_rules.is_migrating(flock, first_day_of_autumn))
	assert_gt(
		_rules.spawn_chance(flock, AUTUMN, NOON, _clear()),
		_rules.spawn_chance(flock, SUMMER, NOON, _clear())
	)


func test_sky_flocks_fade_out_into_winter_and_in_from_it_without_a_step() -> void:
	var flock := WildlifeRules.FLOCK
	var last_autumn_day := 90
	var previous := 1.0
	for day in range(last_autumn_day - 8, last_autumn_day + 9):
		var factor := _rules.season_factor(flock, day)
		assert_lte(factor, previous + 0.001, "day %d" % day)
		assert_lte(previous - factor, 0.25, "no step at day %d" % day)
		previous = factor
	assert_eq(_rules.season_factor(flock, 70), 1.0, "full in mid-autumn")
	assert_eq(_rules.season_factor(flock, 105), 0.0, "none in mid-winter")
	assert_gt(_rules.season_factor(flock, 121), 0.0, "back with the first days of spring")


func test_no_sky_flock_is_wanted_on_the_fade_days_of_winter() -> void:
	for day in [91, 96, 115, 116, 117, 118, 119, 120]:
		assert_eq(_rules.target_count(WildlifeRules.FLOCK, day, NOON, _clear()), 0, "day %d" % day)


func test_sky_flocks_fade_in_across_the_turn_of_the_year() -> void:
	var flock := WildlifeRules.FLOCK
	var previous := _rules.season_factor(flock, 120)
	assert_gt(previous, 0.0, "the last winter day is already fading in")
	for day in range(121, 128):
		var factor := _rules.season_factor(flock, day)
		assert_gte(factor, previous, "day %d" % day)
		assert_lte(factor - previous, 0.25, "no step at day %d" % day)
		previous = factor
	assert_eq(_rules.season_factor(flock, 130), 1.0, "full a week into spring")
