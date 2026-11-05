extends GutTest
## The storage screen: the inventory and the slots of a chest, clicks that move items, Shift+click.

var _inventory: Inventory
var _chest: ItemSlots
var _screen: StorageScreen


func before_each() -> void:
	_inventory = Inventory.new()
	# Holding the last hotbar slot, so items are added from the first slot on.
	_inventory.select(9)
	_chest = WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO).storage


func after_each() -> void:
	_hold_shift(false)


func _hold_shift(is_held := true) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = is_held
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## The storage screen open on a chest with `_chest`'s slots, for `_inventory`'s player.
func _open_screen() -> Array[SlotView]:
	var player := PlayerState.new()
	player.inventory = _inventory
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO)
	chest.storage = _chest
	_screen = StorageScreen.new()
	add_child_autofree(_screen)
	_screen.open(chest, player)
	var views: Array[SlotView] = []
	views.assign(_screen.find_children("*", "SlotView", true, false))
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


func test_the_screen_has_the_backpack_and_hotbar_slots_and_then_the_five_by_three_of_the_chest(
) -> void:
	var views := _open_screen()
	assert_eq(views.size(), Inventory.SLOT_COUNT + 15)


func test_clicking_an_item_and_then_a_chest_slot_moves_it() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	var views := _open_screen()
	_inventory_view(views, 0).pressed.emit()
	_chest_view(views, 2).pressed.emit()
	assert_true(_inventory.slots[0].is_empty())
	assert_eq(_chest.slots[2], {"item": ItemTypes.LOGS, "count": 8})


func test_clicking_a_chest_item_and_then_an_inventory_slot_moves_it_back() -> void:
	_chest.add(ItemTypes.STONE, 3)
	var views := _open_screen()
	_chest_view(views, 0).pressed.emit()
	_inventory_view(views, 5).pressed.emit()
	assert_true(_chest.slots[0].is_empty())
	assert_eq(_inventory.slots[5], {"item": ItemTypes.STONE, "count": 3})


func test_clicking_the_picked_slot_again_puts_it_back_where_it_was() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	var views := _open_screen()
	_inventory_view(views, 0).pressed.emit()
	_inventory_view(views, 0).pressed.emit()
	_inventory_view(views, 1).pressed.emit()
	assert_eq(_inventory.slots[0], {"item": ItemTypes.LOGS, "count": 8}, "nothing was picked")
	assert_true(_inventory.slots[1].is_empty())


func test_shift_click_sends_the_whole_stack_to_the_other_side() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	_chest.add(ItemTypes.STONE, 3)
	var views := _open_screen()
	_hold_shift()
	_inventory_view(views, 0).pressed.emit()
	assert_true(_inventory.slots[0].is_empty())
	assert_eq(_chest.count_of(ItemTypes.LOGS), 8)
	_chest_view(views, 0).pressed.emit()
	assert_eq(_inventory.count_of(ItemTypes.STONE), 3, "and back again")
	assert_eq(_chest.count_of(ItemTypes.STONE), 0)


func test_shift_click_from_the_chest_fills_the_backpack_before_the_hotbar() -> void:
	_chest.add(ItemTypes.STONE, 3)
	var views := _open_screen()
	_hold_shift()
	_chest_view(views, 0).pressed.emit()
	assert_eq(_inventory.slots[Inventory.HOTBAR_SIZE], {"item": ItemTypes.STONE, "count": 3})
	assert_true(_inventory.slots[0].is_empty())


func test_items_move_between_the_hotbar_and_the_backpack() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	var views := _open_screen()
	_inventory_view(views, 0).pressed.emit()
	_inventory_view(views, 12).pressed.emit()
	assert_true(_inventory.slots[0].is_empty())
	assert_eq(_inventory.slots[12], {"item": ItemTypes.LOGS, "count": 8})


func test_shift_click_into_a_full_chest_leaves_the_rest() -> void:
	for slot in 15:
		_chest.slots[slot] = {"item": ItemTypes.HOE, "count": 1}
	_inventory.add(ItemTypes.LOGS, 8)
	var views := _open_screen()
	_hold_shift()
	_inventory_view(views, 0).pressed.emit()
	assert_eq(_inventory.slots[0], {"item": ItemTypes.LOGS, "count": 8})
	assert_eq(_chest.count_of(ItemTypes.LOGS), 0)


func test_closing_the_screen_stops_it_following_the_slots() -> void:
	_open_screen()
	assert_true(_inventory.changed.has_connections())
	_screen.close()
	assert_false(_screen.is_open())
	assert_false(_inventory.changed.has_connections())
	assert_false(_chest.changed.has_connections())
