extends ResourceCase
## Harvesting every crop, and dead crops cleared by hand or hoed away for the next crop.


func _till_and_plant() -> void:
	_hold(ItemTypes.HOE)
	_state.use_facing_tile()
	_hold(ItemTypes.TURNIP_SEEDS)
	_state.use_facing_tile()
	_hold(ItemTypes.NONE)


func _ripen(crop: WorldObject) -> void:
	crop.state["growth"] = 3.0 * crop.type_data()["growth_per_stage"]


func test_every_crop_is_harvested_by_a_use_when_ripe() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_hold(ItemTypes.NONE)
	for crop_id in CropRules.default_rules().crop_ids():
		var crop := WorldObject.new(crop_id, _tile)
		_ripen(crop)
		_world.add_object(crop)
		var expected := CropLife.harvest_of(crop)
		var before := {}
		for item: StringName in expected:
			before[item] = _world.ground_items.count_of(item)
		assert_eq(_state.use_facing_tile(), ToolUse.Use.HARVEST, str(crop_id))
		for item: StringName in expected:
			var gained: int = _world.ground_items.count_of(item) - before[item]
			assert_eq(gained, expected[item], "%s: %s" % [crop_id, item])
		assert_gt(expected[crop.type_data()["produce"]], 0, str(crop_id))
		if CropLife.regrows(crop):
			_world.remove_object(_tile)


func test_a_dead_crop_is_cleared_by_hand_and_the_soil_can_be_planted() -> void:
	_till_and_plant()
	_world.object_at(_tile).state["crop_damage"] = 1.0
	assert_eq(_state.use_facing_tile(), ToolUse.Use.CLEAR)
	_assert_cleared_and_plantable()
	assert_true(_world.ground_items.all().is_empty(), "clearing gives nothing")


func test_a_dead_crop_is_hoed_away_and_the_soil_can_be_planted() -> void:
	_till_and_plant()
	_world.object_at(_tile).state["crop_damage"] = 1.0
	_hold(ItemTypes.HOE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.TILL)
	_assert_cleared_and_plantable()
	assert_true(_world.ground_items.all().is_empty(), "hoeing gives nothing")


func test_hoeing_away_a_dead_crop_costs_what_tilling_costs() -> void:
	_till_and_plant()
	_world.object_at(_tile).state["crop_damage"] = 1.0
	_hold(ItemTypes.HOE)
	_state.player.energy = 100.0
	_state.use_facing_tile()
	assert_almost_eq(
		_state.player.energy,
		100.0 - _state.energy_rules.cost_of(&"till") * _state.energy_drain,
		0.0001
	)


func test_a_cleared_tile_is_still_clear_after_save_and_load() -> void:
	_till_and_plant()
	_world.object_at(_tile).state["crop_damage"] = 1.0
	_hold(ItemTypes.HOE)
	_state.use_facing_tile()
	var path := "user://test_saves/farming.json"
	assert_true(SaveFile.write(_state, path))
	var restored := SaveFile.read(path)
	DirAccess.remove_absolute(path)
	var coords := Chunk.world_to_chunk(_tile)
	restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	assert_null(restored.world.object_at(_tile))
	assert_eq(restored.world.tile_at(_tile).terrain, Tile.Terrain.SOIL)
	restored.player.position = _state.player.position
	restored.player.facing = Vector2i.DOWN
	HotbarHold.hold(restored.player.inventory, ItemTypes.TURNIP_SEEDS)
	assert_eq(restored.use_facing_tile(), ToolUse.Use.PLANT)


func test_the_scythe_leaves_a_dead_crop_alone() -> void:
	_till_and_plant()
	_world.object_at(_tile).state["crop_damage"] = 1.0
	_hold(ItemTypes.SCYTHE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)
	assert_not_null(_world.object_at(_tile))


func _assert_cleared_and_plantable() -> void:
	assert_null(_world.object_at(_tile))
	assert_eq(_world.tile_at(_tile).terrain, Tile.Terrain.SOIL)
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLANT)
