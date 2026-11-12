extends GutTest
## WorldView draws worn grass on the trodden and path layers, redraws only around a tile whose
## wear changed, and a worn tile loses its flowers and tufts. Snow catches less on a path.

const SEED := 1
const CHUNK := Vector2i(-1, -1)
const SUMMER := 45
## Deep in autumn, when every tile has its autumn look.
const AUTUMN := 75
const WINTER := 105
## The tiles of a 2x2 block, from its top-left one.
const BLOCK: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

var _view: WorldView
var _residency: ChunkResidency
var _rules := PathRules.default_rules()


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_residency = ChunkResidency.new(World.new(SEED))
	_view.show_world(_residency)
	_view.world.clock.day = SUMMER
	_view.refresh_looks(SUMMER, 0.0, 0.0)
	_view.finish_refresh()
	_residency.load_chunk(CHUNK)
	_view.finish_drawing()


func _wear(tile: Vector2i, steps: float) -> void:
	for _i in int(steps):
		_view.world.wear_tile(tile)


## A tile of the chunk where a flower grows and that wears, or fails the test.
func _flower_tile() -> Vector2i:
	var origin := Chunk.to_world(CHUNK, Vector2i.ZERO)
	for y in range(1, Chunk.CHUNK_SIZE - 1):
		for x in range(1, Chunk.CHUNK_SIZE - 1):
			var tile := origin + Vector2i(x, y)
			if _view.decorations.has_flower(tile) and _view.world.tile_at(tile).wears():
				return tile
	fail_test("no flower in chunk %s" % CHUNK)
	return origin


func _layer_at(tile: Vector2i) -> int:
	return _view._layer_at(tile)


func test_worn_grass_is_drawn_trodden_and_then_as_a_path() -> void:
	var tile := _flower_tile()
	_wear(tile, _rules.trodden_from())
	assert_eq(_layer_at(tile), TerrainTileset.Layer.TRODDEN)
	var trodden := _view._layers[TerrainTileset.Layer.TRODDEN]
	for offset: Vector2i in WorldView.CORNER_OFFSETS:
		assert_ne(trodden.get_cell_source_id(tile - offset), -1, "the 4 cells around it")
	_wear(tile, _rules.path_from())
	assert_eq(_layer_at(tile), TerrainTileset.Layer.PATH)
	assert_ne(_view._layers[TerrainTileset.Layer.PATH].get_cell_source_id(tile), -1)


func test_a_worn_tile_loses_its_flowers_and_tufts() -> void:
	var tile := _flower_tile()
	_wear(tile, _rules.trodden_from())
	assert_false(_view.decorations.has_flower(tile))
	assert_eq(_view.decorations._decorations.get_cell_source_id(tile), -1, "no decoration")


func test_a_path_grown_back_is_grass_with_its_flowers_again() -> void:
	var tile := _flower_tile()
	var layer := _layer_at(tile)
	_wear(tile, _rules.trodden_from())
	for _i in ceili(_rules.trodden_from() / _rules.regrowth_per_night()):
		_view.world.regrow_paths()
	assert_eq(_layer_at(tile), layer)
	assert_true(_view.decorations.has_flower(tile))


## The top-left tile of a 2x2 block of tiles of the chunk that all wear, or fails the test.
func _wearing_block() -> Vector2i:
	var origin := Chunk.to_world(CHUNK, Vector2i.ZERO)
	for y in range(1, Chunk.CHUNK_SIZE - 2):
		for x in range(1, Chunk.CHUNK_SIZE - 2):
			var block := origin + Vector2i(x, y)
			if BLOCK.all(
				func(offset: Vector2i) -> bool: return _view.world.tile_at(block + offset).wears()
			):
				return block
	fail_test("no 2x2 block of grass in chunk %s" % CHUNK)
	return origin


func test_the_cell_between_worn_tiles_joins_up_as_they_all_wear() -> void:
	var block := _wearing_block()
	var middle := block + Vector2i.ONE
	var trodden := _view._layers[TerrainTileset.Layer.TRODDEN]
	for offset in BLOCK.slice(0, 3):
		_wear(block + offset, _rules.trodden_from())
		assert_lt(trodden.get_cell_atlas_coords(middle).x, TerrainTileset.FULL_COLUMN, "an edge")
	_wear(block + BLOCK[3], _rules.trodden_from())
	assert_gte(trodden.get_cell_atlas_coords(middle).x, TerrainTileset.FULL_COLUMN, "a full tile")


func test_a_path_among_trodden_tiles_is_an_edge_over_a_full_trodden_cell() -> void:
	var block := _wearing_block()
	var middle := block + Vector2i.ONE
	for offset in BLOCK:
		_wear(block + offset, _rules.trodden_from())
	_wear(block, _rules.path_from())
	var trodden := _view._layers[TerrainTileset.Layer.TRODDEN]
	var path := _view._layers[TerrainTileset.Layer.PATH]
	assert_gte(
		trodden.get_cell_atlas_coords(middle).x, TerrainTileset.FULL_COLUMN, "trodden all over"
	)
	assert_lt(path.get_cell_atlas_coords(middle).x, TerrainTileset.FULL_COLUMN, "the path's rim")


func test_snow_catches_less_on_a_path_and_clears_first_in_a_thaw() -> void:
	var tile := _flower_tile()
	var open := _view._cover_map.channels_at(tile)
	_wear(tile, _rules.path_from())
	var worn := _view._cover_map.channels_at(tile)
	assert_lt(worn.g, open.g, "a path catches less snow")
	assert_gt(worn.b, open.b, "and feels more of the thaw")
