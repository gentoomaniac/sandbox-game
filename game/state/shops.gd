class_name Shops
extends RefCounted
## What the shops have and take today, and the trade (design/economy/shop.md): for each shop its
## stock of what it sells, the room left for what it takes, and the day they were last worked out.
## Pure state. What a shop sells, takes and asks is in ShopRules; the numbers here are what has
## been sold and taken since.
##
## The stock fills up over the days and the room is back to its full number each day. Both are
## worked out when the shop is looked at, from the days since it was last looked at, and not by a
## tick: a skip of time, a long absence and a reload give the same stock. A shop that is new, or a
## good that is new to a shop, starts full.

var _rules: ShopRules
var _clock: GameClock
## {shop id: {"stock": {item: count}, "room": {item: count}, "restocked_day": day}}
var _shops: Dictionary = {}


func _init(rules: ShopRules, clock: GameClock) -> void:
	_rules = rules
	_clock = clock


## How many of the item the shop has today.
func stock_of(shop: String, item: StringName) -> int:
	return _worked_out(shop)["stock"].get(item, 0)


## How many more of the item the shop takes today.
func room_of(shop: String, item: StringName) -> int:
	return _worked_out(shop)["room"].get(item, 0)


## What the deal comes to and whether it can be done: `want` is what the player gets (item to
## count, from the shop's `sells`), `give` what they give (from its `takes`) out of `bag`. The
## deal is fair when the value given is at least the price, and the bag holds what it gets once what
## it gives is out. The problems are in this order: nothing chosen, not sold or taken, no stock,
## no room, not carried, too little value, no place in the bag.
func quote(shop: String, want: Dictionary, give: Dictionary, bag: ItemSlots) -> ShopQuote:
	var deal := ShopQuote.new()
	for item: StringName in want:
		if _rules.is_sold(shop, item):
			deal.price += _rules.price(shop, item) * want[item]
	for item: StringName in give:
		if _rules.is_taken(shop, item):
			deal.value += _rules.value(shop, item) * give[item]
	deal.problem = _problem(shop, want, give, bag, deal)
	if deal.is_fair():
		deal.keeps = deal.value - deal.price
	return deal


## Does the deal if `quote` says it can be done: the player's items go, the shop's come, the stock
## shrinks and the room is used up. Returns the problem and changes nothing if it can't be done.
func trade(shop: String, want: Dictionary, give: Dictionary, bag: ItemSlots) -> String:
	var deal := quote(shop, want, give, bag)
	if not deal.is_fair():
		return deal.problem
	# A fair quote has checked that the bag holds it, so this works.
	var is_done := bag.exchange(give, want)
	assert(is_done, "a fair quote is an exchange that works")
	var entry := _worked_out(shop)
	for item: StringName in want:
		entry["stock"][item] -= want[item]
	for item: StringName in give:
		entry["room"][item] -= give[item]
	return ""


## What the player may give to pay for `want`: the cheapest of what they carry that she takes, one
## after the other, until it is paid or there is no more she takes of it (the room of the day and
## the bag's count are the limit). A help for the trade screen, which the player may change.
func cover(shop: String, want: Dictionary, bag: ItemSlots) -> Dictionary:
	var price := quote(shop, want, {}, bag).price
	var in_file_order := _rules.taken(shop)
	var takable := in_file_order.filter(
		func(item: StringName) -> bool: return _rules.value(shop, item) > 0
	)
	# Sorting is not stable: what is worth the same keeps the order of the file by itself.
	takable.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			var first_value := _rules.value(shop, first)
			var second_value := _rules.value(shop, second)
			if first_value != second_value:
				return first_value < second_value
			return in_file_order.find(first) < in_file_order.find(second)
	)
	var give := {}
	var covered := 0
	for item: StringName in takable:
		var most := mini(bag.count_of(item), room_of(shop, item))
		while covered < price and give.get(item, 0) < most:
			give[item] = give.get(item, 0) + 1
			covered += _rules.value(shop, item)
	return give


## Has the shop sell everything and take as much as on its best day: for the console.
func fill(shop: String) -> void:
	_shops.erase(shop)


func _problem(
	shop: String, want: Dictionary, give: Dictionary, bag: ItemSlots, deal: ShopQuote
) -> String:
	if want.is_empty():
		return "Choose what you want." if give.is_empty() else "Choose what you want for it."
	var problem := _stock_problem(shop, want)
	if problem.is_empty():
		problem = _room_problem(shop, give)
	if problem.is_empty():
		problem = _carried_problem(give, bag)
	if not problem.is_empty():
		return problem
	if deal.value < deal.price:
		return "Short by %d Pf." % (deal.price - deal.value)
	return "" if bag.can_exchange(give, want) else "Your bag is full."


func _stock_problem(shop: String, want: Dictionary) -> String:
	for item: StringName in want:
		if not _rules.is_sold(shop, item):
			return "She does not sell %s." % _name_of(item)
		var stock := stock_of(shop, item)
		if stock == 0:
			return "Out of %s today." % _name_of(item)
		if want[item] > stock:
			return "She has only %d %s left today." % [stock, _name_of(item)]
	return ""


func _room_problem(shop: String, give: Dictionary) -> String:
	for item: StringName in give:
		if not _rules.is_taken(shop, item):
			return "She does not take %s." % _name_of(item)
		var room := room_of(shop, item)
		if room == 0:
			return "She has no room for more %s today." % _name_of(item)
		if give[item] > room:
			return "She has room for only %d %s today." % [room, _name_of(item)]
	return ""


func _carried_problem(give: Dictionary, bag: ItemSlots) -> String:
	for item: StringName in give:
		if bag.count_of(item) < give[item]:
			return "You do not carry %d %s." % [give[item], _name_of(item)]
	return ""


## The shop's entry, made new if there is none and brought up to today.
func _worked_out(shop: String) -> Dictionary:
	var today := _clock.day
	if not _shops.has(shop):
		_shops[shop] = {"stock": {}, "room": {}, "restocked_day": today}
	var entry: Dictionary = _shops[shop]
	var days := maxi(today - entry["restocked_day"], 0)
	for item in _rules.sold(shop):
		var most := _rules.most_stock(shop, item)
		var stock: int = entry["stock"].get(item, most)
		entry["stock"][item] = mini(most, stock + _rules.restock(shop, item) * days)
	for item in _rules.taken(shop):
		if days > 0 or not entry["room"].has(item):
			entry["room"][item] = _rules.most_room(shop, item)
	entry["restocked_day"] = today
	return entry


static func _name_of(item: StringName) -> String:
	return ItemTypes.TYPES[item]["name"]
