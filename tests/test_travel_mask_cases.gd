extends TravelMaskCase
## What a mask says of the things that stand in the way, one by one: the player's changes of the
## world (objects, buildings, soil, wear), the plants of the season, the tide and what the generator
## makes. Each is also checked against the loaded chunk.


func before_each() -> void:
	super()
	load_chunk_and_neighbours(COAST)
	load_chunk_and_neighbours(MUD)


func test_an_object_taken_off_no_longer_blocks() -> void:
	var willow := find_object(COAST, WorldObjectTypes.WILLOW)
	assert_false(mask_is_free(willow.pos), "the willow blocks")
	world.take_off(willow)
	assert_true(mask_is_free(willow.pos), "and no more once it is gone")
	assert_parity(COAST)


func test_an_object_put_down_blocks() -> void:
	var tile := empty_row(COAST, Tile.Terrain.GRASS)
	assert_true(mask_is_free(tile))
	world.add_object(WorldObject.new(WorldObjectTypes.STONE, tile))
	assert_false(mask_is_free(tile))
	assert_parity(COAST)


func test_a_big_object_whose_origin_is_west_blocks_the_tiles_it_reaches() -> void:
	var west := COAST + Vector2i.LEFT
	var ewer := put_down_on_grass(WorldObjectTypes.EWER, tile_of(west, Vector2i(28, 10)))
	for tile in ewer.tiles():
		assert_false(mask_is_free(tile), "%s is under the ewer" % tile)
	assert_true(Chunk.world_to_chunk(ewer.tiles().back()) == COAST, "it reaches into the chunk")
	assert_parity(COAST)


func test_a_big_object_whose_origin_is_north_blocks_the_tiles_it_reaches() -> void:
	var north := COAST + Vector2i.UP
	var bed := put_down_on_grass(WorldObjectTypes.SMALL_BED, tile_of(north, Vector2i(5, 31)))
	assert_false(mask_is_free(tile_of(COAST, Vector2i(5, 0))), "the foot of the bed")
	assert_true(world.object_at(tile_of(COAST, Vector2i(5, 0))) == bed)
	assert_parity(COAST)


func test_a_big_object_whose_origin_is_north_west_blocks_the_corner() -> void:
	var north_west := COAST + Vector2i(-1, -1)
	put_down_on_grass(WorldObjectTypes.HEARTH, tile_of(north_west, Vector2i(31, 31)))
	assert_false(mask_is_free(tile_of(COAST, Vector2i(0, 0))))
	assert_parity(COAST)


func test_generated_big_objects_across_a_chunk_border_are_stamped() -> void:
	var crossing := 0
	for y in range(-5, -2):
		for x in range(-10, -6):
			var coords := Vector2i(x, y)
			load_chunk_and_neighbours(coords)
			for object in world.chunk_at(coords).objects():
				if object.tiles().any(
					func(t: Vector2i) -> bool: return Chunk.world_to_chunk(t) != coords
				):
					crossing += 1
					for tile in object.tiles():
						load_chunk_and_neighbours(Chunk.world_to_chunk(tile))
	assert_gt(crossing, 0, "a boulder or ewer lies across a border")
	for y in range(-5, -2):
		for x in range(-10, -6):
			assert_parity(Vector2i(x, y))


func test_a_building_and_its_door_tile_are_closed_but_not_by_the_mask() -> void:
	var building: Building = null
	for y in range(0, Chunk.CHUNK_SIZE, 3):
		for x in range(0, Chunk.CHUNK_SIZE, 3):
			if building == null:
				building = world.place_building(BuildingTypes.SHACK, tile_of(COAST, Vector2i(x, y)))
	assert_not_null(building, "a shack fits somewhere")
	var door := building.door_tile()
	assert_false(Npcs.can_stand_at(world, Vector2(door) + Vector2(0.5, 0.5)), "the door is closed")
	assert_true(mask_is_free(door), "the mask does not know buildings")
	assert_parity(COAST)


func test_a_gate_is_walked_through_and_a_player_fence_is_not() -> void:
	var tile := empty_row(COAST, Tile.Terrain.GRASS, 3)
	world.add_object(WorldObject.new(WorldObjectTypes.PEN_FENCE, tile))
	world.add_object(WorldObject.new(WorldObjectTypes.PEN_GATE, tile + Vector2i.RIGHT))
	world.add_object(WorldObject.new(WorldObjectTypes.PEN_GATE_OPEN, tile + Vector2i(2, 0)))
	assert_false(mask_is_free(tile), "the fence")
	assert_true(mask_is_free(tile + Vector2i.RIGHT), "the gate")
	assert_true(mask_is_free(tile + Vector2i(2, 0)), "the open gate")
	var mask := masks.wait_for_mask(COAST)
	assert_false(
		mask.is_trampled(Chunk.local_pos(tile + Vector2i.RIGHT), 1), "nobody spoils a gate"
	)
	assert_parity(COAST)


func test_an_object_that_is_spoiled_by_feet_costs_more() -> void:
	var reeds := find_object(COAST, WorldObjectTypes.REEDS)
	var mask := masks.wait_for_mask(COAST)
	assert_true(mask.is_free(Chunk.local_pos(reeds.pos), 0.0, 1))
	assert_true(mask.is_trampled(Chunk.local_pos(reeds.pos), 1))


func test_tilled_soil_does_not_wear_and_grass_does() -> void:
	var tile := empty_row(COAST, Tile.Terrain.GRASS, 2)
	var mask := masks.wait_for_mask(COAST)
	assert_true(mask.wears(Chunk.local_pos(tile)))
	world.set_terrain(tile, Tile.Terrain.SOIL)
	mask = masks.wait_for_mask(COAST)
	assert_false(mask.wears(Chunk.local_pos(tile)))
	assert_true(mask.is_free(Chunk.local_pos(tile), 0.0, 1))
	assert_parity(COAST)


func test_a_worn_path_stays_grass_for_the_mask_and_the_wear_is_the_world_s() -> void:
	var tile := empty_row(COAST, Tile.Terrain.GRASS)
	world.set_wear_days(tile, PathRules.default_rules().path_after_days())
	assert_eq(world.wear_stage(tile), PathRules.Stage.PATH)
	assert_true(masks.wait_for_mask(COAST).wears(Chunk.local_pos(tile)))
	assert_parity(COAST)


func test_a_way_is_known_to_the_mask_and_the_grass_under_it_does_not_wear() -> void:
	var tile := empty_row(COAST, Tile.Terrain.GRASS, 2)
	var mask := masks.wait_for_mask(COAST)
	assert_false(mask.is_way(Chunk.local_pos(tile)))
	assert_true(mask.wears(Chunk.local_pos(tile)))
	for type in [WorldObjectTypes.PLANK_WALK, WorldObjectTypes.STONE_PATH]:
		world.remove_object(tile)
		world.add_object(WorldObject.new(type, tile))
		mask = masks.wait_for_mask(COAST)
		assert_true(mask.is_way(Chunk.local_pos(tile)), str(type))
		assert_false(mask.wears(Chunk.local_pos(tile)), str(type))
		assert_true(mask.is_free(Chunk.local_pos(tile), 0.0, 1), str(type))
		assert_false(mask.is_trampled(Chunk.local_pos(tile), 1), str(type))
		assert_parity(COAST, str(type))


func test_a_deck_over_mud_is_walked_at_high_water() -> void:
	var tile := empty_row(MUD, Tile.Terrain.MUD)
	set_high_water()
	assert_false(mask_is_free(tile), "the mud is flooded")
	world.add_object(WorldObject.new(WorldObjectTypes.JETTY, tile))
	assert_true(mask_is_free(tile), "the jetty is not")
	assert_parity(MUD, "at high water")
	set_low_water()
	assert_true(mask_is_free(tile))
	assert_parity(MUD, "at low water")


func test_mud_with_a_boat_on_it_is_blocked_at_low_water_too() -> void:
	load_chunk_and_neighbours(Vector2i(-10, 4))
	var ewer := find_object(Vector2i(-10, 4), WorldObjectTypes.EWER)
	set_low_water()
	assert_false(mask_is_free(ewer.pos))
	assert_parity(Vector2i(-10, 4))


func test_a_seasonal_plant_blocks_nothing_and_costs_something_only_when_it_is_present() -> void:
	var tile := empty_row(COAST, Tile.Terrain.GRASS)
	var fern := WorldObject.new(WorldObjectTypes.FERN_BUSH, tile)
	world.add_object(fern)
	var present_day := 0
	var dormant_day := 0
	for day in range(1, GameClock.DAYS_PER_YEAR + 1):
		if world.vegetation.is_present(fern.type, SEED, tile, day):
			present_day = day
		else:
			dormant_day = day
	assert_ne(present_day * dormant_day, 0, "the fern is there in some season and not in another")
	var mask := masks.wait_for_mask(COAST)
	world.clock.day = present_day
	assert_true(mask.is_trampled(Chunk.local_pos(tile), present_day), "present")
	assert_parity(COAST, "present")
	world.clock.day = dormant_day
	assert_false(mask.is_trampled(Chunk.local_pos(tile), dormant_day), "dormant costs nothing")
	assert_parity(COAST, "dormant")


func test_a_ditch_and_the_dyke_and_the_hedge_are_as_the_loaded_chunk_has_them() -> void:
	var ditch: Array[Vector2i] = []
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			if generator.is_ditch(tile_of(COAST + Vector2i.RIGHT, Vector2i(x, y))):
				ditch.append(Vector2i(x, y))
	load_chunk_and_neighbours(COAST + Vector2i.RIGHT)
	assert_gt(ditch.size(), 0, "a ditch in the chunk")
	assert_false(mask_is_free(tile_of(COAST + Vector2i.RIGHT, ditch[0])), "water")
	find_object(COAST, WorldObjectTypes.DYKE)
	find_object(COAST + Vector2i.RIGHT, WorldObjectTypes.KNICK)
	assert_parity(COAST)
	assert_parity(COAST + Vector2i.RIGHT)
