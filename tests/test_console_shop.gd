extends GutTest
## The console's `shop`: it opens the trade with the keeper, in or out of hours, and `shop restock`
## fills the shop again.

var _state: GameState
var _console: Console
var _opened: Array[Npc] = []


func before_each() -> void:
	_state = GameFactory.new_game(7)
	_console = Console.new(_state)
	_opened.clear()
	_console.context.shop_opener = func(keeper: Npc) -> void: _opened.append(keeper)


func _spawn_trienke() -> Npc:
	var npc := Npc.create_villager("trienke", Vector2.ZERO, _state.npcs.villagers)
	_state.npcs.add(npc)
	return npc


func test_shop_opens_the_trade_with_the_keeper() -> void:
	var trienke := _spawn_trienke()
	assert_eq(_console.run("shop"), ["Trading with Trienke Lorenzen"] as Array[String])
	assert_eq(_opened, [trienke] as Array[Npc])


func test_shop_says_where_to_find_the_keeper_when_she_is_not_in_the_world() -> void:
	assert_eq(_console.run("shop"), ["No keeper in this world: spawn npc trienke"] as Array[String])
	assert_true(_opened.is_empty())


func test_shop_without_a_trade_screen_says_so() -> void:
	_spawn_trienke()
	_console.context.shop_opener = Callable()
	assert_eq(_console.run("shop"), ["No trade screen here"] as Array[String])


func test_restock_fills_the_stock_again() -> void:
	var bag := _state.player.inventory
	bag.add(ItemTypes.LOGS, 10)
	assert_eq(
		_state.shops.trade("trienke", {ItemTypes.TURNIP_SEEDS: 10}, {ItemTypes.LOGS: 8}, bag), ""
	)
	assert_eq(_state.shops.stock_of("trienke", ItemTypes.TURNIP_SEEDS), 30)
	assert_eq(_console.run("shop restock"), ["The shop is full again"] as Array[String])
	assert_eq(_state.shops.stock_of("trienke", ItemTypes.TURNIP_SEEDS), 40)
	assert_true(_opened.is_empty())


func test_shop_takes_no_other_word() -> void:
	assert_eq(_console.run("shop sell")[0], "Usage: shop [restock]")
	assert_eq(_console.run("shop restock now")[0], "Usage: shop [restock]")
