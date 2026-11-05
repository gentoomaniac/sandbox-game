extends ResourceCase
## Picking by hand, berry bushes and planting saplings, in midsummer: see
## test_seasonal_plants.gd for the rest of the year.


func before_each() -> void:
	super.before_each()
	_set_midsummer()


func test_a_hand_picks_fibre_and_the_plant_goes() -> void:
	for type_name in [WorldObjectTypes.SHRUB, WorldObjectTypes.FERN_BUSH]:
		_place(type_name)
		_hold(ItemTypes.NONE)
		assert_eq(_state.use_facing_tile(), GameState.Use.FORAGE)
		assert_null(_world.object_at(_tile))
	assert_eq(_count(ItemTypes.FIBRE), 4)


func test_a_hand_picks_a_wild_sapling_into_a_sapling_item() -> void:
	_place(WorldObjectTypes.SAPLING)
	_hold(ItemTypes.NONE)
	_state.use_facing_tile()
	assert_null(_world.object_at(_tile))
	assert_eq(_count(ItemTypes.SAPLING), 1)


func test_a_wild_sapling_does_not_grow() -> void:
	_place(WorldObjectTypes.SAPLING)
	_sleep_days(10)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SAPLING)


func test_a_berry_bush_is_picked_and_bears_again_after_three_days() -> void:
	var bush := _place(WorldObjectTypes.BERRY_BUSH)
	var ripe_look := ObjectTileset.atlas_cell(bush)
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), GameState.Use.FORAGE)
	assert_eq(_count(ItemTypes.BERRIES), 3)
	assert_same(_world.object_at(_tile), bush, "picking does not remove it")
	assert_ne(ObjectTileset.atlas_cell(bush), ripe_look, "it looks picked")
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)
	_sleep_days(2)
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)
	_sleep_days(1)
	assert_eq(ObjectTileset.atlas_cell(bush), ripe_look)
	# The berries went into the first free slot, which was the held (empty) one.
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), GameState.Use.FORAGE)
	assert_eq(_count(ItemTypes.BERRIES), 6)


func test_a_picked_bush_survives_the_chunk_and_the_save() -> void:
	_place(WorldObjectTypes.BERRY_BUSH)
	_hold(ItemTypes.NONE)
	_state.use_facing_tile()
	_sleep_days(1)
	_reload_chunk()
	assert_true(_world.object_at(_tile).is_picked())
	var restored := _through_save()
	assert_true(restored.world.object_at(_tile).is_picked())
	restored.clock.advance(2 * GameClock.MINUTES_PER_DAY)
	assert_false(restored.world.object_at(_tile).is_picked())


# --- Planting ---


func test_a_sapling_item_is_planted_on_grass_and_grows_into_an_oak() -> void:
	_state.player.inventory.add(ItemTypes.SAPLING, 2)
	_hold(ItemTypes.SAPLING)
	assert_eq(_state.use_facing_tile(), GameState.Use.PLANT)
	assert_eq(_count(ItemTypes.SAPLING), 1)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SAPLING)
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING, "the tile is taken")
	_sleep_days(3)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SAPLING)
	_sleep_days(1)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.OAK)


func test_a_sapling_is_not_planted_on_soil_and_seeds_not_on_grass() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_state.player.inventory.add(ItemTypes.SAPLING, 1)
	_hold(ItemTypes.SAPLING)
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)


func test_the_highlight_shows_for_axe_and_pickaxe_but_not_for_the_can() -> void:
	_hold(ItemTypes.AXE)
	assert_true(_state.can_use_held_item())
	_hold(ItemTypes.PICKAXE)
	assert_true(_state.can_use_held_item())
	_hold(ItemTypes.WATERING_CAN)
	assert_false(_state.can_use_held_item())
