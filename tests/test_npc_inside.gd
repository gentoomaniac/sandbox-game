extends NpcRoadCase
## While the player is inside a building the villagers outside go on (#68, step 5): the trips are
## walked on the masks, as if far, wherever the villager is, so it is where one expects it when the
## player comes out, and whoever it meets on the way it meets.

var _spread: GossipSpread


func before_each() -> void:
	super()
	_build_road()
	# The chunks around a house stay loaded while the player is inside it.
	for x in range(0, ROAD_LENGTH + 1, Chunk.CHUNK_SIZE / 2):
		for step in TravelMasks.SOURCE_STEPS:
			_load(Chunk.world_to_chunk(_road_tile(x)) + step)
	_warm_road_masks()
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	values["meetings"]["chance_topic"] = 1.0
	_spread = GossipSpread.new(_npcs, _state.deeds)
	_spread.rules = SpreadRules.new(values)


func _step_inside() -> void:
	_npcs.update_unseen(STEP_SECONDS, _world, _state.clock)


func test_a_villager_sent_off_before_the_player_went_in_is_where_the_same_play_takes_it() -> void:
	var npc := _walker_on_road(60, 20)
	var steps := 200
	for _i in steps:
		_step_inside()
	var walked := _npcs.rules.behaviour("walk_speed") * STEP_SECONDS * steps
	assert_almost_eq(npc.position.x, _centre_of(_road_tile(60)).x - walked, 0.01)
	assert_almost_eq(npc.position.y, _centre_of(_road_tile(60)).y, 0.01)
	assert_true(npc.is_travelling(), "still on its way")


func test_a_villager_arrives_while_the_player_is_inside() -> void:
	watch_signals(_npcs)
	var npc := _walker_on_road(30, 20)
	for _i in 2000:
		_step_inside()
	assert_false(npc.is_travelling())
	assert_eq(npc.tile(), _road_tile(20))
	assert_signal_emit_count(_npcs, "trip_arrived", 1)


func test_two_whose_trips_cross_while_the_player_is_inside_meet() -> void:
	var local := Npc.create_villager("antje", Vector2.ZERO, _npcs.villagers)
	_npcs.add(local)
	var newcomer := _add_villager(Vector2.ZERO, _yard_middle())
	_send_along_road(local, 60, 20)
	_send_along_road(newcomer, 20, 60)
	assert_eq(newcomer.topics, [] as Array[String])
	for _i in 400:
		_step_inside()
		_spread.advance(1, _state.clock)
	assert_false(newcomer.topics.is_empty(), "the local told the newcomer something")


func test_no_one_jumps_more_than_a_step_when_the_player_goes_in_and_out() -> void:
	var npc := _walker_on_road(70, 10)
	var most := _npcs.rules.behaviour("walk_speed") * STEP_SECONDS
	var jumps: Array[float] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for _i in 4000:
		var before := npc.position
		if rng.randf() < 0.5:
			_step_inside()
		else:
			_step()
		if npc.position.distance_to(before) > most + 0.0001:
			jumps.append(npc.position.distance_to(before))
		if not npc.is_travelling():
			break
	assert_eq(jumps, [] as Array[float])
	assert_eq(npc.tile(), _road_tile(10))


func test_a_villager_with_no_trip_strolls_outside_but_stands_while_the_player_is_inside() -> void:
	var npc := _add_villager(_yard_middle(), _yard_middle())
	npc.activity = Npc.Activity.WALK
	npc.heading = Vector2.RIGHT
	npc.seconds_left = 100.0
	var start := npc.position
	for _i in 20:
		_npcs.update_unseen(STEP_SECONDS, _world, _state.clock)
	assert_eq(npc.position, start)
	for _i in 20:
		_npcs.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
	assert_ne(npc.position, start, "it strolls when the player is out in the world")
