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
	assert_eq(rules.busy_steps(), 10.0)
	assert_eq(rules.trodden_after_days(), 3)
	assert_eq(rules.path_after_days(), 8)
	assert_eq(rules.most_days(), 12)
	assert_eq(rules.quiet_day_loss(), 1)
	assert_eq(rules.animal_step(), 0.5)
	assert_eq(rules.villager_step(), 0.5)
	assert_eq(rules.soaked_by(), 1.5)
	assert_eq(rules.window_hours(), 10)


func test_the_stage_follows_the_days() -> void:
	var rules := PathRules.from_file(PathRules.DEFAULT_PATH)
	assert_eq(rules.stage_of(0), PathRules.Stage.UNWORN)
	assert_eq(rules.stage_of(2), PathRules.Stage.UNWORN)
	assert_eq(rules.stage_of(3), PathRules.Stage.TRODDEN)
	assert_eq(rules.stage_of(7), PathRules.Stage.TRODDEN)
	assert_eq(rules.stage_of(8), PathRules.Stage.PATH)
	assert_eq(rules.stage_of(12), PathRules.Stage.PATH)


func test_every_missing_key_is_reported() -> void:
	var rules := _write("[wear]\nbusy_steps=10\n")
	var missing := rules.problems()
	assert_false(rules.is_valid())
	assert_true(missing.has("[wear] no path_after_days"))
	assert_true(missing.has("[wear] no animal_step"))
	assert_true(missing.has("[mud] no window_hours"))
	assert_false(missing.has("[wear] no busy_steps"))
	assert_push_error_count(missing.size())


func test_numbers_out_of_order_or_range_are_reported() -> void:
	var text := FileAccess.get_file_as_string(PathRules.DEFAULT_PATH)
	text = text.replace("busy_steps=10", "busy_steps=0").replace(
		"path_after_days=8", "path_after_days=40"
	)
	text = text.replace("quiet_day_loss=1", "quiet_day_loss=0")
	text = text.replace("animal_step=0.5", "animal_step=-1")
	text = text.replace("villager_step=0.5", "villager_step=-1")
	text = text.replace("soaked_by=1.5", "soaked_by=0").replace("window_hours=10", "window_hours=0")
	var rules := _write(text)
	assert_eq(
		rules.problems(),
		[
			"[wear] busy_steps must be above 0",
			"[wear] needs 0 < trodden_after_days < path_after_days <= most_days",
			"[wear] quiet_day_loss must be at least 1",
			"[wear] animal_step must not be below 0",
			"[wear] villager_step must not be below 0",
			"[mud] soaked_by must be above 0",
			"[mud] window_hours must be at least 1",
		]
	)
	assert_push_error_count(7)


func test_a_missing_file_is_reported() -> void:
	var rules := PathRules.from_file(DATA_DIR + "/nothing.cfg")
	assert_false(rules.is_valid())
	assert_push_error_count(rules.problems().size() + 1)
