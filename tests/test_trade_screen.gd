extends GutTest
## The trade screen (TradeScreen): its rows, the counts of [-] and [+], the line that says what
## is wrong or right, [Cover it], the state of [Trade], [Talk] and Escape.

const SEEDS := ItemTypes.TURNIP_SEEDS

var _state: GameState
var _keeper: Npc
var _screen: TradeScreen
var _viewport: SubViewport
var _talked_to: Array[Npc] = []


func before_each() -> void:
	_state = GameState.new_game(7)
	_state.player.purse.schilling = 0
	_keeper = Npc.create_villager("trienke", Vector2.ZERO, _state.npcs.villagers)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	add_child_autofree(_viewport)
	_screen = TradeScreen.new()
	_viewport.add_child(_screen)
	_talked_to.clear()
	_screen.talk_requested.connect(func(keeper: Npc) -> void: _talked_to.append(keeper))
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false


func _carry(item: StringName, count: int) -> void:
	assert_eq(_state.player.inventory.add(item, count), 0)


func _open() -> void:
	_screen.open_shop(_keeper, _state)


func test_the_rows_are_what_she_sells_and_what_she_takes() -> void:
	_open()
	assert_eq(_screen._sell_rows.size(), 14)
	assert_eq(_screen._take_rows.size(), 10)
	assert_eq(_screen._title_label.text, "Trienke Lorenzen, the Höker")
	assert_eq(_screen._sell_rows[0]._detail_label.text, "3 ß, 40 left")
	assert_eq(_screen._sell_rows[-1]._detail_label.text, "20 ß, 6 left")


func test_a_row_is_grey_when_there_is_nothing_to_trade() -> void:
	_carry(ItemTypes.EGG, 3)
	_open()
	assert_eq(_screen._take_rows[0].modulate.a, 1.0, "the eggs in the bag")
	assert_eq(_screen._take_rows[0]._detail_label.text, "1 ß, room 12, you have 3")
	assert_lt(_screen._take_rows[1].modulate.a, 1.0, "no berries in the bag")
	assert_eq(_screen._sell_rows[0].modulate.a, 1.0)


func test_the_counts_stay_within_the_stock_the_bag_and_the_room() -> void:
	_carry(ItemTypes.EGG, 20)
	_open()
	_screen.step_want(SEEDS, -1)
	assert_eq(_screen.want, {}, "not below none")
	_screen.step_want(SEEDS, 99)
	assert_eq(_screen.want, {SEEDS: 40}, "not above her stock")
	_screen.step_give(ItemTypes.EGG, 99)
	assert_eq(_screen.give, {ItemTypes.EGG: 12}, "not above her room, though 20 are carried")
	_screen.step_give(ItemTypes.EGG, -99)
	assert_eq(_screen.give, {})
	_screen.step_give(ItemTypes.FIBRE, 1)
	assert_eq(_screen.give, {}, "nothing carried to give")


func test_the_line_says_what_is_short_and_the_trade_button_is_off() -> void:
	_carry(ItemTypes.EGG, 8)
	_open()
	assert_eq(_screen.status_text(), "Choose what to buy or sell.")
	assert_true(_screen._trade_button.disabled)
	assert_true(_screen._cover_button.disabled, "nothing wanted, nothing to cover")
	_screen.step_want(SEEDS, 5)
	assert_eq(_screen.status_text(), "Short by 15 Schilling.")
	_screen.step_give(ItemTypes.EGG, 8)
	assert_eq(_screen.status_text(), "Short by 7 Schilling.")
	assert_eq(_screen._get_label.text, "You get: 5 Turnip seeds (15 ß)")
	assert_eq(_screen._give_label.text, "You give: 8 Egg (8 ß)")
	assert_true(_screen._trade_button.disabled)
	assert_false(_screen._cover_button.disabled)


func test_the_line_says_the_bag_is_full() -> void:
	for slot in Inventory.SLOT_COUNT:
		_state.player.inventory.slots[slot] = {"item": ItemTypes.STONE, "count": 1}
	_state.player.inventory.slots[Inventory.SLOT_COUNT - 1] = {"item": ItemTypes.EGG, "count": 5}
	_open()
	_screen.step_want(SEEDS, 1)
	_screen.step_give(ItemTypes.EGG, 3)
	assert_eq(_screen.status_text(), "Your bag is full.")
	assert_true(_screen._trade_button.disabled)


func test_cover_it_fills_what_is_given_and_a_fair_trade_is_on() -> void:
	_carry(ItemTypes.EGG, 10)
	_carry(ItemTypes.FIBRE, 10)
	_open()
	_screen.step_want(SEEDS, 5)
	_screen._cover_button.pressed.emit()
	assert_eq(_screen.give, {ItemTypes.EGG: 10, ItemTypes.FIBRE: 5})
	assert_eq(_screen.status_text(), "A fair trade.")
	assert_false(_screen._trade_button.disabled)


func test_an_overpayment_says_what_she_pays_and_the_purse_gets_it() -> void:
	_carry(ItemTypes.LOGS, 6)
	_open()
	_screen.step_want(ItemTypes.CANDLE, 1)
	_screen.step_give(ItemTypes.LOGS, 6)
	assert_eq(_screen.status_text(), "She pays you 4 ß.")
	assert_false(_screen._trade_button.disabled)
	_screen._trade_button.pressed.emit()
	assert_eq(_state.player.purse.schilling, 4)
	assert_eq(_screen._purse_label.text, "Your purse: 4 ß")


func test_a_shortfall_says_what_the_player_pays_from_the_purse() -> void:
	_state.player.purse.schilling = 32
	_carry(ItemTypes.EGG, 8)
	_open()
	_screen.step_want(SEEDS, 5)
	_screen.step_give(ItemTypes.EGG, 8)
	assert_eq(_screen.status_text(), "You pay 7 ß.")
	assert_eq(_screen._purse_label.text, "Your purse: 32 ß")
	_screen._trade_button.pressed.emit()
	assert_eq(_state.player.purse.schilling, 25)
	assert_eq(_screen._purse_label.text, "Your purse: 25 ß")


func test_the_player_may_sell_for_coin_with_nothing_wanted() -> void:
	_carry(ItemTypes.LOGS, 2)
	_open()
	_screen.step_give(ItemTypes.LOGS, 2)
	assert_eq(_screen.status_text(), "She pays you 8 ß.")
	assert_false(_screen._trade_button.disabled)


func test_nocost_makes_the_goods_free() -> void:
	_state.cheats.is_cost_off = true
	_open()
	_screen.step_want(SEEDS, 5)
	assert_eq(_screen.status_text(), "A fair trade.")
	assert_eq(_screen._sell_rows[0]._detail_label.text, "0 ß, 40 left")


func test_the_trade_button_does_the_deal_and_clears_the_counts() -> void:
	_carry(ItemTypes.LOGS, 5)
	_open()
	_screen.step_want(ItemTypes.CANDLE, 1)
	_screen.step_give(ItemTypes.LOGS, 5)
	_screen._trade_button.pressed.emit()
	assert_eq(_state.player.inventory.count_of(ItemTypes.CANDLE), 1)
	assert_eq(_state.player.inventory.count_of(ItemTypes.LOGS), 0)
	assert_eq(_state.shops.stock_of("trienke", ItemTypes.CANDLE), 5)
	assert_eq(_screen.want, {})
	assert_eq(_screen.give, {})
	assert_eq(_screen.status_text(), "Done.")
	_screen.step_want(ItemTypes.CANDLE, 1)
	assert_eq(_screen.status_text(), "Short by 20 Schilling.", "the next change clears the note")


func test_a_sold_out_good_is_grey_and_has_no_plus() -> void:
	for item: StringName in [ItemTypes.LOGS, ItemTypes.CLAY]:
		_carry(item, 10)
	for item: StringName in [ItemTypes.FLOUR, ItemTypes.BREAD]:
		_carry(item, 6)
	_open()
	_screen.step_want(ItemTypes.CANDLE, 6)
	_screen.cover()
	_screen.trade()
	assert_eq(_state.shops.stock_of("trienke", ItemTypes.CANDLE), 0)
	var row: TradeRow = _screen._sell_rows[-1]
	assert_lt(row.modulate.a, 1.0)
	assert_true(row._plus.disabled)
	_screen.step_want(ItemTypes.CANDLE, 1)
	assert_eq(_screen.want, {}, "none left to want")


func test_talk_asks_for_the_chat_with_the_keeper() -> void:
	_open()
	_screen._talk_button.pressed.emit()
	assert_eq(_talked_to, [_keeper] as Array[Npc])


func test_the_game_stands_still_and_escape_leaves() -> void:
	_open()
	assert_true(_screen.is_open())
	assert_true(get_tree().paused)
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	_viewport.push_input(event)
	assert_false(_screen.is_open())
	assert_false(get_tree().paused)


func test_opening_again_starts_afresh() -> void:
	_carry(ItemTypes.EGG, 3)
	_open()
	_screen.step_give(ItemTypes.EGG, 2)
	_open()
	assert_eq(_screen.give, {})
	assert_eq(_screen._take_rows.size(), 10, "no rows twice")
