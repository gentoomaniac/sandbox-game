extends GutTest
## data/sounds.cfg: every event is there with all its keys and files, a broken file is
## reported, and the choice of variant and pitch stays within what the file says.

const DATA_DIR := "user://test_sounds"
const DATA_FILE := DATA_DIR + "/sounds.cfg"
const GOOD_EVENT := """
[ui_click]
files=["res://assets/sounds/ui_click_1.wav", "res://assets/sounds/ui_click_2.wav"]
volume_db=-3.0
pitch_min=0.9
pitch_max=1.1
bus="ui"
"""

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 5


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func _rules_from(text: String) -> SoundRules:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var rules := SoundRules.from_file(DATA_FILE)
	assert_push_error_count(rules.problems().size())
	return rules


## The problems that are about this event only (a file with one event lacks all the others).
func _problems_of(rules: SoundRules, event: String) -> Array[String]:
	return rules.problems().filter(func(problem: String) -> bool: return problem.contains(event))


func test_the_data_file_is_valid_and_has_every_event() -> void:
	var rules := SoundRules.default_rules()
	assert_eq(rules.problems(), [])
	for event in SoundRules.EVENTS:
		assert_true(rules.has_event(event), str(event))


func test_every_event_has_all_its_keys_and_existing_files() -> void:
	var rules := SoundRules.default_rules()
	for event in SoundRules.EVENTS:
		var values := rules.event(event)
		for key in SoundRules.REQUIRED_KEYS:
			assert_true(values.has(key), "%s has %s" % [event, key])
		for path in values["files"]:
			assert_true(ResourceLoader.exists(path), path)


func test_a_missing_event_is_reported() -> void:
	var rules := _rules_from(GOOD_EVENT)
	assert_has(rules.problems(), "no [step_grass]")
	assert_eq(_problems_of(rules, "[ui_click]"), [])


func test_a_missing_key_is_reported() -> void:
	var rules := _rules_from(GOOD_EVENT.replace('bus="ui"', ""))
	assert_has(rules.problems(), "[ui_click] no bus")


func test_a_file_that_does_not_exist_is_reported() -> void:
	var rules := _rules_from(GOOD_EVENT.replace("ui_click_2.wav", "nothing_here.wav"))
	assert_eq(
		_problems_of(rules, "[ui_click]"),
		["[ui_click] file res://assets/sounds/nothing_here.wav does not exist"]
	)


func test_an_empty_list_of_files_is_reported() -> void:
	var files_line := GOOD_EVENT.split("\n")[2]
	var rules := _rules_from(GOOD_EVENT.replace(files_line, "files=[]"))
	assert_eq(_problems_of(rules, "[ui_click]").size(), 1)


func test_a_pitch_range_the_wrong_way_round_is_reported() -> void:
	var rules := _rules_from(GOOD_EVENT.replace("pitch_min=0.9", "pitch_min=1.2"))
	assert_eq(_problems_of(rules, "[ui_click]").size(), 1)


func test_an_unknown_bus_is_reported() -> void:
	var rules := _rules_from(GOOD_EVENT.replace('"ui"', '"music"'))
	assert_eq(_problems_of(rules, "[ui_click]").size(), 1)


func test_the_chosen_file_is_one_of_the_events_and_every_variant_comes_up() -> void:
	var rules := _rules_from(GOOD_EVENT)
	var seen := {}
	for _i in 50:
		seen[rules.pick_file(&"ui_click", _rng)] = true
	assert_eq(seen.keys().size(), 2)
	for path in seen:
		assert_has(rules.event(&"ui_click")["files"], path)


func test_the_chosen_pitch_is_within_the_range() -> void:
	var rules := _rules_from(GOOD_EVENT)
	var lowest := 10.0
	var highest := 0.0
	for _i in 200:
		var pitch := rules.pick_pitch(&"ui_click", _rng)
		lowest = minf(lowest, pitch)
		highest = maxf(highest, pitch)
	assert_between(lowest, 0.9, 1.0, "it varies down")
	assert_between(highest, 1.0, 1.1, "and up")


func test_an_equal_pitch_range_plays_unchanged() -> void:
	var rules := SoundRules.default_rules()
	assert_eq(rules.pick_pitch(&"rain_loop", _rng), 1.0)
