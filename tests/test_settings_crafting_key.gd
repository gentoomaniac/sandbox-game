extends GutTest
## Crafting is on Shift+C and C is the character window's: a settings file may name Shift+C, an old
## one that gave crafting the plain C gets Shift+C, and one that gave C to another action takes it
## away.

const DIR := "user://test_settings_crafting_key"
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


func test_an_old_file_that_binds_crafting_to_c_gets_shift_c() -> void:
	_write_file('[controls]\ncrafting=["key:%d"]\n' % KEY_C)
	_settings.load_file()
	assert_eq(_texts(&"crafting"), ["Shift+C"])
	assert_push_warning_count(0)


func test_a_shifted_key_is_read_and_written_back() -> void:
	_write_file(
		'[controls]\ncrafting=["key:%d:shift"]\ndrop_item=["key:%d:shift"]\n' % [KEY_C, KEY_G]
	)
	_settings.load_file()
	assert_eq(_texts(&"crafting"), ["Shift+C"])
	assert_eq(_texts(&"drop_item"), ["Shift+G"])
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	_settings.bind(&"interact", 0, key)
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_value("controls", "drop_item"), ["key:%d:shift" % KEY_G])
	assert_false(file.has_section_key("controls", "crafting"), "the default is not written")


func test_a_file_that_moved_crafting_elsewhere_keeps_it_there() -> void:
	_write_file('[controls]\ncrafting=["key:%d"]\n' % KEY_V)
	_settings.load_file()
	assert_eq(_texts(&"crafting"), ["V"])


func test_the_action_that_an_old_file_gave_c_loses_it_to_the_character_window() -> void:
	_write_file('[controls]\ndrop_item=["key:%d"]\n' % KEY_C)
	_settings.load_file()
	assert_eq(_texts(&"character"), ["C"])
	assert_eq(_texts(&"drop_item"), [])
	assert_push_warning_count(1)


func test_a_character_window_the_file_moved_elsewhere_leaves_c_to_the_other_action() -> void:
	_write_file('[controls]\ncharacter=["key:%d"]\ndrop_item=["key:%d"]\n' % [KEY_F, KEY_C])
	_settings.load_file()
	assert_eq(_texts(&"character"), ["F"])
	assert_eq(_texts(&"drop_item"), ["C"])
	assert_push_warning_count(0)
