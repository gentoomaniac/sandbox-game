extends GutTest
## SeaSearch finds the way to the nearest water of the sea by looking at a coarse grid, not at
## every tile.

const FAR_WEST := -64

var _world: World
var _search := SeaSearch.new()


func before_each() -> void:
	_world = World.new(1, GameClock.new())
	_search.world = _world
	_search.step = 6
	_search.is_flooded_mud_sea = true


## Loads chunks -4..3 by -2..1, all of `terrain`, and then makes the tiles west of `shore_x` sea.
func _make_shore(terrain: Tile.Terrain, shore_x: int) -> void:
	for y in range(-2, 2):
		for x in range(-4, 4):
			_world.add_chunk(Chunk.new(Vector2i(x, y), terrain))
	for y in range(-64, 64):
		for x in range(-128, shore_x):
			_world.chunk_at(Chunk.world_to_chunk(Vector2i(x, y))).set_terrain(
				Chunk.local_pos(Vector2i(x, y)), Tile.Terrain.SEA
			)


func test_the_sea_to_the_west_is_found_to_the_tile() -> void:
	_make_shore(Tile.Terrain.GRASS, -40)
	for start_x in [-30, -29, -28, -27, -20]:
		var way := _search.nearest(Vector2i(start_x, 0), 60.0, 1.0)
		assert_eq(way, Vector2(-41 - start_x, 0), "from x %d" % start_x)


func test_no_sea_within_the_radius_is_infinity() -> void:
	_make_shore(Tile.Terrain.GRASS, -40)
	assert_eq(_search.nearest(Vector2i(0, 0), 30.0, 1.0), Vector2.INF)
	assert_ne(_search.nearest(Vector2i(0, 0), 60.0, 1.0), Vector2.INF)


func test_the_nearest_of_two_shores_is_found() -> void:
	_make_shore(Tile.Terrain.GRASS, -40)
	for x in range(24, 32):
		_world.chunk_at(Vector2i(0, 0)).set_terrain(Vector2i(x, 5), Tile.Terrain.SEA)
	var way := _search.nearest(Vector2i(40, 5), 60.0, 1.0)
	assert_eq(way, Vector2(-9, 0), "the pond 9 away, not the shore 80 away")


func test_unloaded_chunks_are_no_water_and_cost_nothing() -> void:
	assert_eq(_search.nearest(Vector2i(0, 0), 60.0, 1.0), Vector2.INF)


func test_fresh_water_is_not_the_sea() -> void:
	_make_shore(Tile.Terrain.WATER, -1000)
	assert_eq(_search.nearest(Vector2i(0, 0), 60.0, 1.0), Vector2.INF)


func test_flooded_mud_is_sea_at_high_water_and_not_at_low_water() -> void:
	_make_shore(Tile.Terrain.MUD, FAR_WEST)
	assert_eq(_search.nearest(Vector2i(0, 0), 20.0, 1.0), Vector2.ZERO, "all under water")
	var at_low := _search.nearest(Vector2i(0, 0), 20.0, 0.0)
	assert_gt(at_low.length(), 3.0, "the flats lie dry at low water: %s" % at_low)


func test_the_flag_takes_the_mud_out_of_the_sea() -> void:
	_make_shore(Tile.Terrain.MUD, FAR_WEST)
	_search.is_flooded_mud_sea = false
	assert_eq(_search.nearest(Vector2i(0, 0), 20.0, 1.0), Vector2.INF)


func test_the_grid_is_nearest_first_and_within_the_chunks_kept_loaded() -> void:
	var grid := SeaSearch.grid(6)
	assert_eq(grid[0], Vector2i.ZERO)
	for index in range(1, grid.size()):
		assert_true(grid[index].length_squared() >= grid[index - 1].length_squared())
	assert_lt(grid.size(), 1000, "under a thousand samples")
	assert_lte(SeaSearch.MAX_RADIUS, float(ChunkResidency.LOAD_RADIUS * Chunk.CHUNK_SIZE))


func test_a_search_over_the_whole_grid_is_cheap() -> void:
	_make_shore(Tile.Terrain.MUD, FAR_WEST)
	var start := Time.get_ticks_usec()
	for index in 20:
		_search.nearest(Vector2i(60 + index, 0), SeaSearch.MAX_RADIUS, 0.0)
	var millis := (Time.get_ticks_usec() - start) / 20000.0
	gut.p("worst case, all mud, no water in reach: %.2f ms per search" % millis)
	assert_lt(millis, 10.0)
