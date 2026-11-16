extends ResourceCase
## The hint over the hotbar (ActionHintView): the key it shows for E is the bound one, it is quiet
## when there is nothing to do, and the game setting switches it off and is kept in the settings
## file.

const DIR := "user://test_action_hint"
const PATH := DIR + "/settings.cfg"

var _settings: GameSettings
var _view: ActionHintView


func before_each() -> void:
	super.before_each()
	_settings = GameSettings.new(PATH)
	_view = ActionHintView.new()
	_view.interactions = InteractionRegistry.new()
	FlowsCase.make(self, _state, _view.interactions)
	add_child_autofree(_view)
	_place(WorldObjectTypes.CHEST)


func after_each() -> void:
	_settings.reset_bindings()
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


func test_it_shows_e_and_use_lines_for_what_will_happen() -> void:
	_hold(ItemTypes.tool_item(ItemTypes.HOE, 0))
	_world.remove_object(_tile)
	_view.show_for(_state, _settings, _tile, true)
	assert_eq(_view.text(), "Use: Till")
	_place(WorldObjectTypes.CHEST)
	_hold(ItemTypes.NONE)
	_view.show_for(_state, _settings, _tile, true)
	assert_eq(_view.text(), "E: Open chest")


func test_it_shows_the_key_the_player_bound_to_e() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	_settings.bind(&"interact", 0, key)
	_view.show_for(_state, _settings, _tile, true)
	assert_eq(_view.text(), "F: Open chest")


func test_it_is_quiet_when_nothing_is_to_do_or_it_is_not_wanted() -> void:
	_hold(ItemTypes.NONE)
	_world.remove_object(_tile)
	_view.show_for(_state, _settings, _tile, true)
	assert_eq(_view.text(), "")
	_place(WorldObjectTypes.CHEST)
	_view.show_for(_state, _settings, _tile, false)
	assert_eq(_view.text(), "")


func test_the_setting_switches_it_off_and_stays_off_after_a_restart() -> void:
	assert_true(_settings.is_action_hint_shown)
	_settings.set_action_hint_shown(false)
	_view.show_for(_state, _settings, _tile, true)
	assert_eq(_view.text(), "")
	var loaded := GameSettings.new(PATH)
	loaded.load_file()
	assert_false(loaded.is_action_hint_shown)


func test_the_default_is_not_written_to_the_file() -> void:
	_settings.set_action_hint_shown(false)
	_settings.set_action_hint_shown(true)
	var file := ConfigFile.new()
	file.load(PATH)
	assert_false(file.has_section_key(GameSettings.GAME_SECTION, GameSettings.ACTION_HINT_KEY))


func test_a_value_that_is_not_true_or_false_is_ignored() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string('[game]\naction_hint="no"\n')
	file.close()
	var loaded := GameSettings.new(PATH)
	loaded.load_file()
	assert_true(loaded.is_action_hint_shown)
	assert_push_warning_count(1)


func test_the_game_page_button_toggles_the_setting() -> void:
	var menu := PauseMenu.new(_settings)
	add_child_autofree(menu)
	menu._toggle_action_hint()
	assert_false(_settings.is_action_hint_shown)
	assert_eq(menu._action_hint_button.text, "Action hint: Off")
