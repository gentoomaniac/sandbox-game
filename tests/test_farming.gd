extends GutTest
## Tilling, planting, growing and harvesting, and the terrain edits behind them.

const SEED := 7
## Tiles around the camp: grass most likely, checked by `_grass_tile`.
const SEARCH := 6

var _state: GameState
var _world: World
var _tile: Vector2i


func before_each() -> void:
	_state = GameState.new_game(SEED)
	_world = _state.world
	_tile = _grass_tile()
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5) - Vector2(0, 1)
	_state.player.facing = Vector2i.DOWN


func _grass_tile() -> Vector2i:
	var center := _state.player.tile()
	for y in range(-SEARCH, SEARCH):
		for x in range(-SEARCH, SEARCH):
			var pos := center + Vector2i(x, y + 1)
			if _world.is_tillable(pos) and _world.is_tillable(pos - Vector2i(0, 1)):
				return pos
	fail_test("no grass near the camp")
	return center


func _hold(item: StringName) -> void:
	var inventory := _state.player.inventory
	for slot in Inventory.HOTBAR_SIZE:
		if inventory.item_in(slot) == item:
			inventory.select(slot)
			return
	fail_test("not on the hotbar: %s" % item)


func _till_and_plant() -> void:
	_hold(ItemTypes.HOE)
	_state.use_facing_tile()
	_hold(ItemTypes.TURNIP_SEEDS)
	_state.use_facing_tile()
	_hold(ItemTypes.NONE)


func _sleep_days(days: int) -> void:
	_state.clock.advance(days * GameClock.MINUTES_PER_DAY)


func test_using_grass_tills_it_to_soil() -> void:
	assert_eq(_state.use_facing_tile(), GameState.Use.TILL)
	assert_eq(_world.tile_at(_tile).terrain, Tile.Terrain.SOIL)


func test_use_tile_works_on_any_tile_as_reach_is_not_the_states_concern() -> void:
	var far := _tile + Vector2i(0, 1)
	assert_true(Vector2i(far - _state.player.tile()).abs().y > Targeting.REACH)
	var expected := _state.use_at(far)
	assert_eq(_state.use_tile(far), expected)


func test_water_cannot_be_tilled() -> void:
	_world.chunk_at(Chunk.world_to_chunk(_tile)).set_terrain(
		Chunk.local_pos(_tile), Tile.Terrain.WATER
	)
	assert_eq(_state.use_facing_tile(), GameState.Use.NOTHING)


func test_floodplain_cannot_be_tilled_yet() -> void:
	_world.set_terrain(_tile, Tile.Terrain.FLOODPLAIN)
	assert_false(_world.is_tillable(_tile))


func test_a_tile_with_an_object_cannot_be_tilled() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _tile))
	assert_false(_world.is_tillable(_tile))


func test_a_tile_under_a_building_cannot_be_tilled() -> void:
	var meadow := World.new(SEED)
	meadow.add_chunk(Chunk.new(Vector2i.ZERO))
	var origin := Vector2i(5, 5)
	assert_not_null(meadow.place_building(BuildingTypes.SMALL_HOUSE, origin))
	assert_false(meadow.is_tillable(origin))


func test_using_soil_plants_a_crop_at_its_first_stage() -> void:
	_state.use_facing_tile()
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_facing_tile(), GameState.Use.PLANT)
	var crop := _world.object_at(_tile)
	assert_eq(crop.type, GameState.CROP)
	assert_eq(crop.growth_stage(), 0)


func test_a_crop_cannot_be_planted_on_grass() -> void:
	assert_false(_world.is_plantable(_tile))


func test_a_crop_cannot_be_planted_on_a_planted_tile() -> void:
	_till_and_plant()
	assert_false(_world.is_plantable(_tile))


func test_a_crop_does_not_block_walking() -> void:
	_till_and_plant()
	assert_true(_world.is_walkable(_tile))


func test_a_crop_grows_one_stage_per_day_to_ripe() -> void:
	_till_and_plant()
	var crop := _world.object_at(_tile)
	var stages: int = WorldObjectTypes.TYPES[GameState.CROP]["growth_stages"]
	for stage in range(1, stages):
		_sleep_days(1)
		assert_eq(crop.growth_stage(), stage)
	assert_true(crop.is_ripe())
	_sleep_days(3)
	assert_eq(crop.growth_stage(), stages - 1, "stops at the last stage")


func test_a_crop_in_an_unloaded_chunk_keeps_growing() -> void:
	_till_and_plant()
	var coords := Chunk.world_to_chunk(_tile)
	_world.remove_chunk(coords)
	_sleep_days(3)
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	assert_true(_world.object_at(_tile).is_ripe())


func test_an_unripe_crop_cannot_be_harvested() -> void:
	_till_and_plant()
	assert_eq(_state.use_facing_tile(), GameState.Use.NOTHING)
	assert_not_null(_world.object_at(_tile))
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP), 0)


func test_a_ripe_crop_is_harvested_and_the_soil_stays() -> void:
	_till_and_plant()
	_sleep_days(3)
	assert_eq(_state.use_facing_tile(), GameState.Use.HARVEST)
	assert_null(_world.object_at(_tile))
	assert_eq(_world.tile_at(_tile).terrain, Tile.Terrain.SOIL)
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP), 1)
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_facing_tile(), GameState.Use.PLANT, "the soil can be planted again")


func test_tilling_emits_tile_changed() -> void:
	watch_signals(_world)
	_state.use_facing_tile()
	assert_signal_emitted_with_parameters(_world, "tile_changed", [_tile])


func test_tilled_soil_survives_a_chunk_reload() -> void:
	_state.use_facing_tile()
	var coords := Chunk.world_to_chunk(_tile)
	_world.remove_chunk(coords)
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	assert_eq(_world.tile_at(_tile).terrain, Tile.Terrain.SOIL)


func test_growth_emits_objects_changed_for_loaded_crops() -> void:
	_till_and_plant()
	watch_signals(_world)
	_sleep_days(1)
	assert_signal_emitted_with_parameters(_world, "objects_changed", [_tile])
