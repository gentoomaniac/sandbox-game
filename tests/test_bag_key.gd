extends GutTest
## B opens the bag (the character screen) and closes it; Tab does nothing; the hammer has no key,
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


func _press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	_main._unhandled_input(event)


func test_tab_is_bound_to_no_action() -> void:
	for action in GameSettings.actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				assert_ne(event.physical_keycode, KEY_TAB, str(action))


func test_b_opens_and_closes_the_bag_and_tab_does_nothing() -> void:
	_press_key(KEY_TAB)
	assert_false(_main._character_screen.is_open(), "Tab")
	_press_key(KEY_B)
	assert_true(_main._character_screen.is_open(), "B opens it")
	_press_key(KEY_B)
	assert_false(_main._character_screen.is_open(), "B closes it")


func test_the_hammer_is_taken_from_the_hotbar_and_its_key_resumes_a_dismissed_build_mode() -> void:
	var inventory: Inventory = _main._state.player.inventory
	var slot := -1
	for hotbar_slot in Inventory.HOTBAR_SIZE:
		if inventory.item_in(hotbar_slot) == ItemTypes.HAMMER:
			slot = hotbar_slot
	assert_ne(slot, -1, "the player starts with a hammer on the hotbar")
	_press_key(KEY_B)
	_main._character_screen.close()
	assert_false(_main._builder.is_building(), "B does not take the hammer")
	_press(&"hotbar_%d" % (slot + 1))
	assert_true(_main._builder.is_building(), "its slot key takes it")
	_main._builder.dismiss()
	_press(&"hotbar_%d" % (slot + 1))
	assert_true(_main._builder.is_building(), "and takes build mode up again")


func test_the_bag_button_opens_and_closes_the_bag_like_its_key() -> void:
	_main._hotbar.bag_requested.emit()
	assert_true(_main._character_screen.is_open())
	_main._hotbar.bag_requested.emit()
	assert_false(_main._character_screen.is_open())
