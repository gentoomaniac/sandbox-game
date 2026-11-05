extends ResourceCase
## The chest outdoors, taken down with the axe, and saved with what it holds.


func _chest_with_contents() -> WorldObject:
	var chest := _place(WorldObjectTypes.CHEST)
	chest.storage.add(ItemTypes.LOGS, 120)
	chest.storage.add(ItemTypes.HOE, 1)
	return chest


# --- Taking down ---


func test_the_axe_takes_a_chest_down_in_three_hits() -> void:
	var chest := _chest_with_contents()
	assert_eq(_hit(ItemTypes.AXE, 2), GameState.Use.HIT)
	assert_eq(_world.object_at(_tile), chest, "still there")
	assert_eq(chest.storage.count_of(ItemTypes.LOGS), 120, "and full")
	_state.use_facing_tile()
	assert_null(_world.object_at(_tile))


func test_a_felled_chest_gives_the_chest_item_back_as_a_pile() -> void:
	_chest_with_contents()
	_hit(ItemTypes.AXE, 3)
	assert_eq(_world.ground_count_of(ItemTypes.CHEST), 1)
	assert_eq(_count(ItemTypes.CHEST), 0, "it lies on the ground")


func test_a_felled_chest_spills_what_it_held_as_piles_on_the_ground() -> void:
	_chest_with_contents()
	_hit(ItemTypes.AXE, 3)
	assert_eq(_world.ground_count_of(ItemTypes.LOGS), 120)
	assert_eq(_world.ground_count_of(ItemTypes.HOE), 1)
	var piles := _world.ground_items().filter(
		func(pile: GroundItem) -> bool: return pile.item == ItemTypes.LOGS
	)
	assert_gt(piles.size(), 1, "spread over tiles round the chest")


func test_an_empty_chest_taken_down_leaves_only_the_chest_item() -> void:
	_place(WorldObjectTypes.CHEST)
	_hit(ItemTypes.AXE, 3)
	assert_eq(_world.ground_items().size(), 1)
	assert_eq(_world.ground_count_of(ItemTypes.CHEST), 1)


func test_a_chest_inside_a_chest_comes_back_with_its_item_counted_once_each() -> void:
	var chest := _place(WorldObjectTypes.CHEST)
	chest.storage.add(ItemTypes.CHEST, 2)
	_hit(ItemTypes.AXE, 3)
	assert_eq(_world.ground_count_of(ItemTypes.CHEST), 3)


func test_the_pickaxe_does_nothing_to_a_chest() -> void:
	_place(WorldObjectTypes.CHEST)
	assert_eq(_hit(ItemTypes.PICKAXE, 1), GameState.Use.NOTHING)


func test_a_chest_hit_but_not_felled_heals_overnight_and_keeps_its_contents() -> void:
	var chest := _chest_with_contents()
	_hit(ItemTypes.AXE, 2)
	_sleep_days(1)
	_hit(ItemTypes.AXE, 2)
	assert_eq(_world.object_at(_tile), chest)
	assert_eq(chest.storage.count_of(ItemTypes.LOGS), 120)


# --- Saving ---


func test_a_chest_and_its_contents_survive_a_save_and_load() -> void:
	_chest_with_contents()
	var restored := _through_save()
	var chest := restored.world.object_at(_tile)
	assert_eq(chest.type, WorldObjectTypes.CHEST)
	assert_eq(chest.storage.totals(), {ItemTypes.LOGS: 120, ItemTypes.HOE: 1})
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


func test_a_chest_saved_without_storage_comes_back_empty() -> void:
	var data := WorldObject.new(WorldObjectTypes.CHEST, _tile).to_dict()
	data.erase("storage")
	var chest := WorldObject.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(chest.storage.slots.size(), 15)
	assert_true(chest.storage.is_empty())


func test_objects_that_store_nothing_have_no_storage_in_the_save() -> void:
	var stone := WorldObject.new(WorldObjectTypes.STONE, _tile)
	assert_null(stone.storage)
	assert_false(stone.to_dict().has("storage"))
