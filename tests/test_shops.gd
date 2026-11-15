extends GutTest
## The shops' stock, room and the trade (Shops): a trade, each reason to refuse one with nothing
## changed, the stock filling up over the days and a deal that is worth more than it costs.

const SHOP := "trienke"
const SEEDS := ItemTypes.TURNIP_SEEDS

## What she takes most dearly in a day, worth 138 Pf to her: 40 turnip seeds or 6 candles cost 120.
const PAYMENT := {ItemTypes.LOGS: 10, ItemTypes.CLAY: 10, ItemTypes.FLOUR: 6, ItemTypes.BREAD: 6}

var _clock: GameClock
var _shops: Shops
var _bag: ItemSlots


func before_each() -> void:
	_clock = GameClock.new()
	_bag = ItemSlots.new(6)
	_shops = Shops.new(ShopRules.default_rules(), _clock)


func _carry(item: StringName, count: int) -> void:
	assert_eq(_bag.add(item, count), 0, "the bag holds %d %s" % [count, item])


## The refused trade says `problem` and leaves the bag, the stock and the room as they were.
func _assert_refused(want: Dictionary, give: Dictionary, problem: String) -> void:
	var before := _bag.totals()
	var stock := _shops.stock_of(SHOP, SEEDS)
	var room := _shops.room_of(SHOP, ItemTypes.EGG)
	assert_eq(_shops.trade(SHOP, want, give, _bag), problem)
	assert_eq(_bag.totals(), before)
	assert_eq(_shops.stock_of(SHOP, SEEDS), stock)
	assert_eq(_shops.room_of(SHOP, ItemTypes.EGG), room)


func test_a_trade_gives_the_goods_for_the_value_and_uses_up_stock_and_room() -> void:
	_carry(ItemTypes.EGG, 8)
	_carry(ItemTypes.FIBRE, 7)
	var want := {SEEDS: 5}
	var give := {ItemTypes.EGG: 8, ItemTypes.FIBRE: 7}

	var quote := _shops.quote(SHOP, want, give, _bag)
	assert_eq([quote.price, quote.value, quote.keeps, quote.problem], [15, 15, 0, ""])
	assert_eq(_shops.trade(SHOP, want, give, _bag), "")

	assert_eq(_bag.totals(), {SEEDS: 5})
	assert_eq(_shops.stock_of(SHOP, SEEDS), 35)
	assert_eq(_shops.room_of(SHOP, ItemTypes.EGG), 4)
	assert_eq(_shops.room_of(SHOP, ItemTypes.FIBRE), 13)


func test_a_new_shop_starts_full() -> void:
	assert_eq(_shops.stock_of(SHOP, SEEDS), 40)
	assert_eq(_shops.stock_of(SHOP, ItemTypes.CANDLE), 6)
	assert_eq(_shops.room_of(SHOP, ItemTypes.LOGS), 10)


func test_a_trade_with_nothing_chosen_is_refused() -> void:
	_carry(ItemTypes.EGG, 2)
	_assert_refused({}, {}, "Choose what you want.")
	_assert_refused({}, {ItemTypes.EGG: 2}, "Choose what you want for it.")


func test_what_she_does_not_sell_or_take_is_refused() -> void:
	_carry(ItemTypes.EGG, 2)
	_assert_refused({ItemTypes.EGG: 1}, {ItemTypes.EGG: 2}, "She does not sell Egg.")
	_assert_refused({SEEDS: 1}, {ItemTypes.CANDLE: 1}, "She does not take Candle.")


func test_more_than_the_stock_is_refused() -> void:
	_carry_payment()
	_assert_refused({SEEDS: 41}, PAYMENT, "She has only 40 Turnip seeds left today.")
	assert_eq(_shops.trade(SHOP, {SEEDS: 40}, PAYMENT, _bag), "")
	_carry(ItemTypes.EGG, 3)
	_assert_refused({SEEDS: 1}, {ItemTypes.EGG: 3}, "Out of Turnip seeds today.")


func test_more_than_the_room_is_refused() -> void:
	_carry(ItemTypes.EGG, 20)
	_assert_refused({SEEDS: 1}, {ItemTypes.EGG: 13}, "She has room for only 12 Egg today.")
	assert_eq(_shops.trade(SHOP, {SEEDS: 4}, {ItemTypes.EGG: 12}, _bag), "")
	_assert_refused({SEEDS: 1}, {ItemTypes.EGG: 3}, "She has no room for more Egg today.")


func test_offering_what_the_player_does_not_carry_is_refused() -> void:
	_carry(ItemTypes.EGG, 2)
	_assert_refused({SEEDS: 1}, {ItemTypes.EGG: 3}, "You do not carry 3 Egg.")


func test_too_little_value_is_refused_and_says_by_how_much() -> void:
	_carry(ItemTypes.EGG, 8)
	_assert_refused({SEEDS: 5}, {ItemTypes.EGG: 8}, "Short by 7 Pf.")
	_assert_refused({SEEDS: 5}, {}, "Short by 15 Pf.")


func test_what_she_gets_must_fit_the_bag_once_what_she_gives_is_out() -> void:
	var small := ItemSlots.new(1)
	small.add(ItemTypes.EGG, 10)
	_assert_refused_in(small, {SEEDS: 1}, {ItemTypes.EGG: 5}, "Your bag is full.")
	assert_eq(_shops.trade(SHOP, {SEEDS: 3}, {ItemTypes.EGG: 10}, small), "")
	assert_eq(small.totals(), {SEEDS: 3}, "the eggs left the slot first, the seeds took it")


func _assert_refused_in(
	bag: ItemSlots, want: Dictionary, give: Dictionary, problem: String
) -> void:
	var before := bag.totals()
	assert_eq(_shops.trade(SHOP, want, give, bag), problem)
	assert_eq(bag.totals(), before)


func test_an_overpayment_is_hers_and_there_is_no_change() -> void:
	_carry(ItemTypes.LOGS, 6)
	var want := {ItemTypes.CANDLE: 1}
	var give := {ItemTypes.LOGS: 6}
	var quote := _shops.quote(SHOP, want, give, _bag)
	assert_eq([quote.price, quote.value, quote.keeps], [20, 24, 4])
	assert_eq(_shops.trade(SHOP, want, give, _bag), "")
	assert_eq(_bag.totals(), {ItemTypes.CANDLE: 1})


func _carry_payment() -> void:
	for item: StringName in PAYMENT:
		_carry(item, PAYMENT[item])


func _buy_all_the_candles() -> void:
	_carry_payment()
	assert_eq(_shops.trade(SHOP, {ItemTypes.CANDLE: 6}, PAYMENT, _bag), "")
	assert_eq(_shops.stock_of(SHOP, ItemTypes.CANDLE), 0)


func test_the_stock_fills_up_by_the_restock_each_day() -> void:
	_buy_all_the_candles()
	# One candle a day: after 1, 3 and 9 days (the last never over the 6 she has at most).
	for days_and_stock: Array in [[1, 1], [2, 3], [6, 6]]:
		_clock.day += days_and_stock[0]
		assert_eq(_shops.stock_of(SHOP, ItemTypes.CANDLE), days_and_stock[1], "day %d" % _clock.day)


func test_the_room_is_back_to_its_full_number_the_next_day_only() -> void:
	_carry(ItemTypes.EGG, 12)
	assert_eq(_shops.trade(SHOP, {SEEDS: 4}, {ItemTypes.EGG: 12}, _bag), "")
	assert_eq(_shops.room_of(SHOP, ItemTypes.EGG), 0)
	_clock.minute_of_day = 20 * 60
	assert_eq(_shops.room_of(SHOP, ItemTypes.EGG), 0, "the same day")
	_clock.day += 1
	assert_eq(_shops.room_of(SHOP, ItemTypes.EGG), 12)


func test_a_skip_of_time_gives_the_same_stock_as_the_days_one_by_one() -> void:
	_carry_payment()
	assert_eq(_shops.trade(SHOP, {SEEDS: 40}, PAYMENT, _bag), "")
	assert_eq(_shops.stock_of(SHOP, SEEDS), 0)
	_clock.day += 3
	assert_eq(_shops.stock_of(SHOP, SEEDS), 30)
	_clock.day += 30
	assert_eq(_shops.stock_of(SHOP, SEEDS), 40, "never above the most she has")


func test_cover_gives_the_cheapest_of_the_bag_until_the_goods_are_paid() -> void:
	_carry(ItemTypes.EGG, 10)
	_carry(ItemTypes.FIBRE, 10)
	_carry(ItemTypes.LOGS, 10)
	var give := _shops.cover(SHOP, {SEEDS: 5}, _bag)
	assert_eq(
		give, {ItemTypes.EGG: 10, ItemTypes.FIBRE: 5}, "15 Pf, a Pfennig each, the file's order"
	)
	assert_eq(_shops.trade(SHOP, {SEEDS: 5}, give, _bag), "")
	assert_eq(_bag.totals(), {SEEDS: 5, ItemTypes.FIBRE: 5, ItemTypes.LOGS: 10})


func test_cover_stops_at_what_the_bag_and_the_room_hold() -> void:
	_carry(ItemTypes.EGG, 20)
	var give := _shops.cover(SHOP, {SEEDS: 40}, _bag)
	assert_eq(give, {ItemTypes.EGG: 12}, "the room of a day, though 120 Pf is wanted")
	assert_eq(_shops.cover(SHOP, {}, _bag), {}, "nothing wanted, nothing to cover")


func test_fill_gives_back_the_whole_stock_and_room() -> void:
	_carry(ItemTypes.EGG, 12)
	assert_eq(_shops.trade(SHOP, {SEEDS: 4}, {ItemTypes.EGG: 12}, _bag), "")
	_shops.fill(SHOP)
	assert_eq(_shops.stock_of(SHOP, SEEDS), 40)
	assert_eq(_shops.room_of(SHOP, ItemTypes.EGG), 12)


func test_a_lost_harvest_is_paid_for_in_a_days_fibre_and_logs() -> void:
	_carry(ItemTypes.FIBRE, 20)
	_carry(ItemTypes.LOGS, 10)
	var want := {SEEDS: 20}
	var give := {ItemTypes.FIBRE: 20, ItemTypes.LOGS: 10}
	var quote := _shops.quote(SHOP, want, give, _bag)
	assert_eq([quote.price, quote.value, quote.problem], [60, 60, ""])
	assert_eq(_shops.trade(SHOP, want, give, _bag), "")
	assert_eq(_bag.totals(), {SEEDS: 20})


func test_one_turnip_pays_for_a_seed() -> void:
	_carry(ItemTypes.TURNIP, 1)
	assert_eq(_shops.trade(SHOP, {SEEDS: 1}, {ItemTypes.TURNIP: 1}, _bag), "")
