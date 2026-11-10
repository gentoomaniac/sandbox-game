extends ResourceCase
## Skipping time is the same as playing it: a skip, a night's sleep and passing out leave the
## crops, the soil, the weather and a kiln's work as the same minutes played in small steps do,
## and the animals asleep or awake as the hour has them. The 30 days are measured too.

const CROP_TYPES: Array[StringName] = [WorldObjectTypes.TURNIP, &"wheat", &"peas"]
const FIELD_TILES := 6
const KILN_FIRING_MINUTES := 12 * GameClock.MINUTES_PER_HOUR
const STEP_MINUTES := 5
## The most a skip of 30 days may take here, on a field of a thousand crops: a generous bound that
## only catches stepping through every minute, not a measure (the time is printed).
const MOST_SECONDS_FOR_30_DAYS := 10.0
const DAY := 45

var _stepped: GameState


func before_each() -> void:
	super.before_each()
	_stepped = GameState.new_game(SEED)
	_stepped.player.position = _state.player.position
	for state in [_state, _stepped]:
		_make_farm(state)


## A row of tilled tiles with a crop and some moisture each, a kiln that is firing and three
## sheep, all at the same places in every game of the same seed.
func _make_farm(state: GameState) -> void:
	var world := state.world
	for x in FIELD_TILES:
		var pos := _tile + Vector2i(x + 1, 0)
		world.remove_object(pos)
		world.set_terrain(pos, Tile.Terrain.SOIL)
		world.set_moisture(pos, 0.2 + x * 0.15)
		var crop := WorldObject.new(CROP_TYPES[x % CROP_TYPES.size()], pos)
		crop.state["days_growing"] = 1
		world.add_object(crop)
	var kiln := WorldObject.new(WorldObjectTypes.KILN, _tile)
	world.remove_object(kiln.pos)
	world.set_terrain(kiln.pos, Tile.Terrain.GRASS)
	world.add_object(kiln)
	state.player.inventory.add(ItemTypes.RAW_BRICK, 6)
	state.player.inventory.add(ItemTypes.LOGS, 2)
	Crafting.new(state).craft(&"bricks", kiln)
	state.livestock.rng.seed = SEED
	state.livestock.spawn(LivestockRules.SHEEP, 3, Vector2(_tile) + Vector2(3, 5), world)


func _play_in_steps(state: GameState, minutes: int) -> void:
	for _step in minutes / STEP_MINUTES:
		state.simulation.advance(STEP_MINUTES)


func _assert_same_world(skipped: GameState, played: GameState, label: String) -> void:
	assert_eq(skipped.clock.to_dict(), played.clock.to_dict(), label)
	for x in FIELD_TILES:
		var pos := _tile + Vector2i(x + 1, 0)
		assert_almost_eq(
			skipped.world.moisture_at(pos), played.world.moisture_at(pos), 0.000001, label
		)
		var crop := skipped.world.object_at(pos)
		var twin := played.world.object_at(pos)
		assert_eq(crop.state.keys(), twin.state.keys(), label)
		for key: String in crop.state:
			assert_almost_eq(float(crop.state[key]), float(twin.state[key]), 0.000001, label + key)
	var kiln_pos := _tile
	assert_eq(
		StationWork.is_done(skipped.world.object_at(kiln_pos), skipped.clock.total_minutes()),
		StationWork.is_done(played.world.object_at(kiln_pos), played.clock.total_minutes()),
		label + " kiln"
	)
	assert_eq(
		skipped.weather.at(_tile, skipped.clock.day, skipped.clock.minute_of_day).temperature,
		played.weather.at(_tile, played.clock.day, played.clock.minute_of_day).temperature,
		label + " weather"
	)


func _assert_animals_are_as_the_hour_has_them(state: GameState, label: String) -> void:
	assert_eq(state.livestock.all().size(), 3, label)
	for animal in state.livestock.all():
		var is_asleep := animal.activity == FarmAnimal.Activity.SLEEP
		var should_sleep := state.livestock.is_sleep_time(
			animal, state.clock.day, state.clock.minute_of_day
		)
		assert_eq(is_asleep, should_sleep, label)
		assert_true(state.world.is_walkable(Vector2i(animal.position.floor())), label)


func test_a_skip_of_an_hour_a_day_and_a_month_is_the_time_played_in_small_steps() -> void:
	for minutes in [60, GameClock.MINUTES_PER_DAY, 30 * GameClock.MINUTES_PER_DAY]:
		var label := "%d minutes" % minutes
		_state.simulation.skip(minutes)
		_play_in_steps(_stepped, minutes)
		_assert_same_world(_state, _stepped, label)
		_assert_animals_are_as_the_hour_has_them(_state, label)


func test_a_kiln_is_done_after_a_skip_as_after_the_hours_played() -> void:
	var kiln := _state.world.object_at(_tile)
	_state.simulation.skip(KILN_FIRING_MINUTES - 1)
	assert_false(StationWork.is_done(kiln, _state.clock.total_minutes()))
	_state.simulation.skip(1)
	assert_true(StationWork.is_done(kiln, _state.clock.total_minutes()))


func test_animals_are_asleep_after_a_skip_into_the_night_and_awake_after_one_into_the_day() -> void:
	_state.clock.set_time(20, 0)
	_state.simulation.skip(6 * GameClock.MINUTES_PER_HOUR)
	_assert_animals_are_as_the_hour_has_them(_state, "02:00")
	_state.simulation.skip(8 * GameClock.MINUTES_PER_HOUR)
	_assert_animals_are_as_the_hour_has_them(_state, "10:00")


func test_a_night_in_bed_is_the_hours_of_the_night_played() -> void:
	var bed := _world.object_at(_state.player.home_bed)
	_state.clock.set_time(22, 0)
	_stepped.clock.set_time(22, 0)
	var minutes := _state.clock.minutes_until(GameState.WAKE_UP_MINUTE)
	_state.sleep_in(bed)
	_play_in_steps(_stepped, minutes - minutes % STEP_MINUTES)
	_stepped.simulation.advance(minutes % STEP_MINUTES)
	_assert_same_world(_state, _stepped, "a night")
	_assert_animals_are_as_the_hour_has_them(_state, "a night")


func test_passing_out_is_the_hours_of_the_collapse_played() -> void:
	_state.clock.set_time(15, 0)
	_stepped.clock.set_time(15, 0)
	var minutes := _state.pass_out()
	_play_in_steps(_stepped, minutes)
	_assert_same_world(_state, _stepped, "passing out")


func test_a_skip_of_thirty_days_over_a_big_field_takes_seconds() -> void:
	var rows := 25
	var generator := WorldGenerator.new(SEED)
	for corner in [Vector2i(0, 0), Vector2i(40, 0), Vector2i(0, 30), Vector2i(40, 30)]:
		var coords := Chunk.world_to_chunk(_tile + corner)
		if not _world.is_chunk_loaded(coords):
			_world.add_chunk(generator.generate_chunk(coords))
	for y in range(1, rows + 1):
		for x in 40:
			var pos := _tile + Vector2i(x, y + 3)
			_world.remove_object(pos)
			_world.set_terrain(pos, Tile.Terrain.SOIL)
			if x % 2 == 0 and y % 2 == 0:
				var crop := WorldObject.new(CROP_TYPES[x % CROP_TYPES.size()], pos)
				crop.state["days_growing"] = 1
				_world.add_object(crop)
	var started := Time.get_ticks_msec()
	_state.simulation.skip(30 * GameClock.MINUTES_PER_DAY)
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	gut.p(
		(
			"30 days over %d tilled tiles and %d crops: %.2f s"
			% [_world.tilled_tiles().size(), _world.crops().size(), seconds]
		)
	)
	assert_lt(seconds, MOST_SECONDS_FOR_30_DAYS)


## The frames of play with the clock between them, from the same saved game: a skip of 3 minutes
## across the sheep's bedtime ends as that does.
func test_a_short_skip_is_the_frames_of_play_with_the_clock_between_them() -> void:
	var skipped := _through_save()
	var played := _through_save()
	var first_sheep := skipped.livestock.all()[0]
	var bedtime := 12 * GameClock.MINUTES_PER_HOUR
	while not skipped.livestock.is_sleep_time(first_sheep, DAY, bedtime):
		bedtime += 1
	for game in [skipped, played]:
		game.clock.day = DAY
		game.clock.minute_of_day = bedtime - 2
	var before: Array[Vector2] = []
	for animal in skipped.livestock.all():
		before.append(animal.position)
	skipped.simulation.skip(Simulation.WALKED_MINUTES)
	for _minute in Simulation.WALKED_MINUTES:
		played.simulation.advance(1)
		var dice := hash([SEED, played.clock.total_minutes(), 1])
		played.livestock.rng.seed = dice
		played.npcs.rng.seed = dice
		var seconds := 1.0 / GameClock.GAME_MINUTES_PER_REAL_SECOND
		while seconds > 0.0:
			var step := minf(seconds, Livestock.MAX_STEP_SECONDS)
			played.livestock.update(
				step, played.world, played.player.position, played.clock, true, false
			)
			seconds -= step
	assert_eq(first_sheep.activity, FarmAnimal.Activity.SLEEP, "it went to bed meanwhile")
	var has_moved := false
	for index in 3:
		has_moved = has_moved or skipped.livestock.all()[index].position != before[index]
	assert_true(has_moved, "and some of them walked")
	for index in 3:
		var animal := skipped.livestock.all()[index]
		var twin := played.livestock.all()[index]
		assert_eq(animal.position, twin.position, "sheep %d" % index)
		assert_eq(animal.activity, twin.activity, "sheep %d" % index)
		assert_eq(animal.seconds_left, twin.seconds_left, "sheep %d" % index)


## With no crop to read the soil every hour, what the skip leaves undone would show at the first
## look at a tile: the weather of the whole month worked out in one frame.
func test_the_soil_is_ready_when_a_skip_of_thirty_days_is_over() -> void:
	var bare := GameState.new_game(SEED)
	var tile := bare.player.tile() + Vector2i(1, 4)
	bare.world.set_terrain(tile, Tile.Terrain.SOIL)
	bare.simulation.skip(30 * GameClock.MINUTES_PER_DAY)
	var started := Time.get_ticks_usec()
	bare.world.moisture_at(tile)
	var seconds := (Time.get_ticks_usec() - started) / 1000000.0
	assert_lt(seconds, 0.02, "the first look is as quick as the next")
