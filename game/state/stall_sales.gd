class_name StallSales
extends RefCounted
## The villagers buying at the player's sales carts (design/economy/README.md, "The player's
## stall"). When a day ends, each cart is rolled for that day in one go: on a fair day a few
## villagers who need goods (what they `want` in data/barter.cfg) come by, with the chance of their
## friendship, and buy one to three things from the cart that they need or like, as long as the
## price is not over their limit. The roll is seeded by the world, the day and the cart, so the same
## day is always the same sale, whether the player was near the cart or away, and after a reload.
## A sale is a little contact: a villager thinks the more of the player for it, the more if it was
## what they needed. What is bought is the cart's SalesCart: the goods go, the till fills.

## What the villagers do (data/stall.cfg); a test may give others.
var rules := StallRules.default_rules()

## Gives the game: the state owns this, so it is not held (a cycle would leak both).
var _game_of: Callable


func _init(clock: GameClock, game_of: Callable) -> void:
	_game_of = game_of
	clock.new_day.connect(_on_new_day)


## Rolls the day `day`, which has ended, for every cart. Returns how many things were sold.
func roll_day(day: int) -> int:
	var sold := 0
	for cart in SalesCart.all_in(_game().world):
		sold += _roll_cart(cart, day)
	return sold


func _on_new_day(today: int) -> void:
	roll_day(today - 1)


func _roll_cart(cart: SalesCart, day: int) -> int:
	var rain := _game().weather.day_summary(cart.object.pos, day).rain_hours
	if rain > rules.value("visits", "rain_hours_limit"):
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_game().world.world_seed, day, cart.object.pos.x, cart.object.pos.y])
	var friendship := FriendshipRules.default_rules()
	var sold := 0
	var visitors := 0
	for npc in _shuffled_buyers(rng):
		if visitors >= rules.value("visits", "per_day"):
			break
		var level := friendship.level_of(npc.opinion)
		var chance: int = rules.value("chance", "base_percent") * rules.chance_percent(level) / 100
		if rng.randi_range(1, 100) > chance:
			continue
		visitors += 1
		sold += _buy(cart, npc, level, day, rng)
	return sold


## The villagers who barter, in a mixed order that the day's seed fixes (their ids sorted first,
## so that the order of the world's list does not matter).
func _shuffled_buyers(rng: RandomNumberGenerator) -> Array[Npc]:
	var buyers: Array[Npc] = []
	for npc in _game().npcs.all():
		if BarterRules.default_rules().has(npc.id):
			buyers.append(npc)
	buyers.sort_custom(func(first: Npc, second: Npc) -> bool: return first.id < second.id)
	for i in range(buyers.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swapped := buyers[i]
		buyers[i] = buyers[j]
		buyers[j] = swapped
	return buyers


## One visit: the villager buys one to `most_things` things. Returns how many were sold.
func _buy(cart: SalesCart, npc: Npc, level: int, day: int, rng: RandomNumberGenerator) -> int:
	var things := rng.randi_range(1, rules.value("buy", "most_things"))
	var sold := 0
	for _i in things:
		var slot := _slot_to_buy(cart, npc, level, rng)
		if slot == -1:
			break
		var item := cart.slots().item_in(slot)
		cart.sell_one(slot)
		sold += 1
		var is_needed := BarterRules.default_rules().wants(npc.id).has(item)
		var points: int = rules.value(
			"contact", "needed_sale_points" if is_needed else "sale_points"
		)
		var friendship := FriendshipRules.default_rules()
		npc.change_friendship(points, day, friendship, GossipRules.default_rules())
	return sold


## The slot the villager picks: a good they need or like, at a price within their limit. A liked
## good is `liked_weight` times as likely as a need. -1 when nothing suits them.
func _slot_to_buy(cart: SalesCart, npc: Npc, level: int, rng: RandomNumberGenerator) -> int:
	var wants := BarterRules.default_rules().wants(npc.id)
	var slots: Array[int] = []
	var weights: Array[int] = []
	for slot in cart.slots().slots.size():
		if not cart.is_for_sale(slot):
			continue
		var item := cart.slots().item_in(slot)
		var is_liked := Gifts.taste_of(_game(), npc, item) == Gifts.LIKED
		if not (wants.has(item) or is_liked):
			continue
		var worth := Prices.default_prices().worth(item)
		if cart.price_of(slot) > worth * rules.limit_percent(level) / 100:
			continue
		slots.append(slot)
		weights.append(rules.value("buy", "liked_weight") if is_liked else 1)
	if slots.is_empty():
		return -1
	var pick := rng.randi_range(1, weights.reduce(func(sum: int, w: int) -> int: return sum + w, 0))
	for i in slots.size():
		pick -= weights[i]
		if pick <= 0:
			return slots[i]
	return slots[-1]


func _game() -> GameState:
	return _game_of.call()
