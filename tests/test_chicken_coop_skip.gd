extends CoopCase
## The chicken coop and a skip of time (sleeping) (task 122): the egg of each night is counted, as
## many as there are roosts, for the hens that can walk to the coop, and their needs are met like
## the others'.


func test_a_skip_over_bedtime_counts_the_egg_of_each_hen_and_leaves_them_asleep_inside() -> void:
	var hens := _hens(3)
	_state.clock.day = DAY
	_state.clock.set_time(12, 0)
	_state.simulation.skip(14 * GameClock.MINUTES_PER_HOUR)
	assert_eq(_state.clock.time_text(), "02:00")
	assert_eq(_housed(hens).size(), 3)
	assert_eq(_eggs(), 3)


func test_a_skip_over_a_night_into_the_morning_counts_the_eggs_and_lets_the_hens_out() -> void:
	var hens := _hens(3)
	_state.clock.day = DAY
	_state.clock.set_time(16, 0)
	_state.simulation.skip(16 * GameClock.MINUTES_PER_HOUR)
	assert_eq(_state.clock.time_text(), "08:00")
	assert_eq(_eggs(), 3, "one egg a hen for the night")
	assert_eq(_housed(hens).size(), 0)


func test_a_skip_that_does_not_reach_bedtime_lays_no_egg() -> void:
	_hens(3)
	_state.clock.day = DAY
	_state.clock.set_time(9, 0)
	_state.simulation.skip(3 * GameClock.MINUTES_PER_HOUR)
	assert_eq(_eggs(), 0)


func test_a_skip_to_the_morning_lays_no_more_eggs_than_there_are_roosts() -> void:
	_hens(8)
	_state.clock.day = DAY
	_state.clock.set_time(16, 0)
	_state.simulation.skip(16 * GameClock.MINUTES_PER_HOUR)
	assert_eq(_eggs(), 6, "six roosts, six eggs")


func test_a_hen_on_the_far_side_of_the_water_is_not_put_in_the_coop_by_a_skip() -> void:
	var beyond := _middle + Vector2i(PEN_RADIUS + 3, 0)
	for x in range(-1, 2):
		_world.remove_object(beyond + Vector2i(x, 0))
		_world.set_terrain(beyond + Vector2i(x, 0), Tile.Terrain.GRASS)
	var hen := FarmAnimal.new(LivestockRules.CHICKEN, &"brown", Vector2(beyond) + Vector2(0.5, 0.5))
	_livestock.add(hen)
	_state.clock.day = DAY
	_state.clock.set_time(12, 0)
	_state.simulation.skip(14 * GameClock.MINUTES_PER_HOUR)
	assert_false(hen.is_housed)
	assert_eq(_eggs(), 0)
	_run(10.0, NIGHT)
	assert_false(hen.is_housed, "nor does she walk there at bedtime")


func test_a_hen_settled_in_the_coop_by_a_skip_meets_her_needs_like_the_others() -> void:
	var hen := _hens(1)[0]
	_state.cheats.are_needs_off = false
	_state.clock.day = DAY
	_state.clock.set_time(12, 0)
	_state.simulation.skip(14 * GameClock.MINUTES_PER_HOUR)
	assert_true(hen.is_housed)
	assert_lt(hen.thirst, _livestock.yard.needs("seek_at"), "she drank in the night")
	assert_lt(hen.hunger, _livestock.yard.needs("seek_at"), "and pecked")


func test_a_bedtime_in_the_first_walked_minutes_of_a_skip_still_lays_its_egg() -> void:
	var hen := _hens(1)[0]
	var bedtime := 0
	for minute in range(12 * 60, 24 * 60):
		if _livestock.is_sleep_time(hen, DAY, minute):
			bedtime = minute
			break
	assert_gt(bedtime, 0)
	_state.clock.day = DAY
	_state.clock.set_time((bedtime - 1) / 60, (bedtime - 1) % 60)
	_state.simulation.skip(10 * GameClock.MINUTES_PER_HOUR)
	assert_eq(_eggs(), 1)


func test_the_roosts_a_skip_took_are_free_again_for_the_next_night() -> void:
	var hens := _hens(6)
	_state.clock.day = DAY
	_state.clock.set_time(16, 0)
	_state.simulation.skip(16 * GameClock.MINUTES_PER_HOUR)
	assert_eq(_eggs(), 6)
	assert_true(_livestock._roost_taken.is_empty(), "nothing is kept after the skip")
	_run(60.0, NIGHT)
	assert_eq(_housed(hens).size(), 6, "all six get in the next night")


func test_a_skip_by_day_with_no_bedtime_in_it_reserves_no_roost() -> void:
	_hens(3)
	_state.clock.day = DAY
	_state.clock.set_time(9, 0)
	_state.simulation.skip(3 * GameClock.MINUTES_PER_HOUR)
	assert_true(_livestock._roost_taken.is_empty())


func test_a_skip_shorter_than_the_walked_minutes_still_sends_the_hen_to_the_coop() -> void:
	var hen := _hens(1)[0]
	var bedtime := 0
	for minute in range(12 * 60, 24 * 60):
		if _livestock.is_sleep_time(hen, DAY, minute):
			bedtime = minute
			break
	_state.clock.day = DAY
	_state.clock.set_time((bedtime - 1) / 60, (bedtime - 1) % 60)
	_state.simulation.skip(2)
	assert_false(hen.is_housed, "she slept where she stood while the minutes were walked")
	_run(40.0, bedtime + 1)
	assert_true(hen.is_housed)
	assert_eq(_eggs(), 1)


func test_a_hen_in_the_cooldown_of_a_failed_search_still_goes_to_the_coop_after_a_short_skip(
) -> void:
	var hen := _hens(1)[0]
	var bedtime := 0
	for minute in range(12 * 60, 24 * 60):
		if _livestock.is_sleep_time(hen, DAY, minute):
			bedtime = minute
			break
	_state.clock.day = DAY
	_state.clock.set_time((bedtime - 1) / 60, (bedtime - 1) % 60)
	hen.search_seconds = 30.0
	_state.simulation.skip(2)
	assert_true(hen.missed_roost, "the roost is due")
	_run(40.0, bedtime + 1)
	assert_true(hen.is_housed)
	assert_eq(_eggs(), 1)
