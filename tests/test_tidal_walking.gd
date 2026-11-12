extends GutTest
## Tidal mud under water can't be walked on, like the sea; the player who stands in it can wade
## on, so the rising tide cuts no one off from the shore. Nothing is placed, built, dropped or
## tilled on it.

const SEED := 7
## Day 1 at 00:00 is high water; low water is 6 hours 12 minutes later.
const HIGH_WATER_MINUTE := 0
const LOW_WATER_MINUTE := 373
const FRAME := 1.0 / 60.0

var _state: GameState
var _world: World
## A tile of mud that the tide covers at high water and leaves dry at low water, with grass to its
## west and mud all round it otherwise.
var _mud_tile: Vector2i


func before_each() -> void:
	_state = GameState.new_game(SEED)
	_world = _state.world
	var origin := _state.player.tile() + Vector2i(40, 0)
	var generator := WorldGenerator.new(SEED)
	for y in range(-4, 5):
		for x in range(-4, 12):
			var tile := origin + Vector2i(x, y)
			var chunk := Chunk.world_to_chunk(tile)
			if not _world.is_chunk_loaded(chunk):
				_world.add_chunk(generator.generate_chunk(chunk))
			_world.remove_object(tile)
			_world.set_terrain(tile, Tile.Terrain.MUD)
	for x in range(1, 12):
		var tile := origin + Vector2i(x, 0)
		if not Tide.floods(tile, 0.0) and Tide.floods(tile, 1.0):
			_mud_tile = tile
			break
	assert_ne(_mud_tile, Vector2i.ZERO, "mud that floods and dries")
	for y in range(-1, 2):
		_world.set_terrain(_mud_tile + Vector2i(-1, y), Tile.Terrain.GRASS)
	_set_tide(HIGH_WATER_MINUTE)


func _set_tide(minute: int) -> void:
	_state.clock.day = 1
	_state.clock.minute_of_day = minute


func _stand_on(tile: Vector2i) -> void:
	_state.player.position = Vector2(tile) + Vector2(0.5, 0.5)


func _walk_east(seconds: float) -> void:
	for _frame in int(seconds / FRAME):
		_state.walk(Vector2.RIGHT, FRAME)


func _walk_west(seconds: float) -> void:
	for _frame in int(seconds / FRAME):
		_state.walk(Vector2.LEFT, FRAME)


func test_the_mud_is_walkable_at_low_water_and_not_at_high_water() -> void:
	_set_tide(LOW_WATER_MINUTE)
	assert_false(_world.is_flooded(_mud_tile))
	assert_true(_world.is_walkable(_mud_tile))
	_set_tide(HIGH_WATER_MINUTE)
	assert_true(_world.is_flooded(_mud_tile))
	assert_false(_world.is_walkable(_mud_tile))
	assert_false(_world.is_ground_walkable(_mud_tile))


func test_only_mud_floods() -> void:
	_set_tide(HIGH_WATER_MINUTE)
	assert_false(_world.is_flooded(_mud_tile + Vector2i.LEFT), "grass")
	assert_true(_world.is_walkable(_mud_tile + Vector2i.LEFT))


func test_the_player_cannot_step_from_dry_ground_onto_flooded_mud() -> void:
	_set_tide(HIGH_WATER_MINUTE)
	_stand_on(_mud_tile + Vector2i(-1, 0))
	_walk_east(1.5)
	assert_lt(_state.player.position.x, float(_mud_tile.x), "stopped at the water's edge")


func test_the_player_walks_out_onto_the_mud_at_low_water() -> void:
	_set_tide(LOW_WATER_MINUTE)
	_stand_on(_mud_tile + Vector2i(-1, 0))
	_walk_east(1.5)
	assert_gt(_state.player.position.x, float(_mud_tile.x) + 0.5)


func test_the_player_who_stands_in_the_water_can_walk_off_it() -> void:
	_set_tide(LOW_WATER_MINUTE)
	_stand_on(_mud_tile)
	_set_tide(HIGH_WATER_MINUTE)
	_walk_west(2.0)
	assert_lt(_state.player.position.x, float(_mud_tile.x) - 0.5, "back on the grass")
	assert_false(_world.is_flooded(_state.player.tile()))


func test_the_player_who_stands_in_the_water_can_wade_on_over_flooded_mud() -> void:
	_set_tide(HIGH_WATER_MINUTE)
	_stand_on(_mud_tile)
	_walk_east(1.0)
	assert_gt(_state.player.position.x, float(_mud_tile.x) + 1.0)


func test_nothing_is_dropped_on_flooded_mud() -> void:
	_set_tide(LOW_WATER_MINUTE)
	assert_true(_world.can_hold_pile(_mud_tile))
	_set_tide(HIGH_WATER_MINUTE)
	assert_false(_world.can_hold_pile(_mud_tile))
	var piles := _world.drop_items(_mud_tile, {ItemTypes.STONE: 1})
	assert_ne(piles[0].position, Vector2(_mud_tile) + Vector2(0.5, 0.5))


func test_nothing_is_built_planted_or_tilled_on_mud() -> void:
	_set_tide(HIGH_WATER_MINUTE)
	assert_false(_world.is_placeable(_mud_tile))
	assert_false(_world.is_buildable(_mud_tile))
	assert_false(_world.placement_blockers(BuildingTypes.KATE, _mud_tile).is_empty())
	_stand_on(_mud_tile + Vector2i(-1, 0))
	_state.player.facing = Vector2i.RIGHT
	HotbarHold.hold(_state.player.inventory, ItemTypes.HOE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)
	assert_eq(_world.tile_at(_mud_tile).terrain, Tile.Terrain.MUD)
