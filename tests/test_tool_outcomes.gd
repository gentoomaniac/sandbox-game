extends OutcomeCase
## The outcomes of the uses of the hand and the tools that give something or work on a plant or an
## animal: what was picked, mown or dug, and the bone and the saddle.


func before_each() -> void:
	super.before_each()
	_set_midsummer()


func test_harvesting_a_ripe_crop_tells_the_crop_and_what_it_gave() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	var crop := WorldObject.new(WorldObjectTypes.TURNIP, _tile)
	crop.state["growth"] = 3.0 * crop.type_data()["growth_per_stage"]
	_world.add_object(crop)
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.HARVEST)
	assert_eq(_outcomes.size(), 1)
	assert_eq(_outcomes[0].kind, ActionOutcome.HARVEST)
	assert_eq(_outcomes[0].object, WorldObjectTypes.TURNIP)
	assert_false(_outcomes[0].items.is_empty())
	for item: StringName in _outcomes[0].items:
		assert_eq(_dropped(item), _outcomes[0].items[item], str(item))


func test_picking_a_bush_tells_the_berries() -> void:
	_place(WorldObjectTypes.BERRY_BUSH)
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.FORAGE)
	_assert_one(ActionOutcome.FORAGE, _tile, WorldObjectTypes.BERRY_BUSH, {ItemTypes.BERRIES: 3})


func test_clearing_a_dead_crop_tells_which() -> void:
	var crop := _place(WorldObjectTypes.TURNIP)
	crop.state["crop_damage"] = 1.0
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.CLEAR)
	_assert_one(ActionOutcome.CLEAR, _tile, WorldObjectTypes.TURNIP)


func test_watering_tells_the_tile() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_world.set_moisture(_tile, 0.0)
	_hold(ItemTypes.WATERING_CAN)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.WATER)
	_assert_one(ActionOutcome.WATER, _tile)


func test_a_swing_of_the_scythe_tells_the_hay_of_all_the_plants_it_cut() -> void:
	var tiles: Array[Vector2i] = [_tile, _tile + Vector2i.DOWN, _tile + Vector2i.LEFT]
	for tile in tiles:
		_world.remove_object(tile)
		_world.set_terrain(tile, Tile.Terrain.GRASS)
		_world.add_object(WorldObject.new(WorldObjectTypes.TALL_GRASS, tile))
	_hold(ItemTypes.SCYTHE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.MOW)
	assert_eq(_outcomes.size(), 1)
	assert_eq(_outcomes[0].kind, ActionOutcome.MOW)
	assert_eq(_outcomes[0].items, {ItemTypes.HAY: _dropped(ItemTypes.HAY)})
	assert_gt(_dropped(ItemTypes.HAY), 1, "the hay of several plants")


func test_digging_tells_the_clay_found_and_nothing_on_a_miss() -> void:
	_hold(ItemTypes.SHOVEL)
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.DIG)
	_assert_one(ActionOutcome.DIG, _tile)
	var spots := _clay_spots_near()
	var found := 0
	var missed := 0
	for spot in spots:
		_outcomes.clear()
		_state.player.position = Vector2(spot) + Vector2(0.5, 0.5)
		if _state.use_tile(spot) != ToolUse.Use.DIG:
			continue
		assert_eq(_outcomes.size(), 1)
		var items: Dictionary = _outcomes[0].items
		assert_true(items.is_empty() or items == ToolUse.CLAY_DIG_YIELD)
		found += 1 if not items.is_empty() else 0
		missed += 1 if items.is_empty() else 0
	assert_gt(found, 0, "some spot gave clay")
	assert_gt(missed, 0, "some spot did not")


## Clay spots of the loaded chunks, found like the shovel's tests do.
func _clay_spots_near() -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	var centre := _state.player.tile()
	for y in range(-40, 41):
		for x in range(-40, 41):
			var pos := centre + Vector2i(x, y)
			if _world.is_chunk_loaded(Chunk.world_to_chunk(pos)) and _world.has_clay(pos):
				spots.append(pos)
	return spots


func test_giving_a_bone_and_saddling_and_unsaddling_tell_the_animal() -> void:
	var dog := FarmAnimal.new(LivestockRules.DOG, &"collie", Vector2(_tile) + Vector2(0.5, 0.6))
	_state.livestock.add(dog)
	_state.player.inventory.add(ItemTypes.BONE, 1)
	_hold(ItemTypes.BONE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.GIVE_BONE)
	_assert_one(ActionOutcome.GIVE_BONE, _tile, LivestockRules.DOG, {ItemTypes.BONE: 1})
	_outcomes.clear()
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"bay", Vector2(_tile) + Vector2(0.5, 0.6))
	_state.livestock.add(horse)
	_state.player.inventory.add(ItemTypes.SADDLE, 1)
	_hold(ItemTypes.SADDLE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.SADDLE)
	_assert_one(ActionOutcome.SADDLE, _tile, LivestockRules.HORSE, {ItemTypes.SADDLE: 1})
	_outcomes.clear()
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.UNSADDLE)
	_assert_one(ActionOutcome.UNSADDLE, _tile, LivestockRules.HORSE, {ItemTypes.SADDLE: 1})
