class_name Crafting
extends RefCounted
## What the crafting menu does: `craft` takes a recipe's materials from the inventory and puts
## its result in. Plain logic; CraftingScreen only shows the recipes and sends the click. A
## craft that would not leave room for the result is refused, as a building is refused when
## the materials are missing: nothing is dropped on the ground.

enum Result { CRAFTED, MISSING_MATERIALS, NO_ROOM }

## The recipes there are.
var rules: RecipeRules

var _state: GameState


func _init(state: GameState, recipes := RecipeRules.default_rules()) -> void:
	_state = state
	rules = recipes


## What the player lacks for a recipe, item id to the count short; empty when they have it all
## (or the cost cheat is on).
func shortfalls(recipe_id: StringName) -> Dictionary:
	var short := {}
	if _state.cheats.is_cost_off:
		return short
	var materials := rules.materials(recipe_id)
	for item: StringName in materials:
		var missing: int = materials[item] - _state.player.inventory.count_of(item)
		if missing > 0:
			short[item] = missing
	return short


func craft(recipe_id: StringName) -> Result:
	if not shortfalls(recipe_id).is_empty():
		return Result.MISSING_MATERIALS
	var inventory := _state.player.inventory
	var materials := {} if _state.cheats.is_cost_off else rules.materials(recipe_id)
	# The materials leave first, so a full inventory can still hold what they were made into.
	var trial := inventory.duplicate()
	for item: StringName in materials:
		trial.remove(item, materials[item])
	if not trial.can_add({rules.result(recipe_id): rules.count(recipe_id)}):
		return Result.NO_ROOM
	for item: StringName in materials:
		inventory.remove(item, materials[item])
	inventory.add(rules.result(recipe_id), rules.count(recipe_id))
	return Result.CRAFTED
