extends GutTest
## However chunks load and however a look refresh is interleaved with the loads, every cell of
## the terrain layers and the look overlays ends up as a full redraw would draw it.

const SEED := 1
const CHUNKS: Array[Vector2i] = [
	Vector2i(-2, -2), Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-1, -1)
]
## Days across the blends of spring to summer, summer to autumn and autumn to winter.
const DAYS := [25, 32, 40, 45, 55, 62, 70, 80, 90]

var _view: WorldView


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_view.show_world(World.new(SEED))


func _set_day(day: int) -> void:
	_view.world.clock.day = day
	_view.refresh_looks(day, 0.0, 0.0)


## What every layer and overlay holds for the cells of the loaded chunks (and the row and
## column of cells beyond them), as {layer node name: {cell: [source, atlas coords]}}.
func _drawn() -> Dictionary:
	var drawn := {}
	var layers: Array[TileMapLayer] = []
	layers.append_array(_view._layers)
	layers.append_array(_view._overlays.values())
	layers.append_array(_view._variety_overlays.values())
	for layer in layers:
		var cells := {}
		for cell in layer.get_used_cells():
			cells[cell] = [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell)]
		drawn[layer.name] = cells
	return drawn


## Redraws every loaded cell from scratch. The looks of the tiles must be up to date.
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


## The mask of an overlay tile: its corners that are drawn.
func _mask_of(atlas_coords: Vector2i) -> int:
	return (
		TerrainTileset.FULL
		if atlas_coords.x >= TerrainTileset.FULL_COLUMN
		else atlas_coords.x % TerrainTileset.FULL
	)


## Lush and dry grass in a season's look must fade out like the terrain below them, not cover
## the whole cell as soon as one corner is lush (straight-edged blocks), and must not repeat
## the edge of the layer below them (a fringe round the patches of another look).
func test_lush_and_dry_overlays_have_the_shape_of_their_grass() -> void:
	for coords in CHUNKS:
		_view._load_chunk(coords)
	var checked := 0
	for day: int in DAYS:
		_set_day(day)
		_view.finish_refresh()
		for key: Vector2i in _view._variety_overlays:
			var overlay: TileMapLayer = _view._variety_overlays[key]
			var below: TileMapLayer = _view._overlays[key.x]
			if key.y == TerrainTileset.Layer.DRY_GRASS:
				below = _view._variety_overlays[Vector2i(key.x, TerrainTileset.Layer.LUSH_GRASS)]
			for cell in overlay.get_used_cells():
				var corner_layers := PackedInt32Array()
				for offset in WorldView.CORNER_OFFSETS:
					corner_layers.append(_view._layer_at(cell + offset))
				if corner_layers.has(TerrainTileset.MISSING):
					continue  # The edge of the loaded area, drawn with a fallback.
				var mask := _mask_of(overlay.get_cell_atlas_coords(cell))
				var expected := 0
				for corner in 4:
					var pos: Vector2i = cell + WorldView.CORNER_OFFSETS[corner]
					var shown := TerrainTileset.shown_season_look(
						corner_layers[corner], _view._season_look_at(pos)
					)
					if corner_layers[corner] >= key.y and shown == key.x:
						expected |= 1 << corner
				assert_eq(mask, expected, "%s on %s" % [cell, overlay.name])
				if below.get_cell_source_id(cell) != -1:
					var below_mask := _mask_of(below.get_cell_atlas_coords(cell))
					assert_ne(
						below_mask, mask, "%s: %s repeats the edge below" % [cell, overlay.name]
					)
				checked += 1
	assert_gt(checked, 0, "some lush or dry grass shows a season's look")


func test_loading_in_any_order_matches_a_full_redraw() -> void:
	for day: int in DAYS:
		var reversed := CHUNKS.duplicate()
		reversed.reverse()
		for order in [CHUNKS, reversed]:
			_set_day(day)
			for coords: Vector2i in order:
				_view._load_chunk(coords)
			_assert_matches_full_redraw("day %d, order %s" % [day, order])
			for coords: Vector2i in order:
				_view._unload_chunk(coords)


func test_chunks_loading_between_refresh_steps_match_a_full_redraw() -> void:
	for day: int in DAYS:
		_set_day(day - 20)
		_view._load_chunk(CHUNKS[0])
		_view._load_chunk(CHUNKS[1])
		_view.finish_refresh()
		_set_day(day)
		_view._refresh_step()
		_view._load_chunk(CHUNKS[2])
		_view._refresh_step()
		_view._refresh_step()
		_view._load_chunk(CHUNKS[3])
		_assert_matches_full_redraw("day %d" % day)
		for coords: Vector2i in CHUNKS:
			_view._unload_chunk(coords)


func test_unloading_a_chunk_erases_every_layer_and_overlay_in_it() -> void:
	var layers: Array[TileMapLayer] = []
	layers.append_array(_view._layers)
	layers.append_array(_view._overlays.values())
	layers.append_array(_view._variety_overlays.values())
	var first := Chunk.to_world(CHUNKS[0], Vector2i.ZERO)
	var area := Rect2i(first, Vector2i.ONE * Chunk.CHUNK_SIZE)
	for day: int in DAYS:
		_set_day(day)
		_view._load_chunk(CHUNKS[0])
		_view.finish_refresh()
		assert_gt(_cells_in(layers, area), 0, "day %d: the chunk is drawn" % day)
		_view._unload_chunk(CHUNKS[0])
		assert_eq(_cells_in(layers, area), 0, "day %d: nothing is left after unloading" % day)


func _cells_in(layers: Array, area: Rect2i) -> int:
	var count := 0
	for layer: TileMapLayer in layers:
		for cell in layer.get_used_cells():
			count += 1 if area.has_point(cell) else 0
	return count
