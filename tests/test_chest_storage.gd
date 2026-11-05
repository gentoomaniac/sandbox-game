extends GutTest
## Moving items between the inventory and a chest.

var _inventory: Inventory
var _chest: ItemSlots


func before_each() -> void:
	_inventory = Inventory.new()
	# Holding the last hotbar slot, so items are added from the first slot on.
	_inventory.select(9)
	_chest = WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO).storage


func test_a_chest_has_five_by_three_slots() -> void:
	assert_eq(_chest.slots.size(), 15)
	assert_true(_chest.is_empty())


func test_the_slots_of_a_chest_hold_stacks_up_to_the_item_limit() -> void:
	assert_eq(_chest.add(ItemTypes.LOGS, 120), 0)
	assert_eq(_chest.slots[0]["count"], 99)
	assert_eq(_chest.slots[1]["count"], 21)


func test_an_item_moves_from_the_inventory_to_a_free_chest_slot() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	_inventory.move_to(0, _chest, 4)
	assert_true(_inventory.slots[0].is_empty())
	assert_eq(_chest.slots[4], {"item": ItemTypes.LOGS, "count": 8})


func test_moving_onto_the_same_item_stacks_and_the_rest_stays() -> void:
	_inventory.add(ItemTypes.LOGS, 60)
	_chest.add(ItemTypes.LOGS, 70)
	_inventory.move_to(0, _chest, 0)
	assert_eq(_chest.slots[0]["count"], 99)
	assert_eq(_inventory.slots[0]["count"], 31)


func test_moving_onto_a_different_item_swaps_both_ways() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	_chest.add(ItemTypes.STONE, 3)
	_inventory.move_to(0, _chest, 0)
	assert_eq(_inventory.slots[0], {"item": ItemTypes.STONE, "count": 3})
	assert_eq(_chest.slots[0], {"item": ItemTypes.LOGS, "count": 8})
	_chest.move_to(0, _inventory, 0)
	assert_eq(_inventory.slots[0], {"item": ItemTypes.LOGS, "count": 8})
	assert_eq(_chest.slots[0], {"item": ItemTypes.STONE, "count": 3})


func test_a_move_tells_both_sides_that_they_changed() -> void:
	_inventory.add(ItemTypes.LOGS, 8)
	watch_signals(_inventory)
	watch_signals(_chest)
	_inventory.move_to(0, _chest, 0)
	assert_signal_emitted(_inventory, "changed")
	assert_signal_emitted(_chest, "changed")


func test_send_moves_a_whole_stack_onto_a_stack_and_into_a_free_slot() -> void:
	_chest.add(ItemTypes.LOGS, 90)
	_inventory.add(ItemTypes.LOGS, 20)
	assert_true(_inventory.send(0, _chest))
	assert_true(_inventory.slots[0].is_empty())
	assert_eq(_chest.slots[0]["count"], 99)
	assert_eq(_chest.slots[1]["count"], 11)


func test_send_to_a_full_chest_moves_what_fits_and_the_rest_stays() -> void:
	for slot in 14:
		_chest.slots[slot] = {"item": ItemTypes.HOE, "count": 1}
	_chest.slots[14] = {"item": ItemTypes.LOGS, "count": 95}
	_inventory.add(ItemTypes.LOGS, 10)
	assert_false(_inventory.send(0, _chest))
	assert_eq(_chest.slots[14]["count"], 99)
	assert_eq(_inventory.slots[0], {"item": ItemTypes.LOGS, "count": 6})


func test_send_to_a_chest_with_no_room_at_all_changes_nothing() -> void:
	for slot in 15:
		_chest.slots[slot] = {"item": ItemTypes.HOE, "count": 1}
	_inventory.add(ItemTypes.LOGS, 10)
	assert_false(_inventory.send(0, _chest))
	assert_eq(_inventory.slots[0], {"item": ItemTypes.LOGS, "count": 10})


func test_send_from_a_chest_to_a_full_inventory_changes_nothing() -> void:
	for slot in Inventory.SLOT_COUNT:
		_inventory.slots[slot] = {"item": ItemTypes.HOE, "count": 1}
	_chest.add(ItemTypes.LOGS, 4)
	assert_false(_chest.send(0, _inventory))
	assert_eq(_chest.slots[0], {"item": ItemTypes.LOGS, "count": 4})


func test_sending_an_empty_slot_does_nothing() -> void:
	assert_false(_inventory.send(0, _chest))
	assert_true(_chest.is_empty())


func test_the_totals_add_up_the_stacks_of_an_item() -> void:
	_chest.add(ItemTypes.LOGS, 120)
	_chest.add(ItemTypes.STONE, 3)
	assert_eq(_chest.totals(), {ItemTypes.LOGS: 120, ItemTypes.STONE: 3})
