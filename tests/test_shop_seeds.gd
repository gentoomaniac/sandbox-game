extends GutTest
## The seeds at the stall (data/shops.cfg, #11): she sells the seeds of every crop, a seed trade and
## a refused one, the stock of a seed filling up again, and a farm that loses a crop and still
## never runs out of seeds.

const SHOP := "trienke"
## What a day finds anywhere without a harvest, and she takes in a day.
const RAW_GOODS := [
	ItemTypes.EGG,
	ItemTypes.BERRIES,
	ItemTypes.FIBRE,
	ItemTypes.REEDS,
	ItemTypes.HAY,
	ItemTypes.LOGS,
	ItemTypes.CLAY,
]
const PLOT := 12
const ROUNDS := 8
const LOST_ROUND := 3

var _rules := ShopRules.default_rules()
var _clock: GameClock
var _shops: Shops
var _bag: ItemSlots


func before_each() -> void:
	_clock = GameClock.new()
	_shops = Shops.new(_rules, _clock)
	_bag = ItemSlots.new(40)


func _seed_of(crop: StringName) -> StringName:
	return StringName(CropRules.default_rules().crop(crop)["seed"])


func _seeds() -> Array[StringName]:
	var seeds: Array[StringName] = []
	for crop in CropRules.default_rules().crop_ids():
		seeds.append(_seed_of(crop))
	return seeds


## Fills the bag with a day's room of everything she takes that needs no farm.
func _carry_raw_goods() -> void:
	for item: StringName in RAW_GOODS:
		_bag.add(item, _rules.most_room(SHOP, item))


func _drop_raw_goods() -> void:
	for item: StringName in RAW_GOODS:
		_bag.remove(item, _bag.count_of(item))


func test_she_sells_the_seeds_of_every_crop() -> void:
	assert_eq(_seeds().size(), 13)
	for seed_item in _seeds():
		assert_true(_rules.is_sold(SHOP, seed_item), "%s is sold" % seed_item)
		assert_between(_rules.price(SHOP, seed_item), 3, 7, "%s is a few Schilling" % seed_item)
		assert_eq(_shops.stock_of(SHOP, seed_item), _rules.most_stock(SHOP, seed_item))


func test_a_seed_is_bought_with_what_she_takes() -> void:
	_bag.add(ItemTypes.EGG, 6)
	var seeds := _seed_of(&"carrot")

	assert_eq(_shops.trade(SHOP, {seeds: 2}, {ItemTypes.EGG: 6}, _bag), "")

	assert_eq(_bag.totals(), {seeds: 2}, "one seed item, one tile")
	assert_eq(_shops.stock_of(SHOP, seeds), 28)


func test_a_seed_is_refused_when_the_payment_is_short_and_nothing_changes() -> void:
	_bag.add(ItemTypes.EGG, 6)
	var seeds := _seed_of(&"strawberries")

	var refusal := _shops.trade(SHOP, {seeds: 2}, {ItemTypes.EGG: 6}, _bag)

	assert_eq(refusal, "Short by 8 Schilling.", "2 plants cost 14 ß, 6 eggs are worth 6")
	assert_eq(_bag.totals(), {ItemTypes.EGG: 6})
	assert_eq(_shops.stock_of(SHOP, seeds), 12)


func test_a_seed_bought_out_comes_back_by_its_restock_each_day() -> void:
	var seeds := _seed_of(&"pumpkin")
	_carry_raw_goods()
	var give := _shops.cover(SHOP, {seeds: 12}, _bag)
	assert_eq(_shops.trade(SHOP, {seeds: 12}, give, _bag), "")
	assert_eq(_shops.stock_of(SHOP, seeds), 0)

	_clock.day += 1
	assert_eq(_shops.stock_of(SHOP, seeds), 3)
	_clock.day += 3
	assert_eq(_shops.stock_of(SHOP, seeds), 12, "never above the most she has")


func test_a_days_raw_goods_pay_for_all_she_has_of_any_one_seed() -> void:
	for seed_item in _seeds():
		_bag = ItemSlots.new(40)
		_carry_raw_goods()
		var want := {seed_item: _shops.stock_of(SHOP, seed_item)}
		var give := _shops.cover(SHOP, want, _bag)
		assert_eq(_shops.quote(SHOP, want, give, _bag).problem, "", "%s is paid for" % seed_item)


## Eight harvests of a plot of each crop, the third one lost: each round is sown from the seeds the
## last harvest gave back (by the crop's `seed_chance`) and what a day's raw goods buy from her.
func test_a_farm_with_a_lost_crop_never_runs_out_of_seeds() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 11
	for crop in CropRules.default_rules().crop_ids():
		var seeds := _seed_of(crop)
		var seed_chance: float = CropRules.default_rules().crop(crop)["seed_chance"]
		before_each()
		_bag.add(seeds, PLOT)
		for round_number in range(1, ROUNDS + 1):
			_bag.remove(seeds, PLOT)
			for plant in PLOT:
				if round_number != LOST_ROUND and dice.randf() < seed_chance:
					_bag.add(seeds, 1)
			_clock.day += 5
			_carry_raw_goods()
			var missing := PLOT - _bag.count_of(seeds)
			var give := _shops.cover(SHOP, {seeds: missing}, _bag)
			var refusal := _shops.trade(SHOP, {seeds: missing}, give, _bag)
			assert_eq(refusal, "", "%s round %d: %d seeds bought" % [crop, round_number, missing])
			assert_eq(
				_bag.count_of(seeds), PLOT, "%s round %d is sown whole" % [crop, round_number]
			)
			_drop_raw_goods()
