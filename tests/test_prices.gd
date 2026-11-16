extends GutTest
## What a thing is worth (Prices, data/prices.cfg): the file is clean, and each kind of fault is
## reported. The prices a shop makes of the worths are checked here for every worth too.

const SHOP := "trienke"


func _prices_with(worths: Dictionary) -> Prices:
	var values := DataFile.read_sections(Prices.DEFAULT_PATH)
	values["worth"].merge(worths, true)
	return Prices.new(values)


func test_the_data_file_is_clean() -> void:
	assert_eq(Prices.default_prices().problems(), [] as Array[String])
	assert_true(Prices.default_prices().is_valid())


func test_the_worths_are_read() -> void:
	var prices := Prices.default_prices()
	assert_eq(prices.worth(ItemTypes.EGG), 2)
	assert_eq(prices.worth(ItemTypes.BREAD), 12)
	assert_eq(prices.worth(ItemTypes.CANDLE), 16)
	assert_true(prices.has_worth(ItemTypes.TURNIP_SEEDS))
	assert_false(prices.has_worth(ItemTypes.LANTERN))


func test_a_worth_below_one_or_not_whole_is_reported() -> void:
	var problem := ["[worth] egg is not a whole number from 1"] as Array[String]
	assert_eq(_prices_with({"egg": 0}).problems(), problem)
	assert_eq(_prices_with({"egg": 1.5}).problems(), problem)


func test_a_worth_of_no_item_is_reported() -> void:
	var problems := _prices_with({"gold_bar": 5}).problems()
	assert_eq(problems, ["[worth] gold_bar is no item"] as Array[String])


func test_a_missing_or_unknown_section_is_reported() -> void:
	assert_eq(Prices.new({}).problems(), ["[worth] is missing"] as Array[String])
	var values := DataFile.read_sections(Prices.DEFAULT_PATH)
	values["stall"] = {}
	var problems := Prices.new(values).problems()
	assert_eq(problems, ["[stall] is not a section of the file"] as Array[String])


func test_the_shop_rounds_in_the_keepers_favour_for_every_worth() -> void:
	# The table of design/economy/README.md, "Why the worths keep their numbers".
	var sells_at := {1: 2, 2: 3, 3: 4, 4: 5, 5: 7, 6: 8, 8: 10, 10: 13, 12: 15, 16: 20}
	var takes_at := {1: 0, 2: 1, 3: 1, 4: 2, 5: 3, 6: 3, 8: 4, 10: 6, 12: 7, 16: 9}
	var shop_values := DataFile.read_sections(ShopRules.DEFAULT_PATH)
	for worth: int in sells_at:
		var prices := _prices_with({"egg": worth, "candle": worth})
		var rules := ShopRules.new(shop_values, prices)
		assert_eq(rules.price(SHOP, ItemTypes.CANDLE), sells_at[worth], "sells %d" % worth)
		assert_eq(rules.value(SHOP, ItemTypes.EGG), takes_at[worth], "takes %d" % worth)
