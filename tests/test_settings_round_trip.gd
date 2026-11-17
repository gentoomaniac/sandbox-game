extends GutTest
## A settings file keeps its format through the split of GameSettings: it loads to the same
## values and saves back to the same bytes.

const DIR := "user://test_settings_round_trip"
const PATH := DIR + "/settings.cfg"
const FIXTURE := "res://tests/fixtures/settings_all_sections.cfg"

var _settings: GameSettings


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_settings = GameSettings.new(PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(FIXTURE))
	file.close()
	_settings.load_file()


func after_each() -> void:
	# Puts the project's bindings and window back, which the tests share.
	_settings.key_bindings.reset()
	_settings.set_fullscreen(false)
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


func _texts(action: StringName) -> Array:
	return _settings.key_bindings.bindings(action).map(KeyBindings.binding_text)


func test_a_file_with_every_section_saves_back_to_the_same_bytes() -> void:
	_settings.set_action_hint_shown(_settings.is_action_hint_shown)
	assert_eq(FileAccess.get_file_as_string(PATH), FileAccess.get_file_as_string(FIXTURE))


func test_the_file_loads_to_its_values() -> void:
	assert_eq(_texts(&"interact"), ["Y", "Middle mouse"])
	assert_eq(_texts(&"drop_item"), ["Shift+G"])
	assert_true(_settings.is_fullscreen)
	assert_true(_settings.is_classic_art)
	assert_eq(_settings.ui_scale, 0.75)
	assert_eq(_settings.energy_drain, GameSettings.EnergyDrain.HIGH)
	assert_eq(_settings.day_length_variation, 40)
	assert_eq(_settings.autosave_minutes, 30)
	assert_eq(_settings.max_fps, 120)
	assert_false(_settings.is_action_hint_shown)
	assert_eq(_settings.volume_percent(&"effects"), 55)
	assert_eq(_settings.volume_percent(&"ambience"), 0)
	assert_false(_settings.sound_in_background)
	assert_eq(_settings.profiles.active["name"], "Gemini")
	assert_eq(_settings.profiles.language_model()["api_key"], "not-a-real-key")
