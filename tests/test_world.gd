extends GutTest
## World: chunk coordinates, bounds, tile access and changes to loaded chunks.

const SIZE := Chunk.CHUNK_SIZE
const HALF := World.MAX_SIZE_CHUNKS / 2


func test_world_to_chunk_and_local() -> void:
	var cases := [
		[Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)],
		[Vector2i(SIZE - 1, SIZE - 1), Vector2i(0, 0), Vector2i(SIZE - 1, SIZE - 1)],
		[Vector2i(SIZE, 0), Vector2i(1, 0), Vector2i(0, 0)],
		[Vector2i(-1, -1), Vector2i(-1, -1), Vector2i(SIZE - 1, SIZE - 1)],
		[Vector2i(-SIZE, -SIZE), Vector2i(-1, -1), Vector2i(0, 0)],
		[Vector2i(-SIZE - 1, 5), Vector2i(-2, 0), Vector2i(SIZE - 1, 5)],
	]
	for c in cases:
		assert_eq(Chunk.world_to_chunk(c[0]), c[1], "chunk of %s" % c[0])
		assert_eq(Chunk.local_pos(c[0]), c[2], "local of %s" % c[0])
		assert_eq(Chunk.to_world(c[1], c[2]), c[0], "round trip of %s" % c[0])


func test_bounds_are_centred_on_origin() -> void:
	assert_true(World.is_chunk_in_bounds(Vector2i(-HALF, -HALF)))
	assert_true(World.is_chunk_in_bounds(Vector2i(HALF - 1, HALF - 1)))
	assert_false(World.is_chunk_in_bounds(Vector2i(-HALF - 1, 0)))
	assert_false(World.is_chunk_in_bounds(Vector2i(0, HALF)))


func test_tile_bounds_at_edges() -> void:
	assert_true(World.is_in_bounds(Vector2i(-HALF * SIZE, -HALF * SIZE)))
	assert_true(World.is_in_bounds(Vector2i(HALF * SIZE - 1, HALF * SIZE - 1)))
	assert_false(World.is_in_bounds(Vector2i(-HALF * SIZE - 1, 0)))
	assert_false(World.is_in_bounds(Vector2i(0, HALF * SIZE)))


func test_tile_at_loaded_chunk() -> void:
	var world := World.new(1)
	var chunk := Chunk.new(Vector2i(-1, 0))
	chunk.set_terrain(Vector2i(SIZE - 1, 3), Tile.Terrain.WATER)
	world.add_chunk(chunk)
	assert_eq(world.tile_at(Vector2i(-1, 3)).terrain, Tile.Terrain.WATER)
	assert_eq(world.tile_at(Vector2i(-2, 3)).terrain, Tile.Terrain.GRASS)


func test_tile_at_unloaded_or_out_of_bounds_is_null() -> void:
	var world := World.new(1)
	assert_null(world.tile_at(Vector2i(0, 0)))
	assert_null(world.tile_at(Vector2i(HALF * SIZE, 0)))


func test_chunk_setters_change_state() -> void:
	var chunk := Chunk.new(Vector2i.ZERO)
	var local := Vector2i(4, 7)
	chunk.set_terrain(local, Tile.Terrain.WATER)
	chunk.set_water_level(local, 0.5)
	chunk.set_frozen(local, true)
	chunk.set_snow_depth(local, 0.25)
	var tile := chunk.tile_at(local)
	assert_eq(tile.terrain, Tile.Terrain.WATER)
	assert_eq(tile.water_level, 0.5)
	assert_true(tile.frozen)
	assert_eq(tile.snow_depth, 0.25)
	assert_eq(chunk.tile_at(Vector2i(7, 4)).terrain, Tile.Terrain.GRASS)


func test_chunk_read_accessors() -> void:
	var chunk := Chunk.new(Vector2i.ZERO)
	var local := Vector2i(3, 4)
	chunk.set_terrain(local, Tile.Terrain.WATER)
	chunk.set_water_level(local, 0.5)
	chunk.set_frozen(local, true)
	chunk.set_snow_depth(local, 0.25)
	assert_eq(chunk.terrain_at(local), Tile.Terrain.WATER)
	assert_eq(chunk.water_level_at(local), 0.5)
	assert_true(chunk.is_frozen_at(local))
	assert_eq(chunk.snow_depth_at(local), 0.25)
