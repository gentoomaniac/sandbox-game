extends NpcRoadCase
## Walking over chunks that are not loaded (#68): a villager walks its path there at the same
## speed as in sight, and the tiles it enters are asked of the masks, at the time of entry.


func test_a_villager_from_far_comes_into_the_loaded_area_on_its_path_and_arrives() -> void:
	_build_road()
	watch_signals(_npcs)
	var start := _road_tile(ROAD_LENGTH)
	var npc := _add_villager(_centre_of(start), _yard_middle())
	assert_false(_is_loaded(start))
	_npcs.walk_to(npc, _middle, _world)
	var rows := {}
	var has_come_in := [false]
	var is_there := func() -> bool:
		rows[npc.tile().y] = true
		has_come_in[0] = has_come_in[0] or _is_loaded(npc.tile())
		return not npc.is_travelling()
	assert_true(_run_until(is_there))
	assert_eq(rows.keys(), [_middle.y], "it kept to the road")
	assert_true(has_come_in[0], "it walked on into the loaded chunks")
	assert_signal_emit_count(_npcs, "trip_arrived", 1)
	assert_eq(npc.tile(), _middle)


func test_a_villager_leaves_the_loaded_area_and_walks_on_to_a_goal_that_is_not_loaded() -> void:
	_build_road()
	watch_signals(_npcs)
	var goal := _road_tile(ROAD_LENGTH)
	var npc := _add_villager(_yard_middle(), _yard_middle())
	_npcs.walk_to(npc, goal, _world)
	var has_been_far := [false]
	var is_there := func() -> bool:
		has_been_far[0] = has_been_far[0] or not _is_loaded(npc.tile())
		return not npc.is_travelling()
	assert_true(_run_until(is_there))
	assert_true(has_been_far[0])
	assert_signal_emit_count(_npcs, "trip_arrived", 1)
	assert_eq(npc.tile(), goal)


func test_it_never_moves_more_than_a_step_while_its_chunks_load_and_unload() -> void:
	_build_road()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var npc := _add_villager(_centre_of(_road_tile(ROAD_LENGTH)), _yard_middle())
	_npcs.walk_to(npc, _middle, _world)
	var most := _npcs.rules.behaviour("walk_speed") * STEP_SECONDS
	var jumps: Array[float] = []
	for _i in 8000:
		# One chunk of its row, behind it, under it or ahead, goes or comes, between two centres.
		var coords := Chunk.world_to_chunk(npc.tile()) + Vector2i(rng.randi_range(-1, 1), 0)
		if World.is_chunk_in_bounds(coords):
			if _world.is_chunk_loaded(coords):
				_world.remove_chunk(coords)
			else:
				_load(coords)
		var before := npc.position
		_step()
		if npc.position.distance_to(before) > most + 0.0001:
			jumps.append(npc.position.distance_to(before))
		if not npc.is_travelling():
			break
		OS.delay_usec(200)
	assert_eq(jumps, [] as Array[float])
	assert_false(npc.is_travelling(), "it got there")
	assert_eq(npc.tile(), _middle)


func test_the_tide_rising_over_a_far_path_makes_it_search_again_and_then_wait() -> void:
	_build_road()
	var mud := _road_tile(60)
	_load(Chunk.world_to_chunk(mud))
	_world.set_terrain(mud, Tile.Terrain.MUD)
	_world.remove_chunk(Chunk.world_to_chunk(mud))
	var low := -1
	var high := -1
	for minute in range(0, GameClock.MINUTES_PER_DAY, 10):
		var is_flooded := Tide.floods(
			mud, Tide.level((DAY - 1) * GameClock.MINUTES_PER_DAY + minute)
		)
		low = minute if low < 0 and not is_flooded else low
		high = minute if high < 0 and is_flooded else high
	assert_true(low >= 0 and high >= 0, "the mud has its tides")
	watch_signals(_npcs)
	var npc := _add_villager(_centre_of(_road_tile(ROAD_LENGTH)), _yard_middle())
	_npcs.walk_to(npc, _middle, _world)
	var tiles_stood_on := {}
	var is_near := func() -> bool: return npc.tile().x <= mud.x + 5
	assert_true(_run_until(is_near, low))
	var is_blocked := func() -> bool:
		tiles_stood_on[npc.tile()] = true
		return npc.trip.state == NpcTrip.State.BLOCKED
	assert_true(_run_until(is_blocked, high), "the water is up: the way is closed")
	assert_eq(npc.trip.searches, 2, "it searched again from where it stood")
	assert_signal_emitted_with_parameters(_npcs, "trip_blocked", [npc, NpcTrip.Block.NO_WAY])
	assert_false(tiles_stood_on.has(mud))
	var is_there := func() -> bool:
		tiles_stood_on[npc.tile()] = true
		return not npc.is_travelling()
	assert_true(_run_until(is_there, low), "it looks again when the tide is down")
	assert_eq(npc.tile(), _middle)
	assert_signal_emit_count(_npcs, "trip_arrived", 1)


func test_a_crop_edit_at_night_drops_the_mask_and_the_walker_meets_the_new_one() -> void:
	_build_road()
	var tile := _road_tile(70)
	var coords := Chunk.world_to_chunk(tile)
	_load(coords)
	var grass := WorldObject.new(WorldObjectTypes.TALL_GRASS, tile)
	_world.add_object(grass)
	_world.remove_chunk(coords)
	watch_signals(_npcs)
	var npc := _add_villager(_centre_of(_road_tile(ROAD_LENGTH)), _yard_middle())
	_npcs.walk_to(npc, _middle, _world)
	var masks: TravelMasks = _npcs._travel._masks
	var is_near := func() -> bool: return npc.tile().x <= tile.x + 10
	assert_true(_run_until(is_near, MIDNIGHT))
	assert_not_null(masks.made_mask(coords), "it has walked over it")
	_world.replace_object(grass, WorldObject.new(WorldObjectTypes.STONE, tile))
	assert_null(masks.made_mask(coords), "the edit dropped it, at once")
	var tiles_stood_on := {}
	var is_blocked := func() -> bool:
		tiles_stood_on[npc.tile()] = true
		return npc.trip.state == NpcTrip.State.BLOCKED
	assert_true(_run_until(is_blocked, MIDNIGHT))
	assert_false(tiles_stood_on.has(tile), "the new mask has the stone on the road")
	assert_signal_emitted_with_parameters(_npcs, "trip_blocked", [npc, NpcTrip.Block.NO_WAY])


func test_a_step_on_the_rim_respects_a_big_object_whose_chunk_is_not_loaded() -> void:
	_build_road()
	var west := _first_far_chunk() - Vector2i.RIGHT
	var east := _first_far_chunk()
	_load(west)
	_load(east)
	_load(east + Vector2i.UP)
	var boundary := Chunk.to_world(east, Vector2i.ZERO).x
	var npc := _add_villager(_centre_of(Vector2i(boundary + 20, _middle.y)), _yard_middle())
	_npcs.walk_to(npc, Vector2i(boundary - 8, _middle.y), _world)
	assert_true(_run_until(func() -> bool: return npc.trip.state != NpcTrip.State.SEARCHING))
	var ewer := WorldObject.new(WorldObjectTypes.EWER, Vector2i(boundary - 3, _middle.y))
	for covered in ewer.tiles():
		_load(Chunk.world_to_chunk(covered))
		_world.set_terrain(covered, Tile.Terrain.GRASS)
		_world.remove_object(covered)
	_world.add_object(ewer)
	var in_the_east: Vector2i = ewer.tiles().back()
	assert_eq(Chunk.world_to_chunk(in_the_east), east, "it reaches into the loaded chunk")
	_world.remove_chunk(west)
	assert_true(_world.is_walkable(in_the_east), "the world alone does not see it any more")
	var tiles_stood_on := {}
	var is_blocked := func() -> bool:
		tiles_stood_on[npc.tile()] = true
		return npc.trip.state == NpcTrip.State.BLOCKED
	assert_true(_run_until(is_blocked))
	for covered in ewer.tiles():
		assert_false(tiles_stood_on.has(covered), "not on the ewer's %s" % covered)


func test_far_feet_wear_the_grass_they_walk_on() -> void:
	_build_road()
	var npc := _add_villager(_centre_of(_road_tile(ROAD_LENGTH)), _yard_middle())
	_npcs.walk_to(npc, _road_tile(ROAD_LENGTH - 20), _world)
	assert_true(_run_until(func() -> bool: return not npc.is_travelling()))
	var worn := _world.wear_steps()
	for x in range(ROAD_LENGTH - 20, ROAD_LENGTH):
		var tile := _road_tile(x)
		assert_false(_is_loaded(tile))
		assert_true(worn.has(tile), "the grass of %s is worn" % tile)
	assert_false(worn.has(_road_tile(ROAD_LENGTH)), "not where it stood")
	assert_false(worn.has(_road_tile(ROAD_LENGTH - 21)), "nor where it did not walk")
