extends GutTest
## What the villagers do at the sales cart (StallRules, data/stall.cfg): the file is clean, the
## numbers are read by level and each kind of fault is reported.


func _rules_with(section: String, changes: Dictionary) -> StallRules:
	var values := DataFile.read_sections(StallRules.DEFAULT_PATH)
	values[section].merge(changes, true)
	return StallRules.new(values)


func test_the_data_file_is_clean() -> void:
	assert_eq(StallRules.default_rules().problems(), [] as Array[String])
	assert_true(StallRules.default_rules().is_valid())


func test_the_numbers_are_read_and_follow_the_level() -> void:
	var rules := StallRules.default_rules()
	assert_eq(rules.value("visits", "per_day"), 4)
	assert_eq(rules.value("contact", "needed_sale_points"), 10)
	assert_eq(rules.chance_percent(1), 0, "nobody who shuns the player comes")
	assert_eq(rules.chance_percent(2), 50, "half as often when mistrusting")
	assert_eq(rules.chance_percent(3), 100)
	assert_eq(rules.chance_percent(9), 200, "a close friend twice as often")
	assert_eq(rules.limit_percent(3), 120, "the worth and a fifth")
	assert_gt(rules.limit_percent(10), rules.limit_percent(3))


func test_a_key_that_is_missing_or_not_a_number_is_reported() -> void:
	var values := DataFile.read_sections(StallRules.DEFAULT_PATH)
	values["visits"].erase("per_day")
	values["chance"]["base_percent"] = -1
	values["buy"]["liked_weight"] = 1.5
	var problems := StallRules.new(values).problems()
	assert_eq(
		problems,
		(
			[
				"[visits] per_day is not a whole number from 0",
				"[chance] base_percent is not a whole number from 0",
				"[buy] liked_weight is not a whole number from 0",
			]
			as Array[String]
		)
	)


func test_a_list_of_the_wrong_length_is_reported() -> void:
	var rules := _rules_with("friendship", {"limit_percent": [100, 100]})
	assert_eq(
		rules.problems(),
		["[friendship] limit_percent is not a list of 10 whole numbers from 0"] as Array[String]
	)


func test_a_missing_or_unknown_section_is_reported() -> void:
	var values := DataFile.read_sections(StallRules.DEFAULT_PATH)
	values.erase("contact")
	values["stall"] = {}
	assert_eq(
		StallRules.new(values).problems(),
		["[contact] is missing", "[stall] is not a section of the file"] as Array[String]
	)
