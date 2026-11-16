extends GutTest
## WorldView draws worn ground muddy in the rain, in the muddy look of its stage.

const SEED := 1
const CHUNK := Vector2i(-1, -1)

var _view: WorldView
var _residency: ChunkResidency
var _tile: Vector2i


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_residency = ChunkResidency.new(World.new(SEED))
	_view.show_world(_residency)
	_view.world.clock.day = 45
	_view.refresh_looks(45)
	_view.finish_refresh()
	_residency.load_chunk(CHUNK)
	_view.finish_drawing()
	_tile = _grass_tile()


func _grass_tile() -> Vector2i:
	var origin := Chunk.to_world(CHUNK, Vector2i.ZERO)
	for y in range(2, Chunk.CHUNK_SIZE - 2):
		for x in range(2, Chunk.CHUNK_SIZE - 2):
			if _view.world.tile_at(origin + Vector2i(x, y)).wears():
				return origin + Vector2i(x, y)
	fail_test("no grass in chunk %s" % CHUNK)
	return origin


func test_a_path_is_drawn_muddy_in_the_rain_and_dry_again_after() -> void:
	_view.world.set_wear_days(_tile, PathRules.default_rules().path_after_days())
	assert_eq(_view._terrain.layer_at(_tile), TerrainTileset.Layer.PATH)
	_view.world.set_muddy(true)
	assert_eq(_view._terrain.layer_at(_tile), TerrainTileset.Layer.MUDDY_PATH)
	var muddy: TileMapLayer = _view._terrain.layers[TerrainTileset.Layer.MUDDY_PATH]
	assert_ne(muddy.get_cell_source_id(_tile), -1, "the cell is drawn")
	_view.world.set_muddy(false)
	assert_eq(_view._terrain.layer_at(_tile), TerrainTileset.Layer.PATH)
	assert_eq(muddy.get_cell_source_id(_tile), -1, "and gone")


func test_trodden_grass_is_drawn_muddy_too() -> void:
	_view.world.set_wear_days(_tile, PathRules.default_rules().trodden_after_days())
	_view.world.set_muddy(true)
	assert_eq(_view._terrain.layer_at(_tile), TerrainTileset.Layer.MUDDY_TRODDEN)


func test_unworn_grass_is_not_muddy() -> void:
	var layer: int = _view._terrain.layer_at(_tile)
	_view.world.set_muddy(true)
	assert_eq(_view._terrain.layer_at(_tile), layer)


func test_a_chunk_that_loads_in_the_rain_is_drawn_muddy() -> void:
	_view.world.set_wear_days(_tile, PathRules.default_rules().path_after_days())
	_view.world.set_muddy(true)
	_residency.unload_chunk(CHUNK)
	_residency.load_chunk(CHUNK)
	_view.finish_drawing()
	assert_eq(_view._terrain.layer_at(_tile), TerrainTileset.Layer.MUDDY_PATH)
