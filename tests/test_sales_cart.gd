extends ResourceCase
## The player's sales cart (SalesCart, CartScreen): what it holds and sells for, the price rules,
## the till, what is saved with it, and what E does on it.

const EGG := ItemTypes.EGG
const FIBRE := ItemTypes.FIBRE

var _cart: SalesCart


func before_each() -> void:
	super()
	var object := WorldObject.new(WorldObjectStall.SALES_CART, _tile)
	_world.add_object(object)
	_cart = SalesCart.new(object)


func test_the_cart_has_ten_slots_and_is_a_recipe_of_the_workbench() -> void:
	assert_eq(_cart.slots().slots.size(), 10)
	var rules := RecipeRules.default_rules()
	assert_eq(rules.station_of(&"sales_cart"), &"workbench")
	assert_eq(rules.result(&"sales_cart"), ItemTypes.SALES_CART)
	assert_eq(ItemTypes.TYPES[ItemTypes.SALES_CART]["places"], WorldObjectStall.SALES_CART)


func test_a_stack_sells_for_its_worth_until_the_player_sets_a_price() -> void:
	_cart.slots().add(EGG, 6)
	assert_true(_cart.is_for_sale(0))
	assert_eq(_cart.price_of(0), 2, "the worth of an egg")
	assert_true(_cart.set_price(0, 5))
	assert_eq(_cart.price_of(0), 5)


func test_a_price_is_a_whole_number_from_one_and_only_for_goods_with_a_worth() -> void:
	_cart.slots().add(EGG, 1)
	assert_false(_cart.set_price(0, 0))
	assert_eq(_cart.price_of(0), 2)
	_cart.slots().add(ItemTypes.LANTERN, 1)
	assert_false(_cart.is_for_sale(1), "no worth, no sale")
	assert_eq(_cart.price_of(1), 0)
	assert_false(_cart.set_price(1, 3))
	assert_eq(_cart.price_of(5), 0, "an empty slot")


func test_a_price_belongs_to_the_item_it_was_set_for() -> void:
	_cart.slots().add(EGG, 1)
	_cart.set_price(0, 9)
	_cart.slots().take_from(0, 1)
	_cart.slots().add(FIBRE, 1)
	assert_eq(_cart.price_of(0), 3, "fibre in the slot of the eggs: its worth")


func test_a_sale_takes_one_from_the_stack_and_puts_the_price_in_the_till() -> void:
	_cart.slots().add(EGG, 2)
	_cart.set_price(0, 4)
	assert_eq(_cart.sell_one(0), 4)
	assert_eq(_cart.slots().count_of(EGG), 1)
	assert_eq(_cart.till(), 4)
	_cart.sell_one(0)
	assert_eq([_cart.slots().count_of(EGG), _cart.till()], [0, 8])
	assert_eq(_cart.sell_one(0), 0, "nothing left to sell")


func test_the_takings_go_into_the_purse_by_hand() -> void:
	_cart.slots().add(EGG, 3)
	_cart.sell_one(0)
	_cart.sell_one(0)
	var purse := Purse.new(10)
	assert_eq(_cart.take_takings(purse), 4)
	assert_eq([purse.schilling, _cart.till()], [14, 0])
	assert_eq(_cart.take_takings(purse), 0)


func test_the_player_stocks_the_cart_and_takes_goods_back() -> void:
	var bag := _state.player.inventory
	bag.add(EGG, 5)
	bag.add(ItemTypes.LANTERN, 1)
	var egg_slot := bag.slots.find_custom(func(s: Dictionary) -> bool: return s.get("item") == EGG)
	var lantern_slot := bag.slots.find_custom(
		func(s: Dictionary) -> bool: return s.get("item") == ItemTypes.LANTERN
	)
	assert_false(_cart.stock(bag, lantern_slot), "no worth, not for the cart")
	assert_true(_cart.stock(bag, egg_slot))
	assert_eq([bag.count_of(EGG), _cart.slots().count_of(EGG)], [0, 5])
	assert_true(_cart.take_back(bag, 0))
	assert_eq([bag.count_of(EGG), _cart.slots().count_of(EGG)], [5, 0])


func test_the_prices_and_the_till_are_saved_with_the_cart() -> void:
	_cart.slots().add(EGG, 4)
	_cart.set_price(0, 7)
	_cart.sell_one(0)

	var data: Dictionary = JSON.parse_string(JSON.stringify(_cart.object.to_dict()))
	var restored := SalesCart.new(WorldObject.from_dict(data))

	assert_eq(restored.slots().count_of(EGG), 3)
	assert_eq(restored.price_of(0), 7)
	assert_eq(restored.till(), 7)


func test_every_cart_of_the_world_is_found_and_the_rest_is_not() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.CHEST, _tile + Vector2i(2, 0)))
	_world.add_object(WorldObject.new(WorldObjectStall.SALES_CART, _tile + Vector2i(4, 0)))
	assert_eq(SalesCart.all_in(_world).size(), 2)


func test_e_on_the_cart_opens_it_and_the_hint_says_so() -> void:
	var choice := Interaction.choice_at(_state, _tile)
	assert_eq(choice.kind, Interaction.Kind.OPEN_CART)
	assert_eq(choice.subject, _cart.object)


func test_the_screen_stocks_prices_and_empties_the_till() -> void:
	var bag := _state.player.inventory
	bag.add(EGG, 5)
	bag.hold(EGG)
	var screen := CartScreen.new()
	add_child_autofree(screen)
	screen.open_cart(_cart.object, _state.player)
	assert_false(screen._put_button.disabled)
	assert_eq(screen._put_button.text, "Put Egg on the cart")

	screen._put_button.pressed.emit()
	assert_eq(_cart.slots().count_of(EGG), 5)
	assert_eq(screen._rows.get_child_count(), 1)

	screen.step_price(0, 3)
	assert_eq(_cart.price_of(0), 5)
	screen.step_price(0, -99)
	assert_eq(_cart.price_of(0), 1, "never below 1")

	_cart.sell_one(0)
	assert_eq(screen._till_label.text, "In the till: 1 ß ")
	var before := _state.player.purse.schilling
	screen._take_button.pressed.emit()
	assert_eq(_state.player.purse.schilling, before + 1)
	assert_true(screen._take_button.disabled)

	screen.take_back(0)
	assert_eq(_cart.slots().count_of(EGG), 0)
	screen.close()
	await get_tree().process_frame
