extends GutTest
## The seasons in the price (Prices `worth_in`, data/prices.cfg [kind] and [seasons.<kind>]): a
## good of a kind is worth a percent of its worth in each season, rounded once to the nearest
## whole and never below 1 (2 for a good a shop takes); the shop makes its price of that.

const SHOP := "trienke"
const SPRING := GameClock.Season.SPRING
const SUMMER := GameClock.Season.SUMMER
const AUTUMN := GameClock.Season.AUTUMN
const WINTER := GameClock.Season.WINTER

var _prices := Prices.default_prices()


func _prices_with(kinds: Dictionary, worths: Dictionary) -> Prices:
	var values := DataFile.read_sections(Prices.DEFAULT_PATH)
	values["kind"].merge(kinds, true)
	values["worth"].merge(worths, true)
	return Prices.new(values)


func test_the_data_file_is_clean_and_has_the_kinds_of_the_plan() -> void:
	assert_eq(_prices.problems(), [] as Array[String])
	assert_eq(_prices.worth_in(ItemTypes.BREAD, AUTUMN), 10, "grain is cheap after the harvest")
	assert_eq(_prices.worth_in(ItemTypes.BREAD, SPRING), 14, "and dear in spring")
	assert_eq(_prices.worth_in(ItemTypes.TURNIP, AUTUMN), 5, "a vegetable in its season: 4.8")
	assert_eq(_prices.worth_in(ItemTypes.TURNIP, WINTER), 8, "and out of it: 7.8")


func test_each_season_has_its_percent() -> void:
	var expected := {SPRING: 12, SUMMER: 10, AUTUMN: 8, WINTER: 10}
	for season: int in expected:
		assert_eq(_prices.worth_in(ItemTypes.FLOUR, season), expected[season], "flour, %d" % season)


func test_a_flat_good_keeps_its_worth_in_every_season() -> void:
	for season: int in [SPRING, SUMMER, AUTUMN, WINTER]:
		assert_eq(_prices.worth_in(ItemTypes.CANDLE, season), 16)
		assert_eq(_prices.worth_in(ItemTypes.LOGS, season), 8)


func test_no_season_is_the_plain_worth() -> void:
	assert_eq(_prices.worth_in(ItemTypes.BREAD), 12)
	assert_eq(_prices.worth_in(ItemTypes.BREAD, Prices.FLAT), 12)


func test_a_cheap_good_hardly_moves() -> void:
	assert_eq(_prices.worth_in(ItemTypes.EGG, WINTER), 2, "2.4")
	assert_eq(_prices.worth_in(ItemTypes.EGG, SUMMER), 2, "1.8")


func test_a_worth_is_never_below_the_least() -> void:
	var prices := _prices_with({"fibre": "grain"}, {"fibre": 1})
	assert_eq(prices.worth_in(ItemTypes.FIBRE, AUTUMN), 1, "0.8 rounds to 1, the least of a worth")
	assert_eq(prices.worth_in(ItemTypes.FIBRE, AUTUMN, 2), 2, "2 for a good a shop takes")


func test_the_shop_makes_its_price_and_value_of_the_seasons_worth() -> void:
	var rules := ShopRules.default_rules()
	# Bread: worth 14 in spring, sold at 125 percent it would be 17.5; she takes it at 60 percent.
	assert_eq(rules.value(SHOP, ItemTypes.BREAD, SPRING), 8, "8.4")
	assert_eq(rules.value(SHOP, ItemTypes.BREAD, AUTUMN), 6, "6.0")
	assert_eq(rules.value(SHOP, ItemTypes.BREAD), 7, "7.2, no season")
	assert_eq(rules.price(SHOP, ItemTypes.CANDLE, 100, WINTER), 20, "flat")


func test_the_shop_asks_the_price_of_today_s_season() -> void:
	var clock := GameClock.new()
	var shops := Shops.new(ShopRules.default_rules(), clock)
	clock.day = 1
	assert_eq(clock.season(), SPRING)
	assert_eq(shops.value_of(SHOP, ItemTypes.TURNIP), 4, "7.8 is 8, taken at 60 percent: 4.8")
	clock.day = 36 + 35
	assert_eq(clock.season(), AUTUMN)
	assert_eq(shops.value_of(SHOP, ItemTypes.TURNIP), 3, "4.8 is 5, taken at 60 percent: 3")


func test_a_kind_without_percents_or_a_good_without_a_worth_is_reported() -> void:
	var values := DataFile.read_sections(Prices.DEFAULT_PATH)
	values["kind"]["lantern"] = "grain"
	values["kind"]["egg"] = "dairy"
	values["seasons.grain"].erase("winter")
	values["seasons.farm"]["spring"] = 0
	assert_eq(
		Prices.new(values).problems(),
		(
			[
				"[kind] egg: dairy has no [seasons.dairy]",
				"[kind] lantern has no worth",
				"[seasons.grain] winter is not a whole percent from 1",
				"[seasons.farm] spring is not a whole percent from 1",
			]
			as Array[String]
		)
	)
