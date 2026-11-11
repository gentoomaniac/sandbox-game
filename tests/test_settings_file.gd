extends GutTest
## Settings file: what is stored, and loading it, including files that are broken or edited.

const DIR := "user://test_settings"
const PATH := DIR + "/settings.cfg"

var _settings: GameSettings


func before_each() -> void:
	_settings = GameSettings.new(PATH)


func after_each() -> void:
	# Puts the project's bindings back into the input map, which the tests share.
	_settings.reset_bindings()
	_settings.set_fullscreen(false)
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _button(index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _texts(action: StringName) -> Array:
	return _settings.bindings(action).map(GameSettings.binding_text)


func _write_file(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Puts the settings file back after reset_bindings rewrote it, then starts over with a
## new GameSettings as a fresh game start would, on the project's own input map.
func _restart_with_saved_file() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	_settings.reset_bindings()
	_write_file(text)
	_settings = GameSettings.new(PATH)
	_settings.load_file()


func test_bindings_survive_a_restart() -> void:
	_settings.bind(&"interact", 0, _key(KEY_W))
	_settings.bind(&"use", 1, _button(MOUSE_BUTTON_MIDDLE))
	_settings.clear(&"drop_item", 0)
	_settings.set_fullscreen(true)
	_restart_with_saved_file()
	assert_true(_settings.is_fullscreen)
	assert_eq(_texts(&"interact"), ["W"])
	assert_eq(_texts(&"move_up"), ["Up arrow"])
	assert_eq(_texts(&"use"), ["Space", "Middle mouse"])
	assert_eq(_texts(&"drop_item"), [])


func test_the_file_holds_only_what_differs_from_the_defaults() -> void:
	_settings.bind(&"interact", 0, _key(KEY_F))
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_section_keys("controls"), PackedStringArray(["interact"]))


func test_an_action_missing_from_the_file_keeps_its_default() -> void:
	_write_file('[controls]\ninteract=["key:%d"]\n' % KEY_F)
	_settings.load_file()
	assert_eq(_texts(&"interact"), ["F"])
	assert_eq(_texts(&"move_up"), ["Up arrow", "W"])
	assert_eq(_texts(&"use"), ["Space"])


func test_a_broken_file_is_ignored() -> void:
	_write_file("[controls\nmove_up = [")
	_settings.load_file()
	assert_eq(_texts(&"move_up"), ["Up arrow", "W"])
	assert_engine_error("ConfigFile parse error")
	assert_push_warning_count(1)


func test_unknown_actions_and_unreadable_entries_are_ignored() -> void:
	_write_file(
		(
			(
				'[controls]\nno_such_action=["key:%d"]\nmove_up=["nonsense"]\nuse="key:%d"\n'
				+ 'interact=["key:%d"]\n'
			)
			% [KEY_F, KEY_F, KEY_G]
		)
	)
	_settings.load_file()
	assert_eq(_texts(&"move_up"), ["Up arrow", "W"])
	assert_eq(_texts(&"use"), ["Space"])
	assert_eq(_texts(&"interact"), ["G"])
	assert_push_warning_count(3)


func test_the_bindings_of_the_retired_actions_are_skipped_quietly() -> void:
	_write_file(
		(
			(
				'[controls]\nhotbar_1=["key:%d"]\nhotbar_9=["key:%d"]\nhotbar_10=["key:%d"]\n'
				+ 'select_hammer=["key:%d"]\n'
			)
			% [KEY_F, KEY_G, KEY_H, KEY_Z]
		)
	)
	_settings.load_file()
	assert_eq(_texts(&"hotbar_1"), ["F"])
	assert_false(InputMap.has_action(&"hotbar_9"))
	assert_false(InputMap.has_action(&"select_hammer"))
	assert_eq(_texts(&"inventory"), ["B"], "the bag keeps its key")
	assert_push_warning_count(0)


func test_more_than_two_bindings_in_the_file_are_cut() -> void:
	_write_file('[controls]\ninteract=["key:%d", "key:%d", "key:%d"]\n' % [KEY_F, KEY_G, KEY_H])
	_settings.load_file()
	assert_eq(_texts(&"interact"), ["F", "G"])


func test_fullscreen_is_stored_only_once_chosen() -> void:
	_settings.bind(&"interact", 0, _key(KEY_F))
	var file := ConfigFile.new()
	file.load(PATH)
	assert_false(file.has_section("display"))
	_settings.set_fullscreen(true)
	file.load(PATH)
	assert_true(file.get_value("display", "fullscreen"))


func test_loading_gives_the_pause_menu_its_key_back() -> void:
	_write_file('[controls]\npause=[]\ninteract=["key:%d"]\n' % KEY_ESCAPE)
	_settings.load_file()
	assert_eq(_texts(&"pause"), ["Escape"])
	assert_eq(_texts(&"interact"), [])
	assert_push_warning_count(1)


func test_loading_gives_a_shared_key_to_the_first_action() -> void:
	_write_file('[controls]\ninteract=["key:%d"]\n' % KEY_W)
	_settings.load_file()
	assert_eq(_texts(&"move_up"), ["Up arrow", "W"])
	assert_eq(_texts(&"interact"), [])
	assert_push_warning_count(1)


func test_a_missing_file_changes_nothing() -> void:
	_settings.load_file()
	assert_eq(_texts(&"interact"), ["E"])


func test_game_settings_default_to_one_times_and_normal_drain() -> void:
	assert_eq(_settings.ui_scale, 1.0)
	assert_eq(_settings.energy_drain, GameSettings.EnergyDrain.NORMAL)
	assert_eq(_settings.energy_drain_factor(), 1.0)
	_settings.load_file()
	assert_eq(_settings.ui_scale, 1.0)


func test_game_settings_survive_a_restart() -> void:
	_settings.set_ui_scale(1.25)
	_settings.set_energy_drain(GameSettings.EnergyDrain.HIGH)
	_restart_with_saved_file()
	assert_eq(_settings.ui_scale, 1.25)
	assert_eq(_settings.energy_drain, GameSettings.EnergyDrain.HIGH)
	assert_eq(_settings.energy_drain_factor(), 1.5)


func test_drain_factors() -> void:
	_settings.set_energy_drain(GameSettings.EnergyDrain.LOW)
	assert_eq(_settings.energy_drain_factor(), 0.5)
	assert_eq(
		GameSettings.next_drain(GameSettings.EnergyDrain.LOW), GameSettings.EnergyDrain.NORMAL
	)
	assert_eq(GameSettings.next_drain(GameSettings.EnergyDrain.HIGH), GameSettings.EnergyDrain.LOW)


func test_changing_a_game_setting_is_announced() -> void:
	watch_signals(_settings)
	_settings.set_energy_drain(GameSettings.EnergyDrain.LOW)
	assert_signal_emitted(_settings, "drain_changed")
	_settings.set_ui_scale(1.5)
	assert_signal_emitted_with_parameters(_settings, "ui_scale_changed", [1.5])


func test_the_ui_scale_stays_on_the_steps_and_in_range() -> void:
	_settings.set_ui_scale(1.1)
	assert_eq(_settings.ui_scale, 1.0)
	_settings.set_ui_scale(5.0)
	assert_eq(_settings.ui_scale, 2.0)
	_settings.set_ui_scale(0.0)
	assert_eq(_settings.ui_scale, 0.5)


func test_game_settings_at_their_defaults_are_not_stored() -> void:
	_settings.set_ui_scale(2.0)
	_settings.set_ui_scale(1.0)
	var file := ConfigFile.new()
	file.load(PATH)
	assert_false(file.has_section("game"))


func test_a_broken_ui_scale_or_drain_is_ignored() -> void:
	var broken := ["ui_scale=3.0", 'ui_scale="big"', 'energy_drain="extreme"', "energy_drain=2"]
	for index in broken.size():
		var text: String = broken[index]
		_write_file("[game]\n" + text + "\n")
		_settings.load_file()
		assert_eq(_settings.ui_scale, 1.0)
		assert_eq(_settings.energy_drain, GameSettings.EnergyDrain.NORMAL)
		assert_push_warning_count(index + 1)
		_settings = GameSettings.new(PATH)
