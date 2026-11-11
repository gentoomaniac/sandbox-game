class_name IndoorCase
extends ResourceCase
## What the tests of the floors of houses share: a game whose player can step into a house.


## Puts a house near the player and has them walk in. Returns its interior.
func _enter_house() -> Interior:
	var house: Building = null
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := _state.player.tile() + Vector2i(x, y)
			if house == null and _world.placement_blockers(BuildingTypes.KATE, origin).is_empty():
				house = _world.place_building(BuildingTypes.KATE, origin)
	assert_not_null(house, "room for a house")
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_true(_state.is_inside())
	return house.interior


## Has the player walk out of `interior` through its exit.
func _leave_house(interior: Interior) -> void:
	_state.player.position = Vector2(interior.exit_tile) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_false(_state.is_inside())
