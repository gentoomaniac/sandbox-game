extends ActivityCase
## A skip (a night's sleep, the console's `skip`) puts each villager where their day has them be at
## its end (ActivityUpkeep `catch_up`): at the place, on the way, or not yet gone.

const SPOT_TILE_X := 40


func _farmer_working_at(x: int) -> Npc:
	var npc := _resident("hinrich")
	npc.workplace = Workplace.of_spot("the landing", _road_tile(x))
	return npc


## Skips from the time set to `end_minute` of the same day.
func _skip_to(end_minute: int) -> void:
	_state.simulation.skip(end_minute - _minute_of_day())


func test_a_night_s_sleep_leaves_the_villager_at_work_in_the_morning() -> void:
	_build_warm_road()
	var npc := _farmer_working_at(SPOT_TILE_X)
	_set_time(DAY, 21)
	_state.simulation.skip(10 * 60)

	assert_eq(_state.clock.day, DAY + 1)
	assert_eq(_minute_of_day(), 7 * 60)
	assert_eq(npc.current_step.activity, "work")
	assert_true(npc.current_step.is_arrived)
	assert_lte(npc.position.distance_to(npc.workplace.spot()), 2.0, "within the circle of the work")
	assert_eq(npc.anchor, npc.workplace.spot())
	assert_null(npc.trip)


func test_one_who_left_less_long_ago_than_the_walk_takes_is_on_the_way() -> void:
	_build_warm_road()
	var npc := _farmer_working_at(SPOT_TILE_X)
	var leaves_at := _leaving_minute_for_work(npc, DAY)
	_set_time(DAY, 3)
	_skip_to(leaves_at + 20)

	assert_eq(npc.current_step.activity, "work")
	assert_false(npc.current_step.is_arrived)
	assert_eq(npc.position, _house.yard(), "put where the entry before had them")
	assert_not_null(npc.trip, "sent on, the search after the skip")
	assert_eq(npc.trip.goal, npc.workplace.spot_tile)

	var step := npc.current_step
	_pass_minutes(1)
	assert_same(npc.current_step, step, "the tick does not send them again")


func test_one_who_has_not_left_yet_stays_at_home() -> void:
	_build_warm_road()
	var npc := _farmer_working_at(SPOT_TILE_X)
	_set_time(DAY, 3)
	_skip_to(_leaving_minute_for_work(npc, DAY) - 5)

	assert_eq(npc.current_step.activity, "", "nothing is on before breakfast")
	assert_null(npc.trip)
	assert_eq(npc.anchor, _house.yard())
	assert_lte(npc.position.distance_to(_house.yard()), 6.0)


func test_a_skip_over_frames_ends_the_same() -> void:
	_build_warm_road()
	var npc := _farmer_working_at(SPOT_TILE_X)
	var start := npc.position
	_set_time(DAY, 21)
	_state.simulation.skip(10 * 60)
	var end_in_one_go := npc.position

	npc.position = start
	npc.current_step = null
	_set_time(DAY, 21)
	var next_frame := func() -> Signal: return get_tree().process_frame
	var budget := Simulation.frame_budget_usec
	Simulation.frame_budget_usec = 0
	await _state.simulation.skip_over_frames(10 * 60, next_frame)
	Simulation.frame_budget_usec = budget

	assert_eq(npc.current_step.activity, "work")
	assert_true(npc.current_step.is_arrived)
	assert_eq(npc.position, end_in_one_go, "where the same skip in one go puts them")


func test_the_same_game_skipped_the_same_way_ends_the_same() -> void:
	var npc := _resident("hinrich")
	var ends: Array[Vector2] = []
	for _try in 2:
		npc.position = _house.yard()
		npc.current_step = null
		_set_time(DAY, 19)
		_skip_to(20 * 60 + 40)
		ends.append(npc.position)
	assert_eq(npc.current_step.activity, "rest")
	assert_eq(ends[0], ends[1])
	assert_lte(npc.position.distance_to(_house.yard()), 3.0, "within the circle of the rest")


func test_one_who_stands_at_a_meal_is_put_near_the_spot() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 11)
	_skip_to(12 * 60 + 30)
	assert_eq(npc.current_step.activity, "dinner")
	assert_lte(npc.position.distance_to(_house.yard()), 1.0)
	assert_true(npc.is_staying_put)


func test_rain_at_the_end_of_a_skip_keeps_them_at_home() -> void:
	var weather := RainyWeather.new(SEED)
	weather.rain = 0.9
	_upkeep.weather = weather
	_world.set_terrain(Vector2i(_house.yard().floor()) + Vector2i(0, 5), Tile.Terrain.SOIL)
	var npc := _resident("hinrich")
	_set_time(DAY, 16)
	_skip_to(17 * 60 + 30)
	assert_eq(npc.current_step.shelter, "rain")
	assert_lte(npc.position.distance_to(_house.yard()), 0.01, "put at home")


func test_a_villager_with_no_house_is_left_to_the_stroll() -> void:
	var npc := _resident("hinrich")
	npc.house = null
	_set_time(DAY, 3)
	_skip_to(10 * 60)
	assert_null(npc.current_step)
	assert_lte(npc.position.distance_to(npc.anchor), 6.0)
