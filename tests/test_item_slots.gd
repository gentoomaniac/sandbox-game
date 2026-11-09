extends GutTest
## What every row of item slots (the inventory, a chest) does besides stacking and moving.


func test_destroying_a_stack_empties_its_slot_and_leaves_the_rest() -> void:
	var slots := ItemSlots.new(10)
	slots.slots[0] = {"item": ItemTypes.LOGS, "count": 12}
	slots.slots[1] = {"item": ItemTypes.LOGS, "count": 3}
	slots.slots[9] = {"item": ItemTypes.STONE, "count": 5}
	watch_signals(slots)
	slots.destroy(0)
	assert_true(slots.slots[0].is_empty())
	assert_eq(slots.slots[1], {"item": ItemTypes.LOGS, "count": 3})
	assert_eq(slots.slots[9], {"item": ItemTypes.STONE, "count": 5})
	assert_signal_emitted(slots, "changed")
