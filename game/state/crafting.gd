class_name Crafting
extends RefCounted
## What the crafting menu does: `craft` takes a recipe's materials from the inventory and puts
## its result in. Plain logic; CraftingScreen only shows the recipes and sends the click. A
## craft that would not leave room for the result is refused, as a building is refused when
## the materials are missing: nothing is dropped on the ground. A recipe with a skill needs its
## level in that skill (it is locked below it), and each craft practises the skill (see Skills).

## A craft practised `skill`: it grew by `gained` points of the `wanted` the recipe teaches (less
## at the total cap, see Skills).
signal practised(skill: StringName, gained: float, wanted: float)

enum Result { CRAFTED, MISSING_MATERIALS, NO_ROOM, LOCKED }

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


## Whether the player lacks the skill points a recipe needs.
func is_locked(recipe_id: StringName) -> bool:
	var skill := rules.skill(recipe_id)
	return skill != &"" and _state.player.skills.points(skill) < rules.level(recipe_id)


func craft(recipe_id: StringName) -> Result:
	if is_locked(recipe_id):
		return Result.LOCKED
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
	_practise(recipe_id)
	return Result.CRAFTED


func _practise(recipe_id: StringName) -> void:
	var skill := rules.skill(recipe_id)
	if skill == &"":
		return
	var skills := _state.player.skills
	var wanted := skills.gain_at(skill, rules.level(recipe_id))
	practised.emit(skill, skills.practise(skill, rules.level(recipe_id)), wanted)
