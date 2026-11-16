extends GutTest
## The shop deals in coin (Shops, ShopQuote): the player pays a shortfall from the purse, she pays
## an excess, a purse that cannot pay refuses the deal, and either side of a deal may be empty.

const SHOP := "trienke"
const SEEDS := ItemTypes.TURNIP_SEEDS

var _shops: Shops
var _bag: ItemSlots


func before_each() -> void:
	_shops = Shops.new(ShopRules.default_rules(), GameClock.new())
	_bag = ItemSlots.new(6)


func _carry(item: StringName, count: int) -> void:
	assert_eq(_bag.add(item, count), 0, "the bag holds %d %s" % [count, item])


func test_a_shortfall_is_paid_from_the_purse() -> void:
	_carry(ItemTypes.EGG, 8)
	var purse := Purse.new(10)
	var give := {ItemTypes.EGG: 8}
	var quote := _shops.quote(SHOP, {SEEDS: 5}, give, _bag, ShopStanding.new(), purse)
	assert_eq([quote.price, quote.value, quote.player_pays, quote.problem], [15, 8, 7, ""])
	assert_eq(_shops.trade(SHOP, {SEEDS: 5}, give, _bag, ShopStanding.new(), purse), "")
	assert_eq(purse.schilling, 3)
	assert_eq(_bag.totals(), {SEEDS: 5})


func test_a_purse_that_cannot_pay_the_shortfall_refuses_the_deal_and_says_by_how_much() -> void:
	_carry(ItemTypes.EGG, 8)
	var purse := Purse.new(5)
	var standing := ShopStanding.new()
	var problem := _shops.trade(SHOP, {SEEDS: 5}, {ItemTypes.EGG: 8}, _bag, standing, purse)
	assert_eq(problem, "Short by 2 Schilling.")
	assert_eq(purse.schilling, 5)
	assert_eq(_bag.totals(), {ItemTypes.EGG: 8})
	assert_eq(_shops.stock_of(SHOP, SEEDS), 40)


func test_the_player_may_buy_with_coin_only() -> void:
	var purse := Purse.new(32)
	assert_eq(_shops.trade(SHOP, {SEEDS: 10}, {}, _bag, ShopStanding.new(), purse), "")
	assert_eq(purse.schilling, 2, "ten seeds at 3, the start purse of a new game")
	assert_eq(_bag.totals(), {SEEDS: 10})
	assert_eq(_shops.stock_of(SHOP, SEEDS), 30)


func test_the_player_may_sell_for_coin_only() -> void:
	_carry(ItemTypes.TURNIP, 5)
	var purse := Purse.new(0)
	assert_eq(_shops.trade(SHOP, {}, {ItemTypes.TURNIP: 5}, _bag, ShopStanding.new(), purse), "")
	assert_eq(purse.schilling, 15, "3 each")
	assert_eq(_bag.totals(), {})
	assert_eq(_shops.room_of(SHOP, ItemTypes.TURNIP), 5)


func test_selling_beyond_the_room_is_still_refused() -> void:
	_carry(ItemTypes.EGG, 13)
	var purse := Purse.new(0)
	var problem := _shops.trade(SHOP, {}, {ItemTypes.EGG: 13}, _bag, ShopStanding.new(), purse)
	assert_eq(problem, "She has room for only 12 Egg today.")
	assert_eq(purse.schilling, 0)


func test_a_price_of_nothing_makes_the_shop_free() -> void:
	var purse := Purse.new(0)
	var free := ShopStanding.new()
	free.price_percent = 0
	assert_eq(_shops.trade(SHOP, {SEEDS: 5}, {}, _bag, free, purse), "")
	assert_eq(_bag.totals(), {SEEDS: 5})


func test_cover_leaves_to_the_purse_what_it_can_pay() -> void:
	_carry(ItemTypes.EGG, 10)
	_carry(ItemTypes.FIBRE, 10)
	var give := _shops.cover(SHOP, {SEEDS: 5}, _bag, ShopStanding.new(), Purse.new(10))
	assert_eq(give, {ItemTypes.EGG: 5}, "5 of the 15 are left to pay")
	assert_eq(_shops.cover(SHOP, {SEEDS: 5}, _bag, ShopStanding.new(), Purse.new(15)), {})
