class_name Exploration
extends RefCounted
## The land the player has seen, per tile: every tile within SIGHT_RADIUS of where they stood is
## explored for good. The world map lies a fog over what is not (see MapFog).
##
## Per tile, not per chunk, so that the fog clears as the player walks and its edge follows their
## sight instead of the 32 tile grid. Each chunk the player has seen anything of keeps one bit a
## tile (128 bytes), so a world explored from edge to edge stays under a megabyte of save.

## How far the player sees, in tiles: the land about them is explored.
const SIGHT_RADIUS := 12
const BYTES_PER_CHUNK := Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE / 8

## The bits of each chunk, a tile to a bit: index `local.y * CHUNK_SIZE + local.x`.
var _seen_by_chunk: Dictionary[Vector2i, PackedByteArray] = {}
## What `see` saw last, so that standing still costs nothing.
var _last_tile := Vector2i(World.MAX_SIZE_CHUNKS * Chunk.CHUNK_SIZE, 0)


## The player stands on `tile` of the world: the land within sight is explored.
func see(tile: Vector2i) -> void:
	if tile == _last_tile:
		return
	_last_tile = tile
	var radius_squared := SIGHT_RADIUS * SIGHT_RADIUS
	for offset_y in range(-SIGHT_RADIUS, SIGHT_RADIUS + 1):
		for offset_x in range(-SIGHT_RADIUS, SIGHT_RADIUS + 1):
			if offset_x * offset_x + offset_y * offset_y <= radius_squared:
				_mark(tile + Vector2i(offset_x, offset_y))


func is_explored(tile: Vector2i) -> bool:
	var seen: PackedByteArray = _seen_by_chunk.get(Chunk.world_to_chunk(tile), PackedByteArray())
	if seen.is_empty():
		return false
	var bit := _bit_of(Chunk.local_pos(tile))
	return seen[bit >> 3] & (1 << (bit & 7)) != 0


## Whether the player has seen anything of a chunk.
func is_chunk_touched(coords: Vector2i) -> bool:
	return _seen_by_chunk.has(coords)


## A copy of the bits of every chunk, for `array_of` (see GameState `snapshot`).
func snapshot() -> Dictionary:
	return _seen_by_chunk.duplicate(true)


## The save entries of a `snapshot`: `{"chunk": [x, y], "seen": <the bits in base64>}`. Safe to
## call from a thread.
static func array_of(seen_by_chunk: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for coords: Vector2i in seen_by_chunk:
		var seen: PackedByteArray = seen_by_chunk[coords]
		entries.append(
			{"chunk": SaveCodec.vector_to_json(coords), "seen": Marshalls.raw_to_base64(seen)}
		)
	return entries


## Takes the saved entries of `array_of`.
func load_array(entries: Array) -> void:
	for entry: Dictionary in entries:
		var coords := SaveCodec.vector_from_json(entry["chunk"])
		_seen_by_chunk[coords] = Marshalls.base64_to_raw(entry["seen"])


func _mark(tile: Vector2i) -> void:
	var coords := Chunk.world_to_chunk(tile)
	if not World.is_chunk_in_bounds(coords):
		return
	if not _seen_by_chunk.has(coords):
		var empty := PackedByteArray()
		empty.resize(BYTES_PER_CHUNK)
		_seen_by_chunk[coords] = empty
	var bit := _bit_of(Chunk.local_pos(tile))
	_seen_by_chunk[coords][bit >> 3] |= 1 << (bit & 7)


static func _bit_of(local: Vector2i) -> int:
	return local.y * Chunk.CHUNK_SIZE + local.x
