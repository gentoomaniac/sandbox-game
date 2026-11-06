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
	assert_eq(rules.value("fields", "row_height"), 13.0)
	assert_eq(rules.kind_shares().keys(), [&"knick", &"stone_wall", &"wattle_fence"])


func test_every_missing_key_is_reported() -> void:
	var rules := _write("[fields]\nrow_height=13\n[marsh]\nreach=30\n")
	var missing := rules.problems()
	assert_false(rules.is_valid())
	assert_true(missing.has("[fields] no field_width"))
	assert_true(missing.has("[kinds] no knick"))
	assert_true(missing.has("[ditches] no willow_chance"))
	assert_false(missing.has("[marsh] no reach"))
	assert_push_error_count(missing.size())


func test_fields_too_small_for_their_gaps_are_reported() -> void:
	var text := FileAccess.get_file_as_string(LandscapeRules.DEFAULT_PATH)
	text = text.replace("row_jitter=4", "row_jitter=9").replace("knick=0.8", "knick=0")
	text = text.replace("stone_wall=0.1", "stone_wall=0").replace(
		"wattle_fence=0.1", "wattle_fence=0"
	)
	var rules := _write(text)
	assert_eq(
		rules.problems(),
		[
			"[fields] row_height less row_jitter must be at least 6",
			"[kinds] no kind has a share",
		]
	)
	assert_push_error_count(2)


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
