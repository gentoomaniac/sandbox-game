class_name Crafting
extends RefCounted
## What the crafting menu does: `craft` takes a recipe's materials from the inventory and puts
## its result in. Plain logic; CraftingScreen only shows the recipes and sends the click. A
## craft that would not leave room for the result is refused, as a building is refused when
## the materials are missing: nothing is dropped on the ground. A recipe with a skill needs its
## level in that skill (it is locked below it), and each craft practises the skill (see Skills).
## A slow recipe (with `hours`, the kiln's firing) is started at its station instead, which holds
## it until it is done (see StationWork); `take_out` then puts the result in the inventory.

## A craft practised `skill`: it grew by `gained` points of the `wanted` the recipe teaches (less
## at the total cap, see Skills).
signal practised(skill: StringName, gained: float, wanted: float)

enum Result { CRAFTED, STARTED, MISSING_MATERIALS, NO_ROOM, LOCKED, BUSY }

## The recipes there are.
var rules: RecipeRules

var _state: GameState


func _init(state: GameState, recipes := RecipeRules.default_rules()) -> void:
	_state = state
	rules = recipes


## The skills of the player who crafts.
func player_skills() -> Skills:
	return _state.player.skills


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


## Crafts a recipe: at once, or for a slow recipe by starting it at `station` (the object it is
## made at), which must not be busy with another.
func craft(recipe_id: StringName, station: WorldObject = null) -> Result:
	var is_slow := rules.hours(recipe_id) > 0.0
	assert(not is_slow or station != null, "A slow recipe is started at its station")
	if is_locked(recipe_id):
		return Result.LOCKED
	if is_slow and StationWork.is_busy(station):
		return Result.BUSY
	if not shortfalls(recipe_id).is_empty():
		return Result.MISSING_MATERIALS
	var inventory := _state.player.inventory
	var materials := {} if _state.cheats.is_cost_off else rules.materials(recipe_id)
	# The materials leave first, so a full inventory can still hold what they were made into.
	var trial := inventory.duplicate()
	for item: StringName in materials:
		trial.remove(item, materials[item])
	if not is_slow and not trial.can_add({rules.result(recipe_id): rules.count(recipe_id)}):
		return Result.NO_ROOM
	for item: StringName in materials:
		inventory.remove(item, materials[item])
	if is_slow:
		var minutes := roundi(rules.hours(recipe_id) * GameClock.MINUTES_PER_HOUR)
		StationWork.start(station, recipe_id, _state.clock.total_minutes() + minutes)
	else:
		inventory.add(rules.result(recipe_id), rules.count(recipe_id))
	_practise(recipe_id)
	return Result.STARTED if is_slow else Result.CRAFTED


## Whether the station holds work that is done.
func is_work_done(station: WorldObject) -> bool:
	return StationWork.is_done(station, _state.clock.total_minutes())


## The game minutes until the station's work is done (0 once it is).
func minutes_left(station: WorldObject) -> int:
	return maxi(StationWork.done_minute(station) - _state.clock.total_minutes(), 0)


## Takes the done work out of the station into the inventory. Returns false, and leaves it in the
## station, when it does not fit.
func take_out(station: WorldObject) -> bool:
	assert(is_work_done(station), "Nothing done to take out")
	var result := StationWork.contents(station, _state.clock.total_minutes(), rules)
	if not _state.player.inventory.can_add(result):
		return false
	for item: StringName in result:
		_state.player.inventory.add(item, result[item])
	StationWork.clear(station)
	return true


func _practise(recipe_id: StringName) -> void:
	var skill := rules.skill(recipe_id)
	if skill == &"":
		return
	var skills := _state.player.skills
	var wanted := skills.gain_at(skill, rules.level(recipe_id))
	practised.emit(skill, skills.practise(skill, rules.level(recipe_id)), wanted)
