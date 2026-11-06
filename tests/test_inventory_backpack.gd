extends GutTest
## The inventory's layout: a hotbar of eight and a backpack of twenty slots, the hotbar extra room.

var _inventory: Inventory


func before_each() -> void:
	_inventory = Inventory.new()
	# Holding the last hotbar slot, so `add` fills slots from the first (see
	# test_inventory_held_slot.gd).
	_inventory.select(Inventory.HOTBAR_SIZE - 1)


func test_the_slots_are_the_hotbar_and_then_the_backpack() -> void:
	assert_eq(Inventory.HOTBAR_SIZE, 8)
	assert_eq(Inventory.BACKPACK_SIZE, 20)
	assert_eq(Inventory.SLOT_COUNT, 28)
	assert_eq(_inventory.slots.size(), 28)


func test_adding_goes_on_into_the_backpack_when_the_hotbar_is_full() -> void:
	for slot in Inventory.HOTBAR_SIZE - 1:
		_inventory.slots[slot] = {"item": ItemTypes.HOE, "count": 1}
	_inventory.add(ItemTypes.AXE, 1)
	assert_eq(_inventory.item_in(Inventory.HOTBAR_SIZE), ItemTypes.AXE)


func test_hotbar_and_backpack_together_hold_twenty_eight_stacks() -> void:
	for slot in Inventory.SLOT_COUNT:
		assert_eq(_inventory.add(ItemTypes.AXE, 1), 0)
	assert_eq(_inventory.add(ItemTypes.AXE, 1), 1)


func test_a_matching_stack_in_the_backpack_is_joined_before_a_free_hotbar_slot() -> void:
	_inventory.slots[15] = {"item": ItemTypes.TURNIP, "count": 5}
	_inventory.add(ItemTypes.TURNIP, 3)
	assert_eq(_inventory.slots[15]["count"], 8)
	assert_true(_inventory.slots[0].is_empty())


func test_backpack_first_order_puts_the_backpack_before_the_hotbar_and_the_held_slot_last() -> void:
	var order := _inventory.backpack_first_order()
	assert_eq(order.size(), Inventory.SLOT_COUNT)
	assert_eq(order[0], Inventory.HOTBAR_SIZE)
	assert_eq(order[Inventory.BACKPACK_SIZE], 0)
	assert_eq(order[-1], Inventory.HOTBAR_SIZE - 1)


func test_a_duplicate_has_the_same_content_and_changes_alone() -> void:
	_inventory.add(ItemTypes.TURNIP, 5)
	_inventory.select(1)
	var copy := _inventory.duplicate()
	assert_eq(copy.slots, _inventory.slots)
	assert_eq(copy.selected_slot, 1)
	copy.remove(ItemTypes.TURNIP, 5)
	assert_eq(_inventory.count_of(ItemTypes.TURNIP), 5)


func test_tools_add_no_weight() -> void:
	var tools := 0
	for item: StringName in ItemTypes.TYPES:
		if ItemTypes.TYPES[item].has("tool"):
			_inventory.add(item, 1)
			tools += 1
	assert_gt(tools, 0)
	assert_eq(_inventory.total_weight(), 0.0)
