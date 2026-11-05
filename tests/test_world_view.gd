extends GutTest
## WorldView's chunk borders: cells on a border between two chunks must end up drawn from
## both chunks' terrain, whichever chunk loads first. Drives WorldView's private loading
## and reads its layers directly, since streaming itself is covered by ChunkStreaming.

const SEED := 1
## Chunks by the river whose shared borders cross terrain edges, so a fallback that
## copies the loaded side differs from the real terrain.
const LEFT := Vector2i(-2, -1)
const RIGHT := Vector2i(-1, -1)
const BELOW := Vector2i(-1, 0)

var _generator := WorldGenerator.new(SEED)
var _view: WorldView


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_view.show_world(World.new(SEED))


func test_right_neighbour_loaded_second_blends_its_border() -> void:
	_view._load_chunk(LEFT)
	_view._load_chunk(RIGHT)
	_assert_drawn_from_terrain(_left_column(RIGHT))


func test_left_neighbour_loaded_second_fixes_up_the_fallback() -> void:
	_view._load_chunk(RIGHT)
	var border := _left_column(RIGHT)
	_assert_drawn_with_fallback(border)
	_view._load_chunk(LEFT)
	_assert_drawn_from_terrain(border)


func test_bottom_neighbour_loaded_first_is_fixed_up_too() -> void:
	_view._load_chunk(BELOW)
	# Leaves out the corner cell: it also touches the diagonal chunk, which stays unloaded.
	var top_row: Array[Vector2i] = []
	for x in range(1, Chunk.CHUNK_SIZE):
		top_row.append(Chunk.to_world(BELOW, Vector2i(x, 0)))
	_assert_drawn_with_fallback(top_row)
	_view._load_chunk(RIGHT)
	_assert_drawn_from_terrain(top_row)


func test_unloading_erases_the_chunks_cells() -> void:
	_view._load_chunk(RIGHT)
	_view._unload_chunk(RIGHT)
	for cell in _left_column(RIGHT):
		assert_eq(_drawn(cell), _empty())


## The cells owned by `coords` that also touch its left neighbour.
func _left_column(coords: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in Chunk.CHUNK_SIZE:
		cells.append(Chunk.to_world(coords, Vector2i(0, y)))
	return cells


func _assert_drawn_from_terrain(cells: Array[Vector2i]) -> void:
	var blended := 0
	for cell in cells:
		var expected := _expected(cell)
		assert_eq(_drawn(cell), expected, "cell %s" % cell)
		if expected.count(Vector2i(-1, -1)) < TerrainTileset.LAYER_COUNT - 1:
			blended += 1
	assert_gt(blended, 0, "the border crosses at least one terrain edge")


## Every cell is drawn, but with the neighbour missing at least one is not what the real
## terrain gives yet.
func _assert_drawn_with_fallback(cells: Array[Vector2i]) -> void:
	var guessed := 0
	for cell in cells:
		assert_ne(_drawn(cell), _empty(), "fallback drawn at %s" % cell)
		if _drawn(cell) != _expected(cell):
			guessed += 1
	assert_gt(guessed, 0, "the fallback differs from the real terrain somewhere")


## The atlas cell of each layer at `cell`, as drawn.
func _drawn(cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for tile_map in _view._layers:
		cells.append(tile_map.get_cell_atlas_coords(cell))
	return cells


func _empty() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.resize(TerrainTileset.LAYER_COUNT)
	cells.fill(Vector2i(-1, -1))
	return cells


## What each layer should show at `cell`, worked out from the generator's terrain.
func _expected(cell: Vector2i) -> Array[Vector2i]:
	var corners := PackedInt32Array()
	for offset in WorldView.CORNER_OFFSETS:
		var tile := cell + offset
		corners.append(_view._layer_of_tile(_generator.terrain_at(tile), tile))
	var cells := _empty()
	var drawn := TerrainTileset.drawn_layers(corners)
	for layer in TerrainTileset.LAYER_COUNT:
		if drawn & (1 << layer):
			var mask := TerrainTileset.mask_for(corners, layer)
			cells[layer] = _view._tileset.atlas_cell(layer, mask, cell)
	return cells
