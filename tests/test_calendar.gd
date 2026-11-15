extends GutTest
## The calendar of a day number: season, day of the season, year and weekday. Seasons have 35 days
## (five weeks) and a year 140, so the weeks line up with both.


func _clock_on(day: int) -> GameClock:
	var clock := GameClock.new()
	clock.day = day
	return clock


func test_day_150_is_the_10th_day_of_spring_year_2() -> void:
	var clock := _clock_on(150)
	assert_eq(clock.season(), GameClock.Season.SPRING)
	assert_eq(clock.day_of_season(), 10)
	assert_eq(clock.day_of_year(), 10)
	assert_eq(clock.year(), 2)
	assert_eq(clock.date_text(), "10th day of Spring Year 2")


func test_a_season_has_35_days_and_a_year_140() -> void:
	assert_eq(GameClock.DAYS_PER_SEASON, 35)
	assert_eq(GameClock.DAYS_PER_YEAR, 140)


func test_seasons_change_every_35_days() -> void:
	assert_eq(_clock_on(35).date_text(), "35th day of Spring Year 1")
	assert_eq(_clock_on(36).date_text(), "1st day of Summer Year 1")
	assert_eq(_clock_on(70).date_text(), "35th day of Summer Year 1")
	assert_eq(_clock_on(71).season(), GameClock.Season.AUTUMN)
	assert_eq(_clock_on(106).season(), GameClock.Season.WINTER)
	assert_eq(_clock_on(140).date_text(), "35th day of Winter Year 1")
	assert_eq(_clock_on(141).date_text(), "1st day of Spring Year 2")
	assert_eq(_clock_on(280).year(), 2)
	assert_eq(_clock_on(281).year(), 3)


func test_the_day_of_the_year_counts_from_1_to_140() -> void:
	assert_eq(_clock_on(1).day_of_year(), 1)
	assert_eq(_clock_on(140).day_of_year(), 140)
	assert_eq(_clock_on(141).day_of_year(), 1)
	assert_eq(_clock_on(36).day_of_year(), 36)


func test_day_1_is_a_monday_and_every_7th_day_a_sunday() -> void:
	assert_eq(_clock_on(1).weekday_name(), "Monday")
	assert_eq(_clock_on(1).weekday(), 0)
	assert_eq(_clock_on(7).weekday_name(), "Sunday")
	assert_eq(_clock_on(7).weekday(), 6)
	assert_eq(_clock_on(8).weekday_name(), "Monday")
	assert_eq(_clock_on(14).weekday_name(), "Sunday")


func test_the_weeks_line_up_with_the_seasons_and_the_years() -> void:
	assert_eq(_clock_on(35).weekday_name(), "Sunday", "the last day of spring")
	assert_eq(_clock_on(36).weekday_name(), "Monday", "the first of summer")
	assert_eq(_clock_on(140).weekday_name(), "Sunday", "the last day of the year")
	assert_eq(_clock_on(141).weekday_name(), "Monday", "the first of the next")
