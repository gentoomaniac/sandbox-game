extends GutTest
## B opens the bag and closes it; Tab does nothing; the hammer has no key,
## so building starts by selecting it on the hotbar and a dismissed build mode resumes with its key.

const MAIN_SCENE := preload("res://game/scenes/main.tscn")
const SETTLE_SECONDS := 30.0

var _main: Node


func before_each() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await wait_until(
		func() -> bool: return _main._view != null and _main._view.is_settled, SETTLE_SECONDS
	)


func after_each() -> void:
	_main._saves.wait()
	_main.free()


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_main._unhandled_input(event)


func _press_key(code: Key, is_shift_held := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.shift_pressed = is_shift_held
	event.pressed = true
	_main._unhandled_input(event)


func test_tab_is_bound_to_no_action() -> void:
	for action in GameSettings.actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				assert_ne(event.physical_keycode, KEY_TAB, str(action))


func test_b_opens_and_closes_the_bag_and_tab_does_nothing() -> void:
	_press_key(KEY_TAB)
	assert_false(_main._bag_screen.is_open(), "Tab")
	_press_key(KEY_B)
	assert_true(_main._bag_screen.is_open(), "B opens it")
	_press_key(KEY_B)
	assert_false(_main._bag_screen.is_open(), "B closes it")


func test_c_opens_the_character_window_and_closes_it() -> void:
	_press_key(KEY_C)
	assert_true(_main._character_screen.is_open(), "C opens it")
	assert_eq(_main._character_screen.current_tab(), CharacterScreen.Tab.CHARACTER)
	_press_key(KEY_B)
	assert_true(_main._character_screen.is_open(), "B does nothing over it")
	assert_false(_main._bag_screen.is_open())
	_press_key(KEY_C)
	assert_false(_main._character_screen.is_open(), "C closes it")
	_press_key(KEY_B)
	_press_key(KEY_C)
	assert_false(_main._character_screen.is_open(), "C does nothing over the bag")
	assert_true(_main._bag_screen.is_open())


func test_shift_c_opens_crafting_and_closes_it_and_leaves_the_character_window_alone() -> void:
	_press_key(KEY_C, true)
	assert_true(_main._crafting_screen.is_open(), "Shift+C opens crafting")
	assert_false(_main._character_screen.is_open())
	_press_key(KEY_C, true)
	assert_false(_main._crafting_screen.is_open(), "and closes it")


func test_shift_c_over_the_open_character_window_does_nothing() -> void:
	_press_key(KEY_C)
	_press_key(KEY_C, true)
	assert_true(_main._character_screen.is_open(), "Shift+C is not C")
	assert_false(_main._crafting_screen.is_open())


func test_k_opens_the_skills_in_the_character_window() -> void:
	_press_key(KEY_K)
	assert_true(_main._character_screen.is_open())
	assert_eq(_main._character_screen.current_tab(), CharacterScreen.Tab.SKILLS)


func test_escape_closes_the_character_window() -> void:
	_press_key(KEY_C)
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	_main._character_screen._unhandled_input(event)
	assert_false(_main._character_screen.is_open())


func test_the_hammer_is_taken_from_the_hotbar_and_its_key_resumes_a_dismissed_build_mode() -> void:
	var inventory: Inventory = _main._state.player.inventory
	var slot := -1
	for hotbar_slot in Inventory.HOTBAR_SIZE:
		if inventory.item_in(hotbar_slot) == ItemTypes.RUSTY_IRON_HAMMER:
			slot = hotbar_slot
	assert_ne(slot, -1, "the player starts with a hammer on the hotbar")
	_press_key(KEY_B)
	_main._bag_screen.close()
	assert_false(_main._builder.is_building(), "B does not take the hammer")
	_press(&"hotbar_%d" % (slot + 1))
	assert_true(_main._builder.is_building(), "its slot key takes it")
	_main._builder.dismiss()
	_press(&"hotbar_%d" % (slot + 1))
	assert_true(_main._builder.is_building(), "and takes build mode up again")


func test_the_bag_button_opens_and_closes_the_bag_like_its_key() -> void:
	_main._hotbar.bag_requested.emit()
	assert_true(_main._bag_screen.is_open())
	_main._hotbar.bag_requested.emit()
	assert_false(_main._bag_screen.is_open())
