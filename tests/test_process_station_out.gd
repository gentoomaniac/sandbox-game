extends ProcessStationCase
## What a process station's run made, on the smelter of test config: taken out as far as it fits,
## nothing in until it is all out, the run ending with the last; the grid packed again after a
## part comes out, a recipe click refused rather than lose anything, and nothing moved out of the
## player's reach.

# --- The results ---


func test_nothing_goes_in_or_starts_while_results_are_left() -> void:
	_station.fill(&"bricks", 1)
	_station.start()
	_state.simulation.advance(RUN_MINUTES)
	assert_eq(_station.room_for(ItemTypes.STONE), 0)
	assert_false(_station.can_fill(&"bricks"))
	assert_eq(_station.runnable_recipe(), &"")
	assert_false(_station.start())


func test_the_results_come_out_as_far_as_they_fit_and_the_rest_stays() -> void:
	_station.fill(&"bricks", 10)
	_station.start()
	_state.simulation.advance(RUN_MINUTES)
	_fill_inventory()
	_state.player.inventory.slots[_state.player.inventory.selected_slot] = {
		"item": ItemTypes.BRICK, "count": 90
	}
	_station.send_out(0)
	assert_eq(_count(ItemTypes.BRICK), 99)
	assert_eq(_grid(), {ItemTypes.BRICK: 11})
	assert_true(_station.holds_results())


func test_the_run_ends_when_the_last_result_is_taken_out() -> void:
	_station.fill(&"bricks", 1)
	_station.start()
	_state.simulation.advance(RUN_MINUTES)
	var free_slot := Inventory.SLOT_COUNT - 1
	assert_true(_state.player.inventory.slots[free_slot].is_empty())
	_station.take_out(0, _state.player.inventory, free_slot)
	assert_eq(_count(ItemTypes.BRICK), 2)
	assert_false(_station.holds_results())
	assert_false(_smelter.state.has(ProcessStation.RUN))
	assert_eq(_put_in(ItemTypes.STONE), 18, "open again")


func test_taking_out_onto_another_item_swaps_nothing_in() -> void:
	_put_in(ItemTypes.STONE)
	var berries := _slot_of(ItemTypes.BERRIES)
	_station.take_out(0, _state.player.inventory, berries)
	assert_eq(_grid(), {ItemTypes.STONE: 20})
	assert_eq(_state.player.inventory.item_in(berries), ItemTypes.BERRIES)


func test_a_listener_of_the_grid_finds_the_run_settled() -> void:
	_station.fill(&"bricks", 1)
	_station.start()
	_state.simulation.advance(RUN_MINUTES)
	var seen := []
	var look := func() -> void: seen.append([_station.is_running(), _grid()])
	_smelter.storage.changed.connect(look)
	assert_true(_station.holds_results())
	_smelter.storage.changed.disconnect(look)
	assert_eq(seen, [[false, {ItemTypes.BRICK: 2}]], "told once, done and with the bricks")


func test_a_stack_taken_out_in_part_leaves_the_grid_packed() -> void:
	_state.player.inventory.add(ItemTypes.STONE, 100)
	_put_in(ItemTypes.STONE)
	_put_in(ItemTypes.STONE)
	assert_eq(_smelter.storage.slots[1], {"item": ItemTypes.STONE, "count": 21})
	var inventory := _state.player.inventory
	var last := Inventory.SLOT_COUNT - 1
	inventory.slots[last] = {"item": ItemTypes.STONE, "count": 1}
	_station.take_out(0, inventory, last)
	assert_eq(inventory.slots[last]["count"], 99, "98 went onto the stack of one")
	assert_eq(_smelter.storage.slots[0], {"item": ItemTypes.STONE, "count": 22})
	assert_true(_smelter.storage.slots[1].is_empty(), "packed into one stack")


func test_a_recipe_click_the_grid_has_no_room_for_takes_nothing() -> void:
	# Not packed, as no move of the station leaves it: a stone in every slot.
	for slot in _smelter.storage.slots.size():
		_smelter.storage.slots[slot] = {"item": ItemTypes.STONE, "count": 1}
	var before := _state.player.inventory.totals()
	assert_false(_station.fill(&"bricks", 2), "no slot for the logs")
	assert_eq(_state.player.inventory.totals(), before)
	assert_eq(_grid(), {ItemTypes.STONE: 4})


func test_a_run_whose_results_were_dropped_ends_and_the_grid_takes_things_again() -> void:
	_smelter.state[ProcessStation.RUN] = {"recipe": "bricks", "start_minute": 0, "done_minute": 1}
	assert_false(_station.holds_results())
	assert_false(_smelter.state.has(ProcessStation.RUN))
	assert_eq(_put_in(ItemTypes.STONE), 20)


func test_nothing_moves_in_or_out_out_of_reach() -> void:
	_put_in(ItemTypes.STONE)
	_state.player.position += Vector2(5.0, 0.0)
	assert_eq(_put_in(ItemTypes.LOGS), 0)
	assert_false(_station.fill(&"bricks", 10))
	_station.send_out(0)
	_station.take_out(0, _state.player.inventory, Inventory.SLOT_COUNT - 1)
	assert_eq(_grid(), {ItemTypes.STONE: 20})
