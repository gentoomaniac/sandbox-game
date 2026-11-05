extends GutTest

const SEED := 42
## Floodplain tiles must have water within this many tiles: the floodplain is
## WorldGenerator.FLOODPLAIN_WIDTH wide, measured along y, plus one for rounding.
const MAX_WATER_DISTANCE := int(WorldGenerator.FLOODPLAIN_WIDTH) + 1


func _terrain_grid(generator: WorldGenerator, area: Rect2i) -> Dictionary[Vector2i, Tile.Terrain]:
	var grid: Dictionary[Vector2i, Tile.Terrain] = {}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			grid[Vector2i(x, y)] = generator.terrain_at(Vector2i(x, y))
	return grid


func _terrains(chunk: Chunk) -> Array[Tile.Terrain]:
	var result: Array[Tile.Terrain] = []
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			result.append(chunk.tile_at(Vector2i(x, y)).terrain)
	return result


func test_same_seed_and_coords_give_identical_chunks() -> void:
	var first := WorldGenerator.new(SEED).generate_chunk(Vector2i(1, -2))
	var second := WorldGenerator.new(SEED).generate_chunk(Vector2i(1, -2))
	assert_eq(_terrains(first), _terrains(second))


func test_generation_order_does_not_matter() -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	var generator_ab := WorldGenerator.new(SEED)
	var a_first := generator_ab.generate_chunk(a)
	var b_second := generator_ab.generate_chunk(b)
	var generator_ba := WorldGenerator.new(SEED)
	var b_first := generator_ba.generate_chunk(b)
	var a_second := generator_ba.generate_chunk(a)
	assert_eq(_terrains(a_first), _terrains(a_second))
	assert_eq(_terrains(b_second), _terrains(b_first))


func test_different_seeds_differ() -> void:
	var area := Rect2i(-64, -64, 128, 128)
	assert_ne(
		_terrain_grid(WorldGenerator.new(1), area), _terrain_grid(WorldGenerator.new(2), area)
	)


func test_chunk_out_of_bounds_is_null() -> void:
	var generator := WorldGenerator.new(SEED)
	var half := World.MAX_SIZE_CHUNKS / 2
	assert_null(generator.generate_chunk(Vector2i(half, 0)))
	assert_null(generator.generate_chunk(Vector2i(0, -half - 1)))
	assert_not_null(generator.generate_chunk(Vector2i(-half, half - 1)))


func test_chunks_are_seamless() -> void:
	var generator := WorldGenerator.new(SEED)
	var chunk := generator.generate_chunk(Vector2i(0, 0))
	var neighbour := generator.generate_chunk(Vector2i(1, 0))
	for y in Chunk.CHUNK_SIZE:
		var edge_world := Chunk.to_world(Vector2i(0, 0), Vector2i(Chunk.CHUNK_SIZE - 1, y))
		assert_eq(
			chunk.tile_at(Vector2i(Chunk.CHUNK_SIZE - 1, y)).terrain,
			generator.terrain_at(edge_world)
		)
		var next_world := Chunk.to_world(Vector2i(1, 0), Vector2i(0, y))
		assert_eq(neighbour.tile_at(Vector2i(0, y)).terrain, generator.terrain_at(next_world))


func test_area_has_every_terrain_and_floodplain_is_near_water() -> void:
	var generator := WorldGenerator.new(SEED)
	var area := Rect2i(
		-2 * Chunk.CHUNK_SIZE, -2 * Chunk.CHUNK_SIZE, 4 * Chunk.CHUNK_SIZE, 4 * Chunk.CHUNK_SIZE
	)
	var grid := _terrain_grid(generator, area)
	var seen := {}
	for terrain in grid.values():
		seen[terrain] = true
	for terrain in [
		Tile.Terrain.GRASS, Tile.Terrain.WATER, Tile.Terrain.FLOODPLAIN, Tile.Terrain.WETLAND
	]:
		assert_true(seen.has(terrain), "Missing terrain %s" % terrain)

	for pos in grid:
		if grid[pos] != Tile.Terrain.FLOODPLAIN:
			continue
		var has_water := false
		for dy in range(-MAX_WATER_DISTANCE, MAX_WATER_DISTANCE + 1):
			for dx in range(-MAX_WATER_DISTANCE, MAX_WATER_DISTANCE + 1):
				has_water = (
					has_water or generator.terrain_at(pos + Vector2i(dx, dy)) == Tile.Terrain.WATER
				)
		assert_true(has_water, "Floodplain at %s has no water nearby" % pos)
		if not has_water:
			return
