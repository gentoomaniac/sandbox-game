extends GutTest
## The day length variation setting.

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


func test_the_day_length_variation_defaults_to_full_and_survives_a_restart() -> void:
	assert_eq(_settings.day_length_variation, 100)
	assert_eq(_settings.day_length_variation_factor(), 1.0)
	_settings.set_day_length_variation(30)
	_settings = GameSettings.new(PATH)
	_settings.load_file()
	assert_eq(_settings.day_length_variation, 30)
	assert_almost_eq(_settings.day_length_variation_factor(), 0.3, 0.0001)


func test_the_day_length_variation_stays_on_the_steps_and_in_range() -> void:
	_settings.set_day_length_variation(34)
	assert_eq(_settings.day_length_variation, 30)
	_settings.set_day_length_variation(250)
	assert_eq(_settings.day_length_variation, 100)
	_settings.set_day_length_variation(-5)
	assert_eq(_settings.day_length_variation, 0)


func test_changing_the_day_length_variation_is_announced() -> void:
	watch_signals(_settings)
	_settings.set_day_length_variation(50)
	assert_signal_emitted(_settings, "day_length_changed")


func test_the_default_day_length_variation_is_not_stored() -> void:
	_settings.set_day_length_variation(50)
	_settings.set_day_length_variation(100)
	var file := ConfigFile.new()
	file.load(PATH)
	assert_false(file.has_section("game"))


func test_a_broken_day_length_variation_is_ignored() -> void:
	var broken := ["day_length_variation=150", 'day_length_variation="long"']
	for index in broken.size():
		_write_file("[game]\n" + String(broken[index]) + "\n")
		_settings.load_file()
		assert_eq(_settings.day_length_variation, 100)
		assert_push_warning_count(index + 1)
		_settings = GameSettings.new(PATH)
