class_name World
extends GameMap
## The world: a seed, fixed bounds and the chunks that are currently loaded.
##
## The world is centred on the origin: with MAX_SIZE_CHUNKS = 64, chunk coordinates run
## from -32 to 31 on both axes, so world tile positions run from -1024 to 1023.

## An object was added or removed at this world tile position.
signal objects_changed(world_pos: Vector2i)
## A tile's terrain was changed (see `set_terrain`).
signal tile_changed(world_pos: Vector2i)
## A building was placed.
signal building_placed(building: Building)

## Why a footprint tile can't be built on.
enum Blocked {
	## Water, wetland or floodplain, or the tile is not loaded.
	TERRAIN,
	## A world object or a building is on it.
	OCCUPIED,
}

## The only place that defines the world size. Must be even so the world is centred.
const MAX_SIZE_CHUNKS := 64

var world_seed: int
var _chunks: Dictionary[Vector2i, Chunk] = {}
## What the player changed, kept outside the chunks so it survives their unloading: per world
## position the object that stands there now, or null where the generated object was
## removed. Together with the seed this is the whole world (the future save format).
var _object_edits: Dictionary[Vector2i, WorldObject] = {}
## Terrain the player changed (e.g. grass tilled to soil), by world position. Replayed on
## chunks before the objects, which may depend on the ground.
var _terrain_edits: Dictionary[Vector2i, Tile.Terrain] = {}
## Buildings are the player's work and must outlive the chunks they stand on, and one can
## cross a chunk border, so they live here and not in chunks.
var _buildings: Array[Building] = []
var _building_by_tile: Dictionary[Vector2i, Building] = {}


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
## top. It must be inside the bounds. Replaying edits does not emit change signals: the
## caller draws the whole chunk anyway.
func add_chunk(chunk: Chunk) -> void:
	assert(is_chunk_in_bounds(chunk.coords), "Chunk out of bounds: %s" % chunk.coords)
	_chunks[chunk.coords] = chunk
	for pos in _terrain_edits:
		if Chunk.world_to_chunk(pos) == chunk.coords:
			chunk.set_terrain(Chunk.local_pos(pos), _terrain_edits[pos])
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


## Changes the terrain of a loaded tile and remembers it as an edit, so it survives the
## chunk unloading.
func set_terrain(world_pos: Vector2i, terrain: Tile.Terrain) -> void:
	var chunk := chunk_at(Chunk.world_to_chunk(world_pos))
	assert(chunk != null, "Chunk not loaded for tile at %s" % world_pos)
	chunk.set_terrain(Chunk.local_pos(world_pos), terrain)
	_terrain_edits[world_pos] = terrain
	tile_changed.emit(world_pos)


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


## Advances every crop by one day, those in unloaded chunks too: crops are always edits, so
## they are all in `_object_edits`.
func grow_crops() -> void:
	for pos in _object_edits:
		var object := _object_edits[pos]
		if object == null or not object.is_crop():
			continue
		object.grow_one_day()
		# Unloaded tiles have nothing to redraw; they are drawn when their chunk loads.
		if is_chunk_loaded(Chunk.world_to_chunk(pos)):
			objects_changed.emit(pos)


## Tile and object rules, and buildings: only their door can be walked on.
func is_walkable(world_pos: Vector2i) -> bool:
	if not super(world_pos):
		return false
	var building := building_at(world_pos)
	return building == null or building.door_tile() == world_pos


## Must agree with placement_blockers: a tile is buildable if it would not block a building.
func is_buildable(world_pos: Vector2i) -> bool:
	var tile := tile_at(world_pos)
	return (
		tile != null
		and tile.is_buildable()
		and object_at(world_pos) == null
		and building_at(world_pos) == null
	)


func is_tillable(world_pos: Vector2i) -> bool:
	var tile := tile_at(world_pos)
	return (
		tile != null
		and tile.is_tillable()
		and object_at(world_pos) == null
		and building_at(world_pos) == null
	)


func is_plantable(world_pos: Vector2i) -> bool:
	var tile := tile_at(world_pos)
	return (
		tile != null
		and tile.is_plantable()
		and object_at(world_pos) == null
		and building_at(world_pos) == null
	)


# --- Buildings ---


func buildings() -> Array[Building]:
	return _buildings.duplicate()


## The building whose footprint covers a tile, or null.
func building_at(world_pos: Vector2i) -> Building:
	return _building_by_tile.get(world_pos)


## The footprint tiles that stop a building from being placed, with the reason for each.
## Empty if it can be placed. Must agree with is_buildable.
func placement_blockers(
	building_type: StringName, origin: Vector2i
) -> Dictionary[Vector2i, Blocked]:
	var blockers: Dictionary[Vector2i, Blocked] = {}
	for pos in Building.footprint_tiles(building_type, origin):
		var tile := tile_at(pos)
		if tile == null or not tile.is_buildable():
			blockers[pos] = Blocked.TERRAIN
		elif object_at(pos) != null or building_at(pos) != null:
			blockers[pos] = Blocked.OCCUPIED
	# The player has to be able to stand in front of the door, to go in and to come out.
	var door_offset: Vector2i = BuildingTypes.TYPES[building_type]["door_offset"]
	var front := origin + door_offset + Vector2i.DOWN
	if not is_walkable(front):
		var is_blocked_by_thing := tile_at(front) != null and tile_at(front).is_walkable()
		blockers[front] = Blocked.OCCUPIED if is_blocked_by_thing else Blocked.TERRAIN
	return blockers


## Places a building and returns it, or returns null if any footprint tile is blocked.
func place_building(building_type: StringName, origin: Vector2i) -> Building:
	if not placement_blockers(building_type, origin).is_empty():
		return null
	var building := Building.new(building_type, origin)
	_buildings.append(building)
	for pos in building.tiles():
		_building_by_tile[pos] = building
	building_placed.emit(building)
	return building
