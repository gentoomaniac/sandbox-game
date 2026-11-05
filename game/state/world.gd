class_name World
extends RefCounted
## The world: a seed, fixed bounds and the chunks that are currently loaded.
##
## The world is centred on the origin: with MAX_SIZE_CHUNKS = 64, chunk coordinates run
## from -32 to 31 on both axes, so world tile positions run from -1024 to 1023.

## An object was added or removed at this world tile position.
signal objects_changed(world_pos: Vector2i)

## The only place that defines the world size. Must be even so the world is centred.
const MAX_SIZE_CHUNKS := 64

var world_seed: int
var _chunks: Dictionary[Vector2i, Chunk] = {}
## What the player changed, kept outside the chunks so it survives their unloading: per world
## position the object that stands there now, or null where the generated object was
## removed. Together with the seed this is the whole world (the future save format).
var _object_edits: Dictionary[Vector2i, WorldObject] = {}


func _init(seed_value: int) -> void:
	world_seed = seed_value


static func is_chunk_in_bounds(chunk_coords: Vector2i) -> bool:
	var half := MAX_SIZE_CHUNKS / 2
	return (
		chunk_coords.x >= -half
		and chunk_coords.y >= -half
		and chunk_coords.x < half
		and chunk_coords.y < half
	)


static func is_in_bounds(world_pos: Vector2i) -> bool:
	return is_chunk_in_bounds(Chunk.world_to_chunk(world_pos))


## Adds (or replaces) a chunk, freshly generated, and applies the edits within its area on
## top. It must be inside the bounds. Replaying edits does not emit `objects_changed`: the
## caller draws the whole chunk anyway.
func add_chunk(chunk: Chunk) -> void:
	assert(is_chunk_in_bounds(chunk.coords), "Chunk out of bounds: %s" % chunk.coords)
	_chunks[chunk.coords] = chunk
	for pos in _object_edits:
		if Chunk.world_to_chunk(pos) != chunk.coords:
			continue
		chunk.remove_object(Chunk.local_pos(pos))
		if _object_edits[pos] != null:
			chunk.add_object(_object_edits[pos])


func remove_chunk(chunk_coords: Vector2i) -> void:
	_chunks.erase(chunk_coords)


func is_chunk_loaded(chunk_coords: Vector2i) -> bool:
	return _chunks.has(chunk_coords)


func loaded_chunk_coords() -> Array[Vector2i]:
	return _chunks.keys()


## The loaded chunk, or null if it is not loaded.
func chunk_at(chunk_coords: Vector2i) -> Chunk:
	return _chunks.get(chunk_coords)


## The tile at a world position, or null if it is out of bounds or its chunk is not loaded.
func tile_at(world_pos: Vector2i) -> Tile:
	# Out-of-bounds chunks can never be loaded (add_chunk asserts the bounds), so they
	# end up here as null too.
	var chunk := chunk_at(Chunk.world_to_chunk(world_pos))
	if chunk == null:
		return null
	return chunk.tile_at(Chunk.local_pos(world_pos))


## The object on a tile, or null if there is none (or the chunk is not loaded).
func object_at(world_pos: Vector2i) -> WorldObject:
	var chunk := chunk_at(Chunk.world_to_chunk(world_pos))
	if chunk == null:
		return null
	return chunk.object_at(Chunk.local_pos(world_pos))


## Puts an object on its tile. The chunk must be loaded and the tile free.
func add_object(object: WorldObject) -> void:
	var chunk := chunk_at(Chunk.world_to_chunk(object.pos))
	assert(chunk != null, "Chunk not loaded for object at %s" % object.pos)
	chunk.add_object(object)
	_object_edits[object.pos] = object
	objects_changed.emit(object.pos)


## Takes the object off a tile and returns it, or returns null if there was none.
func remove_object(world_pos: Vector2i) -> WorldObject:
	var chunk := chunk_at(Chunk.world_to_chunk(world_pos))
	if chunk == null:
		return null
	var object := chunk.remove_object(Chunk.local_pos(world_pos))
	if object != null:
		_object_edits[world_pos] = null
		objects_changed.emit(world_pos)
	return object


## Tile rules combined with the objects on the tile. False where there is no tile.
func is_walkable(world_pos: Vector2i) -> bool:
	var tile := tile_at(world_pos)
	if tile == null or not tile.is_walkable():
		return false
	var object := object_at(world_pos)
	return object == null or not object.blocks_walking()


func is_buildable(world_pos: Vector2i) -> bool:
	var tile := tile_at(world_pos)
	return tile != null and tile.is_buildable() and object_at(world_pos) == null


func is_plantable(world_pos: Vector2i) -> bool:
	var tile := tile_at(world_pos)
	return tile != null and tile.is_plantable() and object_at(world_pos) == null
