extends GutTest
## The top left line of the clock: the weekday, the date and the time.


func test_the_line_names_the_weekday_before_the_date_and_time() -> void:
	var clock := GameClock.new()
	clock.day = 10
	clock.set_time(7, 5)

	assert_eq(ClockHud.text_of(clock), "Wednesday, 10th day of Spring Year 1 · 07:05")
