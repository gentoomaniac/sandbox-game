class_name Chunk
extends RefCounted
## A CHUNK_SIZE x CHUNK_SIZE square of tiles.
##
## Tiles are stored as parallel packed arrays (one per property) instead of one object per
## tile, so a large world stays small in memory. tile_at() returns a Tile snapshot;
## changes go through the set_* methods. The chunk also holds the world objects standing
## on its tiles, so they stream and unload with it.

const CHUNK_SIZE := 32

var coords: Vector2i
var _terrain := PackedByteArray()
var _frozen := PackedByteArray()
## At most one object per tile, keyed by local position.
var _objects: Dictionary[Vector2i, WorldObject] = {}


## A new chunk with every tile set to `terrain`, unfrozen.
func _init(chunk_coords: Vector2i, terrain := Tile.Terrain.GRASS) -> void:
	coords = chunk_coords
	var tile_count := CHUNK_SIZE * CHUNK_SIZE
	_terrain.resize(tile_count)
	_terrain.fill(terrain)
	_frozen.resize(tile_count)


## Chunk coordinates of the chunk containing a world tile position. Floors, so negative
## positions work.
static func world_to_chunk(world_pos: Vector2i) -> Vector2i:
	return (world_pos - local_pos(world_pos)) / CHUNK_SIZE


## Position of a world tile inside its chunk, 0..CHUNK_SIZE-1 on both axes.
static func local_pos(world_pos: Vector2i) -> Vector2i:
	return Vector2i(posmod(world_pos.x, CHUNK_SIZE), posmod(world_pos.y, CHUNK_SIZE))


## World tile position of a tile given by its chunk and local position.
static func to_world(chunk_coords: Vector2i, local: Vector2i) -> Vector2i:
	return chunk_coords * CHUNK_SIZE + local


static func is_local_in_range(local: Vector2i) -> bool:
	return local.x >= 0 and local.y >= 0 and local.x < CHUNK_SIZE and local.y < CHUNK_SIZE


func tile_at(local: Vector2i) -> Tile:
	var index := _index(local)
	var tile := Tile.new()
	tile.terrain = _terrain[index] as Tile.Terrain
	tile.frozen = _frozen[index] == 1
	return tile


## Direct read accessors: unlike tile_at() they allocate nothing, for hot loops such as
## rendering.
func terrain_at(local: Vector2i) -> Tile.Terrain:
	return _terrain[_index(local)] as Tile.Terrain


func is_frozen_at(local: Vector2i) -> bool:
	return _frozen[_index(local)] == 1


func set_terrain(local: Vector2i, terrain: Tile.Terrain) -> void:
	_terrain[_index(local)] = terrain


func set_frozen(local: Vector2i, frozen: bool) -> void:
	_frozen[_index(local)] = 1 if frozen else 0


## The object on a tile, or null.
func object_at(local: Vector2i) -> WorldObject:
	return _objects.get(local)


## Puts an object on its tile. The tile must be free.
func add_object(object: WorldObject) -> void:
	var local := Chunk.local_pos(object.pos)
	assert(Chunk.world_to_chunk(object.pos) == coords, "Object outside chunk: %s" % object.pos)
	assert(not _objects.has(local), "Tile already has an object: %s" % object.pos)
	_objects[local] = object


## Takes the object off a tile and returns it, or returns null if there was none.
func remove_object(local: Vector2i) -> WorldObject:
	var object := _objects.get(local) as WorldObject
	_objects.erase(local)
	return object


func objects() -> Array[WorldObject]:
	return _objects.values()


func _index(local: Vector2i) -> int:
	assert(is_local_in_range(local), "Local tile position out of range: %s" % local)
	return local.y * CHUNK_SIZE + local.x
