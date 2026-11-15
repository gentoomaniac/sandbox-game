extends GutTest
## How loud and from where the waves of the shore sound (AmbienceRules, [sea] of
## data/ambience.cfg): by the distance to the water, the tide, the storm and the indoors.

var _rules := AmbienceRules.default_rules()
var _calm := WeatherSample.new()
var _storm := WeatherSample.new()


func before_each() -> void:
	_storm.storm = 1.0


func _level(distance: float, tide := 1.0, weather := _calm, is_inside := false) -> float:
	return _rules.sea_level(distance, tide, weather, is_inside)


func test_the_waves_are_at_full_level_at_the_edge() -> void:
	var full := _rules.value("sea", "level")
	assert_almost_eq(_level(0.0), full, 0.0001)
	assert_almost_eq(_level(_rules.value("sea", "near_tiles")), full, 0.0001)


func test_the_waves_fall_with_the_distance_and_end_at_the_reach() -> void:
	var reach := _rules.sea_reach(_calm)
	var last := INF
	for distance in range(4, int(reach)):
		var level := _level(float(distance))
		assert_lt(level, last, "quieter at %d tiles" % distance)
		last = level
	assert_gt(_level(reach - 1.0), 0.0)
	assert_eq(_level(reach), 0.0)
	assert_eq(_level(reach + 50.0), 0.0)
	assert_eq(_level(INF), 0.0, "no water found")


func test_the_reach_is_a_few_chunks_that_stay_loaded() -> void:
	var reach := _rules.sea_reach(_storm)
	assert_gt(_rules.sea_reach(_calm), 1.5 * Chunk.CHUNK_SIZE, "more than a chunk or two")
	assert_lte(reach, SeaSearch.MAX_RADIUS, "even in a storm, only what is loaded")


func test_half_way_it_is_a_quarter_with_the_default_curve() -> void:
	var near := _rules.value("sea", "near_tiles")
	var reach := _rules.sea_reach(_calm)
	var half := _level((near + reach) / 2.0)
	assert_almost_eq(half, _level(0.0) * pow(0.5, _rules.value("sea", "curve")), 0.0001)


func test_low_water_is_quieter_than_high_water_and_between_it_follows_the_tide() -> void:
	var high := _level(10.0, 1.0)
	var low := _level(10.0, 0.0)
	var middle := _level(10.0, 0.5)
	assert_almost_eq(low, high * _rules.value("sea", "low_water_share"), 0.0001)
	assert_between(middle, low, high)
	assert_gt(low, 0.0, "a far hush, not silence")


func test_a_storm_is_louder_and_reaches_further() -> void:
	assert_gt(_level(10.0, 1.0, _storm), _level(10.0, 1.0, _calm))
	var calm_reach := _rules.sea_reach(_calm)
	assert_gt(_rules.sea_reach(_storm), calm_reach)
	assert_eq(_level(calm_reach + 1.0, 1.0, _calm), 0.0)
	assert_gt(_level(calm_reach + 1.0, 1.0, _storm), 0.0)


func test_the_level_never_passes_full() -> void:
	assert_lte(_level(0.0, 1.0, _storm), 1.0)


func test_indoors_the_waves_are_a_share_of_the_outdoor_level() -> void:
	var outside := _level(10.0)
	var inside := _level(10.0, 1.0, _calm, true)
	assert_almost_eq(inside, outside * _rules.value("sea", "indoors_share"), 0.0001)
	assert_lt(inside, outside)


func test_the_waves_pan_to_the_side_the_water_is_on() -> void:
	assert_lt(_rules.sea_pan(Vector2(-20, 0)), -0.5, "water to the west: the left")
	assert_gt(_rules.sea_pan(Vector2(20, 0)), 0.5, "water to the east: the right")
	assert_almost_eq(_rules.sea_pan(Vector2(0, 30)), 0.0, 0.0001, "due south: the middle")
	assert_almost_eq(_rules.sea_pan(Vector2(-20, 0)), -_rules.value("sea", "pan_max"), 0.0001)


func test_the_pan_is_slight_at_the_very_edge_and_never_past_full() -> void:
	assert_eq(_rules.sea_pan(Vector2.ZERO), 0.0)
	assert_lt(absf(_rules.sea_pan(Vector2(-1, 0))), absf(_rules.sea_pan(Vector2(-20, 0))))
	assert_lte(absf(_rules.sea_pan(Vector2(-500, 3))), 1.0)


func test_the_waves_are_calm_up_to_a_storm_and_rough_in_a_full_one() -> void:
	assert_eq(_rules.sea_roughness(_calm), 0.0)
	assert_eq(_rules.sea_roughness(_storm), 1.0)
	var middle := WeatherSample.new()
	var from := _rules.value("sea", "storm_blend_from")
	var full := _rules.value("sea", "storm_blend_full")
	middle.storm = (from + full) / 2.0
	assert_almost_eq(_rules.sea_roughness(middle), 0.5, 0.0001)
	middle.storm = from * 0.5
	assert_eq(_rules.sea_roughness(middle), 0.0, "a breeze doesn't roughen it")


func test_the_crossfade_is_equal_power_and_all_calm_or_all_rough_at_the_ends() -> void:
	assert_eq(AmbienceRules.sea_blend(0.0), Vector2(1.0, 0.0))
	assert_almost_eq(AmbienceRules.sea_blend(1.0).x, 0.0, 0.0001)
	assert_almost_eq(AmbienceRules.sea_blend(1.0).y, 1.0, 0.0001)
	var last := Vector2(1.0, 0.0)
	for step in range(1, 11):
		var blend := AmbienceRules.sea_blend(step / 10.0)
		assert_almost_eq(blend.length(), 1.0, 0.0001, "no dip in the middle")
		assert_lt(blend.x, last.x, "the calm fades out")
		assert_gt(blend.y, last.y, "the rough fades in")
		last = blend
