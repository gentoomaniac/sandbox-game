extends GutTest
## Where new items go relative to the selected (held) hotbar slot.


func test_an_empty_hand_stays_empty_after_adding() -> void:
	var inventory := Inventory.with_starting_items()
	inventory.slots[Inventory.HOTBAR_SIZE - 1] = {}
	inventory.select(Inventory.HOTBAR_SIZE - 1)
	inventory.add(ItemTypes.BERRIES, 3)
	assert_eq(inventory.held_item(), ItemTypes.NONE)
	assert_eq(inventory.item_in(Inventory.HOTBAR_SIZE + 4), ItemTypes.BERRIES)


func test_the_selected_slot_is_used_when_nothing_else_is_free() -> void:
	var inventory := Inventory.new()
	for slot in Inventory.SLOT_COUNT:
		if slot != 3:
			inventory.slots[slot] = {"item": ItemTypes.STONE, "count": 99}
	inventory.select(3)
	assert_eq(inventory.add(ItemTypes.BERRIES, 2), 0)
	assert_eq(inventory.held_item(), ItemTypes.BERRIES)


func test_a_held_stack_of_the_same_item_fills_first() -> void:
	var inventory := Inventory.new()
	inventory.slots[0] = {"item": ItemTypes.BERRIES, "count": 1}
	inventory.select(0)
	inventory.add(ItemTypes.BERRIES, 2)
	assert_eq(inventory.slots[0]["count"], 3)
	assert_true(inventory.slots[1].is_empty())


func test_the_wheel_steps_through_the_hotbar_and_round() -> void:
	var inventory := Inventory.new()
	inventory.select(Inventory.HOTBAR_SIZE - 1)
	inventory.select_next(1)
	assert_eq(inventory.selected_slot, 0, "from the last slot round to the first")
	inventory.select_next(-1)
	assert_eq(inventory.selected_slot, Inventory.HOTBAR_SIZE - 1, "and back")
	inventory.select_next(-2)
	assert_eq(inventory.selected_slot, Inventory.HOTBAR_SIZE - 3)
