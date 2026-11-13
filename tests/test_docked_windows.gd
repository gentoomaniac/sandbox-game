extends CharacterDragCase
## The bag and the character window open side by side: the character window docked at the left,
## the bag at the bottom right above the hotbar, neither dimming nor covering the other.


func before_each() -> void:
	_open_both_screens()
	await wait_process_frames(2)


func test_the_character_window_is_at_the_left_and_the_bag_at_the_bottom_right() -> void:
	var screen := _window.get_visible_rect()
	var character_rect := _character._panel.get_global_rect()
	var bag_rect := _bag._panel.get_global_rect()
	assert_almost_eq(character_rect.position.x, float(Modal.DOCK_MARGIN), 1.0)
	assert_almost_eq(character_rect.get_center().y, screen.get_center().y, 1.0)
	assert_almost_eq(bag_rect.end.x, screen.end.x - Modal.DOCK_MARGIN, 1.0)
	assert_false(character_rect.intersects(bag_rect), "side by side")


func test_the_bag_is_above_the_hotbar() -> void:
	var hotbar_top := _window.get_visible_rect().end.y - HotbarHud.BOTTOM_MARGIN - SlotView.SIZE
	assert_lt(_bag._panel.get_global_rect().end.y, hotbar_top)


func test_the_windows_stay_docked_when_the_character_window_changes_tab() -> void:
	_character.open_tab(CharacterScreen.Tab.SKILLS)
	await wait_process_frames(2)
	assert_almost_eq(_character._panel.get_global_rect().position.x, float(Modal.DOCK_MARGIN), 1.0)


func test_the_game_is_not_dimmed_and_does_not_pause() -> void:
	assert_eq(_bag._backdrop.color.a, 0.0)
	assert_eq(_character._backdrop.color.a, 0.0)
	assert_false(get_tree().paused)


func test_a_window_the_player_moved_stays_where_it_was_put() -> void:
	var grip := _character._panel.get_global_rect().position + Vector2(2, 2)
	_drag(grip, grip + Vector2(100, 0))
	assert_almost_eq(_character._panel.get_global_rect().position.x, 8.0 + 100.0, 2.0)


func test_a_backpack_stack_dragged_onto_an_equipment_slot_is_worn() -> void:
	_set_stack(BACKPACK_SLOT, ItemTypes.STRAW_HAT, 1)
	_drag(_centre_of(_backpack_view(BACKPACK_SLOT)), _centre_of(_equipment_view(Equipment.HEAD)))
	assert_eq(_player.equipment.item_in(Equipment.HEAD), ItemTypes.STRAW_HAT)
	assert_true(_player.inventory.slots[BACKPACK_SLOT].is_empty())


func test_a_stack_that_does_not_fit_the_equipment_slot_stays_in_the_backpack() -> void:
	_set_stack(BACKPACK_SLOT, ItemTypes.LOGS, 3)
	_drag(_centre_of(_backpack_view(BACKPACK_SLOT)), _centre_of(_equipment_view(Equipment.HEAD)))
	assert_eq(_player.equipment.item_in(Equipment.HEAD), ItemTypes.NONE)
	assert_eq(_player.inventory.slots[BACKPACK_SLOT], {"item": ItemTypes.LOGS, "count": 3})


func test_worn_gear_dragged_into_the_backpack_is_taken_off() -> void:
	var target := BACKPACK_SLOT + 2
	_drag(_centre_of(_equipment_view(Equipment.BODY)), _centre_of(_backpack_view(target)))
	assert_eq(_player.equipment.item_in(Equipment.BODY), ItemTypes.NONE)
	assert_eq(_player.inventory.slots[target], {"item": ItemTypes.WAISTCOAT, "count": 1})


func test_hotbar_drags_and_right_click_keep_working_with_both_windows_open() -> void:
	const HOTBAR_SLOT := 5
	_set_stack(HOTBAR_SLOT, ItemTypes.STRAW_HAT, 1)
	_drag(_centre_of(_hotbar._slot_views[HOTBAR_SLOT]), _centre_of(_equipment_view(Equipment.HEAD)))
	assert_eq(_player.equipment.item_in(Equipment.HEAD), ItemTypes.STRAW_HAT)
	_click(_centre_of(_equipment_view(Equipment.HEAD)), MOUSE_BUTTON_RIGHT)
	assert_eq(_player.equipment.item_in(Equipment.HEAD), ItemTypes.NONE)
	_set_stack(BACKPACK_SLOT, ItemTypes.STRAW_HAT, 1)
	_click(_centre_of(_backpack_view(BACKPACK_SLOT)), MOUSE_BUTTON_RIGHT)
	assert_eq(_player.equipment.item_in(Equipment.HEAD), ItemTypes.STRAW_HAT, "right click wears")


func test_shift_click_on_the_hotbar_answers_once_with_both_windows_open() -> void:
	_set_stack(2, ItemTypes.LOGS, 5)
	_click(_centre_of(_hotbar._slot_views[2]), MOUSE_BUTTON_LEFT, true)
	assert_eq(_player.inventory.slots[BACKPACK_SLOT], {"item": ItemTypes.LOGS, "count": 5})
	for slot in Inventory.HOTBAR_SIZE:
		assert_ne(_player.inventory.item_in(slot), ItemTypes.LOGS, "not moved back again")


func test_closing_the_window_that_has_the_hotbar_leaves_it_to_the_other() -> void:
	_character.close()
	_set_stack(2, ItemTypes.LOGS, 5)
	_click(_centre_of(_hotbar._slot_views[2]), MOUSE_BUTTON_LEFT, true)
	assert_true(_player.inventory.slots[2].is_empty(), "the bag still answers")
