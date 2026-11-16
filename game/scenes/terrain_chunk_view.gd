class_name TerrainChunkView
extends Node2D
## The ground of a World: one TileMapLayer per terrain layer for the whole world (not per chunk),
## drawn as a dual grid (see TerrainTileset). WorldView owns it and spends one frame budget on
## it and the look refresh (see WorldView `_process`).
##
## Cell (x, y) of every layer is shifted half a tile up and left, so its corners sit on world
## tiles (x - 1, y - 1) to (x, y). A chunk owns the cells whose bottom-right tile is its own, so
## loading or unloading it fills or erases those cells, with no nodes to create or free.
##
## It keeps the terrain layer of each tile of a loaded chunk, draws the chunks as they load, brings
## loaded chunks up to date after the day, the snow or the frost changed, and keeps the CoverMap
## (the leaves, snow and shelter on the ground). What lies on the ground is not its business: it
## says when a chunk's objects are due or its plants may have changed, and WorldView lets the
## object presenter answer.

## A drawing chunk reached the step that draws its objects.
signal objects_due(chunk: Chunk)
## A loaded chunk was brought up to date: its objects may have changed their look.
signal chunk_refreshed(chunk: Chunk)

## How long a frame may spend bringing the looks up to date after they changed. Scanning a
## chunk takes about 1 ms, redrawing the cells of one whose tiles all changed about 10 ms, so
## the work is cut into cells.
const REFRESH_BUDGET_USEC := 3000
## Drawing a chunk takes about 45 ms: it is cut into steps (a row of cells, the objects, the
## borders) that a frame runs until it has spent this long. The next chunk is loaded when the one
## before is drawn (Main asks WorldView `is_drawing`); the look refresh waits for frames without
## drawing. The chunks load well ahead of the view, so the world around the player is drawn long
## before they get there.
const DRAW_BUDGET_USEC := 8000
## The budget while a chunk next to the player's is still undrawn (at the start, after a jump
## to another place): it is on the screen, so it is drawn sooner, at the cost of longer frames.
const URGENT_DRAW_BUDGET_USEC := 16000

## The 4 corner tiles of a cell, in mask order: top-left, top-right, bottom-left,
## bottom-right.
const CORNER_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)
]

## Visual-only noise, seeded from the world seed with an offset far from the generator's.
## Variety: grass turns lush or dry over patches about this many tiles across.
const VARIETY_SEED_OFFSET := 7919
const VARIETY_FREQUENCY := 0.008


## A chunk that is loaded and is being drawn, a step per call of `_draw_chunk_step`.
class ChunkDrawing:
	extends RefCounted
	var chunk: Chunk
	## 0 is the layers of the tiles, then a step for each row of cells, the objects, the borders.
	var step := 0

	func _init(chunk_to_draw: Chunk) -> void:
		chunk = chunk_to_draw

	func is_done() -> bool:
		return step > Chunk.CHUNK_SIZE + 2


var tileset: TerrainTileset
## Indexed by TerrainTileset.Layer.
var layers: Array[TileMapLayer] = []
var cover_map := CoverMap.new()
var _world: World
var _residency: ChunkResidency
var _decorations: DecorationView
var _way_edges: WayEdges
var _variety_noise := FastNoiseLite.new()
## The terrain layer of each tile of a loaded chunk (see TerrainTileset.Layer), by tile index
## (local y * CHUNK_SIZE + x). It comes from the variety noise, the slowest part of drawing a cell.
var _chunk_layers: Dictionary[Vector2i, PackedInt32Array] = {}
## The tiles with something that gives shade or shelter on them, to tell a change that reaches the
## cover from one that does not.
var _crown_tiles: Dictionary[Vector2i, bool] = {}
## The chunk that is loaded and being drawn, if any.
var _drawing: ChunkDrawing
## The loaded chunks that wait to be drawn, the oldest first.
var _to_draw: Array[Chunk] = []
## Chunks whose plants are not brought up to date yet, the nearest to the focus last.
var _refresh_queue: Array[Vector2i] = []
## The focus chunk that the cover map was drawn for (once it has one), and whether a chunk may
## be waiting there.
var _cover_focus := Vector2i.ZERO
var _is_cover_focused := false
var _is_cover_missing := false


func _init(ambient_motion: AmbientMotion, ground_look: GroundLook) -> void:
	name = "Terrain"
	tileset = TerrainTileset.new(ambient_motion)
	for layer in TerrainTileset.LAYER_COUNT:
		var tile_map := TileMapLayer.new()
		tile_map.name = TerrainTileset.Layer.keys()[layer].capitalize()
		tile_map.tile_set = tileset.tile_set
		tile_map.position = -Vector2(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE) / 2
		tile_map.material = ground_look.terrain
		add_child(tile_map)
		layers.append(tile_map)
	layers[TerrainTileset.Layer.WATER].material = ambient_motion.water
	layers[TerrainTileset.Layer.FORD].material = ambient_motion.ford
	layers[TerrainTileset.Layer.MUD].material = ambient_motion.mud
	layers[TerrainTileset.Layer.SOIL].material = ground_look.soil


func show_art_set() -> void:
	tileset.show_art_set()
	cover_map.show_art_set()


## Shows the chunks of a residency. The ones loaded now are drawn by `draw_chunk`, the ones that
## load later by `on_chunk_loaded`.
func show_world(
	residency: ChunkResidency, decorations: DecorationView, way_edges: WayEdges
) -> void:
	_residency = residency
	_world = residency.world
	_decorations = decorations
	_way_edges = way_edges
	cover_map.show_world(_world)
	_variety_noise.seed = _world.world_seed + VARIETY_SEED_OFFSET
	_variety_noise.frequency = VARIETY_FREQUENCY


## Whether a loaded chunk is not drawn yet.
func is_drawing() -> bool:
	return _drawing != null


## Whether chunks wait for their plants to be brought up to date.
func has_refresh_pending() -> bool:
	return not _refresh_queue.is_empty()


## Draws the chunks that are loaded and not drawn yet, at once (for tests).
func finish_drawing() -> void:
	while is_drawing():
		_draw_next_step()


## Brings every queued chunk up to date at once (for tests).
func finish_refresh() -> void:
	while not _refresh_queue.is_empty():
		_refresh_chunk(_refresh_queue.pop_back())


## Draws a whole chunk at once.
func draw_chunk(chunk: Chunk) -> void:
	var drawing := ChunkDrawing.new(chunk)
	while not drawing.is_done():
		_draw_chunk_step(drawing)


## The drawing part of a frame: moves the cover map's focus with the residency's, runs the steps
## of the drawing (one at least) until the budget is spent, draws the cover chunks that came into
## range and uploads the cover.
func draw_within_budget() -> void:
	sync_cover_focus()
	if _drawing != null:
		var offset := (_drawing.chunk.coords - _residency.focus_chunk).abs()
		var is_urgent := maxi(offset.x, offset.y) <= 1
		var budget := URGENT_DRAW_BUDGET_USEC if is_urgent else DRAW_BUDGET_USEC
		var deadline := Time.get_ticks_usec() + budget
		_draw_next_step()
		while is_drawing() and Time.get_ticks_usec() < deadline:
			_draw_next_step()
	if _is_cover_missing:
		_is_cover_missing = cover_map.draw_missing()
	cover_map.upload()


## Brings the queued chunks up to date until the refresh budget is spent.
func refresh_within_budget() -> void:
	var deadline := Time.get_ticks_usec() + REFRESH_BUDGET_USEC
	while Time.get_ticks_usec() < deadline and not _refresh_queue.is_empty():
		_refresh_chunk(_refresh_queue.pop_back())


## Queues every loaded chunk for a refresh, the nearest to the focus last (it is popped first).
func queue_refresh() -> void:
	_refresh_queue.assign(_world.loaded_chunk_coords())
	var focus := _residency.focus_chunk
	_refresh_queue.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (a - focus).length_squared() > (b - focus).length_squared()
	)


## Moves the focus of the cover map with the residency's. A chunk that waits for it is drawn by
## `draw_within_budget`.
func sync_cover_focus() -> void:
	if _residency.focus_chunk != _cover_focus or not _is_cover_focused:
		_cover_focus = _residency.focus_chunk
		_is_cover_focused = true
		cover_map.set_focus(_cover_focus)
		_is_cover_missing = true


## Redraws one tile after its state changed. WorldView's `redraw_tile` calls it.
func redraw_tile(world_pos: Vector2i) -> void:
	var tile_layers: PackedInt32Array = _chunk_layers.get(Chunk.world_to_chunk(world_pos), [])
	if not tile_layers.is_empty():
		var local := Chunk.local_pos(world_pos)
		var terrain := _world.chunk_at(Chunk.world_to_chunk(world_pos)).terrain_at(local)
		tile_layers[_tile_index(local)] = _layer_of_tile(terrain, world_pos)
		cover_map.redraw_tile(world_pos)
	# The tile is a corner of the 4 cells around it.
	for offset: Vector2i in CORNER_OFFSETS:
		_redraw_cell(world_pos - offset)
	if _world.is_chunk_loaded(Chunk.world_to_chunk(world_pos)):
		_decorations.redraw(world_pos, layer_at(world_pos))
	_way_edges.draw(world_pos)


## Tells whether a tile has something that gives shade or shelter on it now, and redraws the
## cover around it when that changed.
func update_crown(world_pos: Vector2i, is_crown: bool) -> void:
	if is_crown == _crown_tiles.has(world_pos):
		return
	if is_crown:
		_crown_tiles[world_pos] = true
	else:
		_crown_tiles.erase(world_pos)
	cover_map.redraw_around(world_pos)


## The terrain layer of a tile, or TerrainTileset.MISSING if its chunk is not loaded.
func layer_at(world_pos: Vector2i) -> int:
	var tile_layers: PackedInt32Array = _chunk_layers.get(Chunk.world_to_chunk(world_pos), [])
	if tile_layers.is_empty():
		return TerrainTileset.MISSING
	return tile_layers[_tile_index(Chunk.local_pos(world_pos))]


func on_chunk_loaded(chunk: Chunk) -> void:
	if _drawing == null:
		_drawing = ChunkDrawing.new(chunk)
	else:
		_to_draw.append(chunk)


## Erases a chunk that was dropped from the world.
func forget_chunk(chunk: Chunk) -> void:
	var coords := chunk.coords
	if _drawing != null and _drawing.chunk == chunk:
		_drawing = _next_drawing()
	_to_draw.erase(chunk)
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	_chunk_layers.erase(coords)
	_refresh_queue.erase(coords)
	cover_map.forget_chunk(coords)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			for tile_map in layers:
				tile_map.erase_cell(origin + Vector2i(x, y))
			_decorations.forget(origin + Vector2i(x, y))
			_crown_tiles.erase(origin + Vector2i(x, y))


## Does the next step of the drawing.
func _draw_next_step() -> void:
	_draw_chunk_step(_drawing)
	if _drawing.is_done():
		_drawing = _next_drawing()


## The drawing of the oldest chunk that waits, or null if none does.
func _next_drawing() -> ChunkDrawing:
	return null if _to_draw.is_empty() else ChunkDrawing.new(_to_draw.pop_front())


## Does the next step of drawing a chunk. The cells read the tiles' looks as they are when
## their row is drawn, as the world can change between the steps.
func _draw_chunk_step(drawing: ChunkDrawing) -> void:
	var chunk := drawing.chunk
	var coords := chunk.coords
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	if drawing.step == 0:
		_chunk_layers[coords] = _make_chunk_layers(chunk)
		_refresh_queue.erase(coords)
		cover_map.draw_chunk(coords)
		for object in chunk.objects():
			if object.type in GroundCover.CROWNED:
				for tile in object.tiles():
					_crown_tiles[tile] = true
	elif drawing.step <= Chunk.CHUNK_SIZE:
		_draw_row(drawing, drawing.step - 1)
	elif drawing.step == Chunk.CHUNK_SIZE + 1:
		objects_due.emit(chunk)
		_way_edges.draw_chunk(chunk)
	else:
		# The right and bottom neighbours' border cells drew this chunk's tiles with a fallback
		# while it was missing. Now they can blend properly.
		for i in Chunk.CHUNK_SIZE + 1:
			_redraw_cell(origin + Vector2i(Chunk.CHUNK_SIZE, i))
		for i in Chunk.CHUNK_SIZE:
			_redraw_cell(origin + Vector2i(i, Chunk.CHUNK_SIZE))
	drawing.step += 1


## Draws the cells of row `y` of a chunk (and their decorations).
func _draw_row(drawing: ChunkDrawing, y: int) -> void:
	var origin := Chunk.to_world(drawing.chunk.coords, Vector2i.ZERO)
	var tile_layers: PackedInt32Array = _chunk_layers[drawing.chunk.coords]
	# The corners of the row's cells: the layers of the row above and of this row, starting one
	# column to the left. Reading them once, mostly straight from the chunk, is several times
	# faster than looking up 4 corners per cell through the world.
	var above := _layer_row(tile_layers, origin, y - 1)
	var below := _layer_row(tile_layers, origin, y)
	for x in Chunk.CHUNK_SIZE:
		var corners := PackedInt32Array([above[x], above[x + 1], below[x], below[x + 1]])
		var pos := origin + Vector2i(x, y)
		_draw_cell_corners(pos, corners, true)
		# The bottom-right corner is this chunk's tile (x, y).
		_decorations.place(pos, corners[3], _world.object_at(pos) != null)


## The layers of the tiles of row `y` of a chunk, from the column left of it to its last.
func _layer_row(tile_layers: PackedInt32Array, origin: Vector2i, y: int) -> PackedInt32Array:
	var row := PackedInt32Array()
	row.resize(Chunk.CHUNK_SIZE + 1)
	for x in range(-1, Chunk.CHUNK_SIZE):
		if x < 0 or y < 0:
			row[x + 1] = layer_at(origin + Vector2i(x, y))
		else:
			row[x + 1] = tile_layers[_tile_index(Vector2i(x, y))]
	return row


## The terrain layer of each tile of a chunk.
func _make_chunk_layers(chunk: Chunk) -> PackedInt32Array:
	var tile_layers := PackedInt32Array()
	tile_layers.resize(Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE)
	var origin := Chunk.to_world(chunk.coords, Vector2i.ZERO)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			tile_layers[_tile_index(Vector2i(x, y))] = _layer_of_tile(
				chunk.terrain_at(Vector2i(x, y)), origin + Vector2i(x, y)
			)
	return tile_layers


## Brings a loaded chunk up to date with the day, the snow cover and the frost: redraws the
## decorations and the plants that changed.
func _refresh_chunk(coords: Vector2i) -> void:
	var chunk := _world.chunk_at(coords)
	if chunk == null or not _chunk_layers.has(coords):
		return
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	for index in Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE:
		_decorations.refresh(origin + Vector2i(index % Chunk.CHUNK_SIZE, index / Chunk.CHUNK_SIZE))
	_way_edges.refresh_chunk(coords)
	chunk_refreshed.emit(chunk)


## Redraws the terrain layers of a cell if the chunk that owns it is loaded.
func _redraw_cell(cell: Vector2i) -> void:
	if not _world.is_chunk_loaded(Chunk.world_to_chunk(cell)):
		return
	var corners := PackedInt32Array()
	for offset: Vector2i in CORNER_OFFSETS:
		corners.append(layer_at(cell + offset))
	_draw_cell_corners(cell, corners)


## The one place tile state becomes terrain: the layers of a cell's 4 corner tiles (in
## CORNER_OFFSETS order, MISSING where not loaded) decide which layers it draws and with which
## shapes. A cell `is_new` when its chunk was just loaded: it is empty, so nothing needs erasing,
## which saves a good part of a chunk load. The colour of the season and the leaves, frost and
## snow come from the ground shader, not from the cells (see GroundLook).
func _draw_cell_corners(cell: Vector2i, corners: PackedInt32Array, is_new := false) -> void:
	TerrainTileset.fill_missing_corners(corners)
	var drawn := TerrainTileset.drawn_layers(corners)
	for layer in TerrainTileset.LAYER_COUNT:
		if drawn & (1 << layer) == 0:
			if not is_new:
				layers[layer].erase_cell(cell)
		else:
			var mask := TerrainTileset.mask_for(corners, layer)
			var atlas_cell := tileset.atlas_cell(layer, mask, cell)
			layers[layer].set_cell(cell, TerrainTileset.TERRAIN_SOURCE_ID, atlas_cell)


func _layer_of_tile(terrain: Tile.Terrain, world_pos: Vector2i) -> int:
	var variety := _variety_noise.get_noise_2dv(Vector2(world_pos))
	# Only the floodplain can be a ford, which is the cheap part to ask first.
	var is_ford := terrain == Tile.Terrain.FLOODPLAIN and Fords.is_ford(_world, world_pos)
	return TerrainTileset.terrain_layer(
		terrain, variety, _world.wear_stage(world_pos), _world.is_muddy, is_ford
	)


static func _tile_index(local: Vector2i) -> int:
	return local.y * Chunk.CHUNK_SIZE + local.x
