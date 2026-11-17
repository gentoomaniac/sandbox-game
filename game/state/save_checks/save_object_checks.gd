class_name SaveObjectChecks
extends RefCounted
## The checks of what holds items and state: the slots of a stack list, the piles on the ground,
## and the objects of the world with the state of each. A feature with a state of its own (a
## campfire, a nest, a sales cart, a process station's run) has its check below, found by the key
## of the state.

## The state keys whose value is a number, which need no more check than that.
const NUMBER_STATE_KEYS: Array[String] = [
	"damage",
	"growth",
	"crop_damage",
	"days_growing",
	"days_grown",
	"days_ripe",
	"eaten",
	"ripe_at_dawn",
	"hours_under_water",
	"placed_day",
	"days_until_bears",
	ReedLife.REGROWTH,
]

var _ctx: SaveContext
## The one registration of each key an object's state may hold besides the numbers: its check,
## which holds the key's shape too (a dictionary, a flag...). Called as
## `check(state, type_data, path, drop_object)` for every object that has the key. A key with no
## registration at all is refused.
var _state_checks: Dictionary[String, Callable] = {
	DykeProfile.HEIGHT_KEY: _check_dyke_measure.bind(DykeProfile.HEIGHT_KEY),
	DykeProfile.STRENGTH_KEY: _check_dyke_measure.bind(DykeProfile.STRENGTH_KEY),
	"stock": _check_stock,
	Campfire.LOG_LEFT: _check_log_left,
	Campfire.LIT: _check_lit,
	"eggs": _check_eggs,
	"tree": _check_tree,
	ProcessStation.RUN: _check_run,
	"till": _check_till,
	"prices": _check_prices,
}


func _init(context: SaveContext) -> void:
	_ctx = context
	for key in NUMBER_STATE_KEYS:
		_state_checks[key] = _check_number.bind(key)


## The piles on the ground of a map (the world, or an interior), at `path`.
func check_ground_items(map: Dictionary, path: String) -> void:
	var piles: Variant = _ctx.field(map, "ground_items", SaveContext.Kind.LIST, path)
	if piles != null:
		for index in piles.size():
			_check_ground_item(piles[index], "%s ground_items %d" % [path, index], piles)


## `drop` takes the object out of the data, if the game no longer has what it is or needs.
func check_object(object: Variant, path: String, drop: Callable) -> void:
	if not object is Dictionary:
		_ctx.report(path, "should be a dictionary")
		return
	var type: Variant = _ctx.field(object, "type", SaveContext.Kind.TEXT, path)
	_ctx.field(object, "pos", SaveContext.Kind.VECTOR, path)
	var state: Variant = _ctx.field(object, "state", SaveContext.Kind.DICT, path)
	if type == null:
		return
	if not WorldObjectTypes.TYPES.has(StringName(type)):
		_ctx.add_missing("object %s" % type, path, drop)
		return
	if state != null:
		_check_object_state(state, WorldObjectTypes.TYPES[StringName(type)], path, drop)
	var slot_count := WorldObject.storage_slot_count(StringName(type))
	if slot_count > 0:
		check_stacks(object, "storage", slot_count, path)


## The slots of `owner[key]`: `slot_count` of them, each empty (null) or a stack of an item the
## game has, of a count from 1 to the item's stack limit.
func check_stacks(owner: Dictionary, key: String, slot_count: int, path: String) -> void:
	var slots: Variant = _ctx.field(owner, key, SaveContext.Kind.LIST, path)
	if slots == null:
		return
	if slots.size() != slot_count:
		_ctx.report(path, "%s has %d slots, not %d" % [key, slots.size(), slot_count])
		return
	for slot in slot_count:
		var stack: Variant = slots[slot]
		var slot_path := "%s slot %d" % [path, slot]
		if stack == null:
			continue
		if not stack is Dictionary:
			_ctx.report(slot_path, "should be a stack or null")
			continue
		var item: Variant = _ctx.field(stack, "item", SaveContext.Kind.TEXT, slot_path)
		var count: Variant = _ctx.field(stack, "count", SaveContext.Kind.WHOLE, slot_path)
		if item == null or count == null:
			continue
		if not ItemTypes.TYPES.has(StringName(item)):
			_ctx.add_missing("item %s" % item, slot_path, func() -> void: slots[slot] = null)
			continue
		var limit: int = ItemTypes.TYPES[StringName(item)]["stack_limit"]
		if count < 1 or count > limit:
			_ctx.report(slot_path, "count %d is not between 1 and %d" % [count, limit])
		_check_item_state(stack, StringName(item), count, slot_path)


func _check_ground_item(pile: Variant, path: String, piles: Array) -> void:
	if not pile is Dictionary:
		_ctx.report(path, "should be a dictionary")
		return
	var item: Variant = _ctx.field(pile, "item", SaveContext.Kind.TEXT, path)
	var count: Variant = _ctx.field(pile, "count", SaveContext.Kind.WHOLE, path)
	_ctx.field(pile, "position", SaveContext.Kind.POINT, path)
	if item != null and not ItemTypes.TYPES.has(StringName(item)):
		_ctx.add_missing("item %s" % item, path, _ctx.removing(piles, pile))
	elif count != null and count < 1:
		_ctx.report(path, "count %d is less than 1" % count)
	if item != null and count != null and ItemTypes.TYPES.has(StringName(item)):
		_check_item_state(pile, StringName(item), count, path)


## The state of a stack or a pile of `count` of `item`, if it has one: on a single item, and one
## that the item can have.
func _check_item_state(owner: Dictionary, item: StringName, count: Variant, path: String) -> void:
	if not owner.has("state"):
		return
	if not (owner["state"] is Dictionary and count == 1):
		_ctx.report(path, "a state belongs to one item and is a dictionary")
		return
	var problem := LanternCandle.problem_with_state(item, owner["state"])
	if problem != "":
		_ctx.report(path, problem)


func _check_object_state(
	state: Dictionary, type_data: Dictionary, path: String, drop_object: Callable
) -> void:
	for key: String in state.keys():
		if _state_checks.has(key):
			_state_checks[key].call(state, type_data, path, drop_object)
		else:
			_ctx.report(path + " state", "%s is not a state an object has" % key)


## A key whose value is a number.
func _check_number(
	state: Dictionary, _type: Dictionary, path: String, _drop: Callable, key: String
) -> void:
	if not _ctx.is_kind(state[key], SaveContext.Kind.NUMBER):
		_ctx.report(path + " state", "%s should be a number" % key)


## What a trough or a hay rack holds: a whole number up to what it holds.
func _check_stock(state: Dictionary, type_data: Dictionary, path: String, _drop: Callable) -> void:
	var capacity: int = type_data.get("stock_capacity", 0)
	if _ctx.is_kind(state["stock"], SaveContext.Kind.WHOLE):
		_ctx.check_between(state["stock"], 0, capacity, path + " state", "stock")
	else:
		_ctx.report(path + " state", "stock should be a whole number")


## The minutes a campfire's log has left to burn.
func _check_log_left(state: Dictionary, _type: Dictionary, path: String, _drop: Callable) -> void:
	if _ctx.is_kind(state[Campfire.LOG_LEFT], SaveContext.Kind.WHOLE):
		var log_minutes := LightingRules.default_rules().longest_burn_minutes()
		_ctx.check_between(state[Campfire.LOG_LEFT], 0, log_minutes, path + " state", "log_left")
	else:
		_ctx.report(path + " state", "log_left should be a whole number")


## Whether a campfire is lit, which it is only with a log burning.
func _check_lit(state: Dictionary, _type: Dictionary, path: String, _drop: Callable) -> void:
	if not state[Campfire.LIT] is bool:
		_ctx.report(path + " state", "lit should be true or false")
	elif state[Campfire.LIT] and not state.has(Campfire.LOG_LEFT):
		_ctx.report(path + " state", "a lit fire needs log_left")


## The eggs in a nest: a whole number up to what it holds.
func _check_eggs(state: Dictionary, _type: Dictionary, path: String, _drop: Callable) -> void:
	if _ctx.is_kind(state["eggs"], SaveContext.Kind.WHOLE):
		var nest_eggs: int = YardRules.default_rules().coop("nest_eggs")
		_ctx.check_between(state["eggs"], 0, nest_eggs, path + " state", "eggs")
	else:
		_ctx.report(path + " state", "eggs should be a whole number")


## The tree a stump or sapling comes from.
func _check_tree(state: Dictionary, _type: Dictionary, path: String, drop_object: Callable) -> void:
	if not state["tree"] is String:
		_ctx.report(path + " state", "tree should be text")
	elif not WorldObjectTypes.TYPES.has(StringName(state["tree"])):
		_ctx.add_missing("tree %s" % state["tree"], path, drop_object)


## The money in the till of a sales cart.
func _check_till(state: Dictionary, _type: Dictionary, path: String, _drop: Callable) -> void:
	if not (_ctx.is_kind(state["till"], SaveContext.Kind.WHOLE) and state["till"] >= 0):
		_ctx.report(path + " state", "till should be a whole number, at least 0")


## The height (in centimetres) or strength (in percent) of a dyke the game changed.
func _check_dyke_measure(
	state: Dictionary, _type: Dictionary, path: String, _drop: Callable, key: String
) -> void:
	if not _ctx.is_kind(state[key], SaveContext.Kind.WHOLE):
		_ctx.report(path + " state", "%s should be a whole number" % key)
		return
	var most := DykeProfile.MAX_HEIGHT_CM if key == DykeProfile.HEIGHT_KEY else 100
	_ctx.check_between(state[key], 0, most, path + " state", key)


## The prices of a sales cart (see SalesCart), by slot: the item each price is for and the price in
## whole Schilling, from 1. A price for an item the game no longer has is dropped.
func _check_prices(state: Dictionary, _type: Dictionary, path: String, _drop: Callable) -> void:
	var prices: Variant = state["prices"]
	path += " state prices"
	if not prices is Dictionary:
		_ctx.report(path, "should be a dictionary")
		return
	for slot: Variant in prices:
		var entry: Variant = prices[slot]
		var entry_path := "%s %s" % [path, slot]
		if not (slot is String and slot.is_valid_int() and int(slot) >= 0):
			_ctx.report(entry_path, "should be under a slot number")
		elif not entry is Dictionary:
			_ctx.report(entry_path, "should be a dictionary")
		else:
			var item: Variant = _ctx.field(entry, "item", SaveContext.Kind.TEXT, entry_path)
			var price: Variant = _ctx.field(entry, "price", SaveContext.Kind.WHOLE, entry_path)
			if price != null and price < 1:
				_ctx.report(entry_path, "price should be at least 1")
			if item != null and not ItemTypes.TYPES.has(StringName(item)):
				_ctx.add_missing("item %s" % item, entry_path, func() -> void: prices.erase(slot))


## The run of a process station (see ProcessStation): its recipe, start and done minutes, and
## what it makes until that is in the grid.
func _check_run(state: Dictionary, _type: Dictionary, path: String, _drop: Callable) -> void:
	path += " state " + ProcessStation.RUN
	var run: Variant = state[ProcessStation.RUN]
	if not run is Dictionary:
		_ctx.report(path, "should be a dictionary")
		return
	var recipe: Variant = _ctx.field(run, "recipe", SaveContext.Kind.TEXT, path)
	_ctx.field(run, "start_minute", SaveContext.Kind.WHOLE, path)
	_ctx.field(run, "done_minute", SaveContext.Kind.WHOLE, path)
	if recipe != null and not RecipeRules.default_rules().recipe_ids().has(StringName(recipe)):
		_ctx.add_missing(
			"recipe %s" % recipe, path, func() -> void: state.erase(ProcessStation.RUN)
		)
	if not run.has("products"):
		return
	var products: Variant = run["products"]
	if not products is Dictionary:
		_ctx.report(path, "products should be a dictionary")
		return
	for item: Variant in products:
		if not ItemTypes.TYPES.has(StringName(str(item))):
			_ctx.add_missing("item %s" % item, path, func() -> void: products.erase(item))
		elif not (_ctx.is_kind(products[item], SaveContext.Kind.WHOLE) and products[item] >= 1):
			_ctx.report(path, "products %s should be a whole number, at least 1" % item)
