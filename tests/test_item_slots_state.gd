extends GutTest
## A stack with a state is a lone, special item (a candle that has burnt): it stacks with nothing
## and keeps its state wherever it goes.


func test_an_item_with_a_state_stacks_with_nothing_and_nothing_stacks_with_it() -> void:
	var slots := ItemSlots.new(4)
	slots.slots[0] = {"item": ItemTypes.LOGS, "count": 2}
	slots.slots[1] = {"item": ItemTypes.LOGS, "count": 1, "state": {"mark": 1}}

	assert_eq(slots.add(ItemTypes.LOGS, 3), 0)
	assert_eq(slots.slots[0]["count"], 5, "the plain stack takes them")
	assert_eq(slots.slots[1], {"item": ItemTypes.LOGS, "count": 1, "state": {"mark": 1}})
	slots.slots[0] = {}

	assert_eq(slots.add(ItemTypes.LOGS, 2), 0)
	assert_eq(slots.slots[0], {"item": ItemTypes.LOGS, "count": 2}, "not onto the stateful one")


func test_moving_a_stateful_item_swaps_it_and_never_merges_and_keeps_its_state() -> void:
	var slots := ItemSlots.new(3)
	var chest := ItemSlots.new(3)
	slots.slots[0] = {"item": ItemTypes.LOGS, "count": 1, "state": {"mark": 1}}
	chest.slots[0] = {"item": ItemTypes.LOGS, "count": 4}

	assert_true(slots.move_to(0, chest, 0), "a swap")
	assert_eq(chest.slots[0], {"item": ItemTypes.LOGS, "count": 1, "state": {"mark": 1}})
	assert_eq(slots.slots[0], {"item": ItemTypes.LOGS, "count": 4})
	assert_true(chest.send(0, slots), "sent to a free slot")
	assert_eq(slots.slots[1], {"item": ItemTypes.LOGS, "count": 1, "state": {"mark": 1}})
	assert_true(slots.move_into(1, [2]))
	assert_eq(slots.slots[2], {"item": ItemTypes.LOGS, "count": 1, "state": {"mark": 1}})


func test_setting_and_clearing_a_state_tells_the_change() -> void:
	var slots := ItemSlots.new(2)
	slots.slots[0] = {"item": ItemTypes.LOGS, "count": 1}
	watch_signals(slots)

	slots.set_state(0, {"mark": 2})
	assert_eq(slots.slots[0]["state"], {"mark": 2})
	slots.set_state(0, {})
	assert_false(slots.slots[0].has("state"))
	slots.set_state(1, {"mark": 2})
	assert_true(slots.slots[1].is_empty(), "an empty slot gets none")

	assert_signal_emit_count(slots, "changed", 2)


func test_a_state_is_saved_and_loaded_as_a_copy() -> void:
	var slots := ItemSlots.new(2)
	slots.slots[1] = {"item": ItemTypes.LOGS, "count": 1, "state": {"mark": 3}}

	var data := slots.slots_to_data()
	var restored := ItemSlots.new(2)
	restored.load_slots(data)

	assert_eq(data[1], {"item": "logs", "count": 1, "state": {"mark": 3}})
	assert_eq(restored.slots[1], {"item": &"logs", "count": 1, "state": {"mark": 3}})
	restored.slots[1]["state"]["mark"] = 9
	assert_eq(slots.slots[1]["state"]["mark"], 3)


func test_removing_takes_the_plain_stacks_before_those_with_a_state() -> void:
	var slots := ItemSlots.new(4)
	slots.slots[0] = {"item": ItemTypes.LOGS, "count": 3}
	slots.slots[1] = {"item": ItemTypes.LOGS, "count": 1, "state": {"mark": 1}}
	slots.slots[2] = {"item": ItemTypes.LOGS, "count": 2}

	assert_eq(slots.remove(ItemTypes.LOGS, 5), 5)
	assert_eq(slots.slots[1], {"item": ItemTypes.LOGS, "count": 1, "state": {"mark": 1}})
	assert_eq(slots.remove(ItemTypes.LOGS, 3), 1, "the stateful one only when nothing else is left")
	assert_true(slots.slots[1].is_empty())


func test_adding_one_item_with_a_state_needs_a_free_slot_and_keeps_the_state() -> void:
	var slots := ItemSlots.new(2)
	slots.slots[0] = {"item": ItemTypes.LOGS, "count": 5}
	assert_true(slots.can_add({ItemTypes.LOGS: 1}, {"mark": 1}))
	assert_eq(slots.add(ItemTypes.LOGS, 1, [], {"mark": 1}), 0)
	assert_eq(slots.slots[1], {"item": ItemTypes.LOGS, "count": 1, "state": {"mark": 1}})
	assert_false(slots.can_add({ItemTypes.LOGS: 1}, {"mark": 2}), "no free slot left")
	assert_true(slots.can_add({ItemTypes.LOGS: 1}), "a plain one joins the stack")
