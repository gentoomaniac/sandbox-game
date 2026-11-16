extends GutTest
## What a good neighbour pays in the shop (ShopStanding, #48; design/economy/README.md, "Prices"):
## the percent comes from data/friendship.cfg [shop] and is applied once, before the rounding, so
## every price is whole, at least 1 and never past the full price.

const SHOP := "trienke"
const CABBAGE_SEEDS := &"cabbage_seeds"

var _rules := ShopRules.default_rules()
var _friendship := FriendshipRules.default_rules()
var _percent: int


func before_all() -> void:
	_percent = _friendship.value("shop", "better_prices_percent")


func test_every_price_is_whole_at_least_one_and_never_past_the_full_price() -> void:
	for item in _rules.sold(SHOP):
		var full := _rules.price(SHOP, item)
		var cut := _rules.price(SHOP, item, _percent)
		assert_between(cut, 1, full, "%s: %d of %d" % [item, cut, full])


func test_the_percent_is_applied_to_the_worth_once_and_rounded_once() -> void:
	# A worth of 3 sells at 3.75 and, at 80 percent, at exactly 3: rounding the price up first
	# (4) and then the cut (3.2 up to 4) would give nothing back.
	assert_eq(_rules.price(SHOP, CABBAGE_SEEDS), 4)
	assert_eq(_rules.price(SHOP, CABBAGE_SEEDS, _percent), 3)
	# A candle: 20 at full, 16 at 80 percent.
	assert_eq(_rules.price(SHOP, ItemTypes.CANDLE, _percent), 16)


func test_the_cut_is_for_the_benefit_only() -> void:
	var keeper := Npc.create_villager("trienke", Vector2.ZERO, VillagerRules.default_rules())
	keeper.opinion = _friendship.first_point_of(5)
	assert_eq(ShopStanding.with_keeper(keeper).price_percent, 100)
	keeper.opinion = _friendship.first_point_of(6)
	assert_eq(ShopStanding.with_keeper(keeper).price_percent, _percent)
