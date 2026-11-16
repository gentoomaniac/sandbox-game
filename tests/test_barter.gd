extends GutTest
## Barter with a villager (Barter): who opens it, what a fair deal is, the same rates at every
## level, the cap, what a deal changes and that it counts as the day's contact.

const EGG := ItemTypes.EGG
const FIBRE := ItemTypes.FIBRE
const FLOUR := ItemTypes.FLOUR
const SHORT_BY_1 := "Short by 1 Schilling worth."
const CAP_TEXT := "A deal is at most 100 Schilling."

var _state: GameState
var _antje: Npc
var _bag: ItemSlots
var _barter := Barter.new()
var _friendship := FriendshipRules.default_rules()


func before_each() -> void:
	_bag = ItemSlots.new(6)
	_state = GameFactory.new_game(7)
	_antje = Npc.create_villager("antje", Vector2(2.5, 2.5), _state.npcs.villagers)
	_state.npcs.add(_antje)
	_at_level(5)


func _at_level(level: int) -> void:
	_antje.opinion = _friendship.first_point_of(level)


func _carry(item: StringName, count: int) -> void:
	assert_eq(_bag.add(item, count), 0)


func test_only_a_neighbour_barters() -> void:
	_at_level(4)
	assert_false(_barter.is_open(_antje))
	_at_level(5)
	assert_true(_barter.is_open(_antje))


func test_a_villager_with_no_goods_does_not_barter_at_any_level() -> void:
	var trienke := Npc.create_villager("trienke", Vector2.ZERO, _state.npcs.villagers)
	trienke.opinion = _friendship.first_point_of(10)
	assert_false(_barter.is_open(trienke))


func test_a_fair_deal_swaps_the_goods() -> void:
	_carry(FIBRE, 2)
	var deal := _barter.quote(_antje, {EGG: 3}, {FIBRE: 2}, _bag)
	assert_eq([deal.price, deal.value, deal.problem], [6, 6, ""])

	assert_eq(_barter.trade(_state, _antje, {EGG: 3}, {FIBRE: 2}, _bag), "")

	assert_eq(_bag.totals(), {EGG: 3})


func test_a_deal_with_too_little_value_is_refused_and_says_by_how_much() -> void:
	_carry(FIBRE, 2)
	var problem := _barter.trade(_state, _antje, {EGG: 3}, {FIBRE: 1}, _bag)
	assert_eq(problem, "Short by 3 Schilling worth.")
	assert_eq(_bag.totals(), {FIBRE: 2})


func test_more_value_than_asked_is_not_paid_back_in_coin() -> void:
	_carry(FLOUR, 1)
	var deal := _barter.quote(_antje, {EGG: 1}, {FLOUR: 1}, _bag)
	assert_eq([deal.price, deal.value, deal.problem], [2, 10, ""])
	assert_eq([deal.player_pays, deal.she_pays], [0, 0])


func test_friendship_does_not_change_the_rates() -> void:
	_carry(FIBRE, 3)
	for level in range(5, 11):
		_at_level(level)
		var deal := _barter.quote(_antje, {EGG: 5}, {FIBRE: 3}, _bag)
		assert_eq([deal.price, deal.value], [10, 9], "level %d" % level)
		assert_eq(deal.problem, SHORT_BY_1)


func test_what_is_not_offered_or_not_wanted_is_refused() -> void:
	_carry(FIBRE, 2)
	_carry(EGG, 2)
	var not_offered := _barter.quote(_antje, {FIBRE: 1}, {FIBRE: 1}, _bag)
	assert_eq(not_offered.problem, "Antje does not offer Fibre.")
	var not_wanted := _barter.quote(_antje, {EGG: 1}, {EGG: 1}, _bag)
	assert_eq(not_wanted.problem, "Antje does not want Egg.")


func test_what_the_player_does_not_carry_is_refused() -> void:
	_carry(FIBRE, 1)
	var problem := _barter.quote(_antje, {EGG: 1}, {FIBRE: 2}, _bag).problem
	assert_eq(problem, "You do not carry 2 Fibre.")


func test_nothing_chosen_on_either_side_is_refused() -> void:
	_carry(FIBRE, 1)
	var refusal := "Choose what you want and what you give for it."
	assert_eq(_barter.quote(_antje, {}, {FIBRE: 1}, _bag).problem, refusal)
	assert_eq(_barter.quote(_antje, {EGG: 1}, {}, _bag).problem, refusal)


func test_a_villager_who_does_not_know_the_player_well_enough_refuses() -> void:
	_at_level(4)
	_carry(FIBRE, 1)
	var problem := _barter.quote(_antje, {EGG: 1}, {FIBRE: 1}, _bag).problem
	assert_eq(problem, "Antje does not barter with you.")


func test_a_deal_is_at_most_the_cap_to_either_side() -> void:
	var big := ItemSlots.new(20)
	big.add(FLOUR, 11)
	big.add(ItemTypes.REEDS, 40)
	assert_eq(_barter.quote(_antje, {EGG: 1}, {FLOUR: 11}, big).problem, CAP_TEXT, "110 given")
	var too_much_got := _barter.quote(_antje, {EGG: 51}, {ItemTypes.REEDS: 40}, big)
	assert_eq(too_much_got.problem, CAP_TEXT, "102 got")
	assert_eq(_barter.quote(_antje, {EGG: 49}, {ItemTypes.REEDS: 33}, big).problem, "")


func test_the_bag_must_hold_what_the_player_gets() -> void:
	var small := ItemSlots.new(1)
	small.add(FIBRE, 2)
	var want := {EGG: 1, ItemTypes.BERRIES: 1}
	assert_eq(_barter.quote(_antje, want, {FIBRE: 2}, small).problem, "Your bag is full.")


func test_the_first_deal_of_a_day_counts_as_contact_and_a_refused_one_does_not() -> void:
	_carry(FIBRE, 4)
	var before := _antje.opinion
	var contact: int = _friendship.value("talk", "first_chat_points")
	_barter.trade(_state, _antje, {EGG: 3}, {FIBRE: 1}, _bag)
	assert_eq(_antje.opinion, before, "refused, no contact")

	_barter.trade(_state, _antje, {EGG: 1}, {FIBRE: 1}, _bag)
	assert_eq(_antje.opinion, before + contact)

	_barter.trade(_state, _antje, {EGG: 1}, {FIBRE: 1}, _bag)
	assert_eq(_antje.opinion, before + contact, "once a day")
