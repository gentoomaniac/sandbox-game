extends GutTest
## The art setting: the classic or the new art, kept in the settings file.

const DIR := "user://test_settings"
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


func test_the_new_art_is_the_default_and_the_classic_survives_a_restart() -> void:
	assert_false(_settings.is_classic_art)
	_settings.set_classic_art(true)
	_settings = GameSettings.new(PATH)
	_settings.load_file()
	assert_true(_settings.is_classic_art)


func test_switching_the_art_is_announced() -> void:
	watch_signals(_settings)
	_settings.set_classic_art(true)
	assert_signal_emitted(_settings, "art_set_changed")


func test_the_new_art_is_not_stored() -> void:
	_settings.set_classic_art(true)
	_settings.set_classic_art(false)
	var file := ConfigFile.new()
	file.load(PATH)
	assert_false(file.has_section("display"))


func test_a_broken_art_setting_is_ignored() -> void:
	_write_file('[display]\nclassic_art="yes"\n')
	_settings.load_file()
	assert_false(_settings.is_classic_art)
	assert_push_warning_count(1)


func test_f7_switches_the_art_by_default() -> void:
	var events := InputMap.action_get_events(&"toggle_art_set")
	assert_eq(events.size(), 1)
	assert_eq(events[0].physical_keycode, KEY_F7)
