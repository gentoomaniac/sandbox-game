extends GutTest
## An old settings file that gave B (the hammer's key then) to another action: the bag keeps B.

const DIR := "user://test_settings_bag_key"
const PATH := DIR + "/settings.cfg"

var _settings: GameSettings


func before_each() -> void:
	_settings = GameSettings.new(PATH)


func after_each() -> void:
	_settings.reset_bindings()
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


func _write_file(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _texts(action: StringName) -> Array:
	return _settings.bindings(action).map(GameSettings.binding_text)


func test_the_action_that_an_old_file_gave_b_loses_it_to_the_bag() -> void:
	_write_file('[controls]\ndrop_item=["key:%d"]\n' % KEY_B)
	_settings.load_file()
	assert_eq(_texts(&"inventory"), ["B"])
	assert_eq(_texts(&"drop_item"), [])
	assert_push_warning_count(1)


func test_a_bag_the_file_moved_elsewhere_leaves_b_to_the_other_action() -> void:
	_write_file('[controls]\ninventory=["key:%d"]\ndrop_item=["key:%d"]\n' % [KEY_F, KEY_B])
	_settings.load_file()
	assert_eq(_texts(&"inventory"), ["F"])
	assert_eq(_texts(&"drop_item"), ["B"])
	assert_push_warning_count(0)
