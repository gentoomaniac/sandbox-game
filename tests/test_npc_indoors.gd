extends NpcCase
## What villagers do in the room the player is in (#8): they stand and walk about it, on free
## floor, and only those inside that building.

var _house: Building
var _room: Interior


func before_each() -> void:
	super()
	_house = _world.place_building(BuildingTypes.KATE, _middle + Vector2i(-3, -5))
	_room = _house.inside()


func _inside() -> Npc:
	var npc := _add_villager(_house.yard(), _house.yard())
	_npcs.indoors.go_in(npc, _house, true)
	return npc


func _step_room(seconds: float) -> void:
	for _i in int(seconds / STEP_SECONDS):
		_npcs.update_inside(STEP_SECONDS, _room, _state.clock)


func test_a_villager_in_the_room_walks_about_it_on_free_floor() -> void:
	var npc := _inside()
	var start := npc.inside_position
	var has_moved := false
	for _i in int(120.0 / STEP_SECONDS):
		_npcs.update_inside(STEP_SECONDS, _room, _state.clock)
		has_moved = has_moved or npc.inside_position != start
		assert_true(Npcs.can_stand_at(_room, npc.inside_position), str(npc.inside_position))
	assert_true(has_moved)
	assert_eq(npc.position, _house.yard())


func test_villagers_of_another_building_stay_where_they_are() -> void:
	var other := _world.place_building(BuildingTypes.KATE, _middle + Vector2i(4, -5))
	var npc := _add_villager(other.yard(), other.yard())
	_npcs.indoors.go_in(npc, other, true)
	var spot := npc.inside_position
	_step_room(60.0)
	assert_eq(npc.inside_position, spot)


func test_a_villager_who_stands_by_the_day_stays_put() -> void:
	var npc := _inside()
	npc.is_staying_put = true
	var spot := npc.inside_position
	_step_room(60.0)
	assert_eq(npc.inside_position, spot)


func test_nobody_walks_about_at_rest_time() -> void:
	var npc := _inside()
	var spot := npc.inside_position
	_state.clock.minute_of_day = 23 * 60
	_step_room(60.0)
	assert_eq(npc.inside_position, spot)


func test_a_villager_never_leaves_the_room() -> void:
	var npc := _inside()
	_step_room(300.0)
	var tile := Vector2i(npc.inside_position.floor())
	assert_true(Rect2i(Vector2i.ZERO, _room.size).has_point(tile))
