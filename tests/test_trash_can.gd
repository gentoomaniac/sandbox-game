extends GutTest
## The character screen's trash can: a stack put on it is destroyed only after the question
## "Destroy Logs (12)?" is answered with Destroy; Keep, Escape or a click elsewhere keep the pick.

const BACKPACK_SLOT := Inventory.HOTBAR_SIZE

var _player: PlayerState
var _screen: CharacterScreen
var _trash_can: TrashCan
var _window: SubViewport


func before_each() -> void:
	_player = PlayerState.new()
	_window = SubViewport.new()
	_window.size = Vector2i(640, 360)
	add_child_autofree(_window)
	var hotbar := HotbarHud.new()
	_window.add_child(hotbar)
	hotbar.show_inventory(_player.inventory)
	_screen = CharacterScreen.new(hotbar)
	_window.add_child(_screen)
	_screen.show_player(_player)
	_screen.open()
	_trash_can = _screen._trash_can
	await wait_process_frames(2)


func _put_picked_logs_on_the_trash_can() -> void:
	_player.inventory.slots[BACKPACK_SLOT] = {"item": ItemTypes.LOGS, "count": 12}
	_player.inventory.changed.emit()
	_screen._inventory_views[BACKPACK_SLOT].pressed.emit()
	_trash_can._slot.pressed.emit()


func _press_escape() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	_window.push_input(event)


func _click(position: Vector2) -> void:
	for is_pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = is_pressed
		event.position = position
		_window.push_input(event)


func _assert_still_picked() -> void:
	assert_false(_trash_can.is_asking())
	assert_eq(_screen._picked_inventory_slot, BACKPACK_SLOT)
	assert_eq(_player.inventory.slots[BACKPACK_SLOT], {"item": ItemTypes.LOGS, "count": 12})


func test_putting_a_picked_stack_on_the_trash_can_asks_what_it_would_destroy() -> void:
	_put_picked_logs_on_the_trash_can()
	assert_true(_trash_can.is_asking())
	assert_eq(_trash_can._question.text, "Destroy Logs (12)?")
	assert_eq(_player.inventory.slots[BACKPACK_SLOT]["count"], 12, "nothing is destroyed yet")


func test_clicking_the_trash_can_with_nothing_picked_asks_nothing() -> void:
	_trash_can._slot.pressed.emit()
	assert_false(_trash_can.is_asking())


func test_destroy_removes_the_stack_and_leaves_the_rest() -> void:
	_player.inventory.slots[BACKPACK_SLOT + 1] = {"item": ItemTypes.LOGS, "count": 3}
	_put_picked_logs_on_the_trash_can()
	_trash_can._destroy_button.pressed.emit()
	assert_true(_player.inventory.slots[BACKPACK_SLOT].is_empty())
	assert_eq(_player.inventory.slots[BACKPACK_SLOT + 1], {"item": ItemTypes.LOGS, "count": 3})
	assert_false(_trash_can.is_asking())
	assert_eq(_screen._picked_inventory_slot, -1)


func test_a_hotbar_stack_can_be_destroyed() -> void:
	var before := _player.inventory.slots[1].duplicate()
	_screen._on_inventory_slot_pressed(0)
	_trash_can._slot.pressed.emit()
	_trash_can._destroy_button.pressed.emit()
	assert_true(_player.inventory.slots[0].is_empty())
	assert_eq(_player.inventory.slots[1], before)


func test_a_worn_item_can_be_destroyed() -> void:
	_player.equipment.equip(Equipment.BODY, ItemTypes.WAISTCOAT)
	_player.equipment.equip(Equipment.LEGS, ItemTypes.BREECHES)
	var layers_before := _player.appearance.layers.size()
	_screen._equipment_views[Equipment.BODY].pressed.emit()
	_trash_can._slot.pressed.emit()
	assert_eq(_trash_can._question.text, "Destroy Waistcoat?")
	_trash_can._destroy_button.pressed.emit()
	assert_eq(_player.equipment.item_in(Equipment.BODY), ItemTypes.NONE)
	assert_eq(_player.equipment.item_in(Equipment.LEGS), ItemTypes.BREECHES)
	assert_eq(_player.appearance.layers.size(), layers_before - 1, "the look loses the waistcoat")


func test_keep_leaves_the_stack_picked() -> void:
	_put_picked_logs_on_the_trash_can()
	_trash_can._keep_button.pressed.emit()
	_assert_still_picked()


func test_escape_answers_keep_and_does_not_close_the_screen() -> void:
	_put_picked_logs_on_the_trash_can()
	_press_escape()
	_assert_still_picked()
	assert_true(_screen.is_open())
	_press_escape()
	assert_false(_screen.is_open())


func test_a_click_elsewhere_answers_keep_and_drops_nothing() -> void:
	_put_picked_logs_on_the_trash_can()
	watch_signals(_screen)
	_click(Vector2(4, 4))
	_assert_still_picked()
	assert_signal_not_emitted(_screen, "drop_requested")


func test_a_click_on_another_slot_answers_keep_and_moves_nothing() -> void:
	_put_picked_logs_on_the_trash_can()
	_click(_screen._inventory_views[BACKPACK_SLOT + 1].get_global_rect().get_center())
	_assert_still_picked()
	assert_true(_player.inventory.slots[BACKPACK_SLOT + 1].is_empty())


func test_one_item_is_asked_for_without_a_count() -> void:
	_player.inventory.slots[BACKPACK_SLOT] = {"item": ItemTypes.AXE, "count": 1}
	_player.inventory.changed.emit()
	_screen._inventory_views[BACKPACK_SLOT].pressed.emit()
	_trash_can._slot.pressed.emit()
	assert_eq(_trash_can._question.text, "Destroy Axe?")


func test_asking_does_not_change_the_size_of_the_panel() -> void:
	var size_before := _screen._panel.size
	_put_picked_logs_on_the_trash_can()
	await wait_process_frames(2)
	assert_eq(_screen._panel.size, size_before)


func test_closing_the_screen_or_switching_tabs_while_asking_destroys_nothing() -> void:
	_put_picked_logs_on_the_trash_can()
	_screen.open_tab(CharacterScreen.Tab.SKILLS)
	assert_false(_trash_can.is_asking())
	_screen.open_tab(CharacterScreen.Tab.CHARACTER)
	_put_picked_logs_on_the_trash_can()
	_screen.close()
	assert_false(_trash_can.is_asking())
	assert_eq(_player.inventory.slots[BACKPACK_SLOT], {"item": ItemTypes.LOGS, "count": 12})


func test_the_question_stays_inside_a_small_window() -> void:
	_window.size = Vector2i(200, 140)
	await wait_process_frames(2)
	_put_picked_logs_on_the_trash_can()
	assert_true(_window.get_visible_rect().encloses(_trash_can._prompt.get_global_rect()))


func test_resizing_the_window_answers_keep() -> void:
	_put_picked_logs_on_the_trash_can()
	_window.size = Vector2i(500, 300)
	assert_false(_trash_can.is_asking())
	assert_eq(_screen._picked_inventory_slot, BACKPACK_SLOT)


func test_the_buttons_take_focus() -> void:
	_put_picked_logs_on_the_trash_can()
	assert_true(_trash_can._keep_button.has_focus())
	assert_true(_trash_can._destroy_button.focus_mode != Control.FOCUS_NONE)
