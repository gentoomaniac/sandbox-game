class_name ChunkResidency
extends RefCounted
## Which chunks of a World are loaded: the session's decision, apart from drawing. It follows a
## focus (`ChunkStreaming` plans around it), generates and adds the chunks that are missing and
## drops those that are far. A renderer only listens to `chunk_loaded` and `chunk_unloaded` and
## draws what is there; it can come and go without a chunk being loaded or dropped for it.

## A chunk was generated and added to the world.
signal chunk_loaded(chunk: Chunk)
## A chunk was dropped from the world, after the fact: `chunk` is what was in it.
signal chunk_unloaded(chunk: Chunk)

const LOAD_RADIUS := 3
const UNLOAD_RADIUS := 5

var world: World
## While true, `update` loads and drops nothing: the world is held still (a sleep that is made up
## for, a player indoors).
var is_held := false
var focus_chunk := Vector2i.ZERO
## True when `update` found every chunk around the focus loaded (before it loaded the next).
var is_complete := false
var _generator: WorldGenerator


func _init(world_to_hold: World) -> void:
	world = world_to_hold
	_generator = WorldGenerator.new(world.world_seed)


## Streaming follows this world tile position.
func set_focus(world_pos: Vector2i) -> void:
	focus_chunk = Chunk.world_to_chunk(world_pos)


## Drops the chunks that are far from the focus, and loads the nearest missing one if
## `may_load` (the renderer says it can take another).
func update(may_load := true) -> void:
	if is_held:
		return
	var plan := ChunkStreaming.plan(
		focus_chunk, world.loaded_chunk_coords(), LOAD_RADIUS, UNLOAD_RADIUS
	)
	for coords: Vector2i in plan["unload"]:
		unload_chunk(coords)
	var to_load: Array = plan["load"]
	if may_load and not to_load.is_empty():
		load_chunk(to_load[0])
	is_complete = to_load.is_empty()


## Loads, at once, the chunks that hold these world tiles and are not loaded: what an action needs
## to find its tiles, whether or not anything draws them. Tiles out of the world are skipped.
func require(tiles: Array[Vector2i]) -> void:
	for tile in tiles:
		var coords := Chunk.world_to_chunk(tile)
		if World.is_chunk_in_bounds(coords) and not world.is_chunk_loaded(coords):
			load_chunk(coords)


## Generates a chunk and adds it to the world.
func load_chunk(coords: Vector2i) -> void:
	var chunk := _generator.generate_chunk(coords)
	world.add_chunk(chunk)
	chunk_loaded.emit(chunk)


## Drops a loaded chunk from the world. What the player changed in it is kept (see World).
func unload_chunk(coords: Vector2i) -> void:
	var chunk := world.chunk_at(coords)
	world.remove_chunk(coords)
	chunk_unloaded.emit(chunk)
