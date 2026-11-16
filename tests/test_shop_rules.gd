extends GutTest
## What the shopkeepers sell and take (ShopRules, data/shops.cfg): the file is clean, the prices
## and values are made from the worths, and each kind of fault is reported.

const SHOP := "trienke"

var _rules := ShopRules.default_rules()


## The real file with `changes` made to the section `section`, as rules.
func _rules_with(section: String, changes: Dictionary) -> ShopRules:
	var values := DataFile.read_sections(ShopRules.DEFAULT_PATH)
	values[section].merge(changes, true)
	return ShopRules.new(values)


func test_the_data_file_is_clean() -> void:
	assert_eq(_rules.problems(), [] as Array[String])
	assert_true(_rules.is_valid())


func test_the_shop_is_kept_by_trienke() -> void:
	assert_eq(_rules.shop_ids(), [SHOP] as Array[String])
	assert_eq(_rules.shop_of_keeper("trienke"), SHOP)
	assert_eq(_rules.shop_of_keeper("antje"), "")
	assert_eq(_rules.keeper_of(SHOP), "trienke")


func test_what_she_sells_and_takes_is_listed_in_the_order_of_the_file() -> void:
	var sold := _rules.sold(SHOP)
	assert_eq(sold.size(), 14, "13 seeds and the candle")
	assert_eq(sold[0], ItemTypes.TURNIP_SEEDS)
	assert_eq(sold[-1], ItemTypes.CANDLE)
	assert_eq(_rules.taken(SHOP).size(), 10)
	assert_true(_rules.is_taken(SHOP, ItemTypes.EGG))
	assert_false(_rules.is_taken(SHOP, ItemTypes.CANDLE))
	assert_true(_rules.is_sold(SHOP, ItemTypes.CANDLE))


func test_she_sells_at_a_quarter_over_the_worth_rounded_up() -> void:
	assert_eq(_rules.price(SHOP, ItemTypes.TURNIP_SEEDS), 3, "2 ß at 125 percent is 2.5")
	assert_eq(_rules.price(SHOP, ItemTypes.CANDLE), 20)


func test_she_takes_at_six_tenths_of_the_worth_rounded_down() -> void:
	assert_eq(_rules.value(SHOP, ItemTypes.EGG), 1, "2 ß at 60 percent is 1.2")
	assert_eq(_rules.value(SHOP, ItemTypes.TURNIP), 3, "3.6")
	assert_eq(_rules.value(SHOP, ItemTypes.LOGS), 4, "4.8")
	assert_eq(_rules.value(SHOP, ItemTypes.BREAD), 7, "7.2")


func test_the_stock_and_the_room_are_read() -> void:
	assert_eq(_rules.most_stock(SHOP, ItemTypes.TURNIP_SEEDS), 40)
	assert_eq(_rules.restock(SHOP, ItemTypes.TURNIP_SEEDS), 10)
	assert_eq(_rules.most_room(SHOP, ItemTypes.FIBRE), 20)


func test_an_unknown_item_is_reported() -> void:
	var values := DataFile.read_sections(ShopRules.DEFAULT_PATH)
	values["shop.trienke.takes.gold_bar"] = {"room": 1}
	assert_eq(
		ShopRules.new(values).problems(),
		["[shop.trienke.takes.gold_bar] gold_bar is no item"] as Array[String]
	)


func test_an_unknown_keeper_is_reported() -> void:
	var problems := _rules_with("shop.trienke", {"keeper": "nobody"}).problems()
	assert_eq(problems, ["[shop.trienke] keeper nobody is no villager"] as Array[String])


func test_a_good_with_no_worth_is_reported() -> void:
	var prices := Prices.new({"worth": {}})

	var problems := ShopRules.new(DataFile.read_sections(ShopRules.DEFAULT_PATH), prices).problems()

	assert_eq(problems.size(), 24, "every good of the file")
	assert_has(problems, "[shop.trienke.takes.egg] egg has no worth in data/prices.cfg")
	assert_has(problems, "[shop.trienke.sells.candle] candle has no worth in data/prices.cfg")


func test_a_good_she_takes_must_be_worth_two() -> void:
	var values := DataFile.read_sections(Prices.DEFAULT_PATH)
	values["worth"]["egg"] = 1
	values["worth"]["candle"] = 1
	var shop_values := DataFile.read_sections(ShopRules.DEFAULT_PATH)

	var problems := ShopRules.new(shop_values, Prices.new(values)).problems()

	assert_eq(problems, ["[shop.trienke.takes.egg] egg is worth less than 2"] as Array[String])


func test_a_restock_over_the_max_is_reported() -> void:
	var problems := _rules_with("shop.trienke.sells.candle", {"restock": 7}).problems()
	assert_eq(problems, ["[shop.trienke.sells.candle] restock is more than max"] as Array[String])


func test_a_good_both_sold_and_taken_is_reported() -> void:
	var values := DataFile.read_sections(ShopRules.DEFAULT_PATH)
	values["shop.trienke.takes.candle"] = {"room": 2}
	assert_eq(
		ShopRules.new(values).problems(),
		["[shop.trienke] candle is both sold and taken"] as Array[String]
	)


func test_a_missing_key_and_a_bad_percent_are_reported() -> void:
	var values := DataFile.read_sections(ShopRules.DEFAULT_PATH)
	values["shop.trienke"].erase("take_percent")
	values["shop.trienke.sells.candle"].erase("max")
	var problems := ShopRules.new(values).problems()
	assert_has(problems, "[shop.trienke] no take_percent")
	assert_has(problems, "[shop.trienke.sells.candle] no max")
	var percent := _rules_with("shop.trienke", {"sell_percent": 0}).problems()
	assert_eq(
		percent, ["[shop.trienke] sell_percent is not a whole number above 0"] as Array[String]
	)


func test_a_section_that_is_no_shop_is_reported() -> void:
	var values := DataFile.read_sections(ShopRules.DEFAULT_PATH)
	values["stall.trienke"] = {}
	values["shop.nobody.sells.egg"] = {"max": 1, "restock": 1}
	var problems := ShopRules.new(values).problems()
	assert_eq(problems.size(), 2)
	assert_true(problems[0].ends_with("is no shop, no good of a shop and not under a shop"))
