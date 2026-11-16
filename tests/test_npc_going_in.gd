extends NpcCase
## A villager goes into a building through its door, and comes out of it (#8): the door step, being
## inside while `position` stays in the yard, and what takes a villager out.

var _house: Building


func before_each() -> void:
	super()
	_house = _world.place_building(BuildingTypes.KATE, _middle + Vector2i(-3, -5))
	assert_not_null(_house)


func _villager_in_the_yard() -> Npc:
	var npc := _add_villager(_house.yard(), _house.yard())
	_npcs.indoors.go_in(npc, _house, false)
	return npc


func _door_centre() -> Vector2:
	return Vector2(_house.door_tile()) + Vector2(0.5, 0.5)


func _step_until_inside(npc: Npc) -> int:
	var steps := 0
	while npc.inside == null and steps < 200:
		_step()
		steps += 1
	return steps


func test_a_villager_who_goes_in_walks_onto_the_door_tile_first() -> void:
	var npc := _villager_in_the_yard()
	assert_eq(npc.entering, _house)
	_step()
	assert_null(npc.inside)
	assert_lt(npc.position.y, _house.yard().y, "on its way to the door")
	assert_eq(npc.facing, Vector2i.UP)


func test_a_villager_is_inside_when_they_reach_the_door() -> void:
	var npc := _villager_in_the_yard()
	var steps := _step_until_inside(npc)
	assert_eq(npc.inside, _house)
	assert_null(npc.entering)
	# A tile at the walk speed: a few seconds, not a jump.
	assert_gt(steps, 2)
	assert_eq(npc.position, _house.yard(), "the outside position is the door's yard")


func test_a_villager_inside_stands_on_a_free_tile_of_the_room() -> void:
	var npc := _villager_in_the_yard()
	_step_until_inside(npc)
	var room := _house.inside()
	assert_true(Npcs.can_stand_at(room, npc.inside_position), str(npc.inside_position))
	assert_ne(Vector2i(npc.inside_position.floor()), room.entry_tile())


func test_nobody_who_is_inside_is_moved_by_the_world() -> void:
	var npc := _villager_in_the_yard()
	_step_until_inside(npc)
	var spot := npc.inside_position
	for _i in 400:
		_step()
	assert_eq(npc.position, _house.yard())
	assert_eq(npc.inside_position, spot)
	assert_eq(npc.inside, _house)


func test_a_villager_goes_in_at_once_where_nobody_sees_it() -> void:
	var npc := _villager_in_the_yard()
	_npcs.update_unseen(STEP_SECONDS, _world, _state.clock)
	assert_eq(npc.inside, _house)


func test_a_villager_goes_in_at_once_when_it_is_instant() -> void:
	var npc := _add_villager(_house.yard(), _house.yard())
	_npcs.indoors.go_in(npc, _house, true)
	assert_eq(npc.inside, _house)


func test_going_in_twice_changes_nothing() -> void:
	var npc := _villager_in_the_yard()
	_step_until_inside(npc)
	var spot := npc.inside_position
	_npcs.indoors.go_in(npc, _house, false)
	assert_eq(npc.inside_position, spot)
	assert_null(npc.entering)


func test_a_villager_comes_out_in_the_yard() -> void:
	var npc := _villager_in_the_yard()
	_step_until_inside(npc)
	_npcs.indoors.come_out(npc)
	assert_null(npc.inside)
	assert_eq(npc.position, _house.yard())
	_step()
	assert_false(PlayerState.touches_building(_world, npc.position))


func test_a_villager_who_changes_their_mind_at_the_door_does_not_go_in() -> void:
	var npc := _villager_in_the_yard()
	_step()
	_npcs.indoors.come_out(npc)
	assert_null(npc.entering)
	for _i in 100:
		_step()
	assert_null(npc.inside)
	assert_false(PlayerState.touches_building(_world, npc.position))


func test_a_trip_takes_a_villager_out_of_the_building() -> void:
	var npc := _villager_in_the_yard()
	_step_until_inside(npc)
	_npcs.walk_to(npc, _middle + Vector2i(4, 4), _world)
	assert_null(npc.inside)
	assert_true(npc.is_travelling())


func test_a_placed_villager_is_out_of_the_building() -> void:
	var npc := _villager_in_the_yard()
	_step_until_inside(npc)
	_npcs.is_skipping = true
	_npcs.place(npc, _middle + Vector2i(4, 4), _world)
	_npcs.is_skipping = false
	assert_null(npc.inside)


func test_a_skip_leaves_a_villager_inside_where_they_are() -> void:
	var npc := _villager_in_the_yard()
	_step_until_inside(npc)
	var spot := npc.inside_position
	_npcs.catch_up(_world, SEED, 600)
	assert_eq(npc.inside, _house)
	assert_eq(npc.position, _house.yard())
	assert_eq(npc.inside_position, spot)


func test_taking_the_building_down_puts_those_inside_out() -> void:
	var npc := _villager_in_the_yard()
	_step_until_inside(npc)
	assert_true(Demolition.take_down(_state, _house))
	assert_null(npc.inside)
	assert_true(_saves_and_loads())


func test_taking_the_building_down_stops_those_going_in() -> void:
	var npc := _villager_in_the_yard()
	_step()
	assert_eq(npc.entering, _house)
	assert_true(Demolition.take_down(_state, _house))
	assert_null(npc.entering)
	for _i in 100:
		_step()
	assert_null(npc.inside)
	assert_true(_saves_and_loads())


func _saves_and_loads() -> bool:
	return (
		SaveFile.write(_state, "user://test_going_in.json")
		and SaveFile.read("user://test_going_in.json") != null
	)
