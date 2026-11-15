extends GutTest
## The console's `quest`: it lists the quests, posts one now, marks one done and clears the list.

var _state: GameState
var _console: Console


func before_each() -> void:
	_state = GameState.new_game(7)
	_state.npcs.add(Npc.create_villager("antje", Vector2.ZERO, _state.npcs.villagers))
	_console = Console.new(_state)


func test_an_empty_list_says_so() -> void:
	assert_eq(_console.run("quest"), ["No quests are open"] as Array[String])


func test_post_puts_a_quest_up_with_a_giver_and_the_list_shows_it() -> void:
	assert_eq(
		_console.run("quest post fibre_for_beans antje"),
		["Posted fibre_for_beans"] as Array[String]
	)

	assert_eq(
		_console.run("quest"),
		["fibre_for_beans: Antje Boysen, posted day 1, to day 8, not taken"] as Array[String]
	)


func test_post_without_a_giver_picks_one() -> void:
	_console.run("quest post fibre_for_beans")

	assert_eq(_state.quests.open_entries()[0]["giver"], "antje")


func test_post_names_what_is_wrong() -> void:
	assert_eq(_console.run("quest post nothing"), ["No quest nothing"] as Array[String])


func test_done_hands_the_quest_in_for_the_player_and_clear_empties_the_list() -> void:
	_console.run("quest post fibre_for_beans")
	var seeds_before := _state.player.inventory.count_of(ItemTypes.TURNIP_SEEDS)

	assert_eq(_console.run("quest done fibre_for_beans"), ["Done fibre_for_beans"] as Array[String])
	assert_eq(
		_console.run("quest done fibre_for_beans"), ["fibre_for_beans is not open"] as Array[String]
	)
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP_SEEDS), seeds_before + 10)
	_console.run("quest post berries_for_the_pot")
	assert_eq(_console.run("quest clear"), ["No quests are open now"] as Array[String])
	assert_true(_state.quests.open_entries().is_empty())


func test_a_wrong_use_shows_the_usage() -> void:
	assert_string_contains(_console.run("quest post")[0], "Usage: quest")
	assert_string_contains(_console.run("quest dance")[0], "Usage: quest")


func test_tab_completes_the_action_and_the_quest() -> void:
	assert_eq(_console.complete("quest cl"), "quest clear ")
	assert_eq(_console.complete("quest post fibre_f"), "quest post fibre_for_beans ")
