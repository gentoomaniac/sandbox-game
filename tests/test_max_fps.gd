extends GutTest
## The frame rate limit setting.

const DIR := "user://test_max_fps"
const PATH := DIR + "/settings.cfg"

var _settings: GameSettings


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


func test_the_limit_defaults_to_sixty() -> void:
	assert_eq(_settings.max_fps, 60)


func test_the_limit_stays_on_the_steps_and_in_range() -> void:
	_settings.set_max_fps(94)
	assert_eq(_settings.max_fps, 90)
	_settings.set_max_fps(3)
	assert_eq(_settings.max_fps, 10)
	_settings.set_max_fps(900)
	assert_eq(_settings.max_fps, 240)


func test_zero_means_no_limit() -> void:
	_settings.set_max_fps(GameSettings.NO_FPS_LIMIT)
	assert_eq(_settings.max_fps, 0)


func test_the_limit_and_no_limit_survive_a_restart() -> void:
	for fps in [30, 0]:
		_settings.set_max_fps(fps)
		_settings = GameSettings.new(PATH)
		_settings.load_file()
		assert_eq(_settings.max_fps, fps)


func test_the_default_limit_is_not_stored() -> void:
	_settings.set_max_fps(30)
	_settings.set_max_fps(60)
	var file := ConfigFile.new()
	file.load(PATH)
	assert_false(file.has_section_key("game", "max_fps"))


func test_changing_the_limit_is_announced() -> void:
	watch_signals(_settings)
	_settings.set_max_fps(30)
	assert_signal_emitted(_settings, "max_fps_changed")


func test_a_broken_limit_in_the_file_is_ignored() -> void:
	_write_file('[game]\nmax_fps="fast"\n')
	_settings.load_file()
	assert_eq(_settings.max_fps, 60)
	assert_push_warning_count(1)


func test_the_option_overrides_the_setting_for_that_run_only() -> void:
	var options := StartupOptions.new(PackedStringArray(["--max-fps=30"]))
	assert_eq(options.max_fps_or(_settings.max_fps), 30)
	assert_eq(_settings.max_fps, 60)
	var file := ConfigFile.new()
	assert_ne(file.load(PATH), OK, "the option wrote the settings file")


func test_the_option_can_lift_the_limit() -> void:
	var options := StartupOptions.new(PackedStringArray(["--max-fps=0"]))
	assert_eq(options.max_fps_or(_settings.max_fps), GameSettings.NO_FPS_LIMIT)


func test_without_the_option_the_setting_applies() -> void:
	assert_eq(StartupOptions.new().max_fps_or(40), 40)


func test_the_test_runner_lifts_the_limit_for_the_main_scene() -> void:
	if OS.get_environment("SANDBOX_GAME_MAX_FPS") == "":
		pending("only under tools/run_tests.py, which sets SANDBOX_GAME_MAX_FPS")
		return
	assert_eq(StartupOptions.from_command_line().max_fps, GameSettings.NO_FPS_LIMIT)
