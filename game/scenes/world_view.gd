class_name WorldView
extends Node2D
## Renders a World with one TileMapLayer and streams chunks in and out around a focus.
##
## One layer for the whole world (not one per chunk): tiles use world coordinates, and
## loading or unloading a chunk is just filling or erasing its 32x32 cells, with no nodes
## to create or free.

const LOAD_RADIUS := 3
const UNLOAD_RADIUS := 5
## Generating a chunk takes ~2 ms and drawing it ~1 ms; this keeps a frame well under 16 ms.
const MAX_LOADS_PER_FRAME := 2

var world: World
var _generator: WorldGenerator
var _layer := TileMapLayer.new()
var _focus_chunk := Vector2i.ZERO


func _ready() -> void:
	_layer.tile_set = PlaceholderTileset.build()
	add_child(_layer)


func show_world(world_to_show: World) -> void:
	world = world_to_show
	_generator = WorldGenerator.new(world.world_seed)


## Streaming follows this world tile position.
func set_focus(world_pos: Vector2i) -> void:
	_focus_chunk = Chunk.world_to_chunk(world_pos)


func _process(_delta: float) -> void:
	if world == null:
		return
	var plan := ChunkStreaming.plan(
		_focus_chunk, world.loaded_chunk_coords(), LOAD_RADIUS, UNLOAD_RADIUS
	)
	for coords: Vector2i in plan["unload"]:
		_unload_chunk(coords)
	var to_load: Array = plan["load"]
	for coords: Vector2i in to_load.slice(0, MAX_LOADS_PER_FRAME):
		_load_chunk(coords)


## Redraws one tile after its state changed. Call it after any Chunk setter.
func redraw_tile(world_pos: Vector2i) -> void:
	var chunk := world.chunk_at(Chunk.world_to_chunk(world_pos))
	if chunk != null:
		_draw_tile(chunk, Chunk.local_pos(world_pos))


func _load_chunk(coords: Vector2i) -> void:
	var chunk := _generator.generate_chunk(coords)
	world.add_chunk(chunk)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			_draw_tile(chunk, Vector2i(x, y))


func _unload_chunk(coords: Vector2i) -> void:
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			_layer.erase_cell(Chunk.to_world(coords, Vector2i(x, y)))
	world.remove_chunk(coords)


## The one place a tile's state becomes a look.
func _draw_tile(chunk: Chunk, local: Vector2i) -> void:
	var atlas_cell := PlaceholderTileset.atlas_cell(chunk.terrain_at(local))
	_layer.set_cell(Chunk.to_world(chunk.coords, local), PlaceholderTileset.SOURCE_ID, atlas_cell)
