extends GutTest
## The fog of war on the world map: unexplored land is dimmed and greyed but readable, explored
## land is clear, and the edge between them is soft.

const CENTRE := Vector2i(16, 16)

var _clear: Image
var _exploration: Exploration


func before_each() -> void:
	_exploration = Exploration.new()
	# Two colours that must stay apart in the fog: water and grass.
	_clear = Image.create_empty(Chunk.CHUNK_SIZE, Chunk.CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	_clear.fill(MapColors.TERRAIN_COLORS[Tile.Terrain.GRASS])
	_clear.set_pixelv(Vector2i(3, 3), MapColors.TERRAIN_COLORS[Tile.Terrain.WATER])


func _distance(one: Color, other: Color) -> float:
	return absf(one.r - other.r) + absf(one.g - other.g) + absf(one.b - other.b)


func test_fogged_land_is_dimmer_and_less_colourful_than_clear_land() -> void:
	var foggy := MapFog.foggy(_clear)

	var grass_clear := _clear.get_pixelv(Vector2i(10, 10))
	var grass_foggy := foggy.get_pixelv(Vector2i(10, 10))
	assert_lt(grass_foggy.s, grass_clear.s)
	assert_lt(grass_foggy.v, grass_clear.v)


func test_fogged_land_is_still_readable() -> void:
	var foggy := MapFog.foggy(_clear)

	var grass := foggy.get_pixelv(Vector2i(10, 10))
	var water := foggy.get_pixelv(Vector2i(3, 3))
	assert_gt(_distance(grass, water), 0.25, "water and grass stay apart")


func test_land_with_nothing_explored_about_it_is_the_foggy_look() -> void:
	var foggy := MapFog.foggy(_clear)

	var shown := MapFog.apply(_clear, foggy, _exploration, Vector2i(5, 5))

	assert_same(shown, foggy)


func test_land_explored_to_its_edges_is_the_clear_picture() -> void:
	# Every 8 tiles, over the chunk and the ones about it, so that no tile is out of sight.
	for y in range(-40, 72, 8):
		for x in range(-40, 72, 8):
			_exploration.see(Vector2i(x, y))
	var foggy := MapFog.foggy(_clear)

	assert_same(MapFog.apply(_clear, foggy, _exploration, Vector2i.ZERO), _clear)


func test_the_land_the_player_stands_on_is_clear_and_the_land_far_off_is_fogged() -> void:
	_exploration.see(CENTRE)
	var foggy := MapFog.foggy(_clear)

	var shown := MapFog.apply(_clear, foggy, _exploration, Vector2i.ZERO)

	assert_eq(shown.get_pixelv(CENTRE), _clear.get_pixelv(CENTRE))
	assert_eq(shown.get_pixelv(Vector2i(3, 3)), foggy.get_pixelv(Vector2i(3, 3)))


func test_the_edge_of_the_fog_is_soft() -> void:
	_exploration.see(CENTRE)
	var foggy := MapFog.foggy(_clear)

	var shown := MapFog.apply(_clear, foggy, _exploration, Vector2i.ZERO)

	var edge_row := CENTRE.y
	var between := 0
	for x in range(CENTRE.x, Chunk.CHUNK_SIZE):
		var pixel := shown.get_pixel(x, edge_row)
		if pixel != _clear.get_pixel(x, edge_row) and pixel != foggy.get_pixel(x, edge_row):
			between += 1
	assert_gte(between, MapFog.SOFT_RADIUS, "tiles that are neither clear nor foggy")


func test_a_chunk_beside_the_explored_land_is_foggy_at_its_edge_only_softly() -> void:
	_exploration.see(Vector2i(Chunk.CHUNK_SIZE - 2, CENTRE.y))
	var foggy := MapFog.foggy(_clear)

	var shown := MapFog.apply(_clear, foggy, _exploration, Vector2i(1, 0))

	assert_eq(shown.get_pixelv(Vector2i(0, CENTRE.y)), _clear.get_pixelv(Vector2i(0, CENTRE.y)))
	assert_eq(shown.get_pixelv(Vector2i(31, 0)), foggy.get_pixelv(Vector2i(31, 0)))
