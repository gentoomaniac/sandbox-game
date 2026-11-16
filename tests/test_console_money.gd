extends GutTest
## The console's `money`: shows the purse, sets it, or adds to it or takes from it, never below 0.

var _state: GameState
var _console: Console


func before_each() -> void:
	_state = GameState.new_game(7)
	_console = Console.new(_state)


func test_money_shows_the_purse() -> void:
	assert_eq(_console.run("money"), ["Purse: 32 Schilling"] as Array[String])


func test_a_number_sets_the_purse() -> void:
	assert_eq(_console.run("money 100"), ["Purse: 100 Schilling"] as Array[String])
	assert_eq(_state.player.purse.schilling, 100)
	_console.run("money 0")
	assert_eq(_state.player.purse.schilling, 0)


func test_a_plus_or_minus_changes_the_purse() -> void:
	_console.run("money +10")
	assert_eq(_state.player.purse.schilling, 42)
	_console.run("money -2")
	assert_eq(_state.player.purse.schilling, 40)


func test_the_purse_never_goes_below_zero() -> void:
	_console.run("money -500")
	assert_eq(_state.player.purse.schilling, 0)
	assert_eq(_console.run("money -5"), ["Purse: 0 Schilling"] as Array[String])


func test_the_command_wants_a_whole_number() -> void:
	var usage := ["Usage: money [<Schilling>|+<Schilling>|-<Schilling>]"] as Array[String]
	assert_eq(_console.run("money 1.5"), usage)
	assert_eq(_console.run("money lots"), usage)
	assert_eq(_console.run("money 1 2"), usage)
	assert_eq(_state.player.purse.schilling, 32)
