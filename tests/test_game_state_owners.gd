extends GutTest
## The owners a GameState holds (PlayerTravel, ...) are given the game on each call and never
## keep it: a game that is let go must really be freed, or every reload leaks the whole world.


func test_a_game_is_freed_after_the_player_travelled_and_rode() -> void:
	var state := GameState.new_game(7)
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"brown", state.player.position)
	horse.is_saddled = true
	state.livestock.add(horse)
	state.travel.mount(state, horse)
	state.travel.walk(state, Vector2.RIGHT, 0.1, state.travel.walk_speed_factor(state))
	var state_ref: WeakRef = weakref(state)
	var travel_ref: WeakRef = weakref(state.travel)

	horse = null
	state = null

	assert_null(state_ref.get_ref())
	assert_null(travel_ref.get_ref())


func test_a_game_is_freed_after_the_player_slept_and_passed_a_door() -> void:
	var state := GameState.new_game(7)
	PlayerRest.pass_awake_time(state, 5)
	PlayerRest.go_to_home_bed(state)
	PlayerRest.teleport_to(state, Vector2i(3, 3))
	var state_ref: WeakRef = weakref(state)

	state = null

	assert_null(state_ref.get_ref())
