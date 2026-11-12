class_name ProcessLoad
extends RefCounted
## What a process station's grid may hold (task 199): its contents must always be part of whole
## loads of at least one of its recipes, at an amount that fits the grid. A load is one
## crafting's materials; n loads are n times each. Pure: made with the recipes and the grid's size,
## every question takes the grid's contents (item id to count) and changes nothing. The station's
## window only asks it (see ProcessStation).
##
## The slots that items take are counted as if the grid were packed (each item in full stacks and
## at most one part stack): ProcessStation keeps it so, packing it again after anything comes out.

var _rules: RecipeRules
## The recipes the grid is filled for, in the order of the file: the station's that the player
## may make.
var _recipe_ids: Array[StringName]
var _slot_count: int
## Recipe id -> the most loads of it that fit the grid.
var _most_loads := {}


func _init(rules: RecipeRules, recipe_ids: Array[StringName], slot_count: int) -> void:
	_rules = rules
	_recipe_ids = recipe_ids
	_slot_count = slot_count
	for recipe_id in recipe_ids:
		_most_loads[recipe_id] = _count_most_loads(recipe_id)


## The slots `items` (item id to count) take, packed.
static func slots_for(items: Dictionary) -> int:
	var slots := 0
	for item: StringName in items:
		slots += ceili(items[item] / float(ItemTypes.TYPES[item]["stack_limit"]))
	return slots


## How many of its result `loads` loads of a recipe make, with the bonus of `points` in its skill.
static func result_count(
	rules: RecipeRules, recipe_id: StringName, loads: int, points: float
) -> int:
	var count := rules.count(recipe_id) * loads
	return count + floori(count * rules.bonus_share(recipe_id, points))


## The most loads of a recipe whose materials fit the grid, and whose result does too at the
## recipe's highest bonus (the result takes the materials' place in the grid).
func most_loads(recipe_id: StringName) -> int:
	return _most_loads[recipe_id]


## The fewest loads of a recipe that hold the contents: 0 for none, -1 when they hold an item
## that is not one of its materials.
func loads_holding(recipe_id: StringName, contents: Dictionary) -> int:
	var materials := _rules.materials(recipe_id)
	var loads := 0
	for item: StringName in contents:
		if not materials.has(item):
			return -1
		loads = maxi(loads, ceili(contents[item] / float(materials[item])))
	return loads


## Whether the contents are part of loads of the recipe that fit the grid.
func is_open(recipe_id: StringName, contents: Dictionary) -> bool:
	var loads := loads_holding(recipe_id, contents)
	return loads >= 0 and loads <= most_loads(recipe_id) and most_loads(recipe_id) >= 1


## The recipes the contents leave open, in the order of the file.
func open_recipes(contents: Dictionary) -> Array[StringName]:
	return _recipe_ids.filter(
		func(recipe_id: StringName) -> bool: return is_open(recipe_id, contents)
	)


## How many of `item` may go in on top of the contents: as many as keep a recipe open.
func room_for(item: StringName, contents: Dictionary) -> int:
	var room := 0
	for recipe_id in open_recipes(contents):
		var materials := _rules.materials(recipe_id)
		if materials.has(item):
			room = maxi(room, most_loads(recipe_id) * materials[item] - contents.get(item, 0))
	return room


## How many whole loads of the recipe the contents are, exactly; 0 if they are none or a part
## load.
func whole_loads(recipe_id: StringName, contents: Dictionary) -> int:
	var loads := loads_holding(recipe_id, contents)
	if loads <= 0:
		return 0
	var materials := _rules.materials(recipe_id)
	for item: StringName in materials:
		if contents.get(item, 0) != loads * materials[item]:
			return 0
	return loads


## The first open recipe (in the order of the file) the contents are whole loads of, or &"".
func runnable_recipe(contents: Dictionary) -> StringName:
	for recipe_id in open_recipes(contents):
		if whole_loads(recipe_id, contents) > 0:
			return recipe_id
	return &""


## What the contents lack to be whole loads of the recipe (item id to count): the next whole
## load, at least one.
func missing(recipe_id: StringName, contents: Dictionary) -> Dictionary:
	var loads := maxi(loads_holding(recipe_id, contents), 1)
	var materials := _rules.materials(recipe_id)
	var lacking := {}
	for item: StringName in materials:
		var short: int = loads * materials[item] - contents.get(item, 0)
		if short > 0:
			lacking[item] = short
	return lacking


## The fewest loads a click on the recipe can fill the grid to: what it holds, at least one.
func least_amount(recipe_id: StringName, contents: Dictionary) -> int:
	return maxi(loads_holding(recipe_id, contents), 1)


## The most loads a click on the recipe can fill the grid to, with what it holds and `carried`
## (item id to count) besides: no more than fit, nor than the materials make.
func most_amount(recipe_id: StringName, contents: Dictionary, carried: Dictionary) -> int:
	var amount := most_loads(recipe_id)
	var materials := _rules.materials(recipe_id)
	for item: StringName in materials:
		var held: int = contents.get(item, 0) + carried.get(item, 0)
		amount = mini(amount, held / materials[item])
	return amount


## Whether a click on the recipe can fill the grid to at least its least amount: it is open and
## the materials are there.
func can_fill(recipe_id: StringName, contents: Dictionary, carried: Dictionary) -> bool:
	return (
		is_open(recipe_id, contents)
		and most_amount(recipe_id, contents, carried) >= least_amount(recipe_id, contents)
	)


func _count_most_loads(recipe_id: StringName) -> int:
	var loads := 0
	while _fits(recipe_id, loads + 1):
		loads += 1
	return loads


## Whether `loads` loads of the recipe fit the grid, and so does what they make.
func _fits(recipe_id: StringName, loads: int) -> bool:
	var materials := _rules.materials(recipe_id)
	for item: StringName in materials:
		materials[item] *= loads
	var result := {_rules.result(recipe_id): result_count(_rules, recipe_id, loads, INF)}
	return slots_for(materials) <= _slot_count and slots_for(result) <= _slot_count
