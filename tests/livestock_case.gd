class_name LivestockCase
extends GutTest
## What the farm animal tests share: a game with a pen of grass ringed by water beside the
## camp, with a few stones in it and the player far off, and helpers to let time pass.

const SEED := 7
## The pen: a square of grass this many tiles to each side of its middle, ringed by water, with
## a few stones in it.
const PEN_RADIUS := 3
const STEP_SECONDS := 0.05
const DAY := 45
const NOON := 12 * 60
const MIDNIGHT := 0
## A test-only object type (see `_types_with_stile`).
const STILE := &"test_stile"

var _state: GameState
var _world: World
var _middle: Vector2i
var _livestock: Livestock


func before_each() -> void:
	_state = GameState.new_game(SEED)
	_world = _state.world
	_middle = _state.player.tile() + Vector2i(12, 0)
	for y in range(-PEN_RADIUS - 1, PEN_RADIUS + 2):
		for x in range(-PEN_RADIUS - 1, PEN_RADIUS + 2):
			var tile := _middle + Vector2i(x, y)
			_world.remove_object(tile)
			var is_inside := maxi(absi(x), absi(y)) <= PEN_RADIUS
			_world.set_terrain(tile, Tile.Terrain.GRASS if is_inside else Tile.Terrain.WATER)
	for stone in [Vector2i(1, 1), Vector2i(-2, 0), Vector2i(0, -2)]:
		_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _middle + stone))
	# Far from the pen, so that the rabbits take no notice unless a test brings them close.
	_state.player.position = Vector2(_middle) + Vector2(0.5, 30.5)
	_livestock = _state.livestock
	_livestock.rng.seed = SEED
	# The needs and the friendship of the animals count from the clock as the tests set it, not from
	# the game's start.
	_state.clock.day = DAY
	_state.clock.minute_of_day = NOON
	_livestock.account_clock(_state.clock)


func _pen_middle() -> Vector2:
	return Vector2(_middle) + Vector2(0.5, 0.5)


func _run(seconds: float, minute := NOON) -> void:
	for _step in int(seconds / STEP_SECONDS):
		_step(minute)


func _step(minute := NOON) -> void:
	_state.clock.day = DAY
	_state.clock.minute_of_day = minute
	_livestock.update(STEP_SECONDS, _world, _state.player.position, _state.clock)


## The object types and a stile: a stone the player walks over and the farm animals do not (see
## WorldObjectTypes `stops_animals`). A test puts them in WorldObjectTypes.TYPES, and the types it
## had back when it is done.
func _types_with_stile(types: Dictionary) -> Dictionary:
	var stile: Dictionary = types[WorldObjectTypes.STONE].duplicate()
	stile["blocks_walking"] = false
	stile["stops_animals"] = true
	var all_types := types.duplicate()
	all_types[STILE] = stile
	return all_types
