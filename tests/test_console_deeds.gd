extends GutTest
## The console's `deeds` command lists the deed log.

var _state: GameState
var _console: Console


func before_each() -> void:
	_state = GameState.new_game(7)
	_console = Console.new(_state)


func test_without_deeds_it_says_so() -> void:
	assert_eq(_console.run("deeds"), ["No deeds seen yet"] as Array[String])


func test_it_lists_a_deed_with_its_day_time_place_and_witnesses() -> void:
	var tile := _state.player.tile()
	var feet := Vector2(tile) + Vector2(3.5, 0.5)
	var antje := Npc.create_villager("antje", feet, _state.npcs.villagers)
	antje.anchor = feet
	_state.npcs.add(antje)
	_state.clock.day = 4
	_state.clock.minute_of_day = 745
	for _tree in 7:
		_state.report(ActionOutcome.BREAK, tile, WorldObjectTypes.OAK, {})

	assert_eq(
		_console.run("deeds"),
		["Day 4, 12:25: fell 7 trees by Antje's house, seen by Antje Boysen"] as Array[String]
	)


func test_a_deed_older_than_7_days_is_not_listed() -> void:
	var old := {"day": 1, "minute": 600, "kind": GossipRules.TILLED, "count": 1, "place": "x"}
	old["witnesses"] = []
	_state.deeds.entries.append(old)
	_state.clock.day = 8

	assert_eq(_console.run("deeds"), ["No deeds seen yet"] as Array[String])
