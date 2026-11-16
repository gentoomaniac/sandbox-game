extends GutTest
## The console's `goto` sends a villager to a tile, or to where the player stands, to watch the way
## they find (see Npcs `walk_to`).

var _state: GameState
var _console: Console
var _antje: Npc


func before_each() -> void:
	_state = GameFactory.new_game(7)
	_console = Console.new(_state)
	_antje = Npc.create_villager("antje", Vector2.ZERO, _state.npcs.villagers)
	_state.npcs.add(_antje)


func test_a_villager_is_sent_to_the_tile() -> void:
	var lines := _console.run("goto antje 3,-4")
	assert_true(_antje.is_travelling())
	assert_eq(_antje.trip.goal, Vector2i(3, -4))
	assert_eq(lines, ["Antje Boysen is on its way to (3, -4), 5 tiles off"] as Array[String])


func test_here_is_the_tile_the_player_stands_on() -> void:
	_console.run("goto antje here")
	assert_eq(_antje.trip.goal, _state.player.tile())


func test_a_villager_who_is_there_already_says_so() -> void:
	var lines := _console.run("goto antje 0,0")
	assert_false(_antje.is_travelling())
	assert_eq(lines, ["Antje Boysen is at (0, 0) already"] as Array[String])


func test_a_wrong_usage_is_told() -> void:
	var usage := ["Usage: goto <villager> <x>,<y>|here"] as Array[String]
	for line in ["goto", "goto antje", "goto antje 3", "goto antje a,b", "goto antje 1,2,3"]:
		assert_eq(_console.run(line), usage, line)
	assert_false(_antje.is_travelling())


func test_an_unknown_villager_is_told_with_those_there_are() -> void:
	var lines := _console.run("goto nobody here")
	assert_eq(lines[0], "Unknown villager: nobody")
	assert_gt(lines.size(), 1)


func test_tab_completes_the_villager_and_here() -> void:
	assert_eq(_console.complete("goto ant"), "goto antje ")
	assert_eq(_console.complete("goto antje h"), "goto antje here ")


func test_a_tile_with_a_minus_is_read() -> void:
	_console.run("goto antje -3,-4")
	assert_eq(_antje.trip.goal, Vector2i(-3, -4))


func test_a_tile_outside_the_world_is_no_way_once_it_is_searched() -> void:
	var lines := _console.run("goto antje 9000,9000")
	assert_eq(
		lines, ["Antje Boysen is on its way to (9000, 9000), 12729 tiles off"] as Array[String]
	)
	_state.npcs.update(0.05, _state.world, _state.player.position, _state.clock)
	assert_eq(_antje.trip.state, NpcTrip.State.BLOCKED)
	assert_string_contains(_state.npcs.path_text(Vector2.ZERO), "blocked (no way)")


func test_here_inside_a_house_is_refused() -> void:
	var house: Building
	var around := _state.player.tile()
	for y in range(-12, 13):
		for x in range(-12, 13):
			if house == null:
				house = _state.world.place_building(BuildingTypes.KATE, around + Vector2i(x, y))
	assert_not_null(house)
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	PlayerRest.pass_door(_state)
	assert_true(_state.is_inside())
	assert_eq(
		_console.run("goto antje here"),
		["Go outside first: villagers walk in the world"] as Array[String]
	)
	assert_false(_antje.is_travelling())
