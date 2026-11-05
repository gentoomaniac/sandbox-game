extends GutTest
## Settings: rebinding, the rules for conflicts, the defaults and the settings file.

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


func test_actions_are_the_game_actions_without_ui_ones() -> void:
	var actions := GameSettings.actions()
	assert_has(actions, &"move_left")
	assert_has(actions, &"pause")
	for action in actions:
		assert_false(action.begins_with("ui_"))


func test_binding_text_and_action_label_are_readable() -> void:
	assert_eq(_texts(&"move_up"), ["Up arrow", "W"])
	assert_eq(_texts(&"use"), ["Space"])
	assert_eq(_texts(&"use_click"), ["Left mouse"])
	assert_eq(GameSettings.action_label(&"move_up"), "Move up")
	assert_eq(GameSettings.action_label(&"hotbar_3"), "Hotbar 3")


func test_bind_replaces_the_slot() -> void:
	var note := _settings.bind(&"interact", 0, _key(KEY_F))
	assert_eq(_texts(&"interact"), ["F"])
	assert_eq(note, "")
	_settings.bind(&"interact", 1, _button(MOUSE_BUTTON_RIGHT))
	assert_eq(_texts(&"interact"), ["F", "Right mouse"])


func test_bind_ignores_modifiers_and_press_state() -> void:
	var event := _key(KEY_F)
	event.shift_pressed = true
	_settings.bind(&"interact", 0, event)
	var stored := _settings.bindings(&"interact")[0] as InputEventKey
	assert_false(stored.shift_pressed)
	assert_false(stored.pressed)


func test_conflict_moves_the_key_and_says_so() -> void:
	var note := _settings.bind(&"interact", 0, _key(KEY_W))
	assert_eq(note, "W removed from Move up")
	assert_eq(_texts(&"interact"), ["W"])
	assert_eq(_texts(&"move_up"), ["Up arrow"])


func test_the_same_key_in_another_slot_of_the_action_moves_silently() -> void:
	var note := _settings.bind(&"move_up", 0, _key(KEY_W))
	assert_eq(note, "")
	assert_eq(_texts(&"move_up"), ["W"])


func test_binding_what_the_slot_already_has_changes_nothing() -> void:
	assert_eq(_settings.bind(&"interact", 0, _key(KEY_E)), "")
	assert_eq(_texts(&"interact"), ["E"])


func test_conflict_works_for_mouse_buttons() -> void:
	var note := _settings.bind(&"interact", 0, _button(MOUSE_BUTTON_LEFT))
	assert_eq(note, "Left mouse removed from Use (mouse)")
	assert_eq(_settings.bindings(&"use_click"), [])


func test_clear_removes_one_binding() -> void:
	_settings.clear(&"move_up", 0)
	assert_eq(_texts(&"move_up"), ["W"])
	_settings.clear(&"move_up", 0)
	assert_eq(_texts(&"move_up"), [])


func test_the_pause_menu_keeps_a_key() -> void:
	assert_ne(_settings.clear(&"pause", 0), "")
	assert_eq(_texts(&"pause"), ["Escape"])
	assert_ne(_settings.bind(&"interact", 0, _key(KEY_ESCAPE)), "")
	assert_eq(_texts(&"pause"), ["Escape"])
	assert_eq(_texts(&"interact"), ["E"])
	_settings.bind(&"pause", 0, _key(KEY_P))
	assert_eq(_texts(&"pause"), ["P"])


func test_reset_restores_the_project_bindings() -> void:
	_settings.bind(&"interact", 0, _key(KEY_W))
	_settings.clear(&"use", 0)
	_settings.reset_bindings()
	assert_eq(_texts(&"move_up"), ["Up arrow", "W"])
	assert_eq(_texts(&"interact"), ["E"])
	assert_eq(_texts(&"use"), ["Space"])


func test_bindings_survive_a_restart() -> void:
	_settings.bind(&"interact", 0, _key(KEY_W))
	_settings.bind(&"use", 1, _button(MOUSE_BUTTON_MIDDLE))
	_settings.clear(&"toggle_build", 0)
	_settings.set_fullscreen(true)
	_restart_with_saved_file()
	assert_true(_settings.is_fullscreen)
	assert_eq(_texts(&"interact"), ["W"])
	assert_eq(_texts(&"move_up"), ["Up arrow"])
	assert_eq(_texts(&"use"), ["Space", "Middle mouse"])
	assert_eq(_texts(&"toggle_build"), [])


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


func test_more_than_two_bindings_in_the_file_are_cut() -> void:
	_write_file('[controls]\ninteract=["key:%d", "key:%d", "key:%d"]\n' % [KEY_F, KEY_G, KEY_H])
	_settings.load_file()
	assert_eq(_texts(&"interact"), ["F", "G"])


func test_a_missing_file_changes_nothing() -> void:
	_settings.load_file()
	assert_eq(_texts(&"interact"), ["E"])
