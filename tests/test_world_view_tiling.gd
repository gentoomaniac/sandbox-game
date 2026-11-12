extends GutTest
## However chunks load and however a look refresh is interleaved with the loads, every cell of
## the terrain layers ends up as a full redraw would draw it.

const SEED := 1
const CHUNKS: Array[Vector2i] = [
	Vector2i(-2, -2), Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-1, -1)
]
## Days within the blends of each season's first days (see data/seasons.cfg), and one between.
const DAYS := [2, 3, 32, 33, 45, 62, 63, 92, 93]

var _view: WorldView
var _residency: ChunkResidency


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_residency = ChunkResidency.new(World.new(SEED))
	_view.show_world(_residency)


func _set_day(day: int) -> void:
	_view.world.clock.day = day
	_view.refresh_looks(day, 0.0, 0.0)


## What every layer holds for the cells of the loaded chunks (and the row and
## column of cells beyond them), as {layer node name: {cell: [source, atlas coords]}}.
func _drawn() -> Dictionary:
	var drawn := {}
	for layer in _view._layers:
		var cells := {}
		for cell in layer.get_used_cells():
			cells[cell] = [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell)]
		drawn[layer.name] = cells
	return drawn


## Redraws every loaded cell from scratch.
func _redraw_everything() -> void:
	for coords in _view.world.loaded_chunk_coords():
		var origin := Chunk.to_world(coords, Vector2i.ZERO)
		for y in Chunk.CHUNK_SIZE:
			for x in Chunk.CHUNK_SIZE:
				_view._redraw_cell(origin + Vector2i(x, y))


func _assert_matches_full_redraw(message: String) -> void:
	_view.finish_refresh()
	var as_drawn := _drawn()
	_redraw_everything()
	var redrawn := _drawn()
	for name: String in redrawn:
		var wrong: Array = []
		for cell: Vector2i in redrawn[name]:
			if as_drawn[name].get(cell) != redrawn[name][cell]:
				wrong.append(cell)
		for cell: Vector2i in as_drawn[name]:
			if not redrawn[name].has(cell):
				wrong.append(cell)
		assert_eq(wrong.size(), 0, "%s: %s differs at %s" % [message, name, wrong.slice(0, 5)])


func _refresh_one_chunk() -> void:
	if not _view._refresh_queue.is_empty():
		_view._refresh_chunk(_view._refresh_queue.pop_back())


func test_loading_in_any_order_matches_a_full_redraw() -> void:
	for day: int in DAYS:
		var reversed := CHUNKS.duplicate()
		reversed.reverse()
		for order in [CHUNKS, reversed]:
			_set_day(day)
			for coords: Vector2i in order:
				_residency.load_chunk(coords)
				_view.finish_drawing()
			_assert_matches_full_redraw("day %d, order %s" % [day, order])
			for coords: Vector2i in order:
				_residency.unload_chunk(coords)


func test_chunks_loading_between_refresh_steps_match_a_full_redraw() -> void:
	for day: int in DAYS:
		_set_day(day - 20)
		_residency.load_chunk(CHUNKS[0])
		_view.finish_drawing()
		_residency.load_chunk(CHUNKS[1])
		_view.finish_drawing()
		_view.finish_refresh()
		_set_day(day)
		_refresh_one_chunk()
		_residency.load_chunk(CHUNKS[2])
		_view.finish_drawing()
		_refresh_one_chunk()
		_refresh_one_chunk()
		_residency.load_chunk(CHUNKS[3])
		_view.finish_drawing()
		_assert_matches_full_redraw("day %d" % day)
		for coords: Vector2i in CHUNKS:
			_residency.unload_chunk(coords)


func test_unloading_a_chunk_erases_every_layer_in_it() -> void:
	var layers: Array[TileMapLayer] = []
	layers.append_array(_view._layers)
	var first := Chunk.to_world(CHUNKS[0], Vector2i.ZERO)
	var area := Rect2i(first, Vector2i.ONE * Chunk.CHUNK_SIZE)
	for day: int in DAYS:
		_set_day(day)
		_residency.load_chunk(CHUNKS[0])
		_view.finish_drawing()
		_view.finish_refresh()
		assert_gt(_cells_in(layers, area), 0, "day %d: the chunk is drawn" % day)
		_residency.unload_chunk(CHUNKS[0])
		assert_eq(_cells_in(layers, area), 0, "day %d: nothing is left after unloading" % day)


func _cells_in(layers: Array, area: Rect2i) -> int:
	var count := 0
	for layer: TileMapLayer in layers:
		for cell in layer.get_used_cells():
			count += 1 if area.has_point(cell) else 0
	return count
