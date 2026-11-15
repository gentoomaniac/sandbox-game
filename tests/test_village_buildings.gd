extends VillageCase
## The buildings of the village and its record, and a new game that has them
## (design/world/wehlsbuell.md, sections 4 and 12).


func test_the_same_seed_gives_the_same_edits_and_buildings() -> void:
	var world := World.new(1)
	assert_eq(VillageBuilder.build(world, _site(1), _plan), "")
	assert_eq(_edits_of(world), _edits_of(_world(1)))
	assert_eq(
		WorldSave.dict_of(world.snapshot())["buildings"],
		WorldSave.dict_of(_world(1).snapshot())["buildings"]
	)


func test_building_twice_is_refused() -> void:
	var reason := VillageBuilder.build(_world(1), _site(1), _plan)
	assert_string_contains(reason, "a building stands on the village's land")


func test_the_land_alone_puts_up_no_building_and_makes_no_record() -> void:
	var world := World.new(1)
	assert_eq(VillageBuilder.build_land(world, _site(1), _plan), "")
	assert_eq(world.buildings(), [] as Array[Building])
	assert_null(world.village)


func test_the_buildings_of_the_plan_stand_where_it_says() -> void:
	for world_seed: int in SEEDS:
		var world := _world(world_seed)
		assert_eq(world.buildings().size(), _plan.buildings.size())
		for entry in _plan.buildings:
			var origin := _site(world_seed).to_world(entry["origin"])
			_load(world, _generator(world_seed), origin)
			var building := world.building_at(origin)
			assert_not_null(building, "seed %d: %s" % [world_seed, entry["id"]])
			assert_eq(building.origin, origin)
			assert_eq([building.type, building.style], [entry["type"], entry["style"]])


func test_every_door_has_its_free_tile_in_front_with_the_buildings_up() -> void:
	for world_seed: int in SEEDS:
		for building in _world(world_seed).buildings():
			var front := building.door_tile() + Vector2i.DOWN
			_load(_world(world_seed), _generator(world_seed), front)
			assert_true(_world(world_seed).is_walkable(front), "%s" % building.origin)


func test_the_record_has_the_land_the_square_the_spots_and_the_buildings() -> void:
	for world_seed: int in SEEDS:
		var site := _site(world_seed)
		var village := _world(world_seed).village
		assert_eq(village.village_name, "Wehlsbüll")
		assert_eq(village.area, site.land(_plan))
		assert_eq(village.meeting_spot, site.to_world(_plan.meeting_spot))
		assert_eq(village.square.position, site.to_world(_plan.square.position))
		assert_eq(village.square.size, _plan.square.size)
		assert_eq(village.mill_spot.position, site.to_world(_plan.mill_spot.position))
		assert_true(village.area.encloses(village.square))
		assert_eq(village.building_origins.size(), _plan.buildings.size())
		assert_false(village.is_populated)


func test_a_new_game_has_no_village_unless_it_is_asked_for() -> void:
	assert_null(GameState.new_game(1).world.village)


func test_a_new_game_has_the_village_with_its_chunks_unloaded_and_a_save_keeps_it() -> void:
	var state := GameState.new_game(1, true)
	assert_not_null(state.world.village)
	assert_eq(state.world.buildings().size(), _plan.buildings.size())
	assert_eq(state.world.village.area, _site(1).land(_plan))
	for coords in state.world.loaded_chunk_coords():
		var chunk_rect := Rect2i(coords * Chunk.CHUNK_SIZE, Vector2i.ONE * Chunk.CHUNK_SIZE)
		assert_false(chunk_rect.intersects(state.world.village.area), "chunk %s" % coords)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.world.village.to_dict(), state.world.village.to_dict())
	assert_eq(restored.world.buildings().size(), _plan.buildings.size())
