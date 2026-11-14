extends ResourceCase
## The chest outdoors, taken down with the axe, and saved with what it holds.

## The states of the two single items a chest holds in the tests of what keeps its state.
const FRESH_LANTERN := {"mark": 1}
const BURNT_CANDLE := {"mark": 2}


func _chest_with_contents() -> WorldObject:
	var chest := _place(WorldObjectTypes.CHEST)
	chest.storage.add(ItemTypes.LOGS, 120)
	chest.storage.add(ItemTypes.RUSTY_IRON_HOE, 1)
	return chest


# --- Taking down ---


func test_the_axe_takes_a_chest_down_in_three_hits() -> void:
	var chest := _chest_with_contents()
	assert_eq(_hit(ItemTypes.RUSTY_IRON_AXE, 2), ToolUse.Use.HIT)
	assert_eq(_world.object_at(_tile), chest, "still there")
	assert_eq(chest.storage.count_of(ItemTypes.LOGS), 120, "and full")
	_state.use_facing_tile()
	assert_null(_world.object_at(_tile))


func test_a_felled_chest_gives_the_chest_item_back_as_a_pile() -> void:
	_chest_with_contents()
	_hit(ItemTypes.RUSTY_IRON_AXE, 3)
	assert_eq(_world.ground_items.count_of(ItemTypes.CHEST), 1)
	assert_eq(_count(ItemTypes.CHEST), 0, "it lies on the ground")


func test_a_felled_chest_spills_what_it_held_as_piles_on_the_ground() -> void:
	_chest_with_contents()
	_hit(ItemTypes.RUSTY_IRON_AXE, 3)
	assert_eq(_world.ground_items.count_of(ItemTypes.LOGS), 120)
	assert_eq(_world.ground_items.count_of(ItemTypes.RUSTY_IRON_HOE), 1)
	var piles := _world.ground_items.all().filter(
		func(pile: GroundItem) -> bool: return pile.item == ItemTypes.LOGS
	)
	assert_gt(piles.size(), 1, "spread over tiles round the chest")


func test_an_empty_chest_taken_down_leaves_only_the_chest_item() -> void:
	_place(WorldObjectTypes.CHEST)
	_hit(ItemTypes.RUSTY_IRON_AXE, 3)
	assert_eq(_world.ground_items.all().size(), 1)
	assert_eq(_world.ground_items.count_of(ItemTypes.CHEST), 1)


func test_a_chest_inside_a_chest_comes_back_with_its_item_counted_once_each() -> void:
	var chest := _place(WorldObjectTypes.CHEST)
	chest.storage.add(ItemTypes.CHEST, 2)
	_hit(ItemTypes.RUSTY_IRON_AXE, 3)
	assert_eq(_world.ground_items.count_of(ItemTypes.CHEST), 3)


func test_the_pickaxe_does_nothing_to_a_chest() -> void:
	_place(WorldObjectTypes.CHEST)
	assert_eq(_hit(ItemTypes.RUSTY_IRON_PICKAXE, 1), ToolUse.Use.NOTHING)


func test_a_chest_hit_but_not_felled_heals_overnight_and_keeps_its_contents() -> void:
	var chest := _chest_with_contents()
	_hit(ItemTypes.RUSTY_IRON_AXE, 2)
	_sleep_days(1)
	_hit(ItemTypes.RUSTY_IRON_AXE, 2)
	assert_eq(_world.object_at(_tile), chest)
	assert_eq(chest.storage.count_of(ItemTypes.LOGS), 120)


# --- Saving ---


func test_a_chest_and_its_contents_survive_a_save_and_load() -> void:
	_chest_with_contents()
	var restored := _through_save()
	var chest := restored.world.object_at(_tile)
	assert_eq(chest.type, WorldObjectTypes.CHEST)
	assert_eq(chest.storage.totals(), {ItemTypes.LOGS: 120, ItemTypes.RUSTY_IRON_HOE: 1})
	assert_eq(chest.storage.slots_to_data(), _world.object_at(_tile).storage.slots_to_data())


func test_a_chest_survives_its_chunk_unloading_with_what_it_holds() -> void:
	var chest := _chest_with_contents()
	_reload_chunk()
	assert_eq(_world.object_at(_tile), chest, "the same chest, kept by the edits")
	assert_eq(_world.object_at(_tile).storage.count_of(ItemTypes.LOGS), 120)


func test_what_is_put_in_a_chest_after_it_was_placed_is_saved() -> void:
	_state.player.inventory.add(ItemTypes.CHEST, 1)
	_hold(ItemTypes.CHEST)
	_state.use_facing_tile()
	_world.object_at(_tile).storage.add(ItemTypes.STONE, 9)
	var restored := _through_save()
	assert_eq(restored.world.object_at(_tile).storage.count_of(ItemTypes.STONE), 9)


func test_objects_that_store_nothing_have_no_storage_in_the_save() -> void:
	var stone := WorldObject.new(WorldObjectTypes.STONE, _tile)
	assert_null(stone.storage)
	assert_false(stone.to_dict().has("storage"))


# --- What has a state keeps it (task 231) ---


func _chest_with_lantern_and_burnt_candle() -> WorldObject:
	var chest := _place(WorldObjectTypes.CHEST)
	chest.storage.slots[0] = {"item": ItemTypes.LANTERN, "count": 1}
	chest.storage.set_state(0, FRESH_LANTERN)
	chest.storage.slots[1] = {"item": ItemTypes.STONE, "count": 1}
	chest.storage.set_state(1, BURNT_CANDLE)
	chest.storage.add(ItemTypes.STONE, 2)
	return chest


func _states_of(item: StringName, stacks: Array) -> Array:
	return (
		stacks
		. filter(
			func(stack: Dictionary) -> bool: return stack.get("item") == item and stack.has("state")
		)
		. map(func(stack: Dictionary) -> Dictionary: return stack["state"])
	)


func test_a_felled_chest_spills_a_lantern_and_a_burnt_candle_with_their_states() -> void:
	_chest_with_lantern_and_burnt_candle()
	_hit(ItemTypes.RUSTY_IRON_AXE, 3)

	var piles := _world.ground_items.all()
	var states := piles.filter(func(pile: GroundItem) -> bool: return not pile.state.is_empty())
	assert_eq(states.size(), 2)
	for pile: GroundItem in states:
		assert_eq(pile.count, 1)
		assert_eq(pile.state, FRESH_LANTERN if pile.item == ItemTypes.LANTERN else BURNT_CANDLE)
	assert_eq(_world.ground_items.count_of(ItemTypes.STONE), 3)


func test_a_chest_taken_down_with_the_hammer_keeps_the_states_in_the_bag() -> void:
	var chest := _chest_with_lantern_and_burnt_candle()
	_state.player.inventory = Inventory.new()

	assert_true(Builder.new(_state).take_down(TakeDownTarget.of_object(chest)))

	var slots := _state.player.inventory.slots
	assert_eq(_states_of(ItemTypes.LANTERN, slots), [FRESH_LANTERN])
	assert_eq(_states_of(ItemTypes.STONE, slots), [BURNT_CANDLE])
	assert_eq(_state.player.inventory.count_of(ItemTypes.STONE), 3)
	assert_eq(_world.ground_items.all().size(), 0)


func test_what_a_hammered_chest_has_no_room_for_lies_on_the_ground_with_its_state() -> void:
	var chest := _chest_with_lantern_and_burnt_candle()
	for slot in Inventory.SLOT_COUNT:
		_state.player.inventory.slots[slot] = {"item": ItemTypes.RUSTY_IRON_AXE, "count": 1}
	_state.player.inventory.slots[0] = {}

	assert_true(Builder.new(_state).take_down(TakeDownTarget.of_object(chest)))

	var states := _world.ground_items.all().filter(
		func(pile: GroundItem) -> bool: return not pile.state.is_empty()
	)
	assert_eq(states.size(), 2)
