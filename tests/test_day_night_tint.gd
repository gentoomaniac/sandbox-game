extends GutTest


func test_night_is_blue_but_readable_and_noon_is_neutral() -> void:
	var tint: DayNightTint = autofree(DayNightTint.new())
	var clock := GameClock.new()

	clock.set_time(0, 0)
	tint.show_time(clock)
	assert_gt(tint.color.b, tint.color.r)
	assert_gt(tint.color.get_luminance(), 0.3)

	clock.set_time(12, 0)
	tint.show_time(clock)
	assert_eq(tint.color, Color.WHITE)


func test_tint_is_continuous_across_midnight() -> void:
	var tint: DayNightTint = autofree(DayNightTint.new())
	var clock := GameClock.new()
	clock.set_time(23, 59)
	tint.show_time(clock)
	var before := tint.color
	clock.set_time(0, 0)
	tint.show_time(clock)
	assert_eq(tint.color, before)
