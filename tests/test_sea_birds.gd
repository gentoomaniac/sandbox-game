extends WildlifeCase
## The birds of the coast in the view, on a stretch of coast laid around the middle of the view:
## salt marsh, then tidal mud, then the sea, from east to west.

## On day 1 the tide is high at midnight and low half a tide later (see Tide).
const HIGH_WATER := 0
const LOW_WATER := 373
## The coast laid around the middle of the view, in tiles from its middle tile: the sea west of
## SEA_EAST, the salt marsh east of MARSH_WEST, the mud between.
const COAST_REACH := 12
const SEA_EAST := -3
const MARSH_WEST := 4

var _middle: Vector2i


func before_each() -> void:
	super()
	_middle = Vector2i((VIEW_CENTRE / TerrainTileset.TILE_SIZE).floor())
	for y in range(-COAST_REACH, COAST_REACH + 1):
		for x in range(-COAST_REACH, COAST_REACH + 1):
			var terrain := Tile.Terrain.MUD
			if x < SEA_EAST:
				terrain = Tile.Terrain.SEA
			elif x >= MARSH_WEST:
				terrain = Tile.Terrain.SALT_MARSH
			_state.world.set_terrain(_middle + Vector2i(x, y), terrain)
			_state.world.remove_object(_middle + Vector2i(x, y))
	_state.clock.minute_of_day = LOW_WATER


## The middle of a tile of the coast, `x` tiles east of the view's middle tile.
func _point(x: int, y := 0) -> Vector2:
	return TerrainTileset.tile_centre(_middle + Vector2i(x, y))


func test_nothing_stands_on_the_mud_while_the_tide_is_in() -> void:
	var mud := _point(0)
	assert_true(_wildlife.can_stand(mud), "dry at low water")
	assert_false(_wildlife.is_water(mud))
	_state.clock.minute_of_day = HIGH_WATER
	assert_false(_wildlife.can_stand(mud), "under at high water")
	assert_true(_wildlife.is_water(mud))
	assert_true(_wildlife.can_stand(_point(MARSH_WEST)), "the salt marsh stays dry")
	assert_true(_wildlife.is_water(_point(SEA_EAST - 1)), "the sea")


func _flock_of(kind: StringName) -> GroundFlock:
	_wildlife.world_view.player_feet = _point(0)
	assert_eq(_wildlife.spawn_in_view(kind, 1), 1, "%s made by hand" % kind)
	return _animals_of(GroundFlock)[0]


func test_waders_probe_the_mud_at_low_water_and_oystercatchers_wait_on_the_salt_marsh() -> void:
	for kind in [WildlifeRules.OYSTERCATCHER, WildlifeRules.DUNLIN]:
		assert_true(_wildlife._is_habitat(kind, _point(0)), "%s on the mud" % kind)
		assert_false(_wildlife._is_habitat(kind, _point(SEA_EAST - 1)), "%s not at sea" % kind)
	_state.clock.minute_of_day = HIGH_WATER
	assert_false(_wildlife._is_habitat(WildlifeRules.DUNLIN, _point(0)), "the mud under water")
	assert_false(_wildlife._is_habitat(WildlifeRules.DUNLIN, _point(MARSH_WEST)))
	assert_true(_wildlife._is_habitat(WildlifeRules.OYSTERCATCHER, _point(MARSH_WEST)))


func test_waders_keep_to_the_coast_when_made_by_hand() -> void:
	_wildlife.world_view.player_feet = Vector2.ONE * -4000.0
	assert_eq(_wildlife.spawn_in_view(WildlifeRules.DUNLIN, 1), 0, "no mud there")


func test_a_flock_of_waders_probes_the_mud_and_keeps_together() -> void:
	var flock := _flock_of(WildlifeRules.DUNLIN)
	var size: Vector2i = GroundFlock.FLOCKS[WildlifeRules.DUNLIN]["size"]
	assert_between(flock._birds.size(), size.x, size.y)
	var probing := 0
	for _i in 20:
		_run(flock, 1.0)
		for bird in flock._birds:
			if bird.action == &"probe":
				probing += 1
	assert_gt(probing, 0, "they probe")
	assert_eq(flock._state, GroundFlock.FEED)
	for bird in flock._birds:
		assert_true(_wildlife.can_stand(flock.position + bird.spot), "on the dry mud")


func test_oystercatchers_look_up_then_fly_off_low() -> void:
	var flock := _flock_of(WildlifeRules.OYSTERCATCHER)
	_wildlife.is_player_ignored = false
	_wildlife.world_view.player_feet = flock.position + Vector2(5.0 * TerrainTileset.TILE_SIZE, 0)
	_run(flock, STEP)
	assert_eq(flock._state, GroundFlock.ALERT)
	_wildlife.world_view.player_feet = flock.position + Vector2(3.0 * TerrainTileset.TILE_SIZE, 0)
	_run(flock, STEP)
	assert_eq(flock._state, GroundFlock.FLY)
	var start := flock.position
	_run(flock, 3.0)
	assert_lt(flock.position.x, start.x - 60.0, "away from the player")
	assert_lte(flock._lift, GroundFlock.FLOCKS[WildlifeRules.OYSTERCATCHER]["flight_height"])


func test_waders_fly_off_when_the_tide_comes_in() -> void:
	var flock := _flock_of(WildlifeRules.DUNLIN)
	flock.position = _point(0)
	_run(flock, STEP)
	assert_eq(flock._state, GroundFlock.FEED)
	_state.clock.minute_of_day = HIGH_WATER
	_run(flock, STEP)
	assert_eq(flock._state, GroundFlock.FLY)


func test_dunlin_swing_round_in_a_wheel_as_they_fly_off() -> void:
	var flock := _flock_of(WildlifeRules.DUNLIN)
	flock.dismiss()
	var heading := flock._flight_direction
	_run(flock, GroundFlock.WHEEL_SECONDS)
	assert_gt(absf(heading.angle_to(flock._flight_direction)), 1.0, "turned")
	var turned := flock._flight_direction
	_run(flock, 1.0)
	assert_almost_eq(flock._flight_direction, turned, Vector2(0.01, 0.01), "then straight on")
	_run(flock, 30.0)
	assert_true(flock.is_done)


func test_oystercatchers_all_year_dunlin_in_the_migration() -> void:
	var rules := _wildlife.rules
	var clear := WeatherSample.new()
	var noon := 12 * GameClock.MINUTES_PER_HOUR
	for day in [15, 45, 75, 105]:
		assert_gt(
			rules.target_count(WildlifeRules.OYSTERCATCHER, day, noon, clear), 0, "day %d" % day
		)
	assert_gt(rules.target_count(WildlifeRules.DUNLIN, 15, noon, clear), 0, "spring")
	assert_gt(rules.target_count(WildlifeRules.DUNLIN, 75, noon, clear), 0, "autumn")
	assert_eq(rules.target_count(WildlifeRules.DUNLIN, 45, noon, clear), 0, "summer")
	assert_eq(rules.target_count(WildlifeRules.DUNLIN, 75, 0, clear), 0, "none at night")


func test_the_waders_can_be_spawned_from_the_console() -> void:
	var console := Console.new(_state)
	console.wildlife_spawner = func(_kind: StringName, count: int) -> int: return count
	assert_eq(console.run("spawn oystercatcher 2"), ["Spawned 2 of 2 oystercatcher"])
	assert_eq(console.run("spawn dunlin"), ["Spawned 1 of 1 dunlin"])
	var listed := " ".join(console.run("spawn"))
	assert_string_contains(listed, "oystercatcher")
	assert_string_contains(listed, "dunlin")
	assert_eq(console.complete("spawn dun"), "spawn dunlin ")
