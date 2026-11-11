extends GutTest
## The lighting data file: its required keys, its first values and the ranges it allows.

const DATA_DIR := "user://test_lighting"
const DATA_FILE := DATA_DIR + "/lighting.cfg"


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func _write(text: String) -> LightingRules:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return LightingRules.from_file(DATA_FILE)


func test_the_data_file_holds_every_rule_with_the_first_values() -> void:
	var rules := LightingRules.from_file(LightingRules.DEFAULT_PATH)
	assert_true(rules.is_valid(), "problems: %s" % [rules.problems()])
	assert_eq(rules.tint_colour("night"), Color(0.4, 0.46, 0.74))
	assert_eq(rules.tint_colour("day"), Color.WHITE)
	assert_eq(rules.tint_hours("night_before_sunrise"), 1.5)
	assert_eq(rules.tint_hours("night_after_sunset"), 4.0)


func test_every_missing_key_is_reported() -> void:
	var rules := _write("[day_and_night]\nnight=Color(0, 0, 0, 1)\n")
	var missing := rules.problems()
	assert_false(rules.is_valid())
	assert_true(missing.has("[day_and_night] no dawn"))
	assert_true(missing.has("[day_and_night] no min_night_hours"))
	assert_false(missing.has("[day_and_night] no night"))
	assert_push_error_count(missing.size())


func test_wrong_values_are_reported() -> void:
	var text := FileAccess.get_file_as_string(LightingRules.DEFAULT_PATH)
	text = text.replace("dawn=Color(1, 0.82, 0.7, 1)", "dawn=0.8")
	text = text.replace("day_after_sunrise=2.0", "day_after_sunrise=-1.0")
	text = text.replace("purple_after_sunset=2.5", "purple_after_sunset=5.0")
	var rules := _write(text)
	assert_eq(
		rules.problems(),
		(
			[
				"[day_and_night] dawn must be a Color(r, g, b, a)",
				"[day_and_night] day_after_sunrise must not be below 0",
				"[day_and_night] needs glow_after_sunset < purple_after_sunset < night_after_sunset",
			]
			as Array[String]
		)
	)
	assert_push_error_count(3)
