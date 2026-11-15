class_name NpcRoadCase
extends NpcCase
## What the tests of villagers on a road over chunks that are not loaded share (#68).
##
## The road: a row of grass one tile wide, walled by water, from the yard east for ROAD_LENGTH
## tiles. It is the only way, so where the villager is stuck it has no other. The chunks east of the
## yard's are not loaded.

const ROAD_LENGTH := 100

var _generator := WorldGenerator.new(SEED)
var _chunks_by_coords: Dictionary[Vector2i, Chunk] = {}


func before_each() -> void:
	super()
	_chunks_by_coords.clear()


func _road_tile(x: int) -> Vector2i:
	return _middle + Vector2i(x, 0)


func _centre_of(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


func _chunk(coords: Vector2i) -> Chunk:
	if not _chunks_by_coords.has(coords):
		_chunks_by_coords[coords] = _generator.generate_chunk(coords)
	return _chunks_by_coords[coords]


func _load(coords: Vector2i) -> void:
	if not _world.is_chunk_loaded(coords):
		_world.add_chunk(_chunk(coords))


## The chunk east of the yard's, the first of the road that is far.
func _first_far_chunk() -> Vector2i:
	return Chunk.world_to_chunk(_road_tile(YARD_RADIUS + 1)) + Vector2i.RIGHT


## Makes the road (the edits stay when the chunks are unloaded) and unloads every chunk east of the
## yard's.
func _build_road() -> void:
	# The road is a corridor with water to both sides and a water cap at its far end, so the only
	# way along it is the road: the open land has no ditches to hold a walker to it.
	for x in range(YARD_RADIUS + 1, ROAD_LENGTH + 2):
		for dy in [-1, 0, 1]:
			var tile := _road_tile(x) + Vector2i(0, dy)
			var chunk := Chunk.world_to_chunk(tile)
			for step in TravelMasks.SOURCE_STEPS:
				_load(chunk + step)
			_world.remove_object(tile)
			_world.set_terrain(
				tile, Tile.Terrain.GRASS if dy == 0 and x <= ROAD_LENGTH else Tile.Terrain.WATER
			)
	for coords in _world.loaded_chunk_coords():
		if coords.x >= _first_far_chunk().x:
			_world.remove_chunk(coords)


## Steps until `is_done` says so, at the time `minute` of the day. The masks are made on a worker in
## real time, so every step gives them a moment.
func _run_until(is_done: Callable, minute := NOON) -> bool:
	for _i in 8000:
		_step(minute)
		if is_done.call():
			return true
		OS.delay_usec(200)
	return false


func _is_loaded(tile: Vector2i) -> bool:
	return _world.is_chunk_loaded(Chunk.world_to_chunk(tile))


## A villager at the tile `from_x` of the road on a trip along it to `to_x`, its way found already
## (the tiles of the road between), as after a search at the time it left.
func _walker_on_road(from_x: int, to_x: int) -> Npc:
	var npc := _add_villager(_centre_of(_road_tile(from_x)), _yard_middle())
	_send_along_road(npc, from_x, to_x)
	return npc


## Puts `npc` at the tile `from_x` of the road and sends it on a trip along it to `to_x`.
func _send_along_road(npc: Npc, from_x: int, to_x: int) -> void:
	_npcs.cancel_trip(npc)
	npc.position = _centre_of(_road_tile(from_x))
	var trip := NpcTrip.new(_world, _road_tile(to_x))
	var step := signi(to_x - from_x)
	for x in range(from_x + step, to_x + step, step):
		trip.path.append(_road_tile(x))
	trip.state = NpcTrip.State.WALKING
	npc.trip = trip


## Has the masks of the whole road made, so that a walker meets none that is not there yet.
func _warm_road_masks() -> void:
	var masks: TravelMasks = _npcs._travel._masks_of(_world)
	for x in range(0, ROAD_LENGTH + 1, Chunk.CHUNK_SIZE / 2):
		masks.wait_for_mask(Chunk.world_to_chunk(_road_tile(x)))


## Lets `minutes` pass as a skip does: the clock moves to its end and the villagers catch up.
func _skip_minutes(minutes: int) -> void:
	_state.clock.minute_of_day += minutes
	_npcs.catch_up(_world, 1, minutes)
