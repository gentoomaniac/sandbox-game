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


func test_destroying_an_empty_slot_changes_nothing() -> void:
	var slots := ItemSlots.new(3)
	slots.slots[1] = {"item": ItemTypes.LOGS, "count": 3}
	slots.destroy(0)
	assert_true(slots.slots[0].is_empty())
	assert_eq(slots.slots[1], {"item": ItemTypes.LOGS, "count": 3})


func test_sending_shows_listeners_the_finished_move_in_both_containers() -> void:
	var inventory := ItemSlots.new(3)
	var chest := ItemSlots.new(3)
	inventory.slots[0] = {"item": ItemTypes.LOGS, "count": 4}
	var seen := []
	var both_totals := func() -> void:
		seen.append(inventory.count_of(ItemTypes.LOGS) + chest.count_of(ItemTypes.LOGS))
	inventory.changed.connect(both_totals)
	chest.changed.connect(both_totals)
	inventory.send(0, chest)
	assert_eq(seen, [4, 4], "one notification each, never with the logs twice or missing")
	# A listener that holds its own emitter would keep both alive past the test.
	inventory.changed.disconnect(both_totals)
	chest.changed.disconnect(both_totals)


func test_a_move_notifies_each_container_once() -> void:
	var inventory := ItemSlots.new(3)
	var chest := ItemSlots.new(3)
	inventory.slots[0] = {"item": ItemTypes.LOGS, "count": 4}
	watch_signals(inventory)
	watch_signals(chest)
	inventory.move_to(0, chest, 1)
	assert_signal_emit_count(inventory, "changed", 1)
	assert_signal_emit_count(chest, "changed", 1)


func test_sending_a_stack_to_its_own_container_does_nothing() -> void:
	var slots := ItemSlots.new(3)
	slots.slots[0] = {"item": ItemTypes.LOGS, "count": 4}
	watch_signals(slots)
	assert_false(slots.send(0, slots))
	assert_eq(slots.slots[0], {"item": ItemTypes.LOGS, "count": 4})
	assert_signal_not_emitted(slots, "changed")


func test_moving_a_same_item_stack_between_containers_respects_the_limit() -> void:
	var from := ItemSlots.new(2)
	var target := ItemSlots.new(2)
	var limit: int = ItemTypes.TYPES[ItemTypes.LOGS]["stack_limit"]
	from.slots[0] = {"item": ItemTypes.LOGS, "count": 5}
	target.slots[1] = {"item": ItemTypes.LOGS, "count": limit - 2}
	from.move_to(0, target, 1)
	assert_eq(target.slots[1]["count"], limit)
	assert_eq(from.slots[0]["count"], 3)


func test_bad_slots_and_counts_change_nothing() -> void:
	var slots := ItemSlots.new(2)
	var other := ItemSlots.new(2)
	slots.slots[0] = {"item": ItemTypes.LOGS, "count": 4}
	watch_signals(slots)
	assert_false(slots.send(2, other))
	assert_false(slots.send(-1, other))
	assert_false(slots.move_to(0, other, 2))
	assert_false(slots.move_to(5, other, 0))
	assert_false(slots.take_from(0, 0))
	assert_false(slots.take_from(0, -1))
	assert_false(slots.take_from(0, 5))
	assert_false(slots.take_from(1, 1))
	assert_eq(slots.add(ItemTypes.LOGS, -3), -3)
	assert_eq(slots.remove(ItemTypes.LOGS, -3), 0)
	slots.destroy(7)
	assert_eq(slots.slots[0], {"item": ItemTypes.LOGS, "count": 4})
	assert_true(slots.slots[1].is_empty())
	assert_true(other.is_empty())
	assert_signal_not_emitted(slots, "changed")


func test_taking_from_a_slot_takes_that_stack_not_the_last_of_the_item() -> void:
	var slots := ItemSlots.new(3)
	slots.slots[0] = {"item": ItemTypes.BERRIES, "count": 2}
	slots.slots[2] = {"item": ItemTypes.BERRIES, "count": 5}
	assert_true(slots.take_from(0, 1))
	assert_eq(slots.slots[0]["count"], 1)
	assert_eq(slots.slots[2]["count"], 5)
	assert_true(slots.take_from(0, 1))
	assert_true(slots.slots[0].is_empty())


func test_an_exchange_changes_everything_and_notifies_once() -> void:
	var slots := ItemSlots.new(2)
	slots.slots[0] = {"item": ItemTypes.LOGS, "count": 3}
	slots.slots[1] = {"item": ItemTypes.STONE, "count": 2}
	var seen := []
	var record_totals := func() -> void: seen.append(slots.totals())
	slots.changed.connect(record_totals)
	assert_true(slots.exchange({ItemTypes.LOGS: 3}, {ItemTypes.BERRIES: 1}))
	assert_eq(seen, [{ItemTypes.STONE: 2, ItemTypes.BERRIES: 1}])
	slots.changed.disconnect(record_totals)


func test_an_exchange_that_does_not_work_changes_nothing() -> void:
	var slots := ItemSlots.new(1)
	slots.slots[0] = {"item": ItemTypes.LOGS, "count": 3}
	watch_signals(slots)
	assert_false(slots.exchange({ItemTypes.LOGS: 4}, {}), "not enough to pay")
	assert_false(slots.exchange({ItemTypes.LOGS: 1}, {ItemTypes.STONE: 1}), "no room")
	assert_false(slots.exchange({ItemTypes.LOGS: 0}, {}), "bad count")
	assert_eq(slots.slots[0], {"item": ItemTypes.LOGS, "count": 3})
	assert_signal_not_emitted(slots, "changed")


func test_an_exchange_pays_with_the_slot_it_frees_for_the_result() -> void:
	var slots := ItemSlots.new(1)
	slots.slots[0] = {"item": ItemTypes.LOGS, "count": 3}
	assert_true(slots.exchange({ItemTypes.LOGS: 3}, {ItemTypes.STONE: 1}))
	assert_eq(slots.slots[0], {"item": ItemTypes.STONE, "count": 1})


func test_a_listener_that_changes_the_slots_again_sees_each_finished_state() -> void:
	var inventory := ItemSlots.new(3)
	var chest := ItemSlots.new(3)
	inventory.slots[0] = {"item": ItemTypes.LOGS, "count": 4}
	var seen := []
	var send_back := func() -> void:
		seen.append([inventory.count_of(ItemTypes.LOGS), chest.count_of(ItemTypes.LOGS)])
		if seen.size() == 1:
			chest.send(0, inventory)
	chest.changed.connect(send_back)
	inventory.send(0, chest)
	assert_eq(seen, [[0, 4], [4, 0]])
	chest.changed.disconnect(send_back)
	assert_eq(inventory.count_of(ItemTypes.LOGS), 4)
