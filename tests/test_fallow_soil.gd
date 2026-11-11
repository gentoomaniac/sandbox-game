extends GutTest
## Tilled soil that nobody tends comes up in weeds and then grows over to grass, night by night
## (task 166). Working it starts the count anew, and a planted tile never grows over.

const SEED := 7
## Tiles around the camp: grass most likely, checked by `_grass_tile`.
const SEARCH := 6

var _state: GameState
var _world: World
var _fallow: FallowSoil
var _tile: Vector2i


func before_each() -> void:
	_state = GameState.new_game(SEED)
	_world = _state.world
	_fallow = _world.fallow
	_tile = _grass_tile()
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5) - Vector2(0, 1)
	_state.player.facing = Vector2i.DOWN
	_hold(ItemTypes.HOE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.TILL)


func _grass_tile() -> Vector2i:
	var center := _state.player.tile()
	for y in range(-SEARCH, SEARCH):
		for x in range(-SEARCH, SEARCH):
			var pos := center + Vector2i(x, y + 1)
			if (
				_world.is_free_on(pos, Tile.Terrain.GRASS)
				and _world.is_free_on(pos - Vector2i(0, 1), Tile.Terrain.GRASS)
			):
				return pos
	fail_test("no grass near the camp")
	return center


func _hold(item: StringName) -> void:
	HotbarHold.hold(_state.player.inventory, item)


## Lets `count` midnights pass (the game starts in spring, whose days count).
func _pass_nights(count: int) -> void:
	for _night in count:
		_state.simulation.advance(_state.clock.minutes_until(0))


func _terrain() -> Tile.Terrain:
	return _world.tile_at(_tile).terrain


func test_untended_soil_comes_up_in_weeds_after_its_days() -> void:
	_pass_nights(_fallow.weedy_days - 1)
	assert_false(_fallow.is_weedy(_tile), "a day short")
	_pass_nights(1)
	assert_true(_fallow.is_weedy(_tile))
	assert_true(_world.is_tilled(_tile), "weedy soil is still soil")


func test_untended_soil_is_grass_again_after_its_days() -> void:
	_pass_nights(_fallow.grass_days - 1)
	assert_eq(_terrain(), Tile.Terrain.SOIL, "a day short")
	_pass_nights(1)
	assert_eq(_terrain(), Tile.Terrain.GRASS)
	assert_false(_world.is_tilled(_tile))
	assert_false(_fallow.is_weedy(_tile))
	assert_false(_world.soil.tiles().has(_tile), "no moisture kept for it")


func test_a_tilled_path_grows_back_to_unworn_grass() -> void:
	_hold(ItemTypes.NONE)
	var path := _tile + Vector2i.RIGHT
	for _step in PathRules.default_rules().path_from():
		_world.wear_tile(path)
	_world.set_terrain(path, Tile.Terrain.SOIL)
	_pass_nights(_fallow.grass_days)
	assert_eq(_world.tile_at(path).terrain, Tile.Terrain.GRASS)
	assert_eq(_world.wear_stage(path), PathRules.Stage.UNWORN)


func test_soil_in_a_chunk_that_is_not_loaded_grows_over_too() -> void:
	var coords := Chunk.world_to_chunk(_tile)
	_world.remove_chunk(coords)
	_pass_nights(_fallow.grass_days)
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	assert_eq(_terrain(), Tile.Terrain.GRASS)
	assert_false(_world.is_tilled(_tile))


func test_what_lies_on_it_stays() -> void:
	var piles := _world.drop_items(_tile, {ItemTypes.TURNIP_SEEDS: 3})
	_pass_nights(_fallow.grass_days)
	assert_eq(_terrain(), Tile.Terrain.GRASS)
	assert_eq(_world.ground_items.all(), piles)


func test_hoeing_the_weeds_away_starts_the_count_anew() -> void:
	_pass_nights(_fallow.weedy_days)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.TILL, "the hoe works on weedy soil")
	assert_false(_fallow.is_weedy(_tile))
	_pass_nights(_fallow.weedy_days - 1)
	assert_false(_fallow.is_weedy(_tile))
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING, "nothing to hoe on clean soil")


func test_watering_starts_the_count_anew() -> void:
	_pass_nights(_fallow.grass_days - 1)
	_world.set_moisture(_tile, 1.0)
	assert_false(_fallow.is_weedy(_tile), "the weeds went with the watering")
	_pass_nights(_fallow.grass_days - 1)
	assert_eq(_terrain(), Tile.Terrain.SOIL)


func test_sowing_and_clearing_start_the_count_anew() -> void:
	_pass_nights(_fallow.weedy_days)
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLANT)
	assert_false(_fallow.is_weedy(_tile), "sown over")
	_pass_nights(_fallow.weedy_days)
	_world.remove_object(_tile)
	_pass_nights(_fallow.weedy_days - 1)
	assert_false(_fallow.is_weedy(_tile), "counted from the clearing")


func test_a_planted_tile_never_grows_over() -> void:
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLANT)
	# Long enough for the turnip to ripen, wither and lie dead.
	_pass_nights(3 * _fallow.grass_days)
	assert_eq(_terrain(), Tile.Terrain.SOIL)
	assert_false(_fallow.is_weedy(_tile))
	assert_not_null(_world.object_at(_tile))


func test_the_look_changes_when_the_weeds_come_up_and_when_they_go() -> void:
	watch_signals(_world)
	_pass_nights(_fallow.weedy_days)
	assert_signal_emitted_with_parameters(_world, "tile_changed", [_tile])
	_world.set_moisture(_tile, 1.0)
	assert_signal_emit_count(_world, "tile_changed", 2, "the weeds came up, then went")


func test_the_nights_of_winter_do_not_count_when_the_soil_rests_then() -> void:
	var fallow := FallowSoil.new()
	var first_winter_day := 3 * GameClock.DAYS_PER_SEASON + 1
	fallow.rests_in_winter = true
	fallow.count_night(first_winter_day)
	fallow.count_night(first_winter_day + GameClock.DAYS_PER_SEASON - 1)
	assert_eq(fallow.nights, 0)
	fallow.count_night(first_winter_day - 1)
	fallow.count_night(first_winter_day + GameClock.DAYS_PER_SEASON)
	assert_eq(fallow.nights, 2, "autumn's last night and spring's first")
	fallow.rests_in_winter = false
	fallow.count_night(first_winter_day)
	assert_eq(fallow.nights, 3)
