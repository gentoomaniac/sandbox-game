extends GutTest
## The cloud shadows over the ground (a look of WeatherView): none under a clear sky, at night
## or under a closed one, more with more cover, drifting downwind at a speed that
## follows the wind, and no effect on the weather itself.

var _view: WeatherView


func before_each() -> void:
	_view = WeatherView.new()
	add_child_autofree(_view)


func _sample(cover: float, wind_speed := 5.0, direction := Vector2.RIGHT) -> WeatherSample:
	var sample := WeatherSample.new()
	sample.cloud_cover = cover
	sample.wind_speed = wind_speed
	sample.wind_direction = direction
	return sample


## Shows the weather as the first one, which appears at once, and runs `seconds` of it.
func _show(sample: WeatherSample, daylight := 1.0, seconds := 0.0) -> void:
	_view.show_weather(sample, Color.WHITE, daylight)
	_view._process(0.0)
	if seconds > 0.0:
		_view._process(seconds)


func _shadows_shown() -> bool:
	return _view._cloud_shadows.visible


func _shadow_period() -> float:
	var size := LightingRules.default_rules().cloud_shadow("size")
	return WeatherView.CLOUD_SHADOW_PERIOD_PATCHES * size


func _shader_value(name: String) -> Variant:
	return _view._cloud_shadows.material.get_shader_parameter(name)


func test_partial_cover_by_day_casts_shadows() -> void:
	_show(_sample(0.5))
	assert_true(_shadows_shown())
	assert_gt(_view.cloud_shadow_strength, 0.0)


func test_a_clear_sky_casts_none() -> void:
	_show(_sample(0.0))
	assert_false(_shadows_shown())


func test_night_and_indoors_cast_none() -> void:
	_show(_sample(0.5), 0.0)
	assert_false(_shadows_shown())


func test_shadows_fade_with_the_daylight() -> void:
	_show(_sample(0.5), 1.0)
	var at_noon := _view.cloud_shadow_strength
	_show(_sample(0.5), 0.4)
	assert_almost_eq(_view.cloud_shadow_strength, at_noon * 0.4, 0.0001)


func test_a_closed_sky_casts_no_moving_shadows() -> void:
	_show(_sample(1.0))
	assert_false(_shadows_shown())
	assert_eq(_view.cloud_shadow_strength, 0.0)


func test_rain_and_snow_leave_no_sun_for_shadows() -> void:
	_show(_sample(0.5))
	var dry := _view.cloud_shadow_strength
	var raining := _sample(0.5)
	raining.rain = 0.8
	_view.show_weather(raining, Color.WHITE, 1.0)
	_view._process(5.0)
	assert_lt(_view.cloud_shadow_strength, dry * 0.5)


func test_more_cover_shadows_more_of_the_ground_without_moving_the_pattern() -> void:
	_show(_sample(0.3))
	var little_size: float = _shader_value("size")
	var little_cover: float = _shader_value("cover")
	_view = WeatherView.new()
	add_child_autofree(_view)
	_show(_sample(0.7))
	assert_eq(float(_shader_value("size")), little_size)
	assert_gt(float(_shader_value("cover")), little_cover)


func test_shadows_drift_downwind_at_a_speed_that_follows_the_wind() -> void:
	var per_wind := LightingRules.default_rules().cloud_shadow("speed_per_wind")
	_show(_sample(0.5, 4.0, Vector2.RIGHT), 1.0, 2.0)
	assert_almost_eq(
		_view.cloud_shadow_drift, Vector2(4.0 * per_wind * 2.0, 0.0), Vector2.ONE * 0.01
	)
	var slow := _view.cloud_shadow_drift.x
	_view = WeatherView.new()
	add_child_autofree(_view)
	_show(_sample(0.5, 8.0, Vector2.LEFT), 1.0, 2.0)
	assert_almost_eq(_view.cloud_shadow_drift.x, fposmod(-2.0 * slow, _shadow_period()), 0.01)
	assert_eq(_view.cloud_shadow_drift.y, 0.0)


func test_the_drift_wraps_at_the_period_of_the_pattern() -> void:
	_show(_sample(0.5, 10.0, Vector2.RIGHT), 1.0, 1.0)
	var before := _view.cloud_shadow_drift.x
	_view._process(
		_shadow_period() / (10.0 * LightingRules.default_rules().cloud_shadow("speed_per_wind"))
	)
	assert_almost_eq(_view.cloud_shadow_drift.x, before, 0.01)
	assert_lt(_view.cloud_shadow_drift.x, _shadow_period())


func test_no_wind_means_no_drift() -> void:
	_show(_sample(0.5, 0.0), 1.0, 3.0)
	assert_eq(_view.cloud_shadow_drift, Vector2.ZERO)


func test_showing_shadows_changes_nothing_in_the_weather() -> void:
	var sample := _sample(0.5)
	sample.sunlight = 60.0
	_show(sample, 1.0, 2.0)
	assert_eq(sample.cloud_cover, 0.5)
	assert_eq(sample.sunlight, 60.0)
