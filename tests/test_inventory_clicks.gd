extends GutTest
## Every slot of the character screen answers a click, wherever on the slot it lands, the
## hotbar slots of the HUD among them.

var _player: PlayerState
var _screen: CharacterScreen
var _hotbar: HotbarHud
var _window: SubViewport


func before_each() -> void:
	_player = PlayerState.new()
	# A viewport of the game's size of its own, so the clicks need no window.
	_window = SubViewport.new()
	_window.size = Vector2i(640, 360)
	add_child_autofree(_window)
	_hotbar = HotbarHud.new()
	_window.add_child(_hotbar)
	_hotbar.show_inventory(_player.inventory)
	_window.add_child(FadeScreen.new())
	_screen = CharacterScreen.new(_hotbar)
	_window.add_child(_screen)
	_screen.show_player(_player)
	_screen.open()
	await wait_process_frames(2)


func after_each() -> void:
	_hold_shift(false)


func _hold_shift(is_held := true) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = is_held
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	_window.push_input(motion)
	for is_pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = is_pressed
		event.position = position
		_window.push_input(event)


func _click_slot(slot: int) -> void:
	_click(_screen._inventory_views[slot].get_global_rect().get_center())


## The spots of a slot to click: the centre and just inside each corner.
func _spots(view: SlotView) -> Array[Vector2]:
	var rect := view.get_global_rect()
	var spots: Array[Vector2] = [rect.get_center()]
	var corners := [rect.position, rect.end]
	corners.append(Vector2(rect.end.x, rect.position.y))
	corners.append(Vector2(rect.position.x, rect.end.y))
	for corner: Vector2 in corners:
		spots.append(corner.move_toward(rect.get_center(), 1.0))
	return spots


func test_every_slot_can_be_picked_up_wherever_it_is_clicked() -> void:
	for slot in Inventory.SLOT_COUNT:
		_player.inventory.slots[slot] = {"item": ItemTypes.TURNIP_SEEDS, "count": 1}
	_player.inventory.changed.emit()
	for slot in Inventory.SLOT_COUNT:
		var view: SlotView = _screen._inventory_views[slot]
		for spot in _spots(view):
			_click(spot)
			assert_almost_eq(
				view.modulate.a, CharacterScreen.PICKED_ALPHA, 0.01, "slot %d at %s" % [slot, spot]
			)
			_click(spot)


func test_the_hud_hotbar_is_clickable_only_while_the_character_page_is_open() -> void:
	var slot := _hotbar.slot_view(0)
	assert_true(slot.is_clickable)
	_screen.close()
	assert_false(slot.is_clickable)
	_screen.open_tab(CharacterScreen.Tab.SKILLS)
	assert_false(slot.is_clickable, "the skills page moves no items")


func test_the_hotbar_is_drawn_above_the_dimmed_backdrop_of_the_screen() -> void:
	assert_gt(_hotbar.layer, _screen.layer)


func test_an_item_goes_from_the_backpack_onto_the_hotbar_by_clicks() -> void:
	_player.inventory.slots[Inventory.HOTBAR_SIZE + 3] = {"item": ItemTypes.LOGS, "count": 4}
	_player.inventory.slots[2] = {}
	_player.inventory.changed.emit()
	_click_slot(Inventory.HOTBAR_SIZE + 3)
	_click_slot(2)
	assert_eq(_player.inventory.slots[2], {"item": ItemTypes.LOGS, "count": 4})


func test_putting_the_picked_item_on_another_one_swaps_and_picks_that_one_up() -> void:
	_player.inventory.slots[Inventory.HOTBAR_SIZE] = {"item": ItemTypes.LOGS, "count": 4}
	_player.inventory.slots[Inventory.HOTBAR_SIZE + 1] = {"item": ItemTypes.STONE, "count": 2}
	_player.inventory.slots[Inventory.HOTBAR_SIZE + 5] = {}
	_player.inventory.changed.emit()
	_click_slot(Inventory.HOTBAR_SIZE)
	_click_slot(Inventory.HOTBAR_SIZE + 1)
	assert_eq(_player.inventory.item_in(Inventory.HOTBAR_SIZE + 1), ItemTypes.LOGS)
	assert_eq(_player.inventory.item_in(Inventory.HOTBAR_SIZE), ItemTypes.STONE)
	assert_eq(_screen._picked_inventory_slot, Inventory.HOTBAR_SIZE, "the stone is in the hand")
	_click_slot(Inventory.HOTBAR_SIZE + 5)
	assert_eq(_player.inventory.item_in(Inventory.HOTBAR_SIZE + 5), ItemTypes.STONE)
	assert_true(_player.inventory.slots[Inventory.HOTBAR_SIZE].is_empty())
	assert_eq(_screen._picked_inventory_slot, -1, "nothing left in the hand")


func test_putting_the_picked_item_on_the_same_one_stacks_and_drops_the_pick() -> void:
	_player.inventory.slots[Inventory.HOTBAR_SIZE] = {"item": ItemTypes.LOGS, "count": 4}
	_player.inventory.slots[Inventory.HOTBAR_SIZE + 1] = {"item": ItemTypes.LOGS, "count": 2}
	_player.inventory.changed.emit()
	_click_slot(Inventory.HOTBAR_SIZE)
	_click_slot(Inventory.HOTBAR_SIZE + 1)
	assert_eq(_player.inventory.slots[Inventory.HOTBAR_SIZE + 1]["count"], 6)
	assert_eq(_screen._picked_inventory_slot, -1)


func test_shift_click_sends_a_stack_between_the_backpack_and_the_hotbar_and_drops_the_pick(
) -> void:
	var backpack_slot := Inventory.HOTBAR_SIZE + 2
	_player.inventory.slots[backpack_slot] = {"item": ItemTypes.LOGS, "count": 7}
	for slot in Inventory.HOTBAR_SIZE:
		_player.inventory.slots[slot] = {} if slot == 5 else {"item": ItemTypes.AXE, "count": 1}
	_player.inventory.changed.emit()
	_click_slot(0)
	_hold_shift()
	_click_slot(backpack_slot)
	assert_true(_player.inventory.slots[backpack_slot].is_empty())
	assert_eq(_player.inventory.slots[5], {"item": ItemTypes.LOGS, "count": 7})
	assert_eq(_screen._picked_inventory_slot, -1, "shift-click lets go of what was picked")
	_click_slot(5)
	assert_eq(_player.inventory.slots[Inventory.HOTBAR_SIZE], {"item": ItemTypes.LOGS, "count": 7})
	assert_true(_player.inventory.slots[5].is_empty())


func test_a_stack_let_go_outside_the_panel_is_dropped_on_the_ground() -> void:
	_player.inventory.slots[Inventory.HOTBAR_SIZE] = {"item": ItemTypes.LOGS, "count": 7}
	_player.inventory.changed.emit()
	watch_signals(_screen)
	_click_slot(Inventory.HOTBAR_SIZE)
	_click(Vector2(4, 4))
	assert_signal_emitted_with_parameters(_screen, "drop_requested", [Inventory.HOTBAR_SIZE])
	assert_eq(_screen._picked_inventory_slot, -1)


func test_a_click_on_the_panel_between_slots_or_between_hotbar_slots_only_lets_go() -> void:
	_player.inventory.slots[Inventory.HOTBAR_SIZE] = {"item": ItemTypes.LOGS, "count": 7}
	_player.inventory.changed.emit()
	watch_signals(_screen)
	_click_slot(Inventory.HOTBAR_SIZE)
	_click(_screen._panel.get_rect().position + Vector2(2, 2))
	assert_eq(_screen._picked_inventory_slot, -1)
	_click_slot(Inventory.HOTBAR_SIZE)
	var gap := _hotbar.slot_view(0).get_global_rect().end + Vector2(1, -5)
	assert_true(_hotbar.covers(gap))
	_click(gap)
	assert_eq(_screen._picked_inventory_slot, -1)
	assert_signal_not_emitted(_screen, "drop_requested")
