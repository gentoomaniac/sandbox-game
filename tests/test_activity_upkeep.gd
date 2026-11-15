extends ActivityCase
## Villagers follow the entry of their day that is on (ActivityUpkeep): they leave in time, arrive
## at the place, keep to it, and go home for rain and the dark.

const SPOT_TILE_X := 40


## The farmer Hinrich of the yard's house, working at a spot on the road.
func _farmer_working_at(x: int) -> Npc:
	var npc := _resident("hinrich")
	npc.workplace = Workplace.of_spot("the landing", _road_tile(x))
	return npc


func test_a_villager_leaves_in_time_and_is_there_when_the_entry_starts() -> void:
	_build_warm_road()
	var npc := _farmer_working_at(SPOT_TILE_X)
	var work := _entry_of(npc, DAY, "work")
	var spot := npc.workplace.spot()
	var leaves_at := _leaving_minute_for_work(npc, DAY)
	_set_time(DAY, 5)

	var has_left := func() -> bool: return npc.current_step.activity == "work"
	assert_true(_pass_minutes(120, has_left))
	assert_eq(_minute_of_day(), leaves_at, "the minute the walk and the margin say")
	assert_not_null(npc.trip)
	var is_there := func() -> bool: return npc.current_step.is_arrived
	assert_true(_pass_minutes(120, is_there))
	assert_lte(_minute_of_day(), work.minute, "there by the hour")
	assert_eq(npc.anchor, spot)
	assert_eq(npc.keep_radius, 2.0, "the radius of the work")
	assert_false(npc.is_staying_put)


func test_the_same_entry_is_not_sent_again() -> void:
	_build_warm_road()
	var npc := _farmer_working_at(SPOT_TILE_X)
	_set_time(DAY, 6, 0)
	var is_there := func() -> bool: return npc.current_step != null and npc.current_step.is_arrived
	assert_true(_pass_minutes(120, is_there))
	var step := npc.current_step
	_pass_minutes(15)
	assert_same(npc.current_step, step)
	assert_null(npc.trip)


func test_the_next_entry_replaces_the_one_that_is_on_in_time() -> void:
	_build_warm_road()
	var npc := _farmer_working_at(SPOT_TILE_X)
	var dinner := _entry_of(npc, DAY, "dinner")
	_set_time(DAY, 10, 0)
	npc.position = npc.workplace.spot()
	var is_at_work := func() -> bool: return npc.current_step.activity == "work"
	assert_true(_pass_minutes(5, is_at_work))
	assert_null(npc.trip, "at work already")

	var is_on_the_way := func() -> bool: return npc.trip != null
	assert_true(_pass_minutes(180, is_on_the_way))
	assert_eq(npc.current_step.activity, "dinner")
	assert_lt(_minute_of_day(), dinner.minute, "it leaves before dinner is on")
	var is_home := func() -> bool: return npc.current_step.is_arrived
	assert_true(_pass_minutes(120, is_home))
	assert_lte(_minute_of_day(), dinner.minute)
	assert_true(npc.is_staying_put, "dinner is eaten standing")
	assert_eq(npc.anchor, _house.yard())


func test_a_villager_who_is_at_the_place_already_does_not_walk() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 5, 50)
	_pass_minutes(2)
	assert_eq(npc.current_step.activity, "breakfast")
	assert_null(npc.trip)
	assert_true(npc.current_step.is_arrived)
	assert_true(npc.is_staying_put)
	assert_eq(npc.anchor, _house.yard())


func test_between_entries_they_keep_to_the_yard_of_their_home() -> void:
	var npc := _resident("hinrich")
	npc.anchor = Vector2(_middle) + Vector2(4.5, 4.5)
	_set_time(DAY, 6, 20)
	_pass_minutes(1)
	assert_eq(npc.current_step.activity, "", "breakfast is over, work is not on")
	assert_eq(npc.keep_radius, 0.0, "the stroll of the anchor rule")
	assert_false(npc.is_staying_put)


func test_a_villager_with_no_house_is_not_sent_anywhere() -> void:
	var npc := _resident("hinrich")
	npc.house = null
	var anchor := npc.anchor
	_set_time(DAY, 6, 0)
	_pass_minutes(30)
	assert_null(npc.current_step)
	assert_null(npc.trip)
	assert_eq(npc.anchor, anchor)


func test_giving_a_house_sends_the_villager_at_once() -> void:
	var npc := Npc.create_villager("hinrich", _house.yard(), _npcs.villagers)
	_npcs.add(npc)
	_set_time(DAY, 5, 50)
	assert_null(npc.current_step)
	_state.homes.move_in(npc, _house)
	assert_eq(npc.current_step.activity, "breakfast")
	_state.homes.move_out(npc)
	assert_null(npc.current_step, "no house, no day")


func test_giving_a_workplace_changes_where_the_work_is() -> void:
	_build_warm_road()
	var npc := _resident("hinrich")
	_set_time(DAY, 6, 30)
	_pass_minutes(1)
	var at_home := npc.current_step
	assert_eq(at_home.spot, _house.yard(), "no workplace: the work is at home")
	_state.homes.set_workplace(npc, Workplace.of_spot("the landing", _road_tile(SPOT_TILE_X)))
	assert_eq(npc.current_step.spot, npc.workplace.spot())
	assert_not_same(npc.current_step, at_home)


# --- Rain and the dark ---


func test_it_rains_for_an_activity_that_needs_it_dry_and_not_for_work_indoors() -> void:
	var npc := _resident("hinrich")
	var weather := RainyWeather.new(SEED)
	_upkeep.weather = weather
	_set_time(DAY, 17, 5)
	weather.rain = 0.3
	assert_eq(_upkeep.shelter_of(npc, "water_field"), "rain")
	assert_eq(_upkeep.shelter_of(npc, "work"), "", "no flag: the work goes on")
	assert_eq(_upkeep.shelter_of(npc, "dinner"), "")
	assert_eq(_upkeep.shelter_of(npc, ""), "")
	weather.rain = 0.2
	assert_eq(_upkeep.shelter_of(npc, "water_field"), "", "a drizzle is no rain")


func test_the_dark_is_for_the_activities_that_need_light() -> void:
	var npc := _resident("hinrich")
	_upkeep.weather = RainyWeather.new(SEED)
	var midwinter := 3 * GameClock.DAYS_PER_SEASON + GameClock.DAYS_PER_SEASON / 2
	_set_time(midwinter, 12)
	assert_eq(_upkeep.shelter_of(npc, "tend_field"), "")
	_set_time(midwinter, 17, 30)
	assert_eq(_upkeep.shelter_of(npc, "tend_field"), "dark", "the winter day is short")
	assert_eq(_upkeep.shelter_of(npc, "work"), "")
	_set_time(midwinter, 3)
	assert_eq(_upkeep.shelter_of(npc, "pick_flowers"), "dark")


func test_rain_sends_the_farmer_home_and_he_goes_back_when_it_stops() -> void:
	var npc := _resident("hinrich")
	var weather := RainyWeather.new(SEED)
	_upkeep.weather = weather
	var field_tile := Vector2i(_house.yard().floor()) + Vector2i(0, 5)
	_world.set_terrain(field_tile, Tile.Terrain.SOIL)
	var field := Vector2(field_tile) + Vector2(0.5, 0.5)
	_set_time(DAY, 16, 50)
	var is_at_the_field := func() -> bool:
		return npc.current_step.activity == "water_field" and npc.current_step.is_arrived
	assert_true(_pass_minutes(40, is_at_the_field), "a dry evening: they water")
	assert_eq(npc.anchor, field)

	weather.rain = 0.5
	_pass_minutes(1)
	assert_eq(npc.current_step.shelter, "rain")
	assert_eq(npc.current_step.spot, _house.yard())
	var is_home := func() -> bool: return npc.current_step.is_arrived
	assert_true(_pass_minutes(30, is_home))
	assert_true(npc.is_staying_put, "they wait it out in the yard")
	assert_eq(npc.anchor, _house.yard())

	weather.rain = 0.0
	_pass_minutes(1)
	assert_eq(npc.current_step.shelter, "")
	assert_eq(npc.current_step.spot, field, "back to the field")
	assert_true(_pass_minutes(30, is_at_the_field))


# --- A way that is blocked ---


func test_a_way_that_stays_blocked_is_given_up_and_they_stay_at_home() -> void:
	var npc := _resident("hinrich")
	npc.workplace = Workplace.of_spot("the sea", _middle + Vector2i(YARD_RADIUS + 3, 0))
	_set_time(DAY, 6, 0)
	var is_blocked := func() -> bool:
		return npc.trip != null and npc.trip.state == NpcTrip.State.BLOCKED
	assert_true(_pass_minutes(60, is_blocked))
	assert_eq(npc.current_step.activity, "work")
	var blocked_at := _minute_of_day()
	var is_given_up := func() -> bool: return npc.current_step.is_given_up
	assert_true(_pass_minutes(60, is_given_up))
	assert_gte(_minute_of_day() - blocked_at, 29)
	assert_lte(_minute_of_day() - blocked_at, 32)
	assert_eq(npc.current_step.spot, _house.yard(), "home")
	var is_home := func() -> bool: return npc.current_step.is_arrived
	assert_true(_pass_minutes(30, is_home))
	assert_true(npc.is_staying_put)


## Counts how often a place is looked for.
class CountingPlaces:
	extends ActivityPlaces
	var asked := 0

	func spot_of(npc: Npc, target: String, day: int) -> Vector2:
		asked += 1
		return super(npc, target, day)


func test_a_minute_with_the_same_entry_on_looks_for_no_place() -> void:
	var places := CountingPlaces.new(_world, _npcs)
	_upkeep.places = places
	var npc := _resident("hinrich")
	_set_time(DAY, 5, 50)
	_pass_minutes(2)
	var step := npc.current_step
	var asked := places.asked
	assert_gt(asked, 0, "the first minutes did look")

	_pass_minutes(10)
	assert_same(npc.current_step, step)
	assert_eq(places.asked, asked, "an entry is resolved once, not every minute it is on")
