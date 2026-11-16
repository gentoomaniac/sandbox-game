extends GutTest
## What the quests of data/quests/ pay, in Schilling at the stall (design/economy/README.md, "How
## quest rewards relate"): a quest pays items and goodwill, no coin, so none is a better deal than
## the stall.

const SHOP := "trienke"

var _quests := QuestRules.default_rules()
var _shop := ShopRules.default_rules()


## What the reward of the quest would cost at the stall: the price of the items she sells, and
## nothing for those she does not (wax).
func _stall_price_of_reward(id: String) -> int:
	var price := 0
	var items: Dictionary = _quests.quest(id)["reward"].get("items", {})
	for item: String in items:
		if _shop.is_sold(SHOP, StringName(item)):
			price += _shop.price(SHOP, StringName(item)) * items[item]
	return price


func test_a_quest_pays_no_coin() -> void:
	for id in _quests.ids():
		assert_false(_quests.quest(id)["reward"].has("schilling"), "%s pays items" % id)


func test_what_a_starter_pays_costs_no_more_than_the_start_purse_buys() -> void:
	var start := Prices.default_prices().start_purse()
	for id in _quests.ids():
		if _quests.is_starter(id):
			assert_between(_stall_price_of_reward(id), 1, start, "%s, a loan for the farm" % id)


func test_the_other_quests_pay_what_the_stall_does_not_sell() -> void:
	for id in _quests.ids():
		if not _quests.is_starter(id):
			assert_eq(_stall_price_of_reward(id), 0, "%s pays no stall goods" % id)


func test_the_reward_of_the_first_quest_is_the_ten_seeds_the_start_purse_buys() -> void:
	assert_eq(_stall_price_of_reward("fibre_for_beans"), 30)
	assert_eq(_stall_price_of_reward("berries_for_the_pot"), 24)
