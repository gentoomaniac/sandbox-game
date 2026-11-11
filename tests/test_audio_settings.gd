extends GutTest
## The audio settings: defaults, steps, what is stored in the settings file, and loading it.

const DIR := "user://test_audio_settings"
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


func _reloaded() -> GameSettings:
	var settings := GameSettings.new(PATH)
	settings.load_file()
	return settings


func test_defaults_are_full_volume_and_sound_in_background() -> void:
	for channel in GameSettings.VOLUME_CHANNELS:
		assert_eq(_settings.volume_percent(channel), 100, str(channel))
	assert_true(_settings.sound_in_background)


func test_volumes_are_kept_in_range_and_on_the_steps() -> void:
	_settings.set_volume(&"master", 47)
	assert_eq(_settings.volume_percent(&"master"), 45)
	_settings.set_volume(&"effects", 250)
	assert_eq(_settings.volume_percent(&"effects"), 100)
	_settings.set_volume(&"ambience", -10)
	assert_eq(_settings.volume_percent(&"ambience"), 0)


func test_changes_are_announced() -> void:
	watch_signals(_settings)
	_settings.set_volume(&"master", 80)
	_settings.set_sound_in_background(false)
	assert_signal_emit_count(_settings, "audio_changed", 2)


func test_audio_settings_survive_a_restart() -> void:
	_settings.set_volume(&"master", 60)
	_settings.set_volume(&"effects", 0)
	_settings.set_volume(&"ambience", 35)
	_settings.set_volume(&"music", 0)
	_settings.set_sound_in_background(false)
	var loaded := _reloaded()
	assert_eq(loaded.volume_percent(&"master"), 60)
	assert_eq(loaded.volume_percent(&"effects"), 0)
	assert_eq(loaded.volume_percent(&"ambience"), 35)
	assert_eq(loaded.volume_percent(&"music"), 0)
	assert_false(loaded.sound_in_background)


func test_loading_does_not_announce_a_change() -> void:
	_settings.set_volume(&"master", 60)
	var loaded := GameSettings.new(PATH)
	watch_signals(loaded)
	loaded.load_file()
	assert_signal_not_emitted(loaded, "audio_changed")


func test_only_what_differs_from_the_defaults_is_stored() -> void:
	_settings.set_volume(&"master", 60)
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_section_keys(GameSettings.AUDIO_SECTION), PackedStringArray(["master"]))
	_settings.set_volume(&"master", 100)
	file = ConfigFile.new()
	file.load(PATH)
	assert_false(file.has_section(GameSettings.AUDIO_SECTION))


func test_a_broken_entry_is_ignored_and_the_rest_loads() -> void:
	_write_file('[audio]\nmaster="loud"\neffects=40\nambience=250\nin_background=3\n')
	var loaded := _reloaded()
	assert_eq(loaded.volume_percent(&"master"), 100)
	assert_eq(loaded.volume_percent(&"effects"), 40)
	assert_eq(loaded.volume_percent(&"ambience"), 100)
	assert_true(loaded.sound_in_background)
	assert_push_warning_count(3)
