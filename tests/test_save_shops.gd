extends SaveValidationCase
## What the shops have left is saved (version 51): a half-sold shop is half-sold after a reload,
## and a save from before the shops (version 50) has them full.

const SHOP := "trienke"
const SEEDS := ItemTypes.TURNIP_SEEDS


func test_a_half_sold_shop_is_half_sold_after_a_save_and_a_load() -> void:
	var state := GameState.new_game(7)
	state.player.inventory.add(ItemTypes.EGG, 12)
	state.player.inventory.add(ItemTypes.LOGS, 8)
	assert_eq(state.shops.trade(SHOP, {SEEDS: 4}, {ItemTypes.EGG: 12}, state.player.inventory), "")
	assert_eq(state.shops.trade(SHOP, {SEEDS: 8}, {ItemTypes.LOGS: 8}, state.player.inventory), "")
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.shops.stock_of(SHOP, SEEDS), 28)
	assert_eq(restored.shops.room_of(SHOP, ItemTypes.EGG), 0)
	assert_eq(restored.shops.room_of(SHOP, ItemTypes.LOGS), 2)
	assert_eq(restored.shops.stock_of(SHOP, ItemTypes.CANDLE), 6)
	assert_eq(restored.shops.to_dict(), state.shops.to_dict())


func test_the_stock_still_fills_up_by_the_days_after_a_reload() -> void:
	var state := GameState.new_game(7)
	state.player.inventory.add(ItemTypes.LOGS, 10)
	assert_eq(
		state.shops.trade(SHOP, {SEEDS: 13}, {ItemTypes.LOGS: 10}, state.player.inventory), ""
	)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)
	restored.clock.day += 2

	assert_eq(restored.shops.stock_of(SHOP, SEEDS), 40, "27 left and 10 a day: the most she has")


func test_a_version_50_save_has_the_shop_full() -> void:
	var game := _current_game()
	game.erase("shops")
	_write_save(50, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_eq(restored.shops.stock_of(SHOP, SEEDS), 40)
	assert_eq(restored.shops.room_of(SHOP, ItemTypes.EGG), 12)


func test_a_shop_the_game_no_longer_has_is_left_out() -> void:
	var game := _current_game()
	game["shops"]["ghost"] = {"stock": {"egg": 1}, "room": {}, "restocked_day": 1}
	game["shops"][SHOP] = {
		"stock": {"turnip_seeds": 5, "gold_bar": 3}, "room": {"egg": 2}, "restocked_day": 1
	}
	_write_save(SaveFile.VERSION, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.shops.to_dict().keys(), [SHOP])
	assert_eq(restored.shops.stock_of(SHOP, SEEDS), 5)
	assert_false(restored.shops.to_dict()[SHOP]["stock"].has("gold_bar"))


func test_a_seed_added_to_the_shop_after_the_save_is_full() -> void:
	var game := _current_game()
	game["shops"][SHOP] = {"stock": {"turnip_seeds": 5}, "room": {"egg": 2}, "restocked_day": 1}
	_write_save(SaveFile.VERSION, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.shops.stock_of(SHOP, SEEDS), 5)
	assert_eq(restored.shops.stock_of(SHOP, &"wheat_seeds"), 30, "new to the save: starts full")
	assert_eq(restored.shops.stock_of(SHOP, ItemTypes.CANDLE), 6)


func test_a_damaged_shop_is_refused() -> void:
	var game := _current_game()
	game["shops"][SHOP] = {"stock": {"turnip_seeds": -3}, "room": "none"}
	game["shops"]["other"] = 7

	var reason: String = _refusal_of(game).reason

	assert_string_contains(reason, "shops trienke: no restocked_day")
	assert_string_contains(reason, "shops trienke stock: turnip_seeds -3.0 is not a count")
	assert_string_contains(reason, "shops trienke room: should be a dictionary")
	assert_string_contains(reason, "shops other: should be a dictionary")


func test_a_save_without_the_shops_is_refused() -> void:
	var game := _current_game()
	game.erase("shops")
	assert_string_contains(_refusal_of(game).reason, "no shops")
