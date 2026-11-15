extends GutTest
## The kinds of a game day (Monday to Friday, Saturday, Sunday, feasts) and which activities fit
## which days (ActivityRules).

const MONDAY := 1
const SATURDAY := 6
const SUNDAY := 7
const EASTER := 14
const CHRISTMAS := 140
const AUTUMN_MONDAY := 71

var _rules := ActivityRules.default_rules()


func test_day_1_is_a_monday_and_the_week_runs_on_across_the_years_end() -> void:
	assert_eq(_rules.day_kinds(1), ["weekday"] as Array[String])
	assert_eq(_rules.day_kinds(5), ["weekday"] as Array[String])
	assert_eq(_rules.day_kinds(SATURDAY), ["saturday"] as Array[String])
	assert_eq(_rules.day_kinds(SUNDAY), ["sunday"] as Array[String])
	assert_eq(_rules.day_kinds(8), ["weekday"] as Array[String])
	assert_eq(_rules.day_kinds(141), ["weekday"] as Array[String], "the next year's Monday")


func test_easter_and_christmas_are_feast_days_and_sundays() -> void:
	assert_eq(_rules.day_kinds(EASTER), ["sunday", "feast"] as Array[String])
	assert_eq(_rules.day_kinds(CHRISTMAS), ["sunday", "feast"] as Array[String])
	assert_eq(
		_rules.day_kinds(CHRISTMAS + GameClock.DAYS_PER_YEAR), ["sunday", "feast"] as Array[String]
	)


func test_an_activity_fits_the_days_and_seasons_it_names() -> void:
	assert_true(_rules.fits_day("work", MONDAY))
	assert_false(_rules.fits_day("work", SUNDAY))
	assert_true(_rules.fits_day("water_field", MONDAY), "spring")
	assert_false(_rules.fits_day("water_field", AUTUMN_MONDAY))
	assert_true(_rules.fits_day("sleep", AUTUMN_MONDAY), "no days or seasons: always")


func test_the_default_start_may_hold_on_fewer_days_than_the_activity_can_be_planned() -> void:
	assert_true(_rules.fits_day("meet_at_the_krug", MONDAY))
	assert_false(_rules.has_default_on("meet_at_the_krug", MONDAY))
	assert_true(_rules.has_default_on("meet_at_the_krug", SATURDAY))
