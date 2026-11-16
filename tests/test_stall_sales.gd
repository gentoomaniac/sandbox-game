extends GutTest
## The villagers buying at the sales cart (StallSales): who comes, what they buy at which price, a
## day rolled the same every time, bad weather, and the contact a sale is.

const EGG := ItemTypes.EGG
const FIBRE := ItemTypes.FIBRE
const FLOUR := ItemTypes.FLOUR
const SEED := 7

var _friendship := FriendshipRules.default_rules()


## A game with Antje (who wants flour, fibre and reeds, and likes eggs) at `level` and a cart that
## holds `goods` (item to count), set up the same every time. `rules` are the stall's.
func _stall(goods: Dictionary, level := 5, rules := _sure_visits()) -> Dictionary:
	var state := GameState.new_game(SEED)
	var antje := Npc.create_villager("antje", Vector2(2.5, 2.5), state.npcs.villagers)
	antje.opinion = _friendship.first_point_of(level)
	state.npcs.add(antje)
	var object := WorldObject.new(WorldObjectStall.SALES_CART, Vector2i(10, 10))
	state.world.add_object(object)
	var cart := SalesCart.new(object)
	for item: StringName in goods:
		cart.slots().add(item, goods[item])
	state.stall_sales.rules = rules
	return {"state": state, "antje": antje, "cart": cart, "sales": state.stall_sales}


## Rules where everyone who may come does, and the weather does not matter.
func _sure_visits() -> StallRules:
	var values := DataFile.read_sections(StallRules.DEFAULT_PATH)
	values["chance"]["base_percent"] = 100
	values["friendship"]["chance_percent"] = [0, 100, 100, 100, 100, 100, 100, 100, 100, 100]
	values["visits"]["rain_hours_limit"] = 1000.0
	return StallRules.new(values)


func test_a_villager_buys_what_they_need_at_the_price_on_the_cart() -> void:
	var stall := _stall({FIBRE: 20})
	stall["cart"].set_price(0, 3)

	var sold: int = stall["sales"].roll_day(3)

	assert_between(sold, 1, 3, "one visit, one to three things")
	assert_eq(stall["cart"].till(), sold * 3)
	assert_eq(stall["cart"].slots().count_of(FIBRE), 20 - sold)


func test_what_nobody_needs_or_likes_is_not_bought() -> void:
	var stall := _stall({ItemTypes.CANDLE: 5, ItemTypes.TURNIP: 5})
	assert_eq(stall["sales"].roll_day(3), 0)
	assert_eq(stall["cart"].till(), 0)


func test_a_price_over_the_limit_gets_a_shrug() -> void:
	var stall := _stall({FIBRE: 20})
	var worth := Prices.default_prices().worth(FIBRE)
	var limit := worth * StallRules.default_rules().limit_percent(5) / 100
	stall["cart"].set_price(0, limit + 1)
	assert_eq(stall["sales"].roll_day(3), 0, "one over the limit")
	stall["cart"].set_price(0, limit)
	assert_gt(stall["sales"].roll_day(4), 0, "at the limit")


func test_a_friend_pays_a_little_more_than_a_neighbour() -> void:
	var worth := Prices.default_prices().worth(FLOUR)
	var price := worth * 130 / 100
	var neighbour := _stall({FLOUR: 5})
	neighbour["cart"].set_price(0, price)
	assert_eq(neighbour["sales"].roll_day(3), 0)
	var friend := _stall({FLOUR: 5}, 8)
	friend["cart"].set_price(0, price)
	assert_gt(friend["sales"].roll_day(3), 0)


func test_a_villager_who_has_shunned_the_player_never_comes() -> void:
	var stall := _stall({FIBRE: 20}, 1)
	for day in range(1, 30):
		assert_eq(stall["sales"].roll_day(day), 0)


func test_a_day_is_rolled_the_same_every_time() -> void:
	var first := _stall({FIBRE: 20, EGG: 20, FLOUR: 5})
	var second := _stall({FIBRE: 20, EGG: 20, FLOUR: 5})
	for day in range(1, 12):
		assert_eq(first["sales"].roll_day(day), second["sales"].roll_day(day), "day %d" % day)
	assert_eq(first["cart"].till(), second["cart"].till())
	assert_eq(first["cart"].slots().totals(), second["cart"].slots().totals())
	assert_gt(first["cart"].till(), 0)


func test_a_day_away_is_the_same_as_a_day_present_and_the_new_day_rolls_the_ended_one() -> void:
	var present := _stall({FIBRE: 20, EGG: 20})
	var away := _stall({FIBRE: 20, EGG: 20})
	var day: int = present["state"].clock.day
	present["sales"].roll_day(day)

	# The player sleeps and the clock reaches the next day: the state's own sales roll day `day`.
	# (The cart is the state's, so what a second StallSales does is only the same by the seed.)
	away["state"].clock.advance(GameClock.MINUTES_PER_DAY)

	assert_eq(away["state"].clock.day, day + 1)
	assert_eq(away["cart"].till(), present["cart"].till())
	assert_eq(away["cart"].slots().totals(), present["cart"].slots().totals())


func test_a_rainy_day_brings_nobody() -> void:
	var values := DataFile.read_sections(StallRules.DEFAULT_PATH)
	values["chance"]["base_percent"] = 100
	values["friendship"]["chance_percent"] = [0, 100, 100, 100, 100, 100, 100, 100, 100, 100]
	values["visits"]["rain_hours_limit"] = 0.0
	var rules := StallRules.new(values)
	var stall := _stall({FIBRE: 200}, 5, rules)
	var weather: Weather = stall["state"].weather
	var pos := Vector2i(10, 10)
	var wet := 0
	var dry := 0
	for day in range(1, 120):
		var is_wet := weather.day_summary(pos, day).rain_hours > 0.0
		var sold: int = stall["sales"].roll_day(day)
		if is_wet:
			assert_eq(sold, 0, "rain on day %d" % day)
			wet += 1
		else:
			dry += 1
	assert_gt(wet, 0, "there is rain in 120 days")
	assert_gt(dry, 0)
	assert_gt(stall["cart"].till(), 0, "and the dry days sell")


func test_a_sale_is_contact_more_when_it_was_needed() -> void:
	var points := StallRules.default_rules()
	var needed := _stall({FIBRE: 5})
	var before: int = needed["antje"].opinion
	needed["sales"].roll_day(3)
	var sold_fibre: int = 5 - needed["cart"].slots().count_of(FIBRE)
	assert_gt(sold_fibre, 0)
	assert_eq(
		needed["antje"].opinion - before,
		sold_fibre * points.value("contact", "needed_sale_points"),
		"what she needed"
	)

	var liked := _stall({EGG: 5})
	var liked_before: int = liked["antje"].opinion
	liked["sales"].roll_day(3)
	var sold_eggs: int = 5 - liked["cart"].slots().count_of(EGG)
	assert_gt(sold_eggs, 0, "she likes an egg")
	assert_eq(
		liked["antje"].opinion - liked_before,
		sold_eggs * points.value("contact", "sale_points"),
		"what she only liked"
	)
