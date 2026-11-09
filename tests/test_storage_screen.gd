extends GutTest
## The storage screen: the inventory and the slots of a chest, dragging that moves items,
## Shift+click.

var _inventory: Inventory
var _chest: ItemSlots
var _screen: StorageScreen


func before_each() -> void:
	_inventory = Inventory.new()
	# Holding the last hotbar slot, so items are added from the first slot on.
	_inventory.select(Inventory.HOTBAR_SIZE - 1)
	_chest = WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO).storage


## The storage screen open on a chest with `_chest`'s slots, for `_inventory`'s player. Returns
## the views the player sees: the backpack's, the hotbar's (the HUD's), then the chest's.
func _open_screen() -> Array[SlotView]:
	var player := PlayerState.new()
	player.inventory = _inventory
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO)
	chest.storage = _chest
	var hotbar: HotbarHud = autofree(HotbarCase.new_hotbar())
	hotbar.show_inventory(_inventory)
	_screen = StorageScreen.new(hotbar)
	add_child_autofree(_screen)
	_screen.open_chest(chest, player)
	var in_screen: Array[SlotView] = []
	in_screen.assign(_screen.find_children("*", "SlotView", true, false))
	in_screen.erase(_screen._trash_can._slot)
	var views: Array[SlotView] = in_screen.slice(0, Inventory.BACKPACK_SIZE)
	for slot in Inventory.HOTBAR_SIZE:
		views.append(hotbar._slot_views[slot])
	views.append_array(in_screen.slice(Inventory.BACKPACK_SIZE))
	return views


## The view of an inventory slot: the screen has the backpack's views, then the hotbar's.
func _inventory_view(views: Array[SlotView], slot: int) -> SlotView:
	return views[
		slot - Inventory.HOTBAR_SIZE
		if slot >= Inventory.HOTBAR_SIZE
		else slot + Inventory.BACKPACK_SIZE
	]


func _chest_view(views: Array[SlotView], slot: int) -> SlotView:
	return views[Inventory.SLOT_COUNT + slot]


## Drags the stack of `from` onto `to` and lets go, as the mouse does (see test_inventory_drag.gd
## for real mouse events).
func _drag(from: SlotView, to: SlotView) -> void:
	var data := {"from": from}
	if to._can_drop_data(Vector2.ZERO, data):
		to._drop_data(Vector2.ZERO, data)


func test_the_screen_has_the_backpack_slots_the_hotbars_and_then_the_five_by_three_of_the_chest(
) -> void:
	var views := _open_screen()
	assert_eq(views.size(), Inventory.SLOT_COUNT + 15)


func test_dragging_an_item_onto_a_chest_slot_moves_it() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	var views := _open_screen()
	_drag(_inventory_view(views, 0), _chest_view(views, 2))
	assert_true(_inventory.slots[0].is_empty())
	assert_eq(_chest.slots[2], {"item": ItemTypes.LOGS, "count": 8})


func test_dragging_a_chest_item_onto_an_inventory_slot_moves_it_back() -> void:
	_chest.add(ItemTypes.STONE, 3)
	var views := _open_screen()
	_drag(_chest_view(views, 0), _inventory_view(views, 5))
	assert_true(_chest.slots[0].is_empty())
	assert_eq(_inventory.slots[5], {"item": ItemTypes.STONE, "count": 3})


func test_dragging_a_stack_onto_its_own_slot_changes_nothing() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	var views := _open_screen()
	_drag(_inventory_view(views, 0), _inventory_view(views, 0))
	assert_eq(_inventory.slots[0], {"item": ItemTypes.LOGS, "count": 8})


func test_shift_click_sends_the_whole_stack_to_the_other_side() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	_chest.add(ItemTypes.STONE, 3)
	var views := _open_screen()
	_inventory_view(views, 0).quick_move_requested.emit()
	assert_true(_inventory.slots[0].is_empty())
	assert_eq(_chest.count_of(ItemTypes.LOGS), 8)
	_chest_view(views, 0).quick_move_requested.emit()
	assert_eq(_inventory.count_of(ItemTypes.STONE), 3, "and back again")
	assert_eq(_chest.count_of(ItemTypes.STONE), 0)


func test_shift_click_from_the_chest_fills_the_backpack_before_the_hotbar() -> void:
	_chest.add(ItemTypes.STONE, 3)
	var views := _open_screen()
	_chest_view(views, 0).quick_move_requested.emit()
	assert_eq(_inventory.slots[Inventory.HOTBAR_SIZE], {"item": ItemTypes.STONE, "count": 3})
	assert_true(_inventory.slots[0].is_empty())


func test_items_move_between_the_hotbar_and_the_backpack() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	var views := _open_screen()
	_drag(_inventory_view(views, 0), _inventory_view(views, 12))
	assert_true(_inventory.slots[0].is_empty())
	assert_eq(_inventory.slots[12], {"item": ItemTypes.LOGS, "count": 8})


func test_shift_click_into_a_full_chest_leaves_the_rest() -> void:
	for slot in 15:
		_chest.slots[slot] = {"item": ItemTypes.HOE, "count": 1}
	_inventory.add(ItemTypes.LOGS, 8)
	var views := _open_screen()
	_inventory_view(views, 0).quick_move_requested.emit()
	assert_eq(_inventory.slots[0], {"item": ItemTypes.LOGS, "count": 8})
	assert_eq(_chest.count_of(ItemTypes.LOGS), 0)


func test_closing_the_screen_stops_it_following_the_slots() -> void:
	_open_screen()
	assert_true(_inventory.changed.is_connected(_screen._refresh))
	_screen.close()
	assert_false(_screen.is_open())
	assert_false(_inventory.changed.is_connected(_screen._refresh))
	assert_false(_chest.changed.has_connections())


func test_dragging_an_item_onto_another_across_the_sides_swaps_them() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	_chest.add(ItemTypes.STONE, 3)
	var views := _open_screen()
	_drag(_inventory_view(views, 0), _chest_view(views, 0))
	assert_eq(_chest.slots[0], {"item": ItemTypes.LOGS, "count": 8})
	assert_eq(_inventory.slots[0], {"item": ItemTypes.STONE, "count": 3})


func test_a_chest_of_many_slots_scrolls_inside_a_small_window() -> void:
	_chest = ItemSlots.new(50)
	var window := SubViewport.new()
	window.size = Vector2i(320, 180)
	add_child_autofree(window)
	var player := PlayerState.new()
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO)
	chest.storage = _chest
	_screen = StorageScreen.new(autofree(HotbarCase.new_hotbar()))
	window.add_child(_screen)
	_screen.open_chest(chest, player)
	await wait_process_frames(2)
	var list: ScrollingList = _screen.find_children("*", "ScrollingList", true, false)[0]
	assert_true(list.get_v_scroll_bar().visible, "the window is too small for the slots")
	var panel: Control = _screen.find_children("*", "PanelContainer", true, false)[0]
	assert_lte(panel.size.y, float(window.size.y - 2 * ScrollingList.MARGIN))


func test_opening_the_chest_closes_the_window_that_was_open() -> void:
	var crafting := CraftingScreen.new()
	add_child_autofree(crafting)
	crafting.show_crafting(Crafting.new(GameState.new_game(7)), _inventory)
	crafting.open()
	_open_screen()
	assert_false(crafting.is_open())
	assert_true(_screen.is_open())


func test_e_closes_the_screen() -> void:
	_open_screen()
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	_screen._unhandled_input(event)
	assert_false(_screen.is_open())
