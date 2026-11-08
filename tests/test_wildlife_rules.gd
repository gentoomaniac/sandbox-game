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
## Tiles of flowers in bloom around the view: a meadow in flower.
const MEADOW := 100

var _rules := WildlifeRules.default_rules()
var _sun := Sun.new()


func _clear() -> WeatherSample:
	return WeatherSample.new()


func _dawn(day: int) -> int:
	return roundi(_sun.sunrise(day))


func test_the_tile_size_is_the_one_the_world_is_drawn_with() -> void:
	assert_eq(WildlifeRules.TILE_SIZE, TerrainTileset.TILE_SIZE)


func test_the_data_file_holds_every_required_key() -> void:
	assert_true(_rules.is_valid(), "missing: %s" % [_rules.problems()])


func test_every_missing_key_is_reported() -> void:
	var rules := WildlifeRules.new({"general": {"max_total": 12}, "bird": {"cap": 4}})
	var missing := rules.problems()
	assert_true(missing.has("[general] no tick_seconds"))
	assert_true(missing.has("[bird] no spawn_chance"))
	assert_true(missing.has("[deer] no cap"))
	assert_false(missing.has("[bird] no cap"))


func test_no_insects_in_winter_or_autumn() -> void:
	for kind in [WildlifeRules.BEE, WildlifeRules.BUTTERFLY]:
		var summer := _rules.target_count(kind, SUMMER, NOON, _clear(), MEADOW)
		assert_gt(summer, 0, "%s in summer" % kind)
		var spring := _rules.target_count(kind, SPRING, NOON, _clear(), MEADOW)
		assert_gt(spring, 0, "%s in spring" % kind)
		var winter := _rules.target_count(kind, WINTER, NOON, _clear(), MEADOW)
		assert_eq(winter, 0, "%s in winter" % kind)


func test_bees_are_only_where_flowers_bloom_and_more_where_there_are_more() -> void:
	var bee := WildlifeRules.BEE
	assert_eq(_rules.target_count(bee, SUMMER, NOON, _clear(), 0), 0, "no flowers, no bees")
	var few := _rules.target_count(bee, SUMMER, NOON, _clear(), 8)
	assert_between(few, 1, _rules.cap(bee) - 1, "a few flowers, fewer bees")
	assert_eq(_rules.target_count(bee, SUMMER, NOON, _clear(), MEADOW), _rules.cap(bee))
	assert_eq(_rules.target_count(bee, SUMMER, MIDNIGHT, _clear(), MEADOW), 0, "none at night")
	assert_gt(
		_rules.target_count(WildlifeRules.BUTTERFLY, SUMMER, NOON, _clear(), 0),
		0,
		"butterflies do without"
	)


func test_bees_appear_only_at_flowers_in_the_ring_around_the_view() -> void:
	var view := Rect2(0, 0, 384, 216)
	var player := view.get_center()
	var flowers: Array[Vector2i] = []
	for y in range(-8, 22):
		for x in range(-8, 32):
			if (x * 7 + y * 3) % 5 == 0:
				flowers.append(Vector2i(x, y))
	var points := _rules.flower_spawn_points(flowers, view, player)
	assert_gt(points.size(), 0)
	for point in points:
		var tile := Vector2i((point / WildlifeRules.TILE_SIZE).floor())
		assert_true(flowers.has(tile), "at a flower: %s" % point)
		assert_eq(point, TerrainTileset.tile_centre(tile), "in the middle of its tile")
		assert_true(_rules.is_spawn_point(point, view, player), "in the ring: %s" % point)
	assert_eq(_rules.flower_spawn_points([] as Array[Vector2i], view, player).size(), 0)


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


func test_storks_come_in_spring_and_summer_by_day_and_are_away_in_autumn_and_winter() -> void:
	for kind in [WildlifeRules.STORK, WildlifeRules.ROOF_STORK]:
		for day in [SPRING, SUMMER]:
			assert_gt(_rules.target_count(kind, day, NOON, _clear()), 0, "%s by day" % kind)
			assert_eq(_rules.target_count(kind, day, MIDNIGHT, _clear()), 0, "%s at night" % kind)
		for day in [AUTUMN, WINTER]:
			assert_eq(_rules.target_count(kind, day, NOON, _clear()), 0, "%s, day %d" % [kind, day])


func test_geese_graze_in_autumn_winter_and_spring_by_day_and_are_away_in_summer() -> void:
	for day in [AUTUMN, WINTER, SPRING]:
		assert_eq(_rules.target_count(WildlifeRules.GEESE, day, NOON, _clear()), 1, "day %d" % day)
		assert_eq(_rules.target_count(WildlifeRules.GEESE, day, MIDNIGHT, _clear()), 0)
	assert_eq(_rules.target_count(WildlifeRules.GEESE, SUMMER, NOON, _clear()), 0)
	assert_lt(_rules.activity(WildlifeRules.GEESE, SPRING, NOON, _clear()), 1.0, "most have left")


func test_skeins_of_geese_fly_over_mostly_at_dawn_and_dusk_and_not_in_summer() -> void:
	var at_dawn := _rules.activity(WildlifeRules.FLYING_GEESE, AUTUMN, _dawn(AUTUMN), _clear())
	var at_noon := _rules.activity(WildlifeRules.FLYING_GEESE, AUTUMN, NOON, _clear())
	assert_gt(at_dawn, at_noon)
	assert_gt(at_noon, 0.0)
	assert_eq(_rules.activity(WildlifeRules.FLYING_GEESE, SUMMER, NOON, _clear()), 0.0)


func test_the_count_never_passes_the_cap() -> void:
	for kind in WildlifeRules.KINDS:
		for day in [SPRING, SUMMER, AUTUMN, WINTER]:
			for minute in range(0, 24 * 60, 30):
				var count := _rules.target_count(kind, day, minute, _clear(), MEADOW)
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
			"flowers_per_animal": 0,
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


func test_mice_are_about_all_year_mostly_at_dusk_and_at_night() -> void:
	var mouse := WildlifeRules.MOUSE
	var by_day := _rules.activity(mouse, SUMMER, NOON, _clear())
	var at_night := _rules.activity(mouse, SUMMER, MIDNIGHT, _clear())
	var at_dusk := _rules.activity(mouse, SUMMER, roundi(_sun.sunset(SUMMER)), _clear())
	assert_gt(by_day, 0.0, "a few by day")
	assert_gt(at_night, by_day)
	assert_gt(at_dusk, by_day)
	assert_gt(_rules.target_count(mouse, WINTER, MIDNIGHT, _clear()), 0, "in winter too")


func test_frogs_are_about_from_spring_to_early_autumn_and_gone_in_winter() -> void:
	var frog := WildlifeRules.FROG
	var dusk := roundi(_sun.sunset(SUMMER))
	assert_eq(_rules.target_count(frog, SUMMER, dusk, _clear()), _rules.cap(frog))
	assert_gt(_rules.target_count(frog, SPRING, NOON, _clear()), 0)
	var in_autumn := _rules.activity(frog, AUTUMN, NOON, _clear())
	assert_lt(in_autumn, _rules.activity(frog, SUMMER, NOON, _clear()), "fewer in autumn")
	assert_eq(_rules.target_count(frog, WINTER, NOON, _clear()), 0)
	var rain := WeatherSample.new()
	rain.rain = 0.8
	assert_gt(_rules.target_count(frog, SUMMER, dusk, rain), 0, "rain doesn't drive them off")
