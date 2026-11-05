extends ResourceCase
## Felling and mining: hits, tool levels, drops, stumps and regrowth.

const OAK_HITS := 5

# --- Hits ---


func test_a_tree_falls_after_hp_over_power_hits_and_gives_wood() -> void:
	var tree := _place(WorldObjectTypes.OAK)
	var hp: int = tree.type_data()["hp"]
	var power := ItemTypes.tool_power(ItemTypes.AXE)
	assert_eq(hp, OAK_HITS)
	var hits_needed := ceili(float(hp) / power)
	_hit(ItemTypes.AXE, hits_needed - 1)
	assert_same(_world.object_at(_tile), tree, "still standing")
	assert_eq(_count(ItemTypes.WOOD), 0)
	assert_eq(_hit(ItemTypes.AXE, 1), GameState.Use.HIT)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.STUMP)
	assert_eq(_count(ItemTypes.WOOD), 4)


func test_a_better_tool_needs_fewer_hits() -> void:
	var hits_for := {}
	for level in range(1, ItemTypes.POWER_OF_LEVEL.size()):
		hits_for[level] = ceili(7.0 / ItemTypes.POWER_OF_LEVEL[level])
	assert_eq(hits_for, {1: 7, 2: 4, 3: 3})
	var boulder := WorldObject.new(WorldObjectTypes.BOULDER, _tile)
	var power := ItemTypes.POWER_OF_LEVEL[2]
	for _i in 2:
		assert_false(boulder.is_finished_by(power))
		boulder.take_hit(power)
	assert_true(boulder.is_finished_by(power), "a level 2 tool needs 3 of 6 hp")


func test_a_tool_below_the_harvest_level_does_nothing() -> void:
	var boulder := _place(WorldObjectTypes.BOULDER)
	_hold(ItemTypes.PICKAXE)
	assert_eq(_state.use_at(_tile), GameState.Use.NEEDS_BETTER_TOOL)
	assert_eq(_state.use_facing_tile(), GameState.Use.NEEDS_BETTER_TOOL)
	assert_eq(boulder.state, {})
	assert_same(_world.object_at(_tile), boulder)


func test_pine_needs_a_better_axe() -> void:
	_place(WorldObjectTypes.PINE)
	_hold(ItemTypes.AXE)
	assert_eq(_state.use_at(_tile), GameState.Use.NEEDS_BETTER_TOOL)


func test_the_wrong_kind_of_tool_does_nothing() -> void:
	var tree := _place(WorldObjectTypes.OAK)
	_hold(ItemTypes.PICKAXE)
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)
	_hold(ItemTypes.WATERING_CAN)
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)
	assert_eq(tree.state, {})
	_world.remove_object(_tile)
	_place(WorldObjectTypes.STONE)
	_hold(ItemTypes.AXE)
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)


func test_a_hit_emits_object_hit_and_the_final_hit_does_not() -> void:
	_place(WorldObjectTypes.STONE)
	watch_signals(_world)
	_hit(ItemTypes.PICKAXE, 1)
	assert_signal_emit_count(_world, "object_hit", 1)
	_hit(ItemTypes.PICKAXE, 2)
	assert_signal_emit_count(_world, "object_hit", 2)


func test_damage_heals_overnight() -> void:
	var tree := _place(WorldObjectTypes.OAK)
	_hit(ItemTypes.AXE, OAK_HITS - 1)
	_sleep_days(1)
	assert_false(tree.state.has("damage"))
	_hit(ItemTypes.AXE, OAK_HITS - 1)
	assert_same(_world.object_at(_tile), tree, "needs all its hits again")


func test_damage_outlives_the_chunk_and_the_save() -> void:
	var tree := _place(WorldObjectTypes.OAK)
	_hit(ItemTypes.AXE, 3)
	_reload_chunk()
	assert_eq(_world.object_at(_tile).state["damage"], 3)
	assert_eq(int(_through_save().world.object_at(_tile).state["damage"]), 3)
	assert_same(_world.object_at(_tile), tree)


func test_a_generated_tree_keeps_its_damage_when_its_chunk_reloads() -> void:
	var generated: WorldObject = null
	for coords in _world.loaded_chunk_coords():
		for object in _world.chunk_at(coords).objects():
			if object.type == WorldObjectTypes.OAK:
				generated = object
	assert_not_null(generated, "no oak near the camp")
	_hold(ItemTypes.AXE)
	_state.use_tile(generated.pos)
	_state.use_tile(generated.pos)
	var coords := Chunk.world_to_chunk(generated.pos)
	_world.remove_chunk(coords)
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	assert_eq(_world.object_at(generated.pos).state["damage"], 2)


# --- Drops ---


func test_stone_gives_two_stone_and_goes() -> void:
	_place(WorldObjectTypes.STONE)
	_hit(ItemTypes.PICKAXE, 3)
	assert_null(_world.object_at(_tile))
	assert_eq(_count(ItemTypes.STONE), 2)


func test_every_drop_is_an_item() -> void:
	for type_name: StringName in WorldObjectTypes.TYPES:
		for item: StringName in WorldObjectTypes.TYPES[type_name].get("drops", {}):
			assert_true(ItemTypes.TYPES.has(item), "%s drops %s" % [type_name, item])
	assert_eq(WorldObjectTypes.TYPES[WorldObjectTypes.BOULDER]["drops"], {&"stone": 5})
	assert_eq(WorldObjectTypes.TYPES[WorldObjectTypes.PINE]["drops"], {&"wood": 5})
	assert_eq(WorldObjectTypes.TYPES[WorldObjectTypes.DEAD_TREE]["drops"], {&"wood": 2})


func test_the_final_hit_does_not_happen_when_the_drops_do_not_fit() -> void:
	var tree := _place(WorldObjectTypes.OAK)
	_hit(ItemTypes.AXE, OAK_HITS - 1)
	_fill_inventory()
	assert_eq(_hit(ItemTypes.AXE, 1), GameState.Use.INVENTORY_FULL)
	assert_same(_world.object_at(_tile), tree)
	assert_eq(tree.state["damage"], OAK_HITS - 1)
	_state.player.inventory.remove(ItemTypes.TURNIP, 99)
	assert_eq(_hit(ItemTypes.AXE, 1), GameState.Use.HIT)
	assert_eq(_count(ItemTypes.WOOD), 4)


func _saplings_from_felling_on_days(days: int) -> Array[int]:
	var saplings: Array[int] = []
	for day in days:
		_state.clock.day = day + 1
		_place(WorldObjectTypes.OAK)
		_state.player.inventory.remove(ItemTypes.SAPLING, 99)
		_hit(ItemTypes.AXE, OAK_HITS)
		saplings.append(_count(ItemTypes.SAPLING))
		_world.remove_object(_tile)
		_state.player.inventory.remove(ItemTypes.WOOD, 99)
	return saplings


func test_the_sapling_chance_is_deterministic_and_about_a_quarter() -> void:
	var first := _saplings_from_felling_on_days(80)
	var second := _saplings_from_felling_on_days(80)
	assert_eq(first, second)
	var total: int = first.reduce(func(sum: int, count: int) -> int: return sum + count, 0)
	assert_between(total, 8, 32)


func test_a_stone_never_gives_a_sapling() -> void:
	for day in 30:
		_state.clock.day = day + 1
		_place(WorldObjectTypes.STONE)
		_hit(ItemTypes.PICKAXE, 3)
	assert_eq(_count(ItemTypes.SAPLING), 0)


# --- Stumps ---


func test_a_stump_becomes_a_sapling_and_then_the_tree() -> void:
	_place(WorldObjectTypes.SPRUCE)
	_hit(ItemTypes.AXE, 4)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.STUMP)
	_sleep_days(2)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.STUMP)
	_sleep_days(1)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SAPLING)
	_sleep_days(3)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SAPLING)
	_sleep_days(1)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SPRUCE)
	assert_eq(_world.object_at(_tile).state, {})


func test_growth_waits_a_day_while_the_player_stands_on_the_sapling() -> void:
	_place(WorldObjectTypes.SAPLING, "oak")
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	_sleep_days(4)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SAPLING)
	_state.player.position += Vector2(0, 2)
	_sleep_days(1)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.OAK)


func test_a_dead_tree_leaves_a_stump_that_stays() -> void:
	_place(WorldObjectTypes.DEAD_TREE)
	_hit(ItemTypes.AXE, 3)
	assert_eq(_count(ItemTypes.WOOD), 2)
	_sleep_days(10)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.STUMP)


func test_a_stump_can_be_removed_with_the_axe_for_a_wood() -> void:
	_place(WorldObjectTypes.OAK)
	_hit(ItemTypes.AXE, OAK_HITS)
	_state.player.inventory.remove(ItemTypes.WOOD, 99)
	assert_eq(_hit(ItemTypes.AXE, 2), GameState.Use.HIT)
	assert_null(_world.object_at(_tile))
	assert_eq(_count(ItemTypes.WOOD), 1)


func test_regrowth_goes_on_in_unloaded_chunks_and_through_a_save() -> void:
	_place(WorldObjectTypes.OAK)
	_hit(ItemTypes.AXE, OAK_HITS)
	var coords := Chunk.world_to_chunk(_tile)
	_world.remove_chunk(coords)
	_sleep_days(3)
	var restored := _through_save()
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SAPLING)
	assert_eq(restored.world.object_at(_tile).type, WorldObjectTypes.SAPLING)
	assert_eq(restored.world.object_at(_tile).state["tree"], "oak")
	restored.clock.advance(4 * GameClock.MINUTES_PER_DAY)
	assert_eq(restored.world.object_at(_tile).type, WorldObjectTypes.OAK)
