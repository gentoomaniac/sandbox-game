extends GutTest
## Quick save (F9) and quick load (F8): bound by default, and rebindable like the other actions.

const DIR := "user://test_quick_save_keys"
const PATH := DIR + "/settings.cfg"


func after_each() -> void:
	InputMap.load_from_project_settings()
	DirAccess.remove_absolute(PATH)


func _keys_of(action: StringName) -> Array:
	var keys := []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			keys.append(event.physical_keycode)
	return keys


func test_f9_saves_and_f8_loads_by_default() -> void:
	assert_eq(_keys_of(&"quick_save"), [KEY_F9])
	assert_eq(_keys_of(&"quick_load"), [KEY_F8])


func test_no_other_action_has_those_keys() -> void:
	for action in GameSettings.actions():
		if action == &"quick_save" or action == &"quick_load":
			continue
		for key: Key in _keys_of(action):
			assert_false(key in [KEY_F8, KEY_F9], "%s clashes" % action)


func test_both_have_a_label_and_a_description_for_the_controls_page() -> void:
	for action in [&"quick_save", &"quick_load"]:
		assert_true(GameSettings.ACTION_LABELS.has(action))
		assert_ne(GameSettings.action_description(action), "")


func test_a_new_key_for_quick_save_is_kept_and_the_old_one_is_free() -> void:
	var settings := GameSettings.new(PATH)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F5
	settings.bind(&"quick_save", 0, key)
	assert_eq(_keys_of(&"quick_save"), [KEY_F5])
	InputMap.load_from_project_settings()
	settings = GameSettings.new(PATH)
	settings.load_file()
	assert_eq(_keys_of(&"quick_save"), [KEY_F5])
	for action in GameSettings.actions():
		assert_does_not_have(_keys_of(action), KEY_F9, "%s still has F9" % action)
