class_name ProcessStation
extends RefCounted
## A process station as the player uses it (task 199): a station that data/stations.cfg makes one,
## such as the kiln. Its grid is the object's `storage`, saved with it; what may go in is
## ProcessLoad's rule, over the recipes of the station the player may make. Stacks go in by hand
## (`put_in`) or by a recipe click (`fill`), all only within the player's reach, and the
## activation (`start`) runs the first recipe the
## grid holds whole loads of: its run takes the recipe's hours on the game clock, the grid kept and
## locked, also while the player is away. Nothing ticks: whoever looks settles it first (`settle`),
## and once it is done the materials are gone and the grid holds what they made. Until that is
## all taken out, nothing goes in and nothing starts. The grid is packed again after anything
## comes out (see ProcessLoad), so what fits it is what the rule counts. Plain state;
## ProcessScreen only shows it.

## The run in the station's `state`: {recipe, start_minute, done_minute, products}, products
## (item id to count) until they are in the grid. It stays until the grid is empty again.
const RUN := "run"

var station: WorldObject
## What its window is titled, and its grid's columns and rows, from stations.cfg.
var title: String
var grid_size: Vector2i
## The picture on its activation button.
var button_icon: String
## The grid: the station's storage.
var grid: ItemSlots
## The station's recipes, in the order of the file.
var recipe_ids: Array[StringName]
## The recipes, the player's skills and what practising them tells.
var crafting: Crafting
## The player's, which stacks come from and go to.
var inventory: Inventory

var _state: GameState
var _slot_count: int
## The rule for the recipes the player may make now, and those recipes, made anew when they change
## (see `_rule`).
var _cached_rule: ProcessLoad
var _cached_rule_recipes: Array[StringName] = []


func _init(
	game: GameState,
	recipe_crafting: Crafting,
	station_object: WorldObject,
	stations := StationRules.default_rules()
) -> void:
	_state = game
	crafting = recipe_crafting
	inventory = game.player.inventory
	station = station_object
	grid = station_object.storage
	var station_id := stations.station_of(station_object.type)
	assert(stations.is_process(station_id), "Not a process station: %s" % station_object.type)
	title = stations.station_name(station_id)
	grid_size = stations.grid_size(station_id)
	button_icon = stations.button_icon(station_id)
	_slot_count = stations.slot_count(station_id)
	assert(grid != null and grid.slots.size() == _slot_count, "No grid of its size")
	recipe_ids = recipe_crafting.rules.recipes_at(station_id)


## Puts what a run that is done made into the grid, in place of its materials, and ends a run whose
## results are all out (also one the save validator left nothing of). Does nothing while it runs.
static func settle(station_object: WorldObject, now: int) -> void:
	var run: Dictionary = station_object.state.get(RUN, {})
	if run.is_empty():
		return
	if not run.has("products"):
		if station_object.storage.is_empty():
			station_object.state.erase(RUN)
		return
	if now < int(run["done_minute"]):
		return
	# Settled before the grid tells of the change, so a listener that looks finds it done.
	var products: Dictionary = run["products"]
	run.erase("products")
	var grid_slots := station_object.storage
	grid_slots.hold_notifications(
		func() -> void:
			for slot in grid_slots.slots.size():
				grid_slots.destroy(slot)
			for item: String in products:
				grid_slots.add(StringName(item), int(products[item]))
	)


## Whether a run is going on: the grid is locked.
func is_running() -> bool:
	settle(station, _now())
	return station.state.has(RUN) and station.state[RUN].has("products")


## Whether the grid holds what a run made: it only lets things out.
func holds_results() -> bool:
	settle(station, _now())
	return station.state.has(RUN) and not station.state[RUN].has("products")


## How far the run is, 0 to 1.
func progress() -> float:
	var run: Dictionary = station.state[RUN]
	var start := int(run["start_minute"])
	var length := int(run["done_minute"]) - start
	return clampf(float(_now() - start) / maxi(length, 1), 0.0, 1.0)


## The game minutes until the run is done (0 once it is).
func minutes_left() -> int:
	return maxi(int(station.state[RUN]["done_minute"]) - _now(), 0)


func is_locked(recipe_id: StringName) -> bool:
	return crafting.is_locked(recipe_id)


## Whether what is in the grid leaves the recipe open: a part of loads of it that fit.
func is_open(recipe_id: StringName) -> bool:
	return not is_locked(recipe_id) and _rule().is_open(recipe_id, _contents())


## How many of `item` may go in now.
func room_for(item: StringName) -> int:
	return _rule().room_for(item, _contents()) if _is_idle() else 0


## Moves as much of the stack in `slot` of `from` (the inventory) into the grid as may go in.
## Returns how many went.
func put_in(from: ItemSlots, slot: int) -> int:
	var item := from.item_in(slot)
	var count := mini(from.slots[slot].get("count", 0), room_for(item))
	if count < 1 or not crafting.is_in_reach(station):
		return 0
	var before := grid.count_of(item)
	from.send(slot, grid, [], count)
	return grid.count_of(item) - before


## Moves the stack in `slot` of the grid to `to_slot` of `target`: of the inventory when that is
## empty or holds the same item (as much as fits), never a swap, which would put something in; or
## of the grid itself, which changes nothing it holds. Nothing moves while it runs.
func take_out(slot: int, target: ItemSlots, to_slot: int) -> void:
	if is_running() or not target.has_slot(to_slot) or not crafting.is_in_reach(station):
		return
	var item := grid.item_in(slot)
	if item == ItemTypes.NONE:
		return
	if target == grid:
		grid.move_to(slot, grid, to_slot)
		return
	if target.item_in(to_slot) not in [ItemTypes.NONE, item]:
		return
	var was_results := holds_results()
	var before := grid.count_of(item)
	grid.move_to(slot, target, to_slot)
	_taken_out(item, before - grid.count_of(item), was_results)


## Moves the stack in `slot` of the grid into the inventory, the backpack first, as much as fits.
func send_out(slot: int) -> void:
	if is_running() or not crafting.is_in_reach(station):
		return
	var item := grid.item_in(slot)
	if item == ItemTypes.NONE:
		return
	var was_results := holds_results()
	var before := grid.count_of(item)
	grid.send(slot, inventory, inventory.backpack_first_order())
	_taken_out(item, before - grid.count_of(item), was_results)


## Whether a click on the recipe can fill the grid: it may be made, the grid leaves it open and the
## materials are there for its least amount.
func can_fill(recipe_id: StringName) -> bool:
	return (
		_is_idle()
		and not is_locked(recipe_id)
		and _rule().can_fill(recipe_id, _contents(), _carried())
	)


## The loads a click on the recipe can fill the grid to, as (fewest, most): at least what it
## holds and one, at most what the materials, the grid and what is in it allow (none for a
## locked recipe).
func amounts(recipe_id: StringName) -> Vector2i:
	if is_locked(recipe_id):
		return Vector2i(1, 0)
	var rule := _rule()
	return Vector2i(
		rule.least_amount(recipe_id, _contents()),
		rule.most_amount(recipe_id, _contents(), _carried())
	)


## Moves what `amount` loads of the recipe need besides what the grid holds from the inventory into
## the grid. Returns whether it did; an amount out of `amounts`, or one the grid has no room for, is
## refused and nothing moves.
func fill(recipe_id: StringName, amount: int) -> bool:
	var limits := amounts(recipe_id)
	if not can_fill(recipe_id) or amount < limits.x or amount > limits.y:
		return false
	if not crafting.is_in_reach(station):
		return false
	var held := _contents()
	var materials := crafting.rules.materials(recipe_id)
	var to_add := {}
	for item: StringName in materials:
		var count: int = amount * materials[item] - held.get(item, 0)
		if count > 0:
			to_add[item] = count
	if not grid.can_add(to_add):
		return false
	inventory.hold_notifications(
		func() -> void:
			grid.hold_notifications(
				func() -> void:
					for item: StringName in to_add:
						if not _state.cheats.is_cost_off:
							inventory.remove(item, to_add[item])
						grid.add(item, to_add[item])
			)
	)
	return true


## The recipe the activation would run: the first the grid holds whole loads of, or &"".
func runnable_recipe() -> StringName:
	return _rule().runnable_recipe(_contents()) if _is_idle() else &""


## What the grid lacks for the next whole load of the first recipe it leaves open (item id to
## count): empty when it can run, or no recipe is open.
func missing() -> Dictionary:
	if runnable_recipe() != &"":
		return {}
	var open := _rule().open_recipes(_contents())
	return {} if open.is_empty() else _rule().missing(open[0], _contents())


## Starts the run of `runnable_recipe`: what the loads make, with the bonus of the player's skill,
## is done after the recipe's hours. Practises the skill. Returns false and starts nothing when the
## grid holds no whole loads, or the station is out of the player's reach.
func start() -> bool:
	var recipe_id := runnable_recipe()
	if recipe_id == &"" or not crafting.is_in_reach(station):
		return false
	var rules := crafting.rules
	var loads := _rule().whole_loads(recipe_id, _contents())
	var points := crafting.player_skills().points(rules.skill(recipe_id))
	var products := {
		str(rules.result(recipe_id)): ProcessLoad.result_count(rules, recipe_id, loads, points)
	}
	var minutes := roundi(rules.hours(recipe_id) * GameClock.MINUTES_PER_HOUR)
	station.state[RUN] = {
		"recipe": str(recipe_id),
		"start_minute": _now(),
		"done_minute": _now() + minutes,
		"products": products,
	}
	_state.report(ActionOutcome.START_CRAFT, station.pos, station.type, _contents())
	crafting.practise(recipe_id)
	# Nothing in the grid changed, but it is locked now.
	grid.changed.emit()
	return true


## `count` of `item` came out of the grid, which is packed again; when they were results of a run,
## that is told, and the run ends with the last.
func _taken_out(item: StringName, count: int, were_results: bool) -> void:
	if count < 1:
		return
	_pack()
	if not were_results:
		return
	_state.report(ActionOutcome.TAKE_OUT, station.pos, station.type, {item: count})
	if grid.is_empty():
		settle(station, _now())
		grid.changed.emit()


## Puts each item of the grid in as few stacks as hold it, from the first slots on: a stack taken
## out in part (onto a nearly full stack) leaves a small one, and the rule counts packed slots.
func _pack() -> void:
	var held := _contents()
	grid.hold_notifications(
		func() -> void:
			for slot in grid.slots.size():
				grid.destroy(slot)
			for item: StringName in held:
				grid.add(item, held[item])
	)


## What the player carries for a recipe click: the inventory, or with the cost cheat on as much
## of everything as the grid holds.
func _carried() -> Dictionary:
	if not _state.cheats.is_cost_off:
		return inventory.totals()
	var plenty := {}
	for recipe_id in recipe_ids:
		for item: StringName in crafting.rules.materials(recipe_id):
			plenty[item] = _slot_count * ItemTypes.TYPES[item]["stack_limit"]
	return plenty


func _now() -> int:
	return _state.clock.total_minutes()


func _contents() -> Dictionary:
	return grid.totals()


## Whether things may go in and a run may start: no run, and no results in the grid.
func _is_idle() -> bool:
	settle(station, _now())
	return not station.state.has(RUN)


## The rule over the recipes the player may make now (a locked one takes nothing).
func _rule() -> ProcessLoad:
	var unlocked: Array[StringName] = []
	unlocked.assign(
		recipe_ids.filter(func(recipe_id: StringName) -> bool: return not is_locked(recipe_id))
	)
	if _cached_rule == null or unlocked != _cached_rule_recipes:
		_cached_rule_recipes = unlocked
		_cached_rule = ProcessLoad.new(crafting.rules, unlocked, _slot_count)
	return _cached_rule
