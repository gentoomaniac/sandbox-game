extends GutTest
## The values of data/ambience.cfg that make no sense are reported, and the rules are then not
## valid.

var _rules := AmbienceRules.default_rules()


## The rules of the data file with one value changed.
func _rules_with(section: String, key: String, value: Variant) -> AmbienceRules:
	var values := AmbienceRules.read_values(AmbienceRules.DEFAULT_PATH)
	values[section][key] = value
	return AmbienceRules.new(values)


func _assert_bad(rules: AmbienceRules, words: String) -> void:
	assert_false(rules.is_valid(), words)
	var found := rules.bad_values().filter(func(text: String) -> bool: return text.contains(words))
	assert_eq(found.size(), 1, "bad_values names '%s': %s" % [words, rules.bad_values()])


func test_the_data_file_has_no_bad_values() -> void:
	assert_eq(_rules.bad_values(), [])
	assert_true(_rules.is_valid())


func test_a_full_wind_speed_not_above_the_calm_one_is_bad() -> void:
	var calm := _rules.value("loops", "wind_calm_speed")
	_assert_bad(_rules_with("loops", "wind_full_speed", calm), "wind_full_speed")
	_assert_bad(_rules_with("loops", "wind_full_speed", calm - 1.0), "wind_full_speed")


func test_a_wind_loop_that_is_never_audible_is_bad() -> void:
	_assert_bad(_rules_with("loops", "wind_max_level", 0.0), "wind_max_level")
	_assert_bad(_rules_with("loops", "wind_max_level", -0.5), "wind_max_level")


func test_bees_heard_nowhere_are_bad() -> void:
	_assert_bad(_rules_with("bees", "hear_tiles", 0.0), "hear_tiles")


func test_warm_frogs_not_above_cold_ones_are_bad() -> void:
	var cold := _rules.value("frogs", "cold_temperature")
	_assert_bad(_rules_with("frogs", "warm_temperature", cold), "warm_temperature")


func test_season_factors_of_the_wrong_length_are_bad() -> void:
	_assert_bad(_rules_with("birds", "season_factors", [1.0, 1.0, 1.0]), "[birds] season_factors")
	_assert_bad(
		_rules_with("frogs", "season_factors", [1.0, 1.0, 1.0, 1.0, 1.0]), "[frogs] season_factors"
	)


func test_phase_weights_of_the_wrong_length_are_bad() -> void:
	_assert_bad(_rules_with("birds", "phase_weights", [1.0, 1.0]), "[birds] phase_weights")
	_assert_bad(
		_rules_with("frogs", "phase_weights", [1.0, 1.0, 1.0, 1.0]), "[frogs] phase_weights"
	)


func test_thunder_at_the_latest_before_the_earliest_is_bad() -> void:
	var shortest := _rules.value("thunder", "min_delay_seconds")
	_assert_bad(_rules_with("thunder", "max_delay_seconds", shortest - 0.5), "max_delay_seconds")
	assert_true(_rules_with("thunder", "max_delay_seconds", shortest).is_valid(), "equal is fine")
