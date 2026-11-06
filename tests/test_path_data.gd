extends GutTest
## The desire paths data file: its required keys, its first values and the ranges it allows.

const DATA_DIR := "user://test_paths"
const DATA_FILE := DATA_DIR + "/paths.cfg"


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func _write(text: String) -> PathRules:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return PathRules.from_file(DATA_FILE)


func test_the_data_file_holds_every_rule_with_the_first_values() -> void:
	var rules := PathRules.from_file(PathRules.DEFAULT_PATH)
	assert_true(rules.is_valid(), "problems: %s" % [rules.problems()])
	assert_eq(rules.trodden_from(), 8.0)
	assert_eq(rules.path_from(), 24.0)
	assert_eq(rules.most(), 32.0)
	assert_eq(rules.regrowth_per_night(), 2.0)
	assert_eq(rules.animal_step(), 0.5)


func test_the_stage_follows_the_steps() -> void:
	var rules := PathRules.from_file(PathRules.DEFAULT_PATH)
	assert_eq(rules.stage_of(0.0), PathRules.Stage.UNWORN)
	assert_eq(rules.stage_of(7.9), PathRules.Stage.UNWORN)
	assert_eq(rules.stage_of(8.0), PathRules.Stage.TRODDEN)
	assert_eq(rules.stage_of(23.9), PathRules.Stage.TRODDEN)
	assert_eq(rules.stage_of(24.0), PathRules.Stage.PATH)
	assert_eq(rules.stage_of(32.0), PathRules.Stage.PATH)


func test_every_missing_key_is_reported() -> void:
	var rules := _write("[wear]\ntrodden_from=8\n")
	var missing := rules.problems()
	assert_false(rules.is_valid())
	assert_true(missing.has("[wear] no path_from"))
	assert_true(missing.has("[wear] no animal_step"))
	assert_false(missing.has("[wear] no trodden_from"))
	assert_push_error_count(missing.size())


func test_numbers_out_of_order_or_range_are_reported() -> void:
	var text := FileAccess.get_file_as_string(PathRules.DEFAULT_PATH)
	text = text.replace("path_from=24", "path_from=40").replace(
		"regrowth_per_night=2", "regrowth_per_night=0"
	)
	text = text.replace("animal_step=0.5", "animal_step=-1")
	var rules := _write(text)
	assert_eq(
		rules.problems(),
		[
			"[wear] needs 0 < trodden_from < path_from <= most",
			"[wear] regrowth_per_night must be above 0",
			"[wear] animal_step must not be below 0",
		]
	)
	assert_push_error_count(3)


func test_a_missing_file_is_reported() -> void:
	var rules := PathRules.from_file(DATA_DIR + "/nothing.cfg")
	assert_false(rules.is_valid())
	assert_push_error_count(rules.problems().size() + 1)
