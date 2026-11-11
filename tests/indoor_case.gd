class_name IndoorCase
extends ResourceCase
## What the tests of the floors of houses share: a game whose player can step into a house.


## Puts a house near the player and has them walk in. Returns its interior.
func _enter_house() -> Interior:
	return _walk_in(_place_house())


func _place_house() -> Building:
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := _state.player.tile() + Vector2i(x, y)
			if _world.placement_blockers(BuildingTypes.KATE, origin).is_empty():
				return _world.place_building(BuildingTypes.KATE, origin)
	fail_test("no room for a house")
	return null


## Has the player walk in through the door of `house`.
func _walk_in(house: Building) -> Interior:
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_true(_state.is_inside())
	return house.interior


## Has the player walk out through the exit of `interior`.
func _leave_house(interior: Interior) -> void:
	_state.player.position = Vector2(interior.exit_tile) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_false(_state.is_inside())
