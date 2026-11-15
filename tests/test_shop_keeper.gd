extends ActivityCase
## The keeper at her stall (ShopHours, Interaction, NpcPrompt): the shop is open while her entry is
## `keep_shop` and she has arrived, E trades with her then and speaks to her otherwise, a shut stall
## has her say why before the player writes, and a model is told about the shop.

const THURSDAY := DAY
const SATURDAY := DAY + 2
const SUNDAY := DAY + 3
const STALL_TILE_X := 30

var _trienke: Npc


func before_each() -> void:
	super()
	_build_warm_road()
	_trienke = _resident("trienke")
	_trienke.workplace = Workplace.of_spot("the market stall", _road_tile(STALL_TILE_X))


## Time `day` at `hour`, with her standing at the stall (as if she had been there all along), the
## player next to her and the minute passed.
func _at_the_stall(day: int, hour: int, minute := 0) -> void:
	_set_time(day, hour, minute)
	_trienke.position = _trienke.workplace.spot()
	_trienke.anchor = _trienke.position
	_state.player.position = _trienke.position + Vector2(0, 1)
	_pass_minutes(1)


func _choice() -> Interaction.Choice:
	return Interaction.choice_at(_state, _trienke.tile())


func test_the_shop_is_open_when_she_has_arrived_and_the_hours_have_begun() -> void:
	_set_time(THURSDAY, 5, 30)
	var is_open := func() -> bool: return ShopHours.is_open(_state, _trienke)
	assert_false(is_open.call(), "at home at half past five")
	_pass_minutes(8 * 60 - 5 * 60 - 30, is_open)
	assert_true(is_open.call())
	assert_gte(_minute_of_day(), 7 * 60, "not before her entry starts, though she is there")
	assert_true(_trienke.current_step.is_arrived)
	assert_lt(_minute_of_day(), 7 * 60 + 15)


func test_the_shop_is_not_open_while_she_is_still_on_the_way() -> void:
	_set_time(THURSDAY, 5, 30)
	var is_on_the_way := func() -> bool:
		return _trienke.current_step.activity == "keep_shop" and _trienke.trip != null
	assert_true(_pass_minutes(180, is_on_the_way))
	assert_false(_trienke.current_step.is_arrived)
	assert_false(ShopHours.is_open(_state, _trienke))


func test_the_shop_is_shut_at_dinner_and_on_sunday() -> void:
	_at_the_stall(THURSDAY, 12, 30)
	assert_false(ShopHours.is_open(_state, _trienke), "dinner is on")
	_at_the_stall(SUNDAY, 8)
	assert_false(ShopHours.is_open(_state, _trienke))


func test_e_trades_with_the_keeper_in_hours_and_speaks_to_her_otherwise() -> void:
	_at_the_stall(THURSDAY, 8)
	assert_true(ShopHours.is_open(_state, _trienke))
	var choice := _choice()
	assert_eq(choice.kind, Interaction.Kind.TRADE)
	assert_eq(choice.subject, _trienke)
	assert_eq(ActionHint.e_text(_state, _trienke.tile()), "Trade with Trienke Lorenzen")
	_at_the_stall(SUNDAY, 8)
	assert_eq(_choice().kind, Interaction.Kind.CHAT)


func test_a_villager_who_keeps_no_shop_is_only_spoken_to() -> void:
	var hinrich := _resident("hinrich")
	hinrich.position = _trienke.workplace.spot() + Vector2(1, 0)
	_state.player.position = hinrich.position + Vector2(0, 1)
	assert_eq(Interaction.choice_at(_state, hinrich.tile()).kind, Interaction.Kind.CHAT)


func test_a_shut_stall_says_when_it_opens_or_when_she_is_back() -> void:
	_at_the_stall(THURSDAY, 6)
	assert_eq(ShopHours.closed_line(_state, _trienke), "The shop opens at 7.")
	_at_the_stall(THURSDAY, 12, 30)
	assert_eq(ShopHours.closed_line(_state, _trienke), "Back at 1.")
	_at_the_stall(THURSDAY, 19)
	assert_eq(ShopHours.closed_line(_state, _trienke), "The shop is shut for today. It opens at 7.")


func test_a_shut_stall_after_saturday_says_until_when() -> void:
	_at_the_stall(SATURDAY, 19)
	assert_eq(ShopHours.closed_line(_state, _trienke), "The shop is shut until Monday, at 7.")


func test_a_shut_stall_on_sunday_says_church() -> void:
	_at_the_stall(SUNDAY, 8)
	assert_eq(ShopHours.closed_line(_state, _trienke), "Closed on Sundays, neighbour. Church.")


func test_there_is_no_line_when_she_is_not_at_the_stall() -> void:
	_at_the_stall(SUNDAY, 8)
	_trienke.position = _trienke.workplace.spot() + Vector2(20, 0)
	assert_eq(ShopHours.closed_line(_state, _trienke), "")
	ShopHours.greet(_state, _trienke)
	assert_true(_trienke.chat_history.is_empty())


func test_she_says_it_first_once_before_the_player_writes() -> void:
	_at_the_stall(THURSDAY, 6)
	ShopHours.greet(_state, _trienke)
	ShopHours.greet(_state, _trienke)
	assert_eq(_trienke.chat_history.size(), 1)
	assert_eq(_trienke.chat_history[0]["text"], "The shop opens at 7.")
	assert_false(_trienke.chat_history[0]["from_player"])


func test_the_times_are_said_as_an_hour_of_twelve() -> void:
	assert_eq(ShopHours.time_text(7 * 60), "7")
	assert_eq(ShopHours.time_text(13 * 60), "1")
	assert_eq(ShopHours.time_text(0), "12")
	assert_eq(ShopHours.time_text(7 * 60 + 30), "7:30")


func test_a_trade_needs_no_model() -> void:
	_at_the_stall(THURSDAY, 8)
	assert_eq(_choice().kind, Interaction.Kind.TRADE)
	var bag := _state.player.inventory
	bag.add(ItemTypes.LOGS, 5)
	assert_eq(_state.shops.trade("trienke", {ItemTypes.CANDLE: 1}, {ItemTypes.LOGS: 5}, bag), "")
	assert_eq(bag.count_of(ItemTypes.CANDLE), 1)


func _last_prompt_text(npc: Npc) -> String:
	var moment := NpcMoment.of(_state, npc, 8.0)
	var messages := NpcPrompt.reply_messages(
		npc, [] as Array[Dictionary], "Moin!", moment, NpcTalkRules.default_rules(), true
	)
	return messages[-1]["content"]


func test_a_model_is_told_the_stall_is_open_and_what_she_sells_and_takes() -> void:
	_at_the_stall(THURSDAY, 8)
	var text := _last_prompt_text(_trienke)
	assert_string_contains(text, "Trienke's stall on the town square is open.")
	assert_string_contains(text, "sells turnip seeds, seed potatoes, carrot seeds,")
	assert_string_contains(text, "pumpkin seeds and candle and takes egg, berries, turnip")
	assert_string_contains(text, "the game sets them")


func test_a_model_is_told_when_the_shut_stall_opens() -> void:
	_at_the_stall(SUNDAY, 8)
	assert_string_contains(_last_prompt_text(_trienke), "stall on the town square is shut.")
	_at_the_stall(THURSDAY, 6)
	assert_string_contains(_last_prompt_text(_trienke), "is shut. It opens at 7.")


func test_what_is_sold_out_is_not_told() -> void:
	_at_the_stall(THURSDAY, 8)
	var bag := _state.player.inventory
	for item: StringName in [ItemTypes.LOGS, ItemTypes.CLAY]:
		bag.add(item, 10)
	for item: StringName in [ItemTypes.FLOUR, ItemTypes.BREAD]:
		bag.add(item, 6)
	var give := {ItemTypes.LOGS: 10, ItemTypes.CLAY: 10, ItemTypes.FLOUR: 6, ItemTypes.BREAD: 6}
	assert_eq(_state.shops.trade("trienke", {ItemTypes.CANDLE: 6}, give, bag), "")
	var text := _last_prompt_text(_trienke)
	assert_string_contains(text, "sells turnip seeds, seed potatoes,")
	assert_string_contains(text, "pumpkin seeds and takes")
	assert_false(text.contains("candle"))
	assert_false(text.contains("flour"), "her room for flour is used up")


func test_someone_who_keeps_no_shop_is_told_nothing_of_one() -> void:
	var hinrich := _resident("hinrich")
	assert_false(_last_prompt_text(hinrich).contains("stall"))
