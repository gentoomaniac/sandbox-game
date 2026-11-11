extends CharacterDragCase
## Dragging stacks from the hotbar to and from the equipment slots, and letting go outside the
## slots, on the character screen, with real mouse events.

## Hotbar slots the tests use, free of the starting tools.
const HOTBAR_SLOT := 5


func before_each() -> void:
	_open_character_screen()
	await wait_process_frames(2)


func test_a_fitting_item_is_worn_by_dragging_it_onto_the_equipment_slot() -> void:
	_set_stack(HOTBAR_SLOT, ItemTypes.STRAW_HAT, 1)
	_drag(_centre_of(_hotbar._slot_views[HOTBAR_SLOT]), _centre_of(_equipment_view(Equipment.HEAD)))
	assert_eq(_player.equipment.item_in(Equipment.HEAD), ItemTypes.STRAW_HAT)
	assert_true(_player.inventory.slots[HOTBAR_SLOT].is_empty())


func test_the_slots_a_dragged_item_fits_light_up_while_it_is_dragged() -> void:
	_set_stack(HOTBAR_SLOT, ItemTypes.STRAW_HAT, 1)
	var from := _centre_of(_hotbar._slot_views[HOTBAR_SLOT])
	_drag_to(from, from + Vector2(0, 30))
	assert_true(_equipment_view(Equipment.HEAD)._is_drop_target)
	assert_false(_equipment_view(Equipment.FEET)._is_drop_target)
	_release(from + Vector2(0, 30))
	assert_false(_equipment_view(Equipment.HEAD)._is_drop_target)


func test_an_item_that_does_not_fit_is_not_taken_by_the_equipment_slot() -> void:
	_set_stack(HOTBAR_SLOT, ItemTypes.LOGS, 4)
	_drag(_centre_of(_hotbar._slot_views[HOTBAR_SLOT]), _centre_of(_equipment_view(Equipment.HEAD)))
	assert_eq(_player.equipment.item_in(Equipment.HEAD), ItemTypes.NONE)
	assert_eq(_player.inventory.slots[HOTBAR_SLOT], {"item": ItemTypes.LOGS, "count": 4})


func test_a_worn_item_dragged_onto_a_free_slot_is_taken_off() -> void:
	_empty_slot(HOTBAR_SLOT + 1)
	_drag(
		_centre_of(_equipment_view(Equipment.BODY)),
		_centre_of(_hotbar._slot_views[HOTBAR_SLOT + 1])
	)
	assert_eq(_player.equipment.item_in(Equipment.BODY), ItemTypes.NONE)
	assert_eq(_player.inventory.item_in(HOTBAR_SLOT + 1), ItemTypes.WAISTCOAT)


func test_a_worn_item_is_not_swapped_with_one_that_does_not_fit() -> void:
	_set_stack(HOTBAR_SLOT, ItemTypes.LOGS, 4)
	_drag(_centre_of(_equipment_view(Equipment.BODY)), _centre_of(_hotbar._slot_views[HOTBAR_SLOT]))
	assert_eq(_player.equipment.item_in(Equipment.BODY), ItemTypes.WAISTCOAT, "logs are no coat")
	assert_eq(_player.inventory.item_in(HOTBAR_SLOT), ItemTypes.LOGS)


func test_a_worn_item_does_not_go_to_another_equipment_slot() -> void:
	_drag(_centre_of(_equipment_view(Equipment.BODY)), _centre_of(_equipment_view(Equipment.COAT)))
	assert_eq(_player.equipment.item_in(Equipment.BODY), ItemTypes.WAISTCOAT)
	assert_eq(_player.equipment.item_in(Equipment.COAT), ItemTypes.NONE)


func test_a_worn_item_let_go_outside_the_panel_goes_back() -> void:
	_drag(_centre_of(_equipment_view(Equipment.BODY)), Vector2(4, 4))
	assert_eq(_player.equipment.item_in(Equipment.BODY), ItemTypes.WAISTCOAT)


func test_right_click_wears_an_item_and_takes_a_worn_one_off() -> void:
	_set_stack(HOTBAR_SLOT, ItemTypes.STRAW_HAT, 1)
	_click(_centre_of(_hotbar._slot_views[HOTBAR_SLOT]), MOUSE_BUTTON_RIGHT)
	assert_eq(_player.equipment.item_in(Equipment.HEAD), ItemTypes.STRAW_HAT)
	_click(_centre_of(_equipment_view(Equipment.HEAD)), MOUSE_BUTTON_RIGHT)
	assert_eq(_player.equipment.item_in(Equipment.HEAD), ItemTypes.NONE)
	assert_eq(_player.inventory.count_of(ItemTypes.STRAW_HAT), 1)
