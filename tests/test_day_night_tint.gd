extends GutTest
## The day and night tint: its colour across the day and across midnight, and how dark it gets
## through dusk, night and dawn.

## A day of spring with about 12 hours of daylight, so dusk and dawn are not squeezed.
const SPRING_DAY := 15


func test_night_is_dark_blue_but_not_black_and_noon_is_neutral() -> void:
	var tint: DayNightTint = autofree(DayNightTint.new())
	var clock := GameClock.new()

	clock.set_time(0, 0)
	tint.show_time(clock)
	assert_gt(tint.color.b, tint.color.r)
	assert_lt(tint.color.get_luminance(), 0.2)
	assert_gt(tint.color.get_luminance(), 0.1)

	clock.set_time(12, 0)
	tint.show_time(clock)
	assert_eq(tint.color, Color.WHITE)


func test_daylight_is_full_at_noon_and_none_at_night_and_indoors() -> void:
	var tint: DayNightTint = autofree(DayNightTint.new())
	var clock := GameClock.new()
	clock.set_time(12, 0)
	tint.show_time(clock, 1.0)
	assert_eq(tint.daylight, 1.0, "clouds don't change how much daylight there is")
	clock.set_time(0, 0)
	tint.show_time(clock)
	assert_eq(tint.daylight, 0.0)
	clock.set_time(12, 0)
	tint.show_time(clock)
	tint.show_interior()
	assert_eq(tint.daylight, 0.0)


func test_tint_is_continuous_across_midnight() -> void:
	var tint: DayNightTint = autofree(DayNightTint.new())
	var clock := GameClock.new()
	clock.set_time(23, 59)
	tint.show_time(clock)
	var before := tint.color
	clock.set_time(0, 0)
	tint.show_time(clock)
	assert_eq(tint.color, before)


func test_dusk_darkens_step_by_step_into_the_night() -> void:
	var sunset := Sun.new().sunset(SPRING_DAY)
	var night := LightingRules.default_rules().tint_colour("night").get_luminance()
	var hours_after_sunset := [-1.5, 0.5, 1.5, 2.5, 3.25, 4.0]
	var luminances: Array[float] = []
	for hours: float in hours_after_sunset:
		luminances.append(_luminance_at(sunset + hours * GameClock.MINUTES_PER_HOUR))
	assert_eq(luminances[0], Color.WHITE.get_luminance(), "full day before sunset")
	for index in range(1, luminances.size()):
		assert_lt(luminances[index], luminances[index - 1], "%s h" % hours_after_sunset[index])
	assert_gt(luminances[3], 0.5, "the purple twilight is still light")
	assert_almost_eq(luminances[5], night, 0.001, "full night four hours after sunset")
	assert_almost_eq(_luminance_at(sunset + 6.0 * GameClock.MINUTES_PER_HOUR), night, 0.001)


func test_dawn_lightens_step_by_step_out_of_the_night() -> void:
	var sunrise := Sun.new().sunrise(SPRING_DAY)
	var night := LightingRules.default_rules().tint_colour("night").get_luminance()
	var hours_after_sunrise := [-2.0, -1.5, -0.75, 0.0, 1.0, 2.5]
	var luminances: Array[float] = []
	for hours: float in hours_after_sunrise:
		luminances.append(_luminance_at(sunrise + hours * GameClock.MINUTES_PER_HOUR))
	assert_almost_eq(luminances[0], night, 0.001, "still night two hours before sunrise")
	assert_almost_eq(luminances[1], night, 0.001, "the dawn begins an hour and a half before")
	for index in range(2, luminances.size()):
		assert_gt(luminances[index], luminances[index - 1], "%s h" % hours_after_sunrise[index])
	assert_eq(luminances[5], Color.WHITE.get_luminance(), "full day after sunrise")


func _luminance_at(minute_of_day: float) -> float:
	var tint: DayNightTint = autofree(DayNightTint.new())
	var clock := GameClock.new()
	clock.day = SPRING_DAY
	var minute := posmod(roundi(minute_of_day), GameClock.MINUTES_PER_DAY)
	clock.set_time(floori(minute / 60.0), minute % 60)
	tint.show_time(clock)
	return tint.color.get_luminance()
