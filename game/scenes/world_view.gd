class_name WorldView
extends Node2D
## Renders a World and streams chunks in and out around a focus.
##
## One TileMapLayer per terrain layer for the whole world (not per chunk), drawn as a dual
## grid (see TerrainTileset): cell (x, y) of every layer is shifted half a tile up and left,
## so its corners sit on world tiles (x - 1, y - 1) to (x, y). A chunk owns the cells whose
## bottom-right tile is its own, so loading or unloading it fills or erases those cells,
## with no nodes to create or free. On top, a decoration layer on the plain tile grid
## scatters flowers, pebbles and the like; they are only looks, not world objects. Above
## that, an objects layer on the same grid draws the world's trees and rocks. It is y-sorted
## (so a later player can walk behind a tree) and keeps no decoration under an object.

const LOAD_RADIUS := 3
const UNLOAD_RADIUS := 5
## Loading a chunk (generating it and drawing its layers) takes ~6 ms, at worst ~8 ms.
## One per frame keeps a frame well under 16 ms and still streams far faster than the
## camera moves.
const MAX_LOADS_PER_FRAME := 1

## The 4 corner tiles of a cell, in mask order: top-left, top-right, bottom-left,
## bottom-right.
const CORNER_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)
]

## Visual-only noise, seeded from the world seed with offsets far from the generator's.
## Variety: grass turns lush or dry over patches about this many tiles across.
const VARIETY_SEED_OFFSET := 7919
const VARIETY_FREQUENCY := 0.008
## Decoration clusters, a few tiles across.
const DECORATION_SEED_OFFSET := 104729
const DECORATION_FREQUENCY := 0.12

var world: World
## True once every chunk around the focus is loaded.
var is_settled := false
var _generator: WorldGenerator
var _variety_noise := FastNoiseLite.new()
var _decoration_noise := FastNoiseLite.new()
var _focus_chunk := Vector2i.ZERO
var _tileset := TerrainTileset.new()
var _object_tileset := ObjectTileset.new()
## Indexed by TerrainTileset.Layer.
var _layers: Array[TileMapLayer] = []
var _decorations := TileMapLayer.new()
var _objects := TileMapLayer.new()


func _ready() -> void:
	for layer in TerrainTileset.LAYER_COUNT:
		var tile_map := TileMapLayer.new()
		tile_map.name = TerrainTileset.Layer.keys()[layer].capitalize()
		tile_map.tile_set = _tileset.tile_set
		tile_map.position = -Vector2(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE) / 2
		add_child(tile_map)
		_layers.append(tile_map)
	_decorations.name = "Decorations"
	_decorations.tile_set = _tileset.tile_set
	add_child(_decorations)
	_objects.name = "Objects"
	_objects.tile_set = _object_tileset.tile_set
	_objects.y_sort_enabled = true
	add_child(_objects)


func show_world(world_to_show: World) -> void:
	world = world_to_show
	world.objects_changed.connect(_on_objects_changed)
	_generator = WorldGenerator.new(world.world_seed)
	_variety_noise.seed = world.world_seed + VARIETY_SEED_OFFSET
	_variety_noise.frequency = VARIETY_FREQUENCY
	_decoration_noise.seed = world.world_seed + DECORATION_SEED_OFFSET
	_decoration_noise.frequency = DECORATION_FREQUENCY


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
	is_settled = to_load.is_empty()


## Redraws one tile after its state changed. Call it after any Chunk setter.
func redraw_tile(world_pos: Vector2i) -> void:
	# The tile is a corner of the 4 cells around it.
	for offset: Vector2i in CORNER_OFFSETS:
		_redraw_cell(world_pos - offset)
	if world.is_chunk_loaded(Chunk.world_to_chunk(world_pos)):
		_draw_decoration(world_pos, _layer_at(world_pos))


func _on_objects_changed(world_pos: Vector2i) -> void:
	_draw_object(world_pos)
	_draw_decoration(world_pos, _layer_at(world_pos))


func _load_chunk(coords: Vector2i) -> void:
	var chunk := _generator.generate_chunk(coords)
	world.add_chunk(chunk)
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	# The corners of the chunk's cells: its own tiles plus the row above and the column to
	# the left. Reading them once, mostly straight from the chunk, is several times faster
	# than looking up 4 corners per cell through the world.
	var size := Chunk.CHUNK_SIZE + 1
	var corner_layers := PackedInt32Array()
	corner_layers.resize(size * size)
	for y in size:
		for x in size:
			var local := Vector2i(x - 1, y - 1)
			if x == 0 or y == 0:
				corner_layers[y * size + x] = _layer_at(origin + local)
			else:
				corner_layers[y * size + x] = _layer_of_tile(
					chunk.terrain_at(local), origin + local
				)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var top_left := y * size + x
			var corners := PackedInt32Array(
				[
					corner_layers[top_left],
					corner_layers[top_left + 1],
					corner_layers[top_left + size],
					corner_layers[top_left + size + 1]
				]
			)
			_draw_cell_corners(origin + Vector2i(x, y), corners)
			# The bottom-right corner is this chunk's tile (x, y).
			_draw_decoration(origin + Vector2i(x, y), corners[3])
	for object in chunk.objects():
		_draw_object(object.pos)
	# The right and bottom neighbours' border cells drew this chunk's tiles with a fallback
	# while it was missing. Now they can blend properly.
	for i in Chunk.CHUNK_SIZE + 1:
		_redraw_cell(origin + Vector2i(Chunk.CHUNK_SIZE, i))
	for i in Chunk.CHUNK_SIZE:
		_redraw_cell(origin + Vector2i(i, Chunk.CHUNK_SIZE))


func _unload_chunk(coords: Vector2i) -> void:
	for object in world.chunk_at(coords).objects():
		_objects.erase_cell(object.pos)
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			for tile_map in _layers:
				tile_map.erase_cell(origin + Vector2i(x, y))
			_decorations.erase_cell(origin + Vector2i(x, y))
	world.remove_chunk(coords)


## Redraws a cell if the chunk that owns it is loaded.
func _redraw_cell(cell: Vector2i) -> void:
	if not world.is_chunk_loaded(Chunk.world_to_chunk(cell)):
		return
	var corners := PackedInt32Array()
	for offset: Vector2i in CORNER_OFFSETS:
		corners.append(_layer_at(cell + offset))
	_draw_cell_corners(cell, corners)


## The one place tile state becomes a look: the layers of a cell's 4 corner tiles (in
## CORNER_OFFSETS order, MISSING where not loaded) decide which layers it draws and with
## which shapes.
func _draw_cell_corners(cell: Vector2i, corners: PackedInt32Array) -> void:
	TerrainTileset.fill_missing_corners(corners)
	var drawn := TerrainTileset.drawn_layers(corners)
	for layer in TerrainTileset.LAYER_COUNT:
		if drawn & (1 << layer) == 0:
			_layers[layer].erase_cell(cell)
		else:
			var mask := TerrainTileset.mask_for(corners, layer)
			var atlas_cell := _tileset.atlas_cell(layer, mask, cell)
			_layers[layer].set_cell(cell, TerrainTileset.TERRAIN_SOURCE_ID, atlas_cell)


func _draw_object(world_pos: Vector2i) -> void:
	var object := world.object_at(world_pos)
	if object == null:
		_objects.erase_cell(world_pos)
	else:
		_objects.set_cell(world_pos, ObjectTileset.SOURCE_ID, ObjectTileset.atlas_cell(object))


func _draw_decoration(world_pos: Vector2i, layer: int) -> void:
	if world.object_at(world_pos) != null:
		_decorations.erase_cell(world_pos)
		return
	var cluster := _decoration_noise.get_noise_2dv(Vector2(world_pos))
	var atlas_cell := _tileset.decoration_cell(layer, world_pos, cluster)
	if atlas_cell == TerrainTileset.NO_DECORATION:
		_decorations.erase_cell(world_pos)
	else:
		_decorations.set_cell(world_pos, TerrainTileset.DECORATION_SOURCE_ID, atlas_cell)


## The layer a tile is drawn on, or MISSING if its chunk is not loaded.
func _layer_at(world_pos: Vector2i) -> int:
	var chunk := world.chunk_at(Chunk.world_to_chunk(world_pos))
	if chunk == null:
		return TerrainTileset.MISSING
	return _layer_of_tile(chunk.terrain_at(Chunk.local_pos(world_pos)), world_pos)


func _layer_of_tile(terrain: Tile.Terrain, world_pos: Vector2i) -> int:
	return TerrainTileset.layer_of(terrain, _variety_noise.get_noise_2dv(Vector2(world_pos)))
