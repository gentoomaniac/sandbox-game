# gdlint: disable=max-public-methods
class_name WorldEdits
extends RefCounted
## What the player changed in a world, kept outside the chunks so it survives their unloading:
## per world position the terrain they gave it and the object that stands there now (null where
## the generated object was removed). Together with the seed this is the whole world.
##
## It knows no chunks of its own: whoever calls gives the chunk an edit also reaches, or null when
## that chunk is not loaded (the edit then waits for the chunk to be loaded, see `replay`).

## The terrain or an object of this chunk was edited, loaded or not.
signal edited(chunk_coords: Vector2i)

## Terrain the player changed (e.g. grass tilled to soil), by world position. Replayed on
## chunks before the objects, which may depend on the ground.
var _terrain_edits: Dictionary[Vector2i, Tile.Terrain] = {}
var _object_edits: Dictionary[Vector2i, WorldObject] = {}
## The positions of the crops among the object edits, which every hour of the simulation visits.
var _crop_positions: Dictionary[Vector2i, bool] = {}
## The tiles of the scarecrows the player put down, in loaded chunks or not.
var _scarecrow_positions: Dictionary[Vector2i, bool] = {}
## The tiles of the campfires, in loaded chunks or not.
var _campfire_positions: Dictionary[Vector2i, bool] = {}
## The world positions of the terrain edits and of the object edits by the chunk they are in, in
## the order they were first made (the keys of a dictionary, which keeps it), so that a chunk
## replays its own edits, in that order, without looking at the others. Not saved: `load_dict`
## builds them again.
var _terrain_edit_positions_by_chunk: Dictionary[Vector2i, Dictionary] = {}
var _object_edit_positions_by_chunk: Dictionary[Vector2i, Dictionary] = {}


## `replay` from a snapshot (see `snapshot_of_chunk`): the objects are made new, of the types.
static func replay_snapshot(chunk: Chunk, snapshot: Dictionary) -> void:
	var terrain: Dictionary = snapshot["terrain"]
	for pos: Vector2i in terrain:
		chunk.set_terrain(Chunk.local_pos(pos), terrain[pos])
	var objects: Dictionary = snapshot["objects"]
	for pos: Vector2i in objects:
		chunk.remove_object(Chunk.local_pos(pos))
		if objects[pos] != &"":
			var object := WorldObject.new(objects[pos], pos)
			chunk.remove_objects_under(object)
			chunk.add_object(object)


# --- Terrain ---


func edit_terrain(world_pos: Vector2i, terrain: Tile.Terrain) -> void:
	_terrain_edits[world_pos] = terrain
	_note_edited(_terrain_edit_positions_by_chunk, world_pos)
	edited.emit(Chunk.world_to_chunk(world_pos))


## The terrain the player gave a position, or `fallback` if they did not.
func terrain_edit_at(world_pos: Vector2i, fallback: Tile.Terrain) -> Tile.Terrain:
	return _terrain_edits.get(world_pos, fallback)


## Whether the player tilled a tile: it is soil by their hand.
func is_tilled(world_pos: Vector2i) -> bool:
	return _terrain_edits.get(world_pos) == Tile.Terrain.SOIL


## The tilled tiles, in loaded chunks or not.
func tilled_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for pos in _terrain_edits:
		if is_tilled(pos):
			tiles.append(pos)
	return tiles


## The tilled tiles of a chunk, loaded or not.
func tilled_tiles_in_chunk(chunk_coords: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for pos: Vector2i in _terrain_edit_positions_by_chunk.get(chunk_coords, {}):
		if is_tilled(pos):
			tiles.append(pos)
	return tiles


# --- Objects ---


## `object` is null where the generated object was removed.
func edit_object(world_pos: Vector2i, object: WorldObject) -> void:
	_object_edits[world_pos] = object
	if object != null and object.is_crop():
		_crop_positions[world_pos] = true
	else:
		_crop_positions.erase(world_pos)
	if object != null and object.type == WorldObjectTypes.SCARECROW:
		_scarecrow_positions[world_pos] = true
	else:
		_scarecrow_positions.erase(world_pos)
	if Campfire.is_campfire(object):
		_campfire_positions[world_pos] = true
	else:
		_campfire_positions.erase(world_pos)
	_note_edited(_object_edit_positions_by_chunk, world_pos)
	edited.emit(Chunk.world_to_chunk(world_pos))


## Whether an object (or its removal) is an edit at a position.
func has_object_edit(world_pos: Vector2i) -> bool:
	return _object_edits.has(world_pos)


## The object the player left at a position: null for none, or where the generated one was removed.
func object_edit_at(world_pos: Vector2i) -> WorldObject:
	return _object_edits.get(world_pos)


## Puts `replacement` where `old` stands, in `chunk` too if it is loaded (else null).
func replace(chunk: Chunk, old: WorldObject, replacement: WorldObject) -> void:
	assert(old.pos == replacement.pos and old.tiles() == replacement.tiles(), "Not in place")
	if chunk != null:
		chunk.remove_object(Chunk.local_pos(old.pos))
		chunk.add_object(replacement)
	edit_object(old.pos, replacement)


## Takes `power` hit points off an object that this does not finish. The damage makes it an edit.
func hit(object: WorldObject, power: int) -> void:
	object.take_hit(power)
	edit_object(object.pos, object)


## Forgets the edit at a position: the chunk's own generated object stands there again. The
## chunk need not be loaded, nor is it told: whatever stands in it is what the edit said.
func drop_object_edit(world_pos: Vector2i) -> void:
	_object_edits.erase(world_pos)
	_crop_positions.erase(world_pos)
	_scarecrow_positions.erase(world_pos)
	_campfire_positions.erase(world_pos)
	_object_edit_positions_by_chunk[Chunk.world_to_chunk(world_pos)].erase(world_pos)


## Records that an object's state changed.
func change(object: WorldObject) -> void:
	edit_object(object.pos, object)


## Takes an object off its tiles, in `chunk` too if it is loaded (else null); the edit keeps it
## off.
func take_off(chunk: Chunk, object: WorldObject) -> void:
	if chunk != null:
		chunk.remove_object(Chunk.local_pos(object.pos))
	edit_object(object.pos, null)


## The objects the player changed and that are still there, in loaded chunks or not.
func edited_objects() -> Array[WorldObject]:
	var objects: Array[WorldObject] = []
	for object in _object_edits.values():
		if object != null:
			objects.append(object)
	return objects


## The scarecrows the player put down and that are still there, in loaded chunks or not.
func scarecrows() -> Array[WorldObject]:
	return _objects_at(_scarecrow_positions)


## The campfires, in loaded chunks or not.
func campfires() -> Array[WorldObject]:
	return _objects_at(_campfire_positions)


## The crops the player planted and that are still there, in loaded chunks or not.
func crops() -> Array[WorldObject]:
	return _objects_at(_crop_positions)


# --- Chunks ---


## Applies the edits within the area of a freshly generated chunk to it: the terrain first, as
## objects may depend on the ground, then the objects (a removed one is gone, an edited one
## stands in the place of the generated one). The chunk need not be loaded: whoever reads a chunk
## that is not (see TravelMasks) replays them on a copy.
func replay(chunk: Chunk) -> void:
	for pos: Vector2i in _terrain_edit_positions_by_chunk.get(chunk.coords, {}):
		chunk.set_terrain(Chunk.local_pos(pos), _terrain_edits[pos])
	for pos: Vector2i in _object_edit_positions_by_chunk.get(chunk.coords, {}):
		chunk.remove_object(Chunk.local_pos(pos))
		if _object_edits[pos] != null:
			chunk.remove_objects_under(_object_edits[pos])
			chunk.add_object(_object_edits[pos])


## The edits within the area of a chunk, copied: `terrain` by world position to terrain, and
## `objects` by world position to the type of the object that stands there now (&"" where the
## generated one was taken off), each in the order made. Whoever replays them (`replay_snapshot`)
## may do so on another thread: nothing in it is shared with the edits.
func snapshot_of_chunk(chunk_coords: Vector2i) -> Dictionary:
	var terrain := {}
	for pos: Vector2i in _terrain_edit_positions_by_chunk.get(chunk_coords, {}):
		terrain[pos] = _terrain_edits[pos]
	var objects := {}
	for pos: Vector2i in _object_edit_positions_by_chunk.get(chunk_coords, {}):
		var object := _object_edits[pos]
		objects[pos] = &"" if object == null else object.type
	return {"terrain": terrain, "objects": objects}


# --- Saving ---


## A copy of the edits for `WorldSave.dict_of`, in the types they are kept in, sharing nothing
## with them. The objects are the one thing that changes after the copy, so each is made data at
## once.
func snapshot() -> Dictionary:
	var object_edits := []
	for object: WorldObject in _object_edits.values():
		object_edits.append(null if object == null else object.to_dict())
	return {
		"terrain_edits": _terrain_edits.duplicate(),
		"object_edit_positions": _object_edits.keys(),
		"object_edits": object_edits,
	}


## Takes the edits of a save (see `WorldSave.dict_of`).
func load_dict(data: Dictionary) -> void:
	for edit: Array in data["terrain_edits"]:
		edit_terrain(SaveCodec.vector_from_json(edit), SaveCodec.terrain_from_json(edit[2]))
	for edit: Dictionary in data["object_edits"]:
		var object_data: Variant = edit["object"]
		edit_object(
			SaveCodec.vector_from_json(edit["pos"]),
			null if object_data == null else WorldObject.from_dict(object_data)
		)


func _objects_at(positions: Dictionary[Vector2i, bool]) -> Array[WorldObject]:
	var objects: Array[WorldObject] = []
	for pos in positions:
		objects.append(_object_edits[pos])
	return objects


func _note_edited(
	positions_by_chunk: Dictionary[Vector2i, Dictionary], world_pos: Vector2i
) -> void:
	var chunk_coords := Chunk.world_to_chunk(world_pos)
	if not positions_by_chunk.has(chunk_coords):
		positions_by_chunk[chunk_coords] = {}
	positions_by_chunk[chunk_coords][world_pos] = true
