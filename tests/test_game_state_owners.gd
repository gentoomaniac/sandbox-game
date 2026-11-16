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
	PlayerRest.pass_awake_time(state, 5)
	PlayerRest.go_to_home_bed(state)
	PlayerRest.teleport_to(state, Vector2i(3, 3))
	var state_ref: WeakRef = weakref(state)

	state = null

	assert_null(state_ref.get_ref())


func test_a_game_is_freed_with_the_systems_the_factory_installed() -> void:
	var state := GameFactory.new_game(7, true)
	state.simulation.advance(90)
	var state_ref: WeakRef = weakref(state)

	state = null

	assert_null(state_ref.get_ref())
