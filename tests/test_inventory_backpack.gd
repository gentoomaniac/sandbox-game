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
		_inventory.slots[slot] = {"item": ItemTypes.RUSTY_IRON_HOE, "count": 1}
	_inventory.add(ItemTypes.RUSTY_IRON_AXE, 1)
	assert_eq(_inventory.item_in(Inventory.HOTBAR_SIZE), ItemTypes.RUSTY_IRON_AXE)


func test_hotbar_and_backpack_together_hold_twenty_eight_stacks() -> void:
	for slot in Inventory.SLOT_COUNT:
		assert_eq(_inventory.add(ItemTypes.RUSTY_IRON_AXE, 1), 0)
	assert_eq(_inventory.add(ItemTypes.RUSTY_IRON_AXE, 1), 1)


func test_a_free_hotbar_slot_is_used_before_a_matching_stack_in_the_backpack() -> void:
	_inventory.slots[15] = {"item": ItemTypes.TURNIP, "count": 5}
	_inventory.add(ItemTypes.TURNIP, 3)
	assert_eq(_inventory.slots[15]["count"], 5)
	assert_eq(_inventory.slots[0], {"item": ItemTypes.TURNIP, "count": 3})


func test_gained_items_fill_hotbar_stacks_hotbar_free_backpack_stacks_backpack_free() -> void:
	var hotbar_slots := Inventory.HOTBAR_SIZE
	_inventory.select(hotbar_slots - 1)
	_inventory.slots[2] = {"item": ItemTypes.TURNIP, "count": 98}
	_inventory.slots[hotbar_slots + 3] = {"item": ItemTypes.TURNIP, "count": 98}
	for slot in hotbar_slots - 1:
		if slot != 2:
			_inventory.slots[slot] = {"item": ItemTypes.STONE, "count": 1}
	# One tops up the hotbar stack, one the backpack stack, 99 go into the first free backpack slot.
	_inventory.add(ItemTypes.TURNIP, 1 + 1 + 99)
	assert_eq(_inventory.slots[2]["count"], 99)
	assert_eq(_inventory.slots[hotbar_slots + 3]["count"], 99)
	assert_eq(_inventory.slots[hotbar_slots]["count"], 99)
	assert_true(_inventory.slots[hotbar_slots - 1].is_empty(), "the empty held slot stays last")


func test_crafted_items_take_the_same_order() -> void:
	_inventory.slots[15] = {"item": ItemTypes.TURNIP, "count": 5}
	assert_true(_inventory.exchange({}, {ItemTypes.TURNIP: 2}))
	assert_eq(_inventory.slots[0], {"item": ItemTypes.TURNIP, "count": 2})
	assert_eq(_inventory.slots[15]["count"], 5)


func test_exchange_never_loses_an_item_when_the_slots_are_nearly_full() -> void:
	for slot in Inventory.SLOT_COUNT:
		_inventory.slots[slot] = {"item": ItemTypes.STONE, "count": 99}
	_inventory.slots[3] = {}
	var received := {ItemTypes.TURNIP: 1, ItemTypes.BERRIES: 1}
	assert_false(_inventory.exchange({}, received))
	assert_eq(_inventory.count_of(ItemTypes.TURNIP), 0)


func test_a_hotbar_stack_is_topped_up_and_the_rest_goes_to_the_next_free_slot() -> void:
	_inventory.slots[0] = {"item": ItemTypes.TURNIP, "count": 97}
	_inventory.slots[1] = {"item": ItemTypes.STONE, "count": 1}
	_inventory.add(ItemTypes.TURNIP, 5)
	assert_eq(_inventory.slots[0]["count"], 99)
	assert_eq(_inventory.slots[2], {"item": ItemTypes.TURNIP, "count": 3})


func test_the_empty_selected_slot_is_used_last_when_everything_else_is_full() -> void:
	for slot in Inventory.SLOT_COUNT:
		_inventory.slots[slot] = {"item": ItemTypes.STONE, "count": 99}
	_inventory.slots[Inventory.HOTBAR_SIZE - 1] = {}
	assert_eq(_inventory.add(ItemTypes.TURNIP, 1), 0)
	assert_eq(_inventory.held_item(), ItemTypes.TURNIP)


func test_backpack_first_order_puts_the_backpack_before_the_hotbar_and_the_held_slot_last() -> void:
	var order := _inventory.backpack_first_order()
	assert_eq(order.size(), Inventory.SLOT_COUNT)
	assert_eq(order[0], Inventory.HOTBAR_SIZE)
	assert_eq(order[Inventory.BACKPACK_SIZE], 0)
	assert_eq(order[-1], Inventory.HOTBAR_SIZE - 1)


func test_tools_add_no_weight() -> void:
	var tools := 0
	for item: StringName in ItemTypes.TYPES:
		if ItemTypes.TYPES[item].has("tool"):
			_inventory.add(item, 1)
			tools += 1
	assert_gt(tools, 0)
	assert_eq(_inventory.total_weight(), 0.0)


func test_shift_click_moves_a_stack_from_the_backpack_to_the_first_free_hotbar_slot() -> void:
	_inventory.slots[0] = {"item": ItemTypes.RUSTY_IRON_HOE, "count": 1}
	_inventory.slots[Inventory.HOTBAR_SIZE + 4] = {"item": ItemTypes.LOGS, "count": 7}
	assert_true(_inventory.move_to_other_part(Inventory.HOTBAR_SIZE + 4))
	assert_true(_inventory.slots[Inventory.HOTBAR_SIZE + 4].is_empty())
	assert_eq(_inventory.slots[1], {"item": ItemTypes.LOGS, "count": 7})


func test_shift_click_moves_a_hotbar_stack_to_the_first_free_backpack_slot() -> void:
	_inventory.slots[2] = {"item": ItemTypes.LOGS, "count": 7}
	assert_true(_inventory.move_to_other_part(2))
	assert_true(_inventory.slots[2].is_empty())
	assert_eq(_inventory.slots[Inventory.HOTBAR_SIZE], {"item": ItemTypes.LOGS, "count": 7})


func test_shift_click_fills_a_stack_of_the_same_item_before_a_free_slot() -> void:
	var limit: int = ItemTypes.TYPES[ItemTypes.LOGS]["stack_limit"]
	_inventory.slots[0] = {"item": ItemTypes.LOGS, "count": 10}
	_inventory.slots[Inventory.HOTBAR_SIZE + 2] = {"item": ItemTypes.LOGS, "count": limit - 4}
	assert_true(_inventory.move_to_other_part(0))
	assert_eq(_inventory.slots[Inventory.HOTBAR_SIZE + 2]["count"], limit)
	assert_eq(_inventory.slots[Inventory.HOTBAR_SIZE], {"item": ItemTypes.LOGS, "count": 6})
	assert_true(_inventory.slots[0].is_empty())


func test_shift_click_with_room_for_only_a_part_leaves_the_rest_where_it_was() -> void:
	var limit: int = ItemTypes.TYPES[ItemTypes.LOGS]["stack_limit"]
	for slot in range(Inventory.HOTBAR_SIZE, Inventory.SLOT_COUNT):
		_inventory.slots[slot] = {"item": ItemTypes.RUSTY_IRON_AXE, "count": 1}
	_inventory.slots[Inventory.HOTBAR_SIZE] = {"item": ItemTypes.LOGS, "count": limit - 2}
	_inventory.slots[0] = {"item": ItemTypes.LOGS, "count": 10}
	assert_false(_inventory.move_to_other_part(0))
	assert_eq(_inventory.slots[Inventory.HOTBAR_SIZE]["count"], limit)
	assert_eq(_inventory.slots[0], {"item": ItemTypes.LOGS, "count": 8})


func test_shift_click_with_no_room_on_the_other_side_changes_nothing() -> void:
	for slot in range(Inventory.HOTBAR_SIZE, Inventory.SLOT_COUNT):
		_inventory.slots[slot] = {"item": ItemTypes.RUSTY_IRON_AXE, "count": 1}
	_inventory.slots[0] = {"item": ItemTypes.LOGS, "count": 7}
	assert_false(_inventory.move_to_other_part(0))
	assert_eq(_inventory.slots[0], {"item": ItemTypes.LOGS, "count": 7})


func test_shift_click_on_an_empty_slot_does_nothing() -> void:
	assert_false(_inventory.move_to_other_part(3))
