extends CharacterDragCase
## The character screen's slots are moved by dragging: a stack follows the mouse while the button
## is held and lands where it is let go, with real mouse events. The hotbar slots of the HUD are
## among them.


func before_each() -> void:
	_open_character_screen()
	await wait_process_frames(2)


func test_a_stack_dragged_onto_an_empty_slot_goes_there() -> void:
	_set_stack(BACKPACK_SLOT + 3, ItemTypes.LOGS, 4)
	_empty_slot(2)
	_drag(_centre_of(_backpack_view(BACKPACK_SLOT + 3)), _centre_of(_backpack_view(2)))
	assert_eq(_player.inventory.slots[2], {"item": ItemTypes.LOGS, "count": 4})
	assert_true(_player.inventory.slots[BACKPACK_SLOT + 3].is_empty())


func test_a_stack_dragged_onto_a_different_item_swaps_places() -> void:
	_set_stack(BACKPACK_SLOT, ItemTypes.LOGS, 4)
	_set_stack(BACKPACK_SLOT + 1, ItemTypes.STONE, 2)
	_drag(_centre_of(_backpack_view(BACKPACK_SLOT)), _centre_of(_backpack_view(BACKPACK_SLOT + 1)))
	assert_eq(_player.inventory.slots[BACKPACK_SLOT + 1], {"item": ItemTypes.LOGS, "count": 4})
	assert_eq(_player.inventory.slots[BACKPACK_SLOT], {"item": ItemTypes.STONE, "count": 2})


func test_a_stack_dragged_onto_the_same_item_merges() -> void:
	_set_stack(BACKPACK_SLOT, ItemTypes.LOGS, 4)
	_set_stack(BACKPACK_SLOT + 1, ItemTypes.LOGS, 2)
	_drag(_centre_of(_backpack_view(BACKPACK_SLOT)), _centre_of(_backpack_view(BACKPACK_SLOT + 1)))
	assert_eq(_player.inventory.slots[BACKPACK_SLOT + 1], {"item": ItemTypes.LOGS, "count": 6})
	assert_true(_player.inventory.slots[BACKPACK_SLOT].is_empty())


func test_a_merge_that_overflows_the_stack_limit_leaves_the_rest_in_the_source() -> void:
	var limit: int = ItemTypes.TYPES[ItemTypes.LOGS]["stack_limit"]
	_set_stack(BACKPACK_SLOT, ItemTypes.LOGS, 10)
	_set_stack(BACKPACK_SLOT + 1, ItemTypes.LOGS, limit - 4)
	_drag(_centre_of(_backpack_view(BACKPACK_SLOT)), _centre_of(_backpack_view(BACKPACK_SLOT + 1)))
	assert_eq(_player.inventory.slots[BACKPACK_SLOT + 1], {"item": ItemTypes.LOGS, "count": limit})
	assert_eq(_player.inventory.slots[BACKPACK_SLOT], {"item": ItemTypes.LOGS, "count": 6})


func test_the_dragged_icon_is_on_a_layer_above_the_hotbar_and_goes_when_let_go() -> void:
	_set_stack(BACKPACK_SLOT, ItemTypes.LOGS, 4)
	var view := _backpack_view(BACKPACK_SLOT)
	var from := _centre_of(view)
	_drag_to(from, from + Vector2(40, 0))
	assert_gt(view._drag_icon_layer.layer, _hotbar.layer)
	_release(from + Vector2(40, 0))
	await wait_process_frames(1)
	assert_null(view._drag_icon_layer)


func test_every_slot_can_be_dragged_from_wherever_it_is_pressed() -> void:
	for slot in Inventory.SLOT_COUNT:
		_set_stack(slot, ItemTypes.TURNIP_SEEDS, 1)
	for slot in Inventory.SLOT_COUNT:
		var view := _backpack_view(slot)
		var rect := view.get_global_rect()
		var corners := [rect.position, rect.end - Vector2.ONE]
		for spot: Vector2 in [rect.get_center()] + corners:
			_press(spot)
			_move_held(spot, spot + Vector2(20, 0))
			assert_almost_eq(view.modulate.a, SlotView.DRAGGED_ALPHA, 0.01, "slot %d" % slot)
			_move_held(spot + Vector2(20, 0), spot)
			_release(spot)
			assert_eq(view.modulate.a, 1.0, "back to normal once let go")


func test_a_click_picks_nothing_up() -> void:
	_set_stack(BACKPACK_SLOT, ItemTypes.LOGS, 4)
	_click(_centre_of(_backpack_view(BACKPACK_SLOT)))
	assert_false(_window.gui_is_dragging())
	assert_eq(_backpack_view(BACKPACK_SLOT).modulate.a, 1.0)
	_click(_centre_of(_backpack_view(BACKPACK_SLOT + 1)))
	assert_eq(_player.inventory.slots[BACKPACK_SLOT], {"item": ItemTypes.LOGS, "count": 4})
	assert_true(_player.inventory.slots[BACKPACK_SLOT + 1].is_empty())


func test_the_stack_is_dragged_only_while_the_button_is_held() -> void:
	_set_stack(BACKPACK_SLOT, ItemTypes.LOGS, 4)
	var from := _centre_of(_backpack_view(BACKPACK_SLOT))
	_drag_to(from, from + Vector2(40, 0))
	assert_true(_window.gui_is_dragging())
	_release(from + Vector2(40, 0))
	assert_false(_window.gui_is_dragging())


func test_the_hotbar_takes_stacks_while_the_screen_is_open() -> void:
	_set_stack(BACKPACK_SLOT, ItemTypes.LOGS, 4)
	_empty_slot(5)
	_drag(_centre_of(_backpack_view(BACKPACK_SLOT)), _centre_of(_hotbar._slot_views[5]))
	assert_eq(_player.inventory.slots[5], {"item": ItemTypes.LOGS, "count": 4})
	_drag(_centre_of(_hotbar._slot_views[5]), _centre_of(_backpack_view(BACKPACK_SLOT + 2)))
	assert_eq(_player.inventory.slots[BACKPACK_SLOT + 2], {"item": ItemTypes.LOGS, "count": 4})


func test_the_hotbar_is_not_dragged_once_the_screen_is_closed() -> void:
	_screen.close()
	var view := _hotbar._slot_views[0]
	var before := _player.inventory.slots[0].duplicate()
	_drag(_centre_of(view), _centre_of(view) + Vector2(-60, 0))
	assert_eq(_player.inventory.slots[0], before)
	assert_false(_window.gui_is_dragging())


func test_shift_click_sends_a_stack_between_the_backpack_and_the_hotbar() -> void:
	var backpack_slot := BACKPACK_SLOT + 2
	_set_stack(backpack_slot, ItemTypes.LOGS, 7)
	for slot in Inventory.HOTBAR_SIZE:
		_player.inventory.slots[slot] = {} if slot == 5 else {"item": ItemTypes.AXE, "count": 1}
	_player.inventory.changed.emit()
	_click(_centre_of(_backpack_view(backpack_slot)), MOUSE_BUTTON_LEFT, true)
	assert_true(_player.inventory.slots[backpack_slot].is_empty())
	assert_eq(_player.inventory.slots[5], {"item": ItemTypes.LOGS, "count": 7})
	_click(_centre_of(_hotbar._slot_views[5]), MOUSE_BUTTON_LEFT, true)
	assert_eq(_player.inventory.slots[BACKPACK_SLOT], {"item": ItemTypes.LOGS, "count": 7})
	assert_true(_player.inventory.slots[5].is_empty())


func test_the_hud_hotbar_is_clickable_only_while_the_character_page_is_open() -> void:
	var slot := _hotbar._slot_views[0]
	assert_true(slot.is_clickable)
	_screen.close()
	assert_false(slot.is_clickable)
	_screen.open_tab(CharacterScreen.Tab.SKILLS)
	assert_false(slot.is_clickable, "the skills page moves no items")


func test_the_hotbar_is_drawn_above_the_dimmed_backdrop_of_the_screen() -> void:
	assert_gt(_hotbar.layer, _screen.layer)
