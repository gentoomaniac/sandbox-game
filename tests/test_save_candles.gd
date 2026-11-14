extends SaveValidationCase
## How far a candle has burnt is saved with its item (version 40, task 231): in a lantern or on
## its own (a chest saves its slots the same way, see test_item_slots_state.gd). An older save's
## lanterns get a fresh candle. A bad state is refused.


func _state_with_lantern_and_candle() -> GameState:
	var state := GameState.new_game(7)
	var inventory := state.player.inventory
	inventory.slots[6] = {"item": ItemTypes.LANTERN, "count": 1}
	inventory.set_state(6, LanternCandle.lantern_state_with({"burnt_minutes": 700}))
	inventory.slots[5] = {"item": ItemTypes.CANDLE, "count": 1}
	inventory.set_state(5, {"burnt_minutes": 90})
	return state


func test_a_candle_in_a_lantern_and_one_on_its_own_keep_their_burn() -> void:
	var state := _state_with_lantern_and_candle()
	state.player.is_lantern_lit = true
	state.player.inventory.select(6)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	var inventory := restored.player.inventory
	assert_eq(LanternCandle.burnt_minutes(inventory.slots[6]["state"]["candle"]), 700)
	assert_eq(LanternCandle.burnt_minutes(inventory.slots[5]["state"]), 90)
	assert_true(restored.player.is_lantern_shining())
	restored.pass_awake_time(60)
	assert_eq(LanternCandle.burnt_minutes(inventory.slots[6]["state"]["candle"]), 760)


func test_a_version_39_save_loads_its_lanterns_with_a_fresh_candle() -> void:
	var game := _current_game()
	_slots(game)[3] = {"item": "lantern", "count": 1}
	_write_save(39, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.inventory.slots[3]["state"], {"candle": {}})


func test_a_state_that_is_not_a_candles_is_refused() -> void:
	var game := _current_game()
	_slots(game)[1] = {"item": "candle", "count": 1, "state": {"burnt_minutes": 0}}
	_slots(game)[2] = {"item": "candle", "count": 1, "state": {"burnt_minutes": 999999}}
	_slots(game)[3] = {"item": "lantern", "count": 1, "state": {"flame": 1}}
	_slots(game)[4] = {"item": "stone", "count": 1, "state": {}}

	var reason: String = _refusal_of(game).reason

	assert_string_contains(reason, "slot 1: burnt_minutes 0 is not between 1 and")
	assert_string_contains(reason, "slot 2: burnt_minutes 999999 is not between 1 and")
	assert_string_contains(reason, "slot 3: a lantern's state is its candle")
	assert_string_contains(reason, "slot 4: stone has no state")


func test_a_lantern_in_a_pile_on_the_ground_keeps_its_candle() -> void:
	var state := GameState.new_game(7)
	var lantern_state := LanternCandle.lantern_state_with({"burnt_minutes": 250})
	state.world.ground_items.add(
		GroundItem.new(ItemTypes.LANTERN, 1, state.player.position, lantern_state)
	)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	var piles := restored.world.ground_items.all().filter(
		func(pile: GroundItem) -> bool: return pile.item == ItemTypes.LANTERN
	)
	assert_eq(piles.size(), 1)
	assert_eq(LanternCandle.burnt_minutes(piles[0].state["candle"]), 250)


func test_a_version_39_lantern_on_the_ground_gets_a_fresh_candle() -> void:
	var game := _current_game()
	game["world"]["ground_items"].append({"item": "lantern", "count": 1, "position": [4.5, 4.5]})
	_write_save(39, game)

	var restored := SaveFile.read(SAVE_PATH)

	var piles := restored.world.ground_items.all().filter(
		func(pile: GroundItem) -> bool: return pile.item == ItemTypes.LANTERN
	)
	assert_eq(piles[0].state, {"candle": {}})


func test_a_pile_with_a_bad_candle_state_is_refused() -> void:
	var game := _current_game()
	game["world"]["ground_items"].append(
		{"item": "candle", "count": 1, "position": [4.5, 4.5], "state": {"burnt_minutes": 0}}
	)

	assert_string_contains(_refusal_of(game).reason, "burnt_minutes 0 is not between 1 and")
