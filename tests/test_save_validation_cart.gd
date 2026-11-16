extends SaveValidationCase
## The prices and the till of a sales cart (see SalesCart) pass the save check through the real
## loader, and broken ones are refused.


func _with_cart(game: Dictionary, state: Dictionary) -> void:
	var grid := []
	grid.resize(WorldObject.storage_slot_count(WorldObjectStall.SALES_CART))
	grid[0] = {"item": str(ItemTypes.EGG), "count": 4}
	_with_object_edit(
		game,
		{"type": str(WorldObjectStall.SALES_CART), "pos": [3, 4], "state": state, "storage": grid}
	)


func _reason_of_cart_with(state: Dictionary) -> String:
	var game := _current_game()
	_with_cart(game, state)
	return _refusal_of(game).reason


func test_a_cart_with_prices_and_a_till_loads_with_them() -> void:
	var game := _current_game()
	_with_cart(game, {"till": 7, "prices": {"0": {"item": str(ItemTypes.EGG), "price": 7}}})
	_write_save(SaveFile.VERSION, game)

	var result := SaveFile.load_game(SAVE_PATH)

	assert_eq(result.outcome, LoadResult.Outcome.READY, str(result.problems))
	var cart: SalesCart = SalesCart.all_in(result.state.world)[0]
	assert_eq(cart.price_of(0), 7)
	assert_eq(cart.till(), 7)


func test_a_price_below_one_or_not_whole_is_refused() -> void:
	for bad in [0, 2.5, "7"]:
		var prices := {"0": {"item": str(ItemTypes.EGG), "price": bad}}
		assert_string_contains(_reason_of_cart_with({"prices": prices}), "price")


func test_prices_that_are_not_by_slot_or_not_dictionaries_are_refused() -> void:
	assert_string_contains(_reason_of_cart_with({"prices": [7]}), "prices")
	assert_string_contains(_reason_of_cart_with({"prices": {"first": {}}}), "slot number")
	assert_string_contains(_reason_of_cart_with({"prices": {"0": 7}}), "prices 0")


func test_a_negative_or_part_till_is_refused() -> void:
	for bad in [-1, 2.5]:
		assert_string_contains(_reason_of_cart_with({"till": bad}), "till")


func test_a_price_for_an_item_the_game_no_longer_has_is_asked_about_and_dropped() -> void:
	var game := _current_game()
	_with_cart(game, {"prices": {"0": {"item": "old_cheese", "price": 3}}})

	var result := _question_about(game)

	assert_eq(result.missing.size(), 1)
	assert_string_contains(result.missing[0], "item old_cheese")
	var cart: SalesCart = SalesCart.all_in(result.load_dropping_missing().world)[0]
	assert_eq(cart.price_of(0), Prices.default_prices().worth(ItemTypes.EGG))
