extends GutTest
## WorldView draws worn grass on the trodden and path layers, redraws only around a tile whose
## wear changed, and a worn tile loses its flowers and tufts.

const SEED := 1
const CHUNK := Vector2i(-1, -1)
const SUMMER := 45
## Deep in autumn, when every tile has its autumn look.
const AUTUMN := 75
const WINTER := 105

var _view: WorldView
var _rules := PathRules.default_rules()


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_view.show_world(World.new(SEED))
	_view.world.clock.day = SUMMER
	_view.refresh_looks(SUMMER, 0.0, 0.0)
	_view.finish_refresh()
	_view._load_chunk(CHUNK)


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
	return TerrainTileset.layer_of(_view._code_at(tile))


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


func test_a_path_has_its_own_look_in_autumn() -> void:
	var tile := _flower_tile()
	_wear(tile, _rules.path_from())
	_view.world.clock.day = AUTUMN
	_view.refresh_looks(AUTUMN, 0.0, 0.0)
	_view.finish_refresh()
	assert_eq(TerrainTileset.season_of(_view._code_at(tile)), SeasonBlend.Look.AUTUMN)
	var overlay := _view._variety_overlays[Vector2i(
		SeasonBlend.Look.AUTUMN, TerrainTileset.Layer.PATH
	)]
	assert_eq(
		overlay.get_cell_atlas_coords(tile).y, TerrainTileset.Layer.PATH, "drawn from the path row"
	)


func test_snow_covers_a_path_and_shows_a_trodden_track() -> void:
	var tile := _flower_tile()
	_wear(tile, _rules.path_from())
	_view.world.clock.day = WINTER
	_view.refresh_looks(WINTER, 1.0, 0.0)
	_view.finish_refresh()
	assert_eq(TerrainTileset.weather_of(_view._code_at(tile)), SeasonBlend.Look.SNOW)
	assert_ne(_view._overlays[SeasonBlend.Look.SNOW].get_cell_source_id(tile), -1, "snow on it")
	assert_eq(
		_view._snow_track.get_cell_atlas_coords(tile).y,
		TerrainTileset.Layer.TRODDEN,
		"the track: trodden snow"
	)
