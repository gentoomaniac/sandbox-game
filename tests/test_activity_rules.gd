extends GutTest
## The activities of data/activities.cfg and the checks on the file (ActivityRules).

var _rules := ActivityRules.default_rules()


## The real file with `changes` made to the section `section`, as rules.
func _rules_with(section: String, changes: Dictionary) -> ActivityRules:
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values[section].merge(changes, true)
	return ActivityRules.new(values)


func test_the_data_file_is_valid() -> void:
	assert_eq(_rules.problems(), [] as Array[String])


func test_the_activities_are_read_with_their_default_starts() -> void:
	assert_true(_rules.has("work"))
	assert_false(_rules.has("rules"), "a section that is no activity")
	assert_false(_rules.has("flying"))
	assert_eq(_rules.activity("work")["target"], "workplace")
	assert_eq(
		_rules.default_starts("work"),
		[{"minute": 6 * 60 + 30, "minutes": 330}, {"minute": 13 * 60, "minutes": 240}]
	)
	assert_eq(_rules.default_starts("tend_field"), [] as Array[Dictionary], "none: only planned")


func test_the_numbers_are_read() -> void:
	assert_eq(_rules.number("detour_factor"), 1.3)
	assert_eq(_rules.number("min_gap_minutes"), 20.0)
	assert_eq(_rules.search_tiles("field"), 40.0)
	assert_eq(_rules.feast_days(), [14, 140])


func test_the_sets_are_read() -> void:
	assert_true(_rules.has_set("farmer"))
	assert_false(_rules.has_set("pirate"))
	assert_true(_rules.set_activities("base").has("sleep"))
	assert_true(_rules.set_activities("farmer").has("tend_field"))


func test_times_are_hours_and_minutes_of_the_day() -> void:
	assert_eq(ActivityRules.minute_of("06:30"), 390)
	assert_eq(ActivityRules.minute_of("00:00"), 0)
	assert_eq(ActivityRules.minute_of("23:59"), 23 * 60 + 59)
	for text: Variant in ["24:00", "6:30", "06:60", "0630", "ab:cd", "06:30:00", "", 630, null]:
		assert_eq(ActivityRules.minute_of(text), -1, "%s is no time" % text)


func test_a_missing_rule_is_reported() -> void:
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values["rules"].erase("spread_minutes")
	assert_eq(ActivityRules.new(values).problems(), ["[rules] no spread_minutes"] as Array[String])


func test_a_rule_that_is_not_above_zero_is_reported() -> void:
	var problems := _rules_with("rules", {"arrive_margin_minutes": 0}).problems()
	assert_eq(problems, ["[rules] arrive_margin_minutes must be above 0"] as Array[String])


func test_search_tiles_and_feasts_are_checked() -> void:
	assert_eq(_rules_with("rules", {"search_tiles": {"field": 40}}).problems().size(), 1)
	assert_eq(_rules_with("rules", {"feasts": {"easter": 141}}).problems().size(), 1)


func test_an_unknown_target_doing_day_or_season_is_reported() -> void:
	var changes := {"target": "moon", "doing": "fly", "days": ["noday"], "seasons": ["monsoon"]}
	var problems := _rules_with("work", changes).problems()
	assert_eq(problems.size(), 4)
	assert_true(problems[0].begins_with("[work] target is not one of"))


func test_bad_times_and_lengths_are_reported() -> void:
	var bad_lists: Array = [
		[["25:00", 60]], [["06:30", 0]], [["06:30", 1441]], [["06:30"]], "06:30", []
	]
	for at: Variant in bad_lists:
		assert_eq(_rules_with("work", {"at": at}).problems().size(), 1, "%s" % [at])


func test_at_days_without_a_time_is_reported() -> void:
	var problems := _rules_with("tend_field", {"at_days": ["saturday"]}).problems()
	assert_eq(problems, ["[tend_field] at_days without at"] as Array[String])


func test_an_activity_without_its_keys_is_reported() -> void:
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values["work"].erase("verb")
	values["work"].erase("target")
	assert_eq(
		ActivityRules.new(values).problems(),
		["[work] no verb", "[work] no target"] as Array[String]
	)


func test_flags_and_radius_and_priority_are_checked() -> void:
	var changes := {"needs_dry": "yes", "radius": 0.0, "priority": 2.5}
	assert_eq(_rules_with("tend_field", changes).problems().size(), 3)


func test_a_set_that_names_an_unknown_activity_is_reported() -> void:
	var problems := _rules_with("sets", {"farmer": ["work", "plough"]}).problems()
	assert_has(problems, "[sets] farmer names plough, which is no activity")


func test_an_activity_in_no_set_is_reported() -> void:
	var problems := _rules_with("sets", {"farmer": ["work", "meet_at_the_krug"]}).problems()
	assert_has(problems, "[tend_field] is in no set")


func test_base_must_be_there_and_have_sleep() -> void:
	var without_sleep := ["breakfast", "dinner", "supper", "rest"]
	assert_has(_rules_with("sets", {"base": without_sleep}).problems(), "[sets] base has no sleep")
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values["sets"].erase("base")
	assert_has(ActivityRules.new(values).problems(), "[sets] no base")


func test_a_file_that_cannot_be_read_is_all_problems() -> void:
	assert_gt(ActivityRules.new({}).problems().size(), 0)


func test_the_walk_is_the_tiles_along_x_and_y_with_the_detour_at_the_pace() -> void:
	assert_eq(_rules.walk_minutes(Vector2(0, 0), Vector2(10, 5), 1.0), 15.0 * 1.3)
	assert_eq(_rules.walk_minutes(Vector2(10, 5), Vector2(0, 0), 2.0), 15.0 * 1.3 / 2.0)


func test_they_leave_the_walk_and_the_margin_before_the_start() -> void:
	assert_eq(_rules.leaving_minute(7 * 60, 19.5), 7 * 60 - 20 - 3)
	assert_lt(_rules.leaving_minute(5, 30.0), 0, "the evening before")
