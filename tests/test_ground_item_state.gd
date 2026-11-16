extends ResourceCase
## A pile on the ground can be one item with a state (task 231): dropped and picked up with it,
## saved with it, merged with nothing.

const FRAME := 1.0 / 60.0
const SETTLE_FRAMES := 120
const MARK := {"mark": 4}


func _walk_frames(frames: int) -> void:
	for _i in frames:
		GroundPickup.collect(_state, FRAME)


func test_an_item_with_a_state_is_dropped_as_a_pile_of_its_own_and_picked_up_with_it() -> void:
	var inventory := _state.player.inventory
	inventory.slots[3] = {"item": ItemTypes.STONE, "count": 1, "state": MARK}

	assert_true(GroundPickup.drop(_state, 3))

	assert_true(inventory.slots[3].is_empty())
	var piles := _world.ground_items.all()
	assert_eq(piles.size(), 1)
	assert_eq(piles[0].count, 1)
	assert_eq(piles[0].state, MARK)
	_state.player.position = piles[0].position + Vector2(0, -6)
	_walk_frames(SETTLE_FRAMES)
	_state.player.position = piles[0].position
	_walk_frames(SETTLE_FRAMES)
	assert_eq(_world.ground_items.count_of(ItemTypes.STONE), 0)
	var picked_up := inventory.slots.filter(
		func(stack: Dictionary) -> bool: return stack.has("state")
	)
	assert_eq(picked_up.size(), 1)
	assert_eq(picked_up[0]["state"], MARK)


func test_a_pile_with_a_state_is_not_picked_up_while_the_inventory_has_no_free_slot() -> void:
	var inventory := _state.player.inventory
	for slot in Inventory.SLOT_COUNT:
		inventory.slots[slot] = {"item": ItemTypes.STONE, "count": 1}
	var pile := GroundItem.new(ItemTypes.STONE, 1, _state.player.position, MARK)
	_world.ground_items.add(pile)

	_walk_frames(SETTLE_FRAMES)

	assert_eq(_world.ground_items.count_of(ItemTypes.STONE), 1, "it stays")


func test_the_state_of_a_pile_is_saved_and_loaded() -> void:
	var piles := GroundItems.new()
	piles.add(GroundItem.new(ItemTypes.STONE, 3, Vector2(1.5, 2.5)))
	piles.add(GroundItem.new(ItemTypes.STONE, 1, Vector2(4.5, 2.5), MARK))

	var data := piles.to_array()
	var restored := GroundItems.new()
	restored.load_array(data)

	assert_false(data[0].has("state"))
	assert_eq(data[1]["state"], MARK)
	assert_eq(restored.all()[0].state, {})
	assert_eq(restored.all()[1].state, MARK)
	restored.all()[1].state["mark"] = 9
	assert_eq(data[1]["state"], MARK, "a copy")
