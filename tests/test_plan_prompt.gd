extends GutTest
## The request that has the model plan a villager's day (NpcPrompt `plan_request`, [plan] of
## data/npc_talk.cfg) and the weather of the day in words (WeatherDay `words`). Pure: no model.

const SATURDAY_OF_SUMMER := 62

var _rules := NpcTalkRules.default_rules()
var _activity_rules := ActivityRules.default_rules()
var _antje := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())


func _day_to_plan() -> DayToPlan:
	var to_plan := DayToPlan.new()
	to_plan.today = SATURDAY_OF_SUMMER - 1
	to_plan.day = SATURDAY_OF_SUMMER
	to_plan.sunrise = 4 * 60 + 5
	to_plan.sunset = 21 * 60 + 40
	to_plan.weather_words = "8 to 17 °C, rain from 14:00 to 17:00, wind up to 6 m/s"
	to_plan.activities = [
		{"id": "breakfast", "walk_minutes": 0.0},
		{"id": "work", "walk_minutes": 10.2},
		{"id": "water_field", "walk_minutes": 3.0},
		{"id": "pick_flowers", "walk_minutes": 5.0},
	]
	return to_plan


func _user_text(to_plan: DayToPlan, full_sheets := false) -> String:
	var request := NpcPrompt.plan_request(_antje, to_plan, _activity_rules, _rules, full_sheets)
	return request["messages"][1]["content"]


func _rainy_day(hours: Array[int], rain := 0.5) -> WeatherDay:
	var day := WeatherDay.new()
	day.min_temperature = 2.6
	day.max_temperature = 9.4
	day.max_wind_speed = 5.6
	for hour in 24:
		day.rain_by_hour.append(rain if hours.has(hour) else 0.0)
	return day


# --- The weather of the day in words ---


func test_a_dry_day_is_told_with_no_rain() -> void:
	assert_eq(_rainy_day([]).words(0.25), "3 to 9 °C, no rain, wind up to 6 m/s")


func test_the_hours_of_rain_are_told_as_spans() -> void:
	var day := _rainy_day([6, 7, 14, 15, 16])
	assert_eq(
		day.words(0.25),
		"3 to 9 °C, rain from 06:00 to 08:00 and from 14:00 to 17:00, wind up to 6 m/s"
	)


func test_rain_in_the_last_hour_of_the_day_ends_at_midnight() -> void:
	assert_string_contains(_rainy_day([23]).words(0.25), "rain from 23:00 to 24:00")


func test_a_drizzle_below_the_limit_is_no_rain() -> void:
	assert_string_contains(_rainy_day([10, 11], 0.2).words(0.25), "no rain")


# --- The request ---


func test_the_request_has_a_system_and_a_user_turn_with_the_numbers_of_the_plan_section() -> void:
	var request := NpcPrompt.plan_request(_antje, _day_to_plan(), _activity_rules, _rules, false)
	assert_eq(request["messages"].size(), 2)
	assert_eq(request["messages"][0]["role"], "system")
	assert_eq(request["messages"][1]["role"], "user")
	assert_eq(request["temperature"], 0.6)
	assert_eq(request["max_tokens"], 400)


func test_it_tells_who_the_villager_is() -> void:
	var text := _user_text(_day_to_plan())
	assert_string_contains(text, "Antje Boysen")
	assert_string_contains(text, _antje.day, "the cut-down sheet leaves it out, the prompt adds it")
	assert_eq(
		_user_text(_day_to_plan(), true).count(_antje.day), 1, "told once with the full sheet"
	)


func test_it_tells_the_day_the_sun_and_the_weather() -> void:
	var text := _user_text(_day_to_plan())
	assert_string_contains(text, "Saturday, the 27th day of Summer, year 1")
	assert_string_contains(text, "rises at 04:05 and sets at 21:40")
	assert_string_contains(text, "rain from 14:00 to 17:00")


func test_a_whole_day_is_asked_from_the_morning() -> void:
	var text := _user_text(_day_to_plan())
	assert_string_contains(text, "Plan the whole day")
	assert_false(text.contains(" now. Plan"))


func test_the_rest_of_a_day_says_what_time_it_is() -> void:
	var to_plan := _day_to_plan()
	to_plan.from_minute = 14 * 60 + 20
	var text := _user_text(to_plan)
	assert_string_contains(text, "It is 14:20 now. Plan the rest of the day")
	assert_false(text.contains("Plan the whole day"))


func test_each_activity_is_told_with_its_walk_default_times_and_needs() -> void:
	var text := _user_text(_day_to_plan())
	assert_string_contains(text, "- breakfast: have breakfast, 0 minutes' walk, usually at 05:30\n")
	assert_string_contains(text, "- work: work, 11 minutes' walk, usually at 06:30, 13:00\n")
	assert_string_contains(
		text,
		(
			"- water_field: water the field, 3 minutes' walk, usually at 17:00, only in daylight,"
			+ " only when it is dry"
		)
	)


func test_yesterday_is_told_only_when_there_is_a_line_of_it() -> void:
	var to_plan := _day_to_plan()
	assert_false(_user_text(to_plan).contains("Yesterday"))
	to_plan.yesterday = "05:30 have breakfast, 06:30 work"
	assert_string_contains(
		_user_text(to_plan), "Yesterday Antje did: 05:30 have breakfast, 06:30 work."
	)


func test_what_the_villager_has_come_to_know_is_told_when_there_is_something() -> void:
	_antje.memories.append({"day": 1, "text": "I told the newcomer of the dyke.", "weight": 1})
	assert_string_contains(_user_text(_day_to_plan()), "I told the newcomer of the dyke.")
	_antje.memories.clear()
	assert_false(_user_text(_day_to_plan()).contains("come to know"))


func test_the_rules_of_the_answer_come_last() -> void:
	var text := _user_text(_day_to_plan())
	assert_string_contains(text, "at least 20 minutes apart, at most 12")
	assert_true(text.ends_with("The JSON for Antje:"))


func test_a_local_model_gets_the_cut_down_sheet_and_a_hosted_one_the_full_sheet() -> void:
	var cut_down := _user_text(_day_to_plan(), false)
	var full := _user_text(_day_to_plan(), true)
	assert_gt(full.length(), cut_down.length())
