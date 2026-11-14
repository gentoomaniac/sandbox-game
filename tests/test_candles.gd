extends GutTest
## Wax comes from the console for now, and two candles are made of it by hand (task 231).

var _state: GameState
var _inventory: Inventory
var _crafting: Crafting


func before_each() -> void:
	_state = GameState.new_game(7)
	_state.player.inventory = Inventory.new()
	_inventory = _state.player.inventory
	_crafting = Crafting.new(_state)


func test_the_console_gives_wax() -> void:
	Console.new(_state).run("give wax 3")
	assert_eq(_inventory.count_of(ItemTypes.WAX), 3)


func test_two_candles_are_made_by_hand_of_wax_and_a_fibre() -> void:
	var rules := RecipeRules.default_rules()
	assert_eq(rules.result(&"candle"), ItemTypes.CANDLE)
	assert_eq(rules.station_of(&"candle"), &"", "by hand")
	assert_eq(rules.level(&"candle"), 0.0)
	assert_eq(_crafting.craft(&"candle"), Crafting.Result.MISSING_MATERIALS)
	_inventory.add(ItemTypes.WAX, 2)
	_inventory.add(ItemTypes.FIBRE, 1)

	assert_eq(_crafting.craft(&"candle"), Crafting.Result.CRAFTED)

	assert_eq(_inventory.count_of(ItemTypes.CANDLE), 2)
	assert_eq(_inventory.count_of(ItemTypes.WAX), 0)
	assert_eq(_inventory.count_of(ItemTypes.FIBRE), 0)


func test_fresh_candles_stack() -> void:
	_inventory.add(ItemTypes.CANDLE, 5)
	_inventory.add(ItemTypes.CANDLE, 5)
	assert_eq(_inventory.count_of(ItemTypes.CANDLE), 10)
	assert_eq(
		(
			_inventory
			. slots
			. filter(func(stack: Dictionary) -> bool: return not stack.is_empty())
			. size()
		),
		1
	)
