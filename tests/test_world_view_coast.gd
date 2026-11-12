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
var _residency: ChunkResidency


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_residency = ChunkResidency.new(World.new(SEED))
	_view.show_world(_residency)
	_view.world.clock.day = SUMMER
	_view.refresh_looks(SUMMER)
	_view.finish_refresh()
	_residency.load_chunk(CHUNK)
	_view.finish_drawing()


## Lays a 3x3 patch of `terrain` around the middle of the chunk and gives its middle tile.
func _patch_of(terrain: Tile.Terrain) -> Vector2i:
	var middle := Chunk.to_world(CHUNK, Vector2i.ONE * Chunk.CHUNK_SIZE / 2)
	for y in range(-1, 2):
		for x in range(-1, 2):
			_view.world.set_terrain(middle + Vector2i(x, y), terrain)
	return middle


func _show(day: int, snow: float) -> void:
	_view.world.clock.day = day
	_view.show_ground_cover(day, snow, 0.0, 0.0)


func test_the_mud_has_no_season_or_snow_over_it() -> void:
	var tile := _patch_of(Tile.Terrain.MUD)
	assert_ne(_view._layers[TerrainTileset.Layer.MUD].get_cell_source_id(tile), -1)
	assert_eq(_view._layers[TerrainTileset.Layer.MUD].material, _view.ambient_motion.mud)
	_show(WINTER, 1.0)
	assert_false(_view.is_snowed_over(tile), "the tide washes it clear")
	assert_eq(_view._cover_map.channels_at(tile).g, 0.0, "it catches no snow")


func test_snow_covers_the_salt_marsh() -> void:
	var tile := _patch_of(Tile.Terrain.SALT_MARSH)
	_show(WINTER, 1.0)
	assert_true(_view.is_snowed_over(tile))


func test_the_salt_marsh_is_drawn_from_its_own_layer() -> void:
	var tile := _patch_of(Tile.Terrain.SALT_MARSH)
	assert_ne(_view._layers[TerrainTileset.Layer.SALT_MARSH].get_cell_source_id(tile), -1)
