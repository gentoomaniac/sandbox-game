extends LivestockCase
## Farm animals and villagers while time skips: the first minutes are walked through with the clock,
## the rest is made up for in one go, so that they are where the hour could have led them: on
## ground they could have walked to, asleep or awake as the hour has them, and only those in loaded
## chunks.

## How many villagers and tiles of soil the tests of a skip over frames put on the pen.
const VILLAGERS := 6
const SOIL_TILES := 5


func before_each() -> void:
	super()
	Simulation.frame_budget_usec = 0


func after_each() -> void:
	Simulation.frame_budget_usec = Simulation.DEFAULT_FRAME_BUDGET_USEC


func _noon() -> void:
	_state.clock.day = DAY
	_state.clock.set_time(12, 0)


func _positions(livestock: Livestock) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for animal in livestock.all():
		positions.append(animal.position)
	return positions


func _is_in_pen(point: Vector2) -> bool:
	return (
		maxf(absf(point.x - _pen_middle().x), absf(point.y - _pen_middle().y)) <= PEN_RADIUS + 0.5
	)


## The game saved and loaded, with its chunks.
func _reloaded() -> GameState:
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	for coords in _world.loaded_chunk_coords():
		restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	return restored


func test_a_skip_into_the_night_leaves_the_animals_asleep() -> void:
	_livestock.spawn(LivestockRules.COW, 3, _pen_middle(), _world)
	_noon()
	_state.simulation.skip(14 * GameClock.MINUTES_PER_HOUR)
	assert_eq(_state.clock.time_text(), "02:00")
	for animal in _livestock.all():
		assert_eq(animal.activity, FarmAnimal.Activity.SLEEP)


func test_a_skip_into_the_day_wakes_them() -> void:
	_livestock.spawn(LivestockRules.COW, 3, _pen_middle(), _world)
	_state.clock.day = DAY
	_state.clock.set_time(2, 0)
	_state.simulation.skip(10 * GameClock.MINUTES_PER_HOUR)
	for animal in _livestock.all():
		assert_ne(animal.activity, FarmAnimal.Activity.SLEEP)


func test_after_long_skips_the_animals_are_still_in_their_pen() -> void:
	_livestock.spawn(LivestockRules.SHEEP, 5, _pen_middle(), _world)
	_noon()
	for _skip in 20:
		_state.simulation.skip(6 * GameClock.MINUTES_PER_HOUR)
		for animal in _livestock.all():
			assert_true(_is_in_pen(animal.position), "inside the water that rings the pen")
			assert_true(_world.is_walkable(animal.tile()))


func test_the_animals_of_a_pen_cut_in_two_stay_on_their_side() -> void:
	for y in range(-PEN_RADIUS, PEN_RADIUS + 1):
		_world.set_terrain(_middle + Vector2i(1, y), Tile.Terrain.WATER)
	_livestock.spawn(LivestockRules.SHEEP, 1, _pen_middle() + Vector2(-2, 0), _world)
	var animal := _livestock.all()[0]
	var is_west := animal.position.x < _middle.x + 1.0
	_noon()
	for _skip in 20:
		_state.simulation.skip(6 * GameClock.MINUTES_PER_HOUR)
		assert_eq(animal.position.x < _middle.x + 1.0, is_west, "never across the water")


func test_the_same_save_skipped_the_same_way_ends_the_same() -> void:
	_livestock.spawn(LivestockRules.COW, 4, _pen_middle(), _world)
	var villager := Npc.create(SEED, _pen_middle(), _state.npcs.rules)
	villager.anchor = _pen_middle()
	_state.npcs.add(villager)
	_noon()
	var first := _reloaded()
	var second := _reloaded()
	first.simulation.skip(5 * GameClock.MINUTES_PER_HOUR)
	second.simulation.skip(5 * GameClock.MINUTES_PER_HOUR)
	assert_eq(_positions(first.livestock), _positions(second.livestock))
	assert_eq(first.npcs.all()[0].position, second.npcs.all()[0].position)
	assert_ne(_positions(first.livestock), _positions(_livestock), "and they did move")


func test_a_short_skip_walks_the_animals_no_further_than_the_seconds_of_play_would() -> void:
	_livestock.spawn(LivestockRules.SHEEP, 8, _pen_middle(), _world)
	_noon()
	var before := _positions(_livestock)
	_state.simulation.skip(Simulation.WALKED_MINUTES)
	var seconds := float(Simulation.WALKED_MINUTES) / GameClock.GAME_MINUTES_PER_REAL_SECOND
	var after := _positions(_livestock)
	for index in after.size():
		var rules := _livestock.rules
		var farthest := (
			maxf(rules.run_speed(LivestockRules.SHEEP), rules.walk_speed(LivestockRules.SHEEP))
			* seconds
		)
		assert_lte(after[index].distance_to(before[index]), farthest + 0.001)
	assert_ne(after, before, "and they did walk")


func test_played_minutes_move_no_animal_by_themselves() -> void:
	_livestock.spawn(LivestockRules.SHEEP, 3, _pen_middle(), _world)
	_noon()
	var before := _positions(_livestock)
	_state.simulation.advance(120)
	assert_eq(_positions(_livestock), before, "the frames of play walk them, not the clock")


func test_a_follower_left_behind_is_beside_the_player_after_a_long_skip() -> void:
	_livestock.spawn(LivestockRules.DOG, 1, _pen_middle(), _world)
	var dog := _livestock.all()[0]
	_noon()
	dog.follow_until_minute = _state.clock.total_minutes() + 120
	_state.player.position = _pen_middle() + Vector2(10, 0)
	_state.simulation.skip(30)
	assert_lte(dog.position.distance_to(_state.player.position), 4.0)


func test_a_follower_is_not_sent_to_an_indoor_player() -> void:
	_livestock.spawn(LivestockRules.DOG, 1, _pen_middle(), _world)
	var dog := _livestock.all()[0]
	_noon()
	dog.follow_until_minute = _state.clock.total_minutes() + 120
	var before := dog.position
	var indoors := func() -> Vector2: return Vector2.INF
	ActorsUpkeep.new(_world, _livestock, _state.npcs, indoors).skipped(30, _state.clock)
	assert_true(dog.position.is_finite())
	assert_lte(dog.position.distance_to(before), 6.0)


func test_animals_and_villagers_in_chunks_that_are_not_loaded_stay_as_they_are() -> void:
	var far := _middle + Vector2i(900, 900)
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Chunk.world_to_chunk(far)))
	_livestock.spawn(LivestockRules.SHEEP, 1, Vector2(far) + Vector2(0.5, 0.5), _world)
	var sheep := _livestock.all()[0]
	var villager := Npc.create(SEED, Vector2(far) + Vector2(2.5, 0.5), _state.npcs.rules)
	villager.anchor = villager.position
	_state.npcs.add(villager)
	_world.remove_chunk(Chunk.world_to_chunk(far))
	_noon()
	var sheep_before := [sheep.position, sheep.activity, sheep.seconds_left]
	var villager_before := [villager.position, villager.activity, villager.seconds_left]
	_state.simulation.skip(2)
	_state.simulation.skip(5 * GameClock.MINUTES_PER_HOUR)
	assert_eq([sheep.position, sheep.activity, sheep.seconds_left], sheep_before)
	assert_eq([villager.position, villager.activity, villager.seconds_left], villager_before)


func test_a_long_skip_puts_a_villager_in_the_circle_of_its_anchor_on_ground_it_could_reach(
) -> void:
	var villager := Npc.create(SEED, _pen_middle(), _state.npcs.rules)
	villager.anchor = _pen_middle()
	_state.npcs.add(villager)
	_noon()
	for _skip in 10:
		_state.simulation.skip(5 * GameClock.MINUTES_PER_HOUR)
		assert_true(_is_in_pen(villager.position), "inside the water that rings the pen")
		assert_lte(
			villager.position.distance_to(villager.anchor),
			_state.npcs.rules.behaviour("anchor_radius")
		)
		assert_eq(villager.activity, Npc.Activity.IDLE)


func test_reloaded_games_skipped_across_sunset_and_sunrise_end_the_same() -> void:
	_livestock.spawn(LivestockRules.COW, 4, _pen_middle(), _world)
	_livestock.spawn(LivestockRules.SHEEP, 3, _pen_middle(), _world)
	var first := _reloaded()
	var second := _reloaded()
	for game in [first, second]:
		game.clock.day = DAY
		game.clock.set_time(17, 30)
	for hours in [5, 12]:
		first.simulation.skip(hours * GameClock.MINUTES_PER_HOUR)
		second.simulation.skip(hours * GameClock.MINUTES_PER_HOUR)
		assert_eq(_positions(first.livestock), _positions(second.livestock), "after %d h" % hours)
		var activities_first := first.livestock.all().map(
			func(a: FarmAnimal) -> int: return a.activity
		)
		var activities_second := second.livestock.all().map(
			func(a: FarmAnimal) -> int: return a.activity
		)
		assert_eq(activities_first, activities_second, "after %d h" % hours)


func test_a_villager_in_an_unloaded_chunk_keeps_walking_through_the_night() -> void:
	var far := _middle + Vector2i(900, 900)
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Chunk.world_to_chunk(far)))
	var villager := Npc.create(SEED, Vector2(far) + Vector2(0.5, 0.5), _state.npcs.rules)
	villager.anchor = villager.position
	villager.activity = Npc.Activity.WALK
	_state.npcs.add(villager)
	_world.remove_chunk(Chunk.world_to_chunk(far))
	_state.clock.day = DAY
	_state.clock.set_time(23, 58)
	_state.simulation.skip(2)
	assert_eq(villager.activity, Npc.Activity.WALK)


func test_a_dog_with_a_bone_sleeps_through_the_night_while_the_player_is_indoors() -> void:
	_livestock.spawn(LivestockRules.DOG, 1, _pen_middle(), _world)
	var dog := _livestock.all()[0]
	_state.clock.day = DAY
	_state.clock.set_time(2, 0)
	dog.follow_until_minute = _state.clock.total_minutes() + 300
	var indoors := func() -> Vector2: return Vector2.INF
	ActorsUpkeep.new(_world, _livestock, _state.npcs, indoors).skipped(30, _state.clock)
	assert_true(_livestock.is_sleep_time(dog, DAY, 2 * 60))
	assert_eq(dog.activity, FarmAnimal.Activity.SLEEP)


func test_an_animal_on_a_small_island_ends_in_a_pose_a_step_would_leave_or_where_it_was() -> void:
	for hour in [2, 12]:
		_assert_island_poses(hour)


func _assert_island_poses(hour: int) -> void:
	for y in range(-PEN_RADIUS, PEN_RADIUS + 1):
		for x in range(-PEN_RADIUS, PEN_RADIUS + 1):
			_world.set_terrain(_middle + Vector2i(x, y), Tile.Terrain.WATER)
	_world.set_terrain(_middle, Tile.Terrain.GRASS)
	_world.set_terrain(_middle + Vector2i.LEFT, Tile.Terrain.GRASS)
	var look: StringName = _livestock.rules.looks(LivestockRules.SHEEP)[0]
	var sheep := FarmAnimal.new(LivestockRules.SHEEP, look, _pen_middle())
	_livestock.add(sheep)
	var reach := _livestock.rules.body_tiles(LivestockRules.SHEEP)
	_state.clock.day = DAY
	_state.clock.set_time(hour, 0)
	for _skip in 30:
		var before := sheep.position
		var heading := sheep.heading
		_state.simulation.skip(5)
		var nose := sheep.position + sheep.heading * reach
		var is_as_before := sheep.position == before and sheep.heading == heading
		var is_a_pose := (
			_world.is_walkable(sheep.tile()) and _world.is_walkable(Vector2i(nose.floor()))
		)
		assert_true(
			is_as_before or is_a_pose, "feet and nose on dry ground, or not moved, at %d:00" % hour
		)


## The games are the same: what is saved, the dice, and what the animals and villagers are in the
## middle of, which a save leaves out.
func _assert_same_game(game: GameState, expected: GameState) -> void:
	assert_eq(game.to_dict(), expected.to_dict())
	assert_eq(game.npcs.rng.state, expected.npcs.rng.state, "the villagers' dice")
	assert_eq(game.livestock.rng.state, expected.livestock.rng.state, "the animals' dice")
	assert_eq(_doings_of(game), _doings_of(expected))


func _doings_of(game: GameState) -> Array:
	var doings := []
	for animal in game.livestock.all():
		doings.append(
			[
				animal.activity,
				animal.seconds_left,
				animal.heading,
				animal.last_step,
				animal.facing,
				animal.stuck_seconds,
				animal.pounce_at,
				animal.hunt_rest_seconds
			]
		)
	for npc in game.npcs.all():
		doings.append(
			[npc.activity, npc.seconds_left, npc.heading, npc.facing, npc.free_body_tiles]
		)
	return doings


func _next_frame() -> Signal:
	return get_tree().process_frame


## Puts animals and villagers on the pen and the clock at noon, for games to be loaded from.
func _crowd_the_pen() -> void:
	_livestock.spawn(LivestockRules.COW, 4, _pen_middle(), _world)
	for seed_value in VILLAGERS:
		var villager := Npc.create(seed_value, _pen_middle(), _state.npcs.rules)
		villager.anchor = _pen_middle()
		_state.npcs.add(villager)
	for index in SOIL_TILES:
		var tile := _middle + Vector2i(index - 2, -2)
		_world.set_terrain(tile, Tile.Terrain.SOIL)
		_world.set_moisture(tile, 0.1 * index)
	_noon()


func _home_bed_of(game: GameState) -> WorldObject:
	return game.world.object_at(game.player.home_bed)


func test_a_skip_over_frames_ends_as_the_skip_in_one_go() -> void:
	_crowd_the_pen()
	var in_one_go := _reloaded()
	var over_frames := _reloaded()
	var frame_before := Engine.get_process_frames()

	in_one_go.simulation.skip(5 * GameClock.MINUTES_PER_HOUR)
	await over_frames.simulation.skip_over_frames(5 * GameClock.MINUTES_PER_HOUR, _next_frame)

	var frames := Engine.get_process_frames() - frame_before
	assert_gt(frames, VILLAGERS + SOIL_TILES, "a frame for every villager and tile of soil")
	_assert_same_game(over_frames, in_one_go)
	assert_ne(over_frames.npcs.to_array(), _state.npcs.to_array(), "and they did move")


func test_passing_out_over_frames_ends_as_passing_out_in_one_go() -> void:
	_crowd_the_pen()
	var in_one_go := _reloaded()
	var over_frames := _reloaded()

	var minutes := in_one_go.pass_out()
	var minutes_over_frames: int = await over_frames.pass_out_over_frames(_next_frame)

	assert_eq(minutes_over_frames, minutes)
	_assert_same_game(over_frames, in_one_go)


func test_sleeping_over_frames_ends_as_sleeping_in_one_go() -> void:
	_crowd_the_pen()
	var in_one_go := _reloaded()
	var over_frames := _reloaded()

	in_one_go.sleep_in(_home_bed_of(in_one_go))
	await over_frames.sleep_in_over_frames(_home_bed_of(over_frames), _next_frame)

	_assert_same_game(over_frames, in_one_go)
