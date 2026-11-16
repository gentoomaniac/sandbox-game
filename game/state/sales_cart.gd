class_name SalesCart
extends RefCounted
## The player's hand cart with a board (design/economy/README.md, "The player's stall"): a placed
## object that holds goods like a chest, each stack with a price in whole Schilling, and a till
## that the villagers' payments go into. It is a view of the WorldObject, so the slots, the prices
## and the till are saved with it (`state` of the object: `till`, and `prices` by slot, each with
## the item it was set for, so a slot filled with something else is priced anew).
##
## A stack is for sale when its item has a worth (see Prices); until the player sets a price it
## sells for that worth. The stall pays 100 percent: the player gets the whole price, where a shop
## pays 60.

var object: WorldObject


func _init(cart: WorldObject) -> void:
	assert(cart.type == WorldObjectStall.SALES_CART, "Not a sales cart: %s" % cart.type)
	object = cart


## The carts the player has set out, in loaded chunks or not.
static func all_in(world: World) -> Array[SalesCart]:
	var carts: Array[SalesCart] = []
	for placed in world.edited_objects():
		if placed.type == WorldObjectStall.SALES_CART:
			carts.append(SalesCart.new(placed))
	return carts


func slots() -> ItemSlots:
	return object.storage


## The Schilling in the till, which the player empties by hand.
func till() -> int:
	return int(object.state.get("till", 0))


## Whether the stack in `slot` is for sale: it holds something with a worth.
func is_for_sale(slot: int) -> bool:
	var item := slots().item_in(slot)
	return item != ItemTypes.NONE and Prices.default_prices().has_worth(item)


## What one of the stack in `slot` costs: the price the player set, or the item's worth. 0 for a
## slot that is not for sale.
func price_of(slot: int) -> int:
	if not is_for_sale(slot):
		return 0
	var item := slots().item_in(slot)
	var set_for: Dictionary = object.state.get("prices", {}).get(str(slot), {})
	if set_for.get("item") == str(item):
		return int(set_for["price"])
	return Prices.default_prices().worth(item)


## Sets the price of the stack in `slot`, a whole number of Schilling from 1. Returns false for a
## price below 1 or a slot that is not for sale.
func set_price(slot: int, price: int) -> bool:
	if price < 1 or not is_for_sale(slot):
		return false
	if not object.state.has("prices"):
		object.state["prices"] = {}
	object.state["prices"][str(slot)] = {"item": str(slots().item_in(slot)), "price": price}
	return true


## Puts the stack in slot `from` of the player's `bag` on the cart, as much of it as fits, if it
## is for sale. Returns whether the whole stack went.
func stock(bag: ItemSlots, from: int) -> bool:
	if not Prices.default_prices().has_worth(bag.item_in(from)):
		return false
	return bag.send(from, slots())


## Takes the stack in slot `from` of the cart back into the `bag`, as much of it as fits. Returns
## whether the whole stack went.
func take_back(bag: ItemSlots, from: int) -> bool:
	return slots().send(from, bag)


## One of the stack in `slot` is sold: it leaves the cart and its price goes into the till. Returns
## the price, or 0 if the stack is not for sale.
func sell_one(slot: int) -> int:
	var price := price_of(slot)
	if price == 0:
		return 0
	# The till first: taking from the stack tells whoever shows the cart, which then shows the till.
	object.state["till"] = till() + price
	var is_taken := slots().take_from(slot, 1)
	assert(is_taken, "A stack for sale holds one")
	return price


## Empties the till into the purse. Returns how much it held.
func take_takings(purse: Purse) -> int:
	var takings := till()
	purse.add(takings)
	object.state["till"] = 0
	return takings
