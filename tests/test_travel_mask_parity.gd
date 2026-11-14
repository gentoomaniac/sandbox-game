extends TravelMaskCase
## A mask answers what `Npcs.can_stand_at` answers on the same chunk loaded with `add_chunk`: over
## whole regions of several seeds, in the generated world.

const REGIONS: Array[Rect2i] = [Rect2i(-9, -4, 2, 2), Rect2i(0, -1, 2, 2), Rect2i(-14, -4, 1, 1)]


func _region_agrees(seed_value: int, region: Rect2i) -> void:
	make_world(seed_value)
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			load_chunk_and_neighbours(Vector2i(x, y))
	for hour in [HIGH_WATER_HOUR, LOW_WATER_HOUR]:
		world.clock.set_time(hour, 0)
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				assert_parity(Vector2i(x, y), "seed %d, hour %d" % [seed_value, hour])


func test_regions_of_seed_7_equal_the_loaded_chunks() -> void:
	for region in REGIONS:
		_region_agrees(7, region)


func test_regions_of_seed_42_equal_the_loaded_chunks() -> void:
	for region in REGIONS:
		_region_agrees(42, region)


func test_regions_of_seed_1_equal_the_loaded_chunks() -> void:
	for region in REGIONS:
		_region_agrees(1, region)


func test_the_coast_has_the_objects_that_matter() -> void:
	load_chunk_and_neighbours(COAST)
	var types := {}
	for object in world.chunk_at(COAST).objects():
		types[object.type] = true
	for type in [WorldObjectTypes.DYKE, WorldObjectTypes.WILLOW, WorldObjectTypes.REEDS]:
		assert_true(types.has(type), "%s in the chunk" % type)


func test_mud_is_blocked_at_high_water_and_free_at_low_water() -> void:
	load_chunk_and_neighbours(MUD)
	var mask := masks.wait_for_mask(MUD)
	var mud: Array[Vector2i] = []
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			if world.chunk_at(MUD).terrain_at(Vector2i(x, y)) == Tile.Terrain.MUD:
				mud.append(Vector2i(x, y))
	assert_gt(mud.size(), 100, "there is mud")
	var free_at_high := mud.filter(
		func(local: Vector2i) -> bool: return mask.is_free(local, 1.0, 1)
	)
	var free_at_low := mud.filter(func(local: Vector2i) -> bool: return mask.is_free(local, 0.0, 1))
	assert_eq(free_at_high.size(), 0, "all of it is under water at the highest water")
	assert_gt(free_at_low.size(), mud.size() * 3 / 4, "most of it is dry at the lowest")


func test_the_first_chunk_of_the_world_has_no_neighbours_to_the_west_or_north() -> void:
	var corner := Vector2i(-World.MAX_SIZE_CHUNKS / 2, -World.MAX_SIZE_CHUNKS / 2)
	load_chunk_and_neighbours(corner)
	assert_eq(TravelMasks.chunks_for(corner), [corner] as Array[Vector2i])
	assert_parity(corner, "the north west corner")


func test_the_last_chunk_of_the_world_is_made_from_its_neighbours() -> void:
	var corner := Vector2i.ONE * (World.MAX_SIZE_CHUNKS / 2 - 1)
	load_chunk_and_neighbours(corner)
	assert_eq(TravelMasks.chunks_for(corner).size(), 4)
	assert_parity(corner, "the south east corner")


func test_a_chunk_outside_the_world_has_no_mask() -> void:
	assert_null(masks.mask_of(Vector2i(-World.MAX_SIZE_CHUNKS / 2 - 1, 0)))
	assert_null(masks.wait_for_mask(Vector2i(0, World.MAX_SIZE_CHUNKS / 2)))
