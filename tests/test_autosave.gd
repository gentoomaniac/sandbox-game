extends GutTest
## The autosave interval setting and the timer that follows it.

const DIR := "user://test_autosave"
const PATH := DIR + "/settings.cfg"

var _settings: GameSettings
var _timer := AutosaveTimer.new()


func before_each() -> void:
	_settings = GameSettings.new(PATH)


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


func _write_file(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_the_interval_defaults_to_ten_minutes_and_survives_a_restart() -> void:
	assert_eq(_settings.autosave_minutes, 10)
	_settings.set_autosave_minutes(40)
	_settings = GameSettings.new(PATH)
	_settings.load_file()
	assert_eq(_settings.autosave_minutes, 40)


func test_the_interval_stays_on_the_steps_and_in_range() -> void:
	_settings.set_autosave_minutes(34)
	assert_eq(_settings.autosave_minutes, 30)
	_settings.set_autosave_minutes(5)
	assert_eq(_settings.autosave_minutes, 10)
	_settings.set_autosave_minutes(600)
	assert_eq(_settings.autosave_minutes, 60)


func test_the_default_interval_is_not_stored() -> void:
	_settings.set_autosave_minutes(30)
	_settings.set_autosave_minutes(10)
	var file := ConfigFile.new()
	file.load(PATH)
	assert_false(file.has_section_key("game", "autosave_minutes"))


func test_a_broken_interval_is_ignored() -> void:
	_write_file('[game]\nautosave_minutes="often"\n')
	_settings.load_file()
	assert_eq(_settings.autosave_minutes, 10)
	assert_push_warning_count(1)


func test_an_interval_out_of_range_in_the_file_is_ignored() -> void:
	_write_file("[game]\nautosave_minutes=90\n")
	_settings.load_file()
	assert_eq(_settings.autosave_minutes, 10)
	assert_push_warning_count(1)


func test_the_timer_is_due_after_the_interval_of_play() -> void:
	_timer.tick(599.0)
	assert_false(_timer.is_due(10))
	_timer.tick(1.0)
	assert_true(_timer.is_due(10))
	assert_false(_timer.is_due(20))


func test_the_timer_stays_due_until_restarted() -> void:
	_timer.tick(700.0)
	assert_true(_timer.is_due(10))
	assert_true(_timer.is_due(10))
	_timer.restart()
	assert_false(_timer.is_due(10))


func test_the_timer_counts_only_the_time_it_is_ticked_for() -> void:
	# Main ticks it from _process, which does not run while a window pauses the game.
	var node := Node.new()
	node.set_script(preload("res://tests/autosave_ticker.gd"))
	node.timer = _timer
	add_child_autofree(node)
	await wait_frames(3)
	var counted: float = node.counted
	assert_gt(counted, 0.0)
	get_tree().paused = true
	await wait_frames(3)
	get_tree().paused = false
	assert_eq(node.counted, counted)
