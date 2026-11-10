class_name ObjectStock
extends RefCounted
## What a trough or a hay rack holds (see WorldObjectTypes `stock_capacity`): units of water or of
## feed, from 0 to the capacity, kept as `stock` in the object's state and so saved with it. Plain
## functions of the object.


## Whether the object holds a stock at all.
static func is_stocked(object: WorldObject) -> bool:
	return object.type_data().has("stock_capacity")


## How much it holds, in units.
static func units(object: WorldObject) -> int:
	return int(object.state.get("stock", 0))


static func capacity(object: WorldObject) -> int:
	return int(object.type_data()["stock_capacity"])


## Puts `amount` into the stock, as far as there is room; returns how many units went in.
static func add(object: WorldObject, amount: int) -> int:
	var added := mini(amount, capacity(object) - units(object))
	object.state["stock"] = units(object) + added
	return added


## Takes up to `amount` out of the stock; returns how many units came out.
static func take(object: WorldObject, amount: int) -> int:
	var taken := mini(amount, units(object))
	object.state["stock"] = units(object) - taken
	return taken


## Which of its pictures shows how full it is: 0 empty, 1 low, 2 half (from WorldObjectTypes
## STOCK_HALF_FROM of its capacity), 3 full (from STOCK_FULL_FROM).
static func look(object: WorldObject) -> int:
	if units(object) == 0:
		return 0
	var fraction := float(units(object)) / float(capacity(object))
	if fraction >= WorldObjectTypes.STOCK_FULL_FROM:
		return 3
	return 2 if fraction >= WorldObjectTypes.STOCK_HALF_FROM else 1
