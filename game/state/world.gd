# gdlint: disable=max-public-methods
# (World is the one entry point for map changes; splitting off the object edits is a
# TASKS.md follow-up.)
class_name World
extends GameMap
## The world: a seed, fixed bounds and the chunks that are currently loaded.
##
## The world is centred on the origin: with MAX_SIZE_CHUNKS = 64, chunk coordinates run
## from -32 to 31 on both axes, so world tile positions run from -1024 to 1023.

## An object was added or removed at this world tile position: one signal for each tile it
## covers.
signal objects_changed(world_pos: Vector2i)
## A tile's terrain was changed (see `set_terrain`).
signal tile_changed(world_pos: Vector2i)
## A tool hit an object that is still standing (see `hit_object`).
signal object_hit(object: WorldObject)
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
## The game's clock: what the seasonal plants follow (see `is_dormant`). Whoever owns the
## clock shares it here.
var clock := GameClock.new()
var vegetation := Vegetation.default_vegetation()
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


## The object that covers a tile (see WorldObject.tiles), or null if there is none, the chunk
## is not loaded or the object is dormant (see `is_dormant`): a dormant plant is not there for
## anything that walks, builds, targets or draws.
func object_at(world_pos: Vector2i) -> WorldObject:
	var object := _stored_object_at(world_pos)
	return null if object != null and is_dormant(object) else object


## Whether a seasonal plant is dormant: it is out of its season, by the vegetation curve of its
## type and its own threshold. The one rule that the view, walking, building and targeting
## share. Nothing about it is saved.
func is_dormant(object: WorldObject) -> bool:
	return (
		object.type_data().get("seasonal") == WorldObjectTypes.DORMANCY
		and not vegetation.is_present(object.type, world_seed, object.pos, clock.day)
	)


## Whether a plant that bears fruit has none now: its season is over or has not begun. Picked
## or not, it then looks picked and can't be picked.
func is_bare(object: WorldObject) -> bool:
	return (
		object.type_data().get("seasonal") == WorldObjectTypes.FRUIT
		and not vegetation.is_present(object.type, world_seed, object.pos, clock.day)
	)


## Like `object_at`, but dormant plants are seen too. A big object is stored at its own tile
## only, so look back from the tile over the largest footprint: in its own chunk, and only
## near the chunk's top and left border in the neighbours. A big object whose own chunk is not
## loaded is not seen; that is safe because the player only acts on tiles well inside the
## loaded area (see WorldView.LOAD_RADIUS and UNLOAD_RADIUS).
func _stored_object_at(world_pos: Vector2i) -> WorldObject:
	var own_chunk := chunk_at(Chunk.world_to_chunk(world_pos))
	var local := Chunk.local_pos(world_pos)
	for y in WorldObjectTypes.MAX_FOOTPRINT.y:
		for x in WorldObjectTypes.MAX_FOOTPRINT.x:
			var origin_local := local - Vector2i(x, y)
			var chunk := own_chunk
			if not Chunk.is_local_in_range(origin_local):
				chunk = chunk_at(Chunk.world_to_chunk(world_pos - Vector2i(x, y)))
			if chunk == null:
				continue
			var object := chunk.object_at(Chunk.local_pos(world_pos - Vector2i(x, y)))
			if object != null and object.covers(world_pos):
				return object
	return null


## Changes the terrain of a loaded tile and remembers it as an edit, so it survives the
## chunk unloading. A dormant plant on the tile is gone for good.
func set_terrain(world_pos: Vector2i, terrain: Tile.Terrain) -> void:
	var chunk := chunk_at(Chunk.world_to_chunk(world_pos))
	assert(chunk != null, "Chunk not loaded for tile at %s" % world_pos)
	_clear_dormant(world_pos)
	chunk.set_terrain(Chunk.local_pos(world_pos), terrain)
	_terrain_edits[world_pos] = terrain
	tile_changed.emit(world_pos)


## Puts an object on its tiles. The chunk of its own tile must be loaded and its tiles free,
## except for dormant plants, which are gone for good.
func add_object(object: WorldObject) -> void:
	var chunk := chunk_at(Chunk.world_to_chunk(object.pos))
	assert(chunk != null, "Chunk not loaded for object at %s" % object.pos)
	for tile in object.tiles():
		_clear_dormant(tile)
	assert(
		object.tiles().all(func(tile: Vector2i) -> bool: return object_at(tile) == null),
		"Tiles already have an object: %s" % object.pos
	)
	chunk.add_object(object)
	_object_edits[object.pos] = object
	for tile in object.tiles():
		objects_changed.emit(tile)


## Takes the object that covers a tile off the world and returns it, or returns null if there
## was none.
func remove_object(world_pos: Vector2i) -> WorldObject:
	var object := object_at(world_pos)
	if object != null:
		_take_off(object)
	return object


## Puts `replacement` where `old` stands. Works for objects in unloaded chunks too: they are
## edits, so the replacement is drawn when the chunk loads.
func replace_object(old: WorldObject, replacement: WorldObject) -> void:
	assert(old.pos == replacement.pos and old.tiles() == replacement.tiles(), "Not in place")
	var chunk := chunk_at(Chunk.world_to_chunk(old.pos))
	if chunk != null:
		chunk.remove_object(Chunk.local_pos(old.pos))
		chunk.add_object(replacement)
	_object_edits[old.pos] = replacement
	_emit_objects_changed(old)


## Hits an object that this does not finish, taking `power` hit points off it. The damage
## makes it an edit, so it outlives the chunk. Draws nothing new, but the view shakes it.
func hit_object(object: WorldObject, power: int) -> void:
	object.take_hit(power)
	_object_edits[object.pos] = object
	object_hit.emit(object)


## Records that an object's state changed, so it outlives its chunk, and has it redrawn.
func change_object(object: WorldObject) -> void:
	_object_edits[object.pos] = object
	_emit_objects_changed(object)


## Lets a night pass over everything the player changed, in unloaded chunks too: crops grow,
## damage heals, picked bushes bear again, stumps and saplings grow back. Only edits change
## like this (a hit or a planting makes one), so they are all in `_object_edits`. A stump or
## sapling does not turn into something that blocks walking on a tile in `occupied_tiles`:
## it waits a day.
func pass_night(occupied_tiles: Array[Vector2i]) -> void:
	for object: WorldObject in _object_edits.values():
		if object == null:
			continue
		if object.pass_night():
			_emit_objects_changed(object)
		if object.is_mature():
			var next := object.matured()
			if not (next.blocks_walking() and occupied_tiles.has(next.pos)):
				replace_object(object, next)


func _take_off(object: WorldObject) -> void:
	chunk_at(Chunk.world_to_chunk(object.pos)).remove_object(Chunk.local_pos(object.pos))
	_object_edits[object.pos] = null
	for tile in object.tiles():
		objects_changed.emit(tile)


## Removes a dormant plant from a tile: whatever is put there now would otherwise have it
## back in its way when its season comes.
func _clear_dormant(world_pos: Vector2i) -> void:
	var object := _stored_object_at(world_pos)
	if object != null and is_dormant(object):
		_take_off(object)


# Unloaded tiles have nothing to redraw; they are drawn when their chunk loads.
func _emit_objects_changed(object: WorldObject) -> void:
	if is_chunk_loaded(Chunk.world_to_chunk(object.pos)):
		for tile in object.tiles():
			objects_changed.emit(tile)


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


## Whether a tile has this terrain and neither an object nor a building.
func is_free_on(world_pos: Vector2i, terrain: Tile.Terrain) -> bool:
	var tile := tile_at(world_pos)
	return (
		tile != null
		and tile.terrain == terrain
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
	for tile in building.tiles():
		_clear_dormant(tile)
	_add_building(building)
	building_placed.emit(building)
	return building


# --- Saving ---


## The seed and what the player changed. The chunks are not saved: they are generated again
## from the seed, with the edits replayed on top (see `add_chunk`).
func to_dict() -> Dictionary:
	var terrain_edits: Array[Array] = []
	for pos in _terrain_edits:
		terrain_edits.append(
			SaveCodec.vector_to_json(pos) + [SaveCodec.terrain_to_json(_terrain_edits[pos])]
		)
	# A removed object is saved as `{"pos": [x, y], "object": null}`.
	var object_edits: Array[Dictionary] = []
	for pos in _object_edits:
		var object := _object_edits[pos]
		(
			object_edits
			. append(
				{
					"pos": SaveCodec.vector_to_json(pos),
					"object": null if object == null else object.to_dict(),
				}
			)
		)
	var buildings_data: Array[Dictionary] = []
	for building in _buildings:
		buildings_data.append(building.to_dict())
	return {
		"seed": world_seed,
		"terrain_edits": terrain_edits,
		"object_edits": object_edits,
		"buildings": buildings_data,
	}


## A world with no chunks loaded; whoever shows it loads them.
static func from_dict(data: Dictionary) -> World:
	var world := World.new(int(data["seed"]))
	for edit: Array in data["terrain_edits"]:
		world._terrain_edits[SaveCodec.vector_from_json(edit)] = SaveCodec.terrain_from_json(
			edit[2]
		)
	for edit: Dictionary in data["object_edits"]:
		var object_data: Variant = edit["object"]
		world._object_edits[SaveCodec.vector_from_json(edit["pos"])] = (
			null if object_data == null else WorldObject.from_dict(object_data)
		)
	for building_data: Dictionary in data["buildings"]:
		world._add_building(Building.from_dict(building_data))
	return world


func _add_building(building: Building) -> void:
	_buildings.append(building)
	for pos in building.tiles():
		_building_by_tile[pos] = building
