extends GutTest
## Villagers wear the grass they walk onto, like the player and the farm animals do (see
## PathRules.villager_step): outdoors only, on or off screen, and it grows back when they stop.

const STEP_SECONDS := 0.05
const DAY := 45
const NOON := 12 * 60
const MIDNIGHT := 0

var _state: GameState
var _world: World
var _npcs: Npcs
var _start: Vector2i
var _step_of_wear := PathRules.default_rules().villager_step()


func before_each() -> void:
	_state = GameState.new_game(7)
	_world = _state.world
	_npcs = _state.npcs
	_start = _state.player.tile() + Vector2i(30, 0)
	var generator := WorldGenerator.new(7)
	for y in range(-3, 4):
		for x in range(-3, 14):
			var tile := _start + Vector2i(x, y)
			var chunk := Chunk.world_to_chunk(tile)
			if not _world.is_chunk_loaded(chunk):
				_world.add_chunk(generator.generate_chunk(chunk))
			_world.remove_object(tile)
			_world.set_terrain(tile, Tile.Terrain.GRASS)
	_state.player.position = Vector2(_start) + Vector2(0.5, 40.5)


func _wear_of(tile: Vector2i) -> float:
	for entry: Array in _world.to_dict()["wear"]:
		if Vector2i(entry[0], entry[1]) == tile:
			return entry[2]
	return 0.0


## Lets a villager walk to the right from `_start` for `seconds` at the given time of day.
func _walk_right(minute: int, seconds := 1.0) -> Npc:
	var npc := Npc.create(7, Vector2(_start) + Vector2(0.5, 0.5), _npcs.rules)
	npc.anchor = npc.position
	npc.activity = Npc.Activity.WALK
	npc.heading = Vector2.RIGHT
	npc.seconds_left = seconds + 1.0
	_npcs.add(npc)
	_state.clock.day = DAY
	_state.clock.minute_of_day = minute
	for _step_index in int(seconds / STEP_SECONDS):
		_npcs.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
	return npc


func test_each_tile_a_villager_steps_onto_takes_its_step() -> void:
	var npc := _walk_right(NOON)
	var entered := npc.tile().x - _start.x
	assert_gt(entered, 0, "it walked on")
	for x in range(1, entered + 1):
		assert_eq(_wear_of(_start + Vector2i(x, 0)), _step_of_wear, "tile %d" % x)
	assert_eq(_wear_of(_start), 0.0, "the tile it started on")


func test_a_villager_walking_in_place_wears_nothing() -> void:
	var npc := _walk_right(NOON, 0.1)
	assert_eq(npc.tile(), _start)
	assert_eq(_world.to_dict()["wear"], [])


func test_villagers_resting_at_night_wear_nothing() -> void:
	_walk_right(MIDNIGHT)
	assert_eq(_world.to_dict()["wear"], [])


func test_a_second_walk_over_the_same_tiles_adds_another_step() -> void:
	var npc := _walk_right(NOON)
	var tile := npc.tile() - Vector2i.RIGHT
	npc.position = Vector2(_start) + Vector2(0.5, 0.5)
	npc.heading = Vector2.RIGHT
	npc.seconds_left = 2.0
	for _step_index in int(1.0 / STEP_SECONDS):
		_npcs.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
	assert_eq(_wear_of(tile), 2.0 * _step_of_wear)


func test_the_wear_of_villagers_grows_back_like_any_other() -> void:
	var npc := _walk_right(NOON)
	var tile := npc.tile() - Vector2i.RIGHT
	_world.regrow_paths()
	assert_eq(_wear_of(tile), 0.0, "half a step is less than a night takes off")
