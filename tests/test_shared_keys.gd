extends GutTest
## Actions that may share a key (see GameSettings.SHARING_PAIRS) keep it through loading and
## rebinding.

const DIR := "user://test_shared_keys"
const PATH := DIR + "/settings.cfg"

var _settings: GameSettings


func before_each() -> void:
	_settings = GameSettings.new(PATH)


func after_each() -> void:
	# Puts the project's bindings back into the input map, which the tests share.
	_settings.reset_bindings()
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _texts(action: StringName) -> Array:
	return _settings.bindings(action).map(GameSettings.binding_text)


func _write_file(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_actions_of_a_sharing_pair_keep_their_shared_key_when_a_file_is_loaded() -> void:
	_write_file('[controls]\ntoggle_coordinates=["key:%d"]\n' % KEY_F5)
	_settings.load_file()
	assert_eq(_texts(&"interact"), ["E"])
	assert_eq(_texts(&"build_next"), ["E", "Right arrow"])
	assert_eq(_texts(&"move_right"), ["Right arrow", "D"])
	assert_eq(_texts(&"build_style_up"), ["Up arrow"])
	assert_eq(_texts(&"move_up"), ["Up arrow", "W"])


func test_binding_a_key_to_one_of_a_sharing_pair_leaves_the_other() -> void:
	_settings.bind(&"build_next", 0, _key(KEY_X))
	var note := _settings.bind(&"interact", 0, _key(KEY_X))
	assert_eq(note, "")
	assert_eq(_texts(&"interact"), ["X"])
	assert_eq(_texts(&"build_next"), ["X", "Right arrow"])
