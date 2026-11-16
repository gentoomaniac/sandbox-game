class_name Barter
extends RefCounted
## Small things for small things with a villager who knows the player as a neighbour (see
## design/economy/README.md, "Barter with villagers"). The villager must give the benefit `barter`;
## both sides are valued at the worths of Prices, with no coin: a deal is fair when what the player
## gives is worth at least what they get, for every villager and at every level: friendship opens
## barter but never changes its rates, or a loop of deals between two villagers could make goods
## out of nothing. A deal is at most `cap` Schilling to either side. The game
## decides the numbers, the model only voices them.

var _rules: BarterRules
var _prices: Prices


func _init(rules := BarterRules.default_rules(), prices := Prices.default_prices()) -> void:
	_rules = rules
	_prices = prices


## Whether there is something to barter with the villager now: they have goods to trade and the
## player's friendship opens them.
func is_open(npc: Npc) -> bool:
	return _rules.has(npc.id) and Benefits.allows(npc, &"barter")


## What the deal comes to and whether it can be done: `want` is what the player gets (item to
## count, from the villager's `offers`), `give` what they give (from their `wants`) out of `bag`.
## `price` is what the villager asks, `value` what the player gives, both in Schilling; there is no
## coin, so `player_pays` and `she_pays` stay 0. The problems are in this order: nothing chosen,
## the villager does not barter, goods they do not offer or want, not carried, too big, too little
## value, no place in the bag.
func quote(npc: Npc, want: Dictionary, give: Dictionary, bag: ItemSlots) -> ShopQuote:
	var deal := ShopQuote.new()
	var got := _worth_of(want)
	deal.value = _worth_of(give)
	deal.price = got
	deal.problem = _problem(npc, want, give, bag, deal, got)
	return deal


## Does the deal if `quote` says it can be done: the goods change hands, and the day's contact
## counts for their friendship as a first chat does. Returns the problem and changes nothing if it
## can't be done.
func trade(
	state: GameState, npc: Npc, want: Dictionary, give: Dictionary, bag: ItemSlots
) -> String:
	var deal := quote(npc, want, give, bag)
	if not deal.is_fair():
		return deal.problem
	var is_done := bag.exchange(give, want)
	assert(is_done, "a fair quote is an exchange that works")
	TalkFriendship.count_chat(state, npc)
	return ""


func _worth_of(goods: Dictionary) -> int:
	var worth := 0
	for item: StringName in goods:
		if _prices.has_worth(item):
			worth += _prices.worth(item) * goods[item]
	return worth


func _problem(
	npc: Npc, want: Dictionary, give: Dictionary, bag: ItemSlots, deal: ShopQuote, got: int
) -> String:
	if want.is_empty() or give.is_empty():
		return "Choose what you want and what you give for it."
	var problem := _goods_problem(npc, want, give, bag)
	if not problem.is_empty():
		return problem
	if maxi(got, deal.value) > _rules.cap():
		return "A deal is at most %d Schilling." % _rules.cap()
	if deal.value < deal.price:
		return "Short by %d Schilling worth." % (deal.price - deal.value)
	return "" if bag.can_exchange(give, want) else "Your bag is full."


## What is wrong with the goods themselves: the villager does not barter, does not offer or want
## them, or the player does not carry them.
func _goods_problem(npc: Npc, want: Dictionary, give: Dictionary, bag: ItemSlots) -> String:
	var first_name := npc.name.get_slice(" ", 0)
	if not is_open(npc):
		return "%s does not barter with you." % first_name
	for item: StringName in want:
		if not _rules.offers(npc.id).has(item):
			return "%s does not offer %s." % [first_name, ItemTypes.TYPES[item]["name"]]
	for item: StringName in give:
		if not _rules.wants(npc.id).has(item):
			return "%s does not want %s." % [first_name, ItemTypes.TYPES[item]["name"]]
		if bag.count_of(item) < give[item]:
			return "You do not carry %d %s." % [give[item], ItemTypes.TYPES[item]["name"]]
	return ""
