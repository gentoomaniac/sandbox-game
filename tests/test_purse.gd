extends GutTest
## The player's money (Purse): whole Schilling, never below 0.


func test_a_new_game_starts_with_the_start_purse() -> void:
	var state := GameFactory.new_game(7)
	assert_eq(state.player.purse.schilling, 32)
	assert_eq(state.player.purse.schilling, Prices.default_prices().start_purse())


func test_adding_and_spending() -> void:
	var purse := Purse.new(10)
	purse.add(5)
	assert_eq(purse.schilling, 15)
	assert_true(purse.spend(15))
	assert_eq(purse.schilling, 0)


func test_spending_more_than_it_holds_changes_nothing() -> void:
	var purse := Purse.new(10)
	assert_false(purse.can_afford(11))
	assert_false(purse.spend(11))
	assert_eq(purse.schilling, 10)
	assert_true(purse.can_afford(10))


func test_a_change_is_told() -> void:
	var purse := Purse.new(10)
	watch_signals(purse)
	purse.add(0)
	assert_signal_not_emitted(purse, "changed")
	purse.add(1)
	assert_signal_emit_count(purse, "changed", 1)
