extends GutTest
## The owners of what GameState does (PlayerTravel, PlayerRest, GameFactory) are given the game on
## each call and never keep it: a game that is let go must really be freed, or every reload leaks
## the whole world.


func test_a_game_is_freed_after_the_player_travelled_and_rode() -> void:
	var state := GameFactory.new_game(7)
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"brown", state.player.position)
	horse.is_saddled = true
	state.livestock.add(horse)
	PlayerTravel.mount(state, horse)
	PlayerTravel.walk(state, Vector2.RIGHT, 0.1, PlayerTravel.walk_speed_factor(state))
	var state_ref: WeakRef = weakref(state)

	horse = null
	state = null

	assert_null(state_ref.get_ref())


func test_a_game_is_freed_after_the_player_slept_and_passed_a_door() -> void:
	var state := GameFactory.new_game(7)
	var house := _house_near_the_player(state)
	state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	PlayerRest.pass_door(state)
	var bed: WorldObject = house.interior.object_at(Vector2i(1, 2))
	PlayerRest.sleep_in(state, bed)
	var next_frame := func() -> Signal: return get_tree().process_frame
	await PlayerRest.sleep_in_over_frames(state, bed, next_frame)
	state.player.position = Vector2(house.interior.exit_tile) + Vector2(0.5, 0.5)
	PlayerRest.pass_door(state)
	PlayerRest.pass_awake_time(state, 5)
	PlayerRest.go_to_home_bed(state)
	PlayerRest.teleport_to(state, Vector2i(3, 3))
	var state_ref: WeakRef = weakref(state)

	house = null
	bed = null
	state = null
	# A finished `await` keeps its function's arguments, the game among them, until a frame later.
	await wait_process_frames(3)

	assert_null(state_ref.get_ref())


func test_a_game_is_freed_with_the_systems_the_factory_installed() -> void:
	var state := GameFactory.new_game(7, true)
	state.simulation.advance(90)
	var state_ref: WeakRef = weakref(state)

	state = null

	assert_null(state_ref.get_ref())


## A cottage built on free ground near the player. IndoorCase `_place_house` does the same for the
## game it keeps; this test cannot keep one, as it lets its game go to see it freed.
func _house_near_the_player(state: GameState) -> Building:
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := state.player.tile() + Vector2i(x, y)
			if state.world.placement_blockers(BuildingTypes.KATE, origin).is_empty():
				return state.world.place_building(BuildingTypes.KATE, origin)
	fail_test("no room for a house")
	return null
