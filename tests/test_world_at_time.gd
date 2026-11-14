extends TravelMaskCase
## The world's answers at a time given, not the clock's: the tide over the mud and the plants of the
## season (what a search needs for the time it expects to be somewhere, see TravelView).


func before_each() -> void:
	super()
	load_chunk_and_neighbours(COAST)
	load_chunk_and_neighbours(MUD)


func test_mud_is_flooded_at_high_water_and_not_at_low_whatever_the_clock_says() -> void:
	var tile := empty_row(MUD, Tile.Terrain.MUD)
	var low_water := LOW_WATER_HOUR * GameClock.MINUTES_PER_HOUR + LOW_WATER_MINUTE
	set_low_water()
	assert_true(world.is_flooded_at(tile, HIGH_WATER_HOUR))
	assert_false(world.is_flooded_at(tile, low_water))
	assert_false(world.is_flooded(tile), "the clock is at low water")
	assert_true(world.is_walkable(tile), "the clock is at low water")
	assert_false(world.is_walkable_at(tile, HIGH_WATER_HOUR))
	assert_true(world.is_walkable_at(tile, low_water))


func test_a_dormant_plant_is_not_there_on_the_day_given_whatever_the_clock_says() -> void:
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
	world.clock.day = present_day
	assert_eq(world.object_on(tile, present_day), fern)
	assert_null(world.object_on(tile, dormant_day))
	assert_true(world.is_dormant_on(fern, dormant_day))
	assert_false(world.is_dormant_on(fern, present_day))
	assert_eq(world.object_at(tile), fern)


func test_the_day_of_a_game_minute() -> void:
	assert_eq(GameClock.day_of(0), 1)
	assert_eq(GameClock.day_of(GameClock.MINUTES_PER_DAY - 1), 1)
	assert_eq(GameClock.day_of(GameClock.MINUTES_PER_DAY), 2)
	world.clock.set_time(7, 30)
	world.clock.day = 5
	assert_eq(GameClock.day_of(world.clock.total_minutes()), 5)
