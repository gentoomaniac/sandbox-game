class_name Chunk
extends RefCounted
## A CHUNK_SIZE x CHUNK_SIZE square of tiles.
##
## Tiles are stored as parallel packed arrays (one per property) instead of one object per
## tile, so a large world stays small in memory. tile_at() returns a Tile snapshot;
## changes go through the set_* methods.

const CHUNK_SIZE := 32

var coords: Vector2i
var _terrain := PackedByteArray()
var _water_level := PackedFloat32Array()
var _frozen := PackedByteArray()
var _snow_depth := PackedFloat32Array()


## A new chunk with every tile set to `terrain`, dry and unfrozen.
func _init(chunk_coords: Vector2i, terrain := Tile.Terrain.GRASS) -> void:
	coords = chunk_coords
	var tile_count := CHUNK_SIZE * CHUNK_SIZE
	_terrain.resize(tile_count)
	_terrain.fill(terrain)
	_water_level.resize(tile_count)
	_frozen.resize(tile_count)
	_snow_depth.resize(tile_count)


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
	tile.water_level = _water_level[index]
	tile.frozen = _frozen[index] == 1
	tile.snow_depth = _snow_depth[index]
	return tile


func set_terrain(local: Vector2i, terrain: Tile.Terrain) -> void:
	_terrain[_index(local)] = terrain


func set_water_level(local: Vector2i, water_level: float) -> void:
	_water_level[_index(local)] = water_level


func set_frozen(local: Vector2i, frozen: bool) -> void:
	_frozen[_index(local)] = 1 if frozen else 0


func set_snow_depth(local: Vector2i, snow_depth: float) -> void:
	_snow_depth[_index(local)] = snow_depth


func _index(local: Vector2i) -> int:
	assert(is_local_in_range(local), "Local tile position out of range: %s" % local)
	return local.y * CHUNK_SIZE + local.x
