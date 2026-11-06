extends GutTest
## WorldView draws the ground of the coast: the tidal mud keeps its look in every season and
## weather, and the salt marsh takes the looks of its season like the grass it lies on.

const SEED := 1
const CHUNK := Vector2i(-1, -1)
const SUMMER := 45
## Deep in autumn, when every tile has its autumn look.
const AUTUMN := 75
const WINTER := 105

var _view: WorldView


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_view.show_world(World.new(SEED))
	_view.world.clock.day = SUMMER
	_view.refresh_looks(SUMMER, 0.0, 0.0)
	_view.finish_refresh()
	_view._load_chunk(CHUNK)


## Lays a 3x3 patch of `terrain` around the middle of the chunk and gives its middle tile.
func _patch_of(terrain: Tile.Terrain) -> Vector2i:
	var middle := Chunk.to_world(CHUNK, Vector2i.ONE * Chunk.CHUNK_SIZE / 2)
	for y in range(-1, 2):
		for x in range(-1, 2):
			_view.world.set_terrain(middle + Vector2i(x, y), terrain)
	return middle


func _show(day: int, snow: float) -> void:
	_view.world.clock.day = day
	_view.refresh_looks(day, snow, 0.0)
	_view.finish_refresh()


func test_the_mud_has_no_season_or_snow_drawn_over_it() -> void:
	var tile := _patch_of(Tile.Terrain.MUD)
	assert_ne(_view._layers[TerrainTileset.Layer.MUD].get_cell_source_id(tile), -1)
	_show(AUTUMN, 0.0)
	assert_eq(_view._overlays[SeasonBlend.Look.AUTUMN].get_cell_source_id(tile), -1)
	_show(WINTER, 1.0)
	assert_eq(_view._overlays[SeasonBlend.Look.SNOW].get_cell_source_id(tile), -1)
	assert_false(_view.is_snowed_over(tile))


func test_the_salt_marsh_has_its_own_autumn_look() -> void:
	var tile := _patch_of(Tile.Terrain.SALT_MARSH)
	assert_ne(_view._layers[TerrainTileset.Layer.SALT_MARSH].get_cell_source_id(tile), -1)
	_show(AUTUMN, 0.0)
	var overlay := _view._variety_overlays[Vector2i(
		SeasonBlend.Look.AUTUMN, TerrainTileset.Layer.SALT_MARSH
	)]
	assert_eq(overlay.get_cell_atlas_coords(tile).y, TerrainTileset.Layer.SALT_MARSH)


func test_snow_covers_the_salt_marsh() -> void:
	var tile := _patch_of(Tile.Terrain.SALT_MARSH)
	_show(WINTER, 1.0)
	assert_ne(_view._overlays[SeasonBlend.Look.SNOW].get_cell_source_id(tile), -1)
