extends GutTest
## The inventory: stacking, a full inventory, moving and swapping, weight, the selected slot.

var _inventory: Inventory


func before_each() -> void:
	_inventory = Inventory.new()
	# Holding the last hotbar slot, so `add` fills slots from the first in these layout tests
	# (it keeps the held slot for last, see test_inventory_held_slot.gd).
	_inventory.select(Inventory.HOTBAR_SIZE - 1)


func _fill_with_tools() -> void:
	for slot in Inventory.SLOT_COUNT:
		_inventory.add(ItemTypes.HOE, 1)


func test_a_new_inventory_has_twenty_eight_empty_slots() -> void:
	assert_eq(_inventory.slots.size(), 28)
	assert_true(_inventory.slots.all(func(stack: Dictionary) -> bool: return stack.is_empty()))
	assert_eq(_inventory.held_item(), ItemTypes.NONE)


func test_empty_slots_are_not_the_same_dictionary() -> void:
	_inventory.add(ItemTypes.TURNIP, 1)
	assert_true(_inventory.slots[1].is_empty())


func test_the_starting_items_fill_the_first_slots() -> void:
	var start := Inventory.with_starting_items()
	assert_eq(start.item_in(0), ItemTypes.HOE)
	assert_eq(start.item_in(1), ItemTypes.AXE)
	assert_eq(start.item_in(2), ItemTypes.PICKAXE)
	assert_eq(start.item_in(3), ItemTypes.WATERING_CAN)
	assert_eq(start.item_in(4), ItemTypes.TURNIP_SEEDS)
	assert_eq(start.count_of(ItemTypes.TURNIP_SEEDS), 15)
	assert_eq(start.held_item(), ItemTypes.HOE)


func test_adding_fills_an_existing_stack_first() -> void:
	_inventory.add(ItemTypes.TURNIP, 5)
	_inventory.add(ItemTypes.AXE, 1)
	assert_eq(_inventory.add(ItemTypes.TURNIP, 3), 0)
	assert_eq(_inventory.slots[0], {"item": ItemTypes.TURNIP, "count": 8})
	assert_eq(_inventory.item_in(1), ItemTypes.AXE)


func test_what_exceeds_the_stack_limit_goes_to_the_next_free_slot() -> void:
	_inventory.add(ItemTypes.TURNIP, 90)
	assert_eq(_inventory.add(ItemTypes.TURNIP, 20), 0)
	assert_eq(_inventory.slots[0]["count"], 99)
	assert_eq(_inventory.slots[1]["count"], 11)


func test_tools_do_not_stack() -> void:
	_inventory.add(ItemTypes.HOE, 1)
	_inventory.add(ItemTypes.HOE, 1)
	assert_eq(_inventory.slots[0]["count"], 1)
	assert_eq(_inventory.item_in(1), ItemTypes.HOE)


func test_adding_to_a_full_inventory_reports_what_did_not_fit() -> void:
	_fill_with_tools()
	assert_eq(_inventory.add(ItemTypes.AXE, 2), 2)
	assert_eq(_inventory.count_of(ItemTypes.AXE), 0)


func test_a_full_inventory_still_stacks_onto_existing_stacks() -> void:
	_fill_with_tools()
	_inventory.remove(ItemTypes.HOE, 1)
	_inventory.add(ItemTypes.TURNIP, 99)
	assert_eq(_inventory.add(ItemTypes.TURNIP, 1), 1)
	_inventory.remove(ItemTypes.TURNIP, 50)
	assert_eq(_inventory.add(ItemTypes.TURNIP, 60), 10)


func test_can_add_checks_all_items_together_without_adding() -> void:
	_fill_with_tools()
	_inventory.remove(ItemTypes.HOE, 1)
	assert_true(_inventory.can_add({ItemTypes.TURNIP: 1}))
	assert_false(_inventory.can_add({ItemTypes.TURNIP: 1, ItemTypes.TURNIP_SEEDS: 1}))
	assert_eq(_inventory.count_of(ItemTypes.TURNIP), 0)


func test_remove_takes_from_stacks_and_empties_slots() -> void:
	_inventory.add(ItemTypes.TURNIP, 99)
	_inventory.add(ItemTypes.TURNIP, 1)
	assert_eq(_inventory.remove(ItemTypes.TURNIP, 3), 3)
	assert_eq(_inventory.count_of(ItemTypes.TURNIP), 97)
	assert_eq(_inventory.remove(ItemTypes.TURNIP, 100), 97)
	assert_true(_inventory.slots[0].is_empty())
	assert_true(_inventory.slots[1].is_empty())


func test_moving_to_an_empty_slot() -> void:
	_inventory.add(ItemTypes.TURNIP, 4)
	assert_false(_inventory.move_to(0, _inventory, 15), "no swap")
	assert_true(_inventory.slots[0].is_empty())
	assert_eq(_inventory.slots[15], {"item": ItemTypes.TURNIP, "count": 4})


func test_moving_onto_a_different_item_swaps() -> void:
	_inventory.add(ItemTypes.TURNIP, 4)
	_inventory.add(ItemTypes.AXE, 1)
	assert_true(_inventory.move_to(0, _inventory, 1), "says it swapped")
	assert_eq(_inventory.item_in(0), ItemTypes.AXE)
	assert_eq(_inventory.slots[1], {"item": ItemTypes.TURNIP, "count": 4})


func test_moving_onto_the_same_item_merges_up_to_the_limit() -> void:
	_inventory.add(ItemTypes.TURNIP, 99)
	_inventory.add(ItemTypes.TURNIP, 10)
	assert_false(_inventory.move_to(1, _inventory, 0), "no swap")
	assert_eq(_inventory.slots[0]["count"], 99)
	assert_eq(_inventory.slots[1]["count"], 10)


func test_merging_everything_empties_the_source_slot() -> void:
	_inventory.slots[0] = {"item": ItemTypes.TURNIP, "count": 40}
	_inventory.slots[7] = {"item": ItemTypes.TURNIP, "count": 30}
	_inventory.move_to(7, _inventory, 0)
	assert_eq(_inventory.slots[0]["count"], 70)
	assert_true(_inventory.slots[7].is_empty())


func test_moving_an_empty_slot_or_onto_itself_changes_nothing() -> void:
	_inventory.add(ItemTypes.TURNIP, 4)
	_inventory.move_to(5, _inventory, 0)
	_inventory.move_to(0, _inventory, 0)
	assert_eq(_inventory.slots[0], {"item": ItemTypes.TURNIP, "count": 4})
	assert_true(_inventory.slots[5].is_empty())


func test_total_weight_adds_every_stack() -> void:
	assert_eq(_inventory.total_weight(), 0.0)
	_inventory.add(ItemTypes.HOE, 1)
	_inventory.add(ItemTypes.TURNIP, 10)
	var expected: float = (
		ItemTypes.TYPES[ItemTypes.HOE]["weight"] + 10 * ItemTypes.TYPES[ItemTypes.TURNIP]["weight"]
	)
	assert_almost_eq(_inventory.total_weight(), expected, 0.0001)


func test_selecting_a_slot_holds_its_item() -> void:
	_inventory.add(ItemTypes.HOE, 1)
	_inventory.add(ItemTypes.AXE, 1)
	_inventory.select(1)
	assert_eq(_inventory.held_item(), ItemTypes.AXE)
	_inventory.select(Inventory.HOTBAR_SIZE - 1)
	assert_eq(_inventory.held_item(), ItemTypes.NONE)


func test_changes_are_announced() -> void:
	watch_signals(_inventory)
	_inventory.add(ItemTypes.HOE, 1)
	_inventory.select(2)
	assert_signal_emit_count(_inventory, "changed", 2)


func test_round_trip_through_json() -> void:
	_inventory.add(ItemTypes.TURNIP, 120)
	_inventory.add(ItemTypes.AXE, 1)
	_inventory.select(1)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_inventory.to_dict()))
	var restored := Inventory.from_dict(data)
	assert_eq(restored.slots, _inventory.slots)
	assert_eq(restored.selected_slot, 1)
