extends GutTest
## Sunrise and sunset over the year, and the day/night tint that follows them.

var _sun: Sun


func before_each() -> void:
	_sun = Sun.new()


func _hours(minutes: float) -> float:
	return minutes / 60.0


func test_the_days_are_longest_in_midsummer_shortest_in_midwinter_and_12_hours_between() -> void:
	assert_almost_eq(_hours(_sun.day_length(45)), 18.25, 0.01)
	assert_almost_eq(_hours(_sun.sunrise(45)), 3.875, 0.01)
	assert_almost_eq(_hours(_sun.sunset(45)), 22.125, 0.01)
	assert_almost_eq(_hours(_sun.sunrise(105)), 9.375, 0.01)
	assert_almost_eq(_hours(_sun.sunset(105)), 15.125, 0.01)
	assert_almost_eq(_hours(_sun.day_length(105)), 5.75, 0.01)
	assert_almost_eq(_hours(_sun.day_length(15)), 12.0, 0.01)
	assert_almost_eq(_hours(_sun.day_length(75)), 12.0, 0.01)


func test_solar_noon_runs_from_13_00_in_summer_to_12_15_in_winter() -> void:
	assert_almost_eq(_sun.solar_noon(45), 780.0, 0.01)
	assert_almost_eq(_sun.solar_noon(105), 735.0, 0.01)
	for day in range(1, 240):
		assert_lt(absf(_sun.solar_noon(day + 1) - _sun.solar_noon(day)), 2.0)


func test_the_day_length_changes_smoothly() -> void:
	for day in range(1, 240):
		assert_lt(absf(_sun.day_length(day + 1) - _sun.day_length(day)), 25.0)


func test_no_variation_gives_12_hour_days_all_year() -> void:
	_sun.variation = 0.0
	for day in [1, 45, 75, 105]:
		assert_almost_eq(_sun.sunrise(day), 360.0, 0.01)
		assert_almost_eq(_sun.sunset(day), 1080.0, 0.01)
		assert_almost_eq(_sun.solar_noon(day), 720.0, 0.01)
		assert_almost_eq(_sun.noon_height(day), 1.0, 0.0001)


func test_variation_scales_the_swing() -> void:
	_sun.variation = 0.5
	assert_almost_eq(_hours(_sun.day_length(45)), 15.125, 0.01)


func test_the_sun_is_down_at_night_and_highest_at_noon() -> void:
	assert_eq(_sun.height(105, 0), 0.0)
	assert_eq(_sun.height(105, 1439), 0.0)
	assert_gt(_sun.height(105, 720), 0.3)
	assert_almost_eq(_sun.height(45, 780), 1.0, 0.0001)
	assert_lt(_sun.noon_height(105), _sun.noon_height(45))


func test_time_text() -> void:
	assert_eq(Sun.time_text(345.0), "05:45")


func _distance(first: Color, second: Color) -> float:
	return absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)


func _tint_at(day: int, hour: int, minute: int, cloud_cover := 0.0) -> Color:
	var tint: DayNightTint = autofree(DayNightTint.new())
	var clock := GameClock.new()
	clock.day = day
	clock.set_time(hour, minute)
	tint.show_time(clock, cloud_cover)
	return tint.color


func test_the_dawn_tint_comes_at_sunrise() -> void:
	# Mid-winter: sunrise about 09:22.
	var sunrise := roundi(Sun.new().sunrise(105))
	var at_sunrise := _tint_at(105, sunrise / 60, sunrise % 60)
	assert_lt(_distance(at_sunrise, DayNightTint.DAWN), 0.02)
	assert_eq(_tint_at(105, 6, 0), DayNightTint.NIGHT)
	assert_eq(_tint_at(105, 12, 0), Color.WHITE)


func test_a_short_summer_night_still_gets_dark() -> void:
	assert_lt(_distance(_tint_at(45, 2, 0), DayNightTint.NIGHT), 0.01)
	assert_eq(_tint_at(45, 12, 0), Color.WHITE)


func test_the_tint_has_no_jump_at_midnight_in_any_season() -> void:
	for day in [1, 45, 75, 105]:
		var before := _tint_at(day, 23, 59)
		var after := _tint_at(day + 1, 0, 0)
		assert_lt(absf(before.get_luminance() - after.get_luminance()), 0.01, "day %d" % day)


func test_clouds_darken_the_day_but_not_the_night() -> void:
	assert_lt(_tint_at(45, 12, 0, 1.0).get_luminance(), 1.0)
	assert_gt(_tint_at(45, 12, 0, 1.0).get_luminance(), 0.7)
	assert_lt(_distance(_tint_at(45, 2, 0, 1.0), DayNightTint.NIGHT), 0.01)
