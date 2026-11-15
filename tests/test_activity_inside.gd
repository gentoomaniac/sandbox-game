extends ActivityCase
## The day sends villagers into buildings (#8): to a meal and to sleep in their house, to work in a
## workplace that is a building, out again when the entry is over, and a skip puts them in or out as
## the hour has it.

var _barn: Building


func before_each() -> void:
	super()
	_barn = _world.place_building(BuildingTypes.BARN, _middle + Vector2i(2, -8))
	assert_not_null(_barn, "a barn in the yard")


func _is_inside(npc: Npc, building: Building) -> Callable:
	return func() -> bool: return npc.inside == building


func test_a_building_is_found_by_the_yard_in_front_of_its_door() -> void:
	var places := _upkeep.places
	assert_eq(places.building_at_yard(_house.yard()), _house)
	assert_eq(places.building_at_yard(_barn.yard()), _barn)
	assert_null(places.building_at_yard(_house.yard() + Vector2.RIGHT))
	assert_null(places.building_at_yard(ActivityPlaces.NOWHERE))


func test_they_go_in_for_breakfast() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 5, 50)
	assert_true(_pass_minutes(5, _is_inside(npc, _house)))
	assert_eq(npc.current_step.activity, "breakfast")
	assert_eq(npc.position, _house.yard())
	assert_true(Npcs.can_stand_at(_house.inside(), npc.inside_position))


func test_they_come_out_when_the_meal_is_over() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 5, 50)
	assert_true(_pass_minutes(5, _is_inside(npc, _house)))
	var is_out := func() -> bool: return npc.inside == null
	assert_true(_pass_minutes(120, is_out))
	assert_ne(npc.current_step.activity, "breakfast")
	assert_false(PlayerState.touches_building(_world, npc.position))


func test_they_stay_in_the_room_while_the_entry_is_on() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 12, 20)
	assert_true(_pass_minutes(10, _is_inside(npc, _house)))
	assert_eq(npc.current_step.activity, "dinner")
	var spot := npc.inside_position
	_pass_minutes(30)
	assert_eq(npc.inside, _house)
	assert_eq(npc.inside_position, spot, "nobody strolls in a room the player is not in")


func test_a_workplace_that_is_a_building_is_gone_into() -> void:
	_build_warm_road()
	var npc := _resident("hinrich")
	npc.workplace = Workplace.of_building(_barn)
	_set_time(DAY, 6, 0)
	assert_true(_pass_minutes(120, _is_inside(npc, _barn)))
	assert_eq(npc.current_step.activity, "work")
	assert_eq(npc.position, _barn.yard())


func test_a_workplace_that_is_a_spot_is_not() -> void:
	_build_warm_road()
	var npc := _resident("hinrich")
	npc.workplace = Workplace.of_spot("the landing", _road_tile(40))
	_set_time(DAY, 6, 0)
	var is_there := func() -> bool: return npc.current_step.activity == "work" and npc.trip == null
	assert_true(_pass_minutes(180, is_there))
	assert_null(npc.inside)


func test_a_skip_puts_them_in_the_house_for_the_night() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 20)
	_state.simulation.skip(3 * 60)
	assert_eq(npc.current_step.activity, "sleep")
	assert_eq(npc.inside, _house)
	assert_eq(npc.position, _house.yard())


func test_a_skip_puts_them_out_again_in_the_morning() -> void:
	var npc := _resident("hinrich")
	npc.workplace = Workplace.of_spot("a field", _middle + Vector2i(5, 5))
	_set_time(DAY, 21)
	_state.simulation.skip(60)
	assert_eq(npc.inside, _house)
	_state.simulation.skip(9 * 60)
	assert_eq(npc.current_step.activity, "work")
	assert_null(npc.inside)


func test_they_are_put_in_the_building_they_are_at_after_a_skip_to_work_in_it() -> void:
	_build_warm_road()
	var npc := _resident("hinrich")
	npc.workplace = Workplace.of_building(_barn)
	_set_time(DAY, 21)
	_state.simulation.skip(10 * 60)
	assert_eq(npc.current_step.activity, "work")
	assert_eq(npc.inside, _barn)


func test_a_villager_who_loses_their_house_inside_it_is_put_out() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 5, 50)
	assert_true(_pass_minutes(5, _is_inside(npc, _house)))
	_state.homes.move_out(npc)
	assert_null(npc.house)
	assert_null(npc.inside)
