class_name NpcCase
extends GutTest
## What the villager tests share: a yard of grass ringed by water, with a few stones in it and the
## player far off, and helpers to let time pass.

const SEED := 7
## The yard: a square of grass this many tiles to each side of its middle, ringed by water, with
## a few stones in it. Wider than the anchor's reach, so that only the anchor keeps them in.
const YARD_RADIUS := 9
const STEP_SECONDS := 0.05
const DAY := 45
const NOON := 12 * 60
const MIDNIGHT := 0

var _state: GameState
var _world: World
var _middle: Vector2i
var _npcs: Npcs


func before_each() -> void:
	_state = GameState.new_game(SEED)
	_world = _state.world
	_middle = _state.player.tile() + Vector2i(30, 0)
	var generator := WorldGenerator.new(SEED)
	for y in range(-YARD_RADIUS - 1, YARD_RADIUS + 2):
		for x in range(-YARD_RADIUS - 1, YARD_RADIUS + 2):
			var tile := _middle + Vector2i(x, y)
			var chunk := Chunk.world_to_chunk(tile)
			if not _world.is_chunk_loaded(chunk):
				_world.add_chunk(generator.generate_chunk(chunk))
			_world.remove_object(tile)
			var is_inside := maxi(absi(x), absi(y)) <= YARD_RADIUS
			_world.set_terrain(tile, Tile.Terrain.GRASS if is_inside else Tile.Terrain.WATER)
	for stone in [Vector2i(1, 1), Vector2i(-2, 0), Vector2i(0, -2), Vector2i(4, 3)]:
		_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _middle + stone))
	# Far from the yard, so the villagers have no player to stop short of.
	_state.player.position = Vector2(_middle) + Vector2(0.5, 40.5)
	_npcs = _state.npcs
	_npcs.rng.seed = SEED


func _yard_middle() -> Vector2:
	return Vector2(_middle) + Vector2(0.5, 0.5)


## A villager standing at `feet` and keeping near `anchor`.
func _add_villager(feet: Vector2, anchor: Vector2) -> Npc:
	var npc := Npc.create(SEED, feet, _npcs.rules)
	npc.anchor = anchor
	_npcs.add(npc)
	return npc


func _step(minute := NOON) -> void:
	_state.clock.day = DAY
	_state.clock.minute_of_day = minute
	_npcs.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
