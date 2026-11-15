extends GutTest
## The landscape data file: its required keys, its first values and the sizes it allows.

const DATA_DIR := "user://test_landscape"
const DATA_FILE := DATA_DIR + "/landscape.cfg"


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func _write(text: String) -> LandscapeRules:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return LandscapeRules.from_file(DATA_FILE)


func test_the_data_file_holds_every_required_key() -> void:
	var rules := LandscapeRules.from_file(LandscapeRules.DEFAULT_PATH)
	assert_true(rules.is_valid(), "problems: %s" % [rules.problems()])
	assert_eq(rules.value("marsh", "reach"), 36.0)


func test_every_missing_key_is_reported() -> void:
	var rules := _write("[dykes]\nstretch_above=-0.3\n[marsh]\nreach=30\n")
	var missing := rules.problems()
	assert_false(rules.is_valid())
	assert_true(missing.has("[coast] no line_x"))
	assert_true(missing.has("[tideways] no spacing"))
	assert_false(missing.has("[dykes] no stretch_above"))
	assert_false(missing.has("[marsh] no reach"))
	assert_push_error_count(missing.size())


func test_a_missing_file_is_reported() -> void:
	var rules := LandscapeRules.from_file(DATA_DIR + "/nothing.cfg")
	assert_false(rules.is_valid())
	assert_push_error_count(rules.problems().size() + 1)


func test_tideways_that_could_run_together_are_reported() -> void:
	var text := FileAccess.get_file_as_string(LandscapeRules.DEFAULT_PATH)
	var rules := _write(text.replace("meander=11", "meander=15"))
	assert_eq(
		rules.problems(),
		["[tideways] twice the meander and the widest must be less than the spacing"]
	)
	assert_push_error_count(1)
