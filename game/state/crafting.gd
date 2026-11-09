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

## WRONG_STATION: the recipe is made at a station of another kind than the one given. NO_STATION:
## it is made at a station and there is none, or the one given is not on the player's map or is out
## of their reach.
enum Result {
	CRAFTED,
	STARTED,
	MISSING_MATERIALS,
	NO_ROOM,
	LOCKED,
	BUSY,
	WRONG_STATION,
	NO_STATION,
}

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
## made at), which must not be busy with another. A recipe made at a station needs one of that
## kind in the player's reach; one made by hand ignores `station`.
func craft(recipe_id: StringName, station: WorldObject = null) -> Result:
	var is_slow := rules.hours(recipe_id) > 0.0
	var station_refusal := _station_refusal(recipe_id, station)
	if station_refusal != Result.CRAFTED:
		return station_refusal
	if is_locked(recipe_id):
		return Result.LOCKED
	if is_slow and StationWork.is_busy(station):
		return Result.BUSY
	if not shortfalls(recipe_id).is_empty():
		return Result.MISSING_MATERIALS
	var materials := {} if _state.cheats.is_cost_off else rules.materials(recipe_id)
	var made := {} if is_slow else {rules.result(recipe_id): rules.count(recipe_id)}
	var is_exchange_needed := not (materials.is_empty() and made.is_empty())
	if is_exchange_needed and not _state.player.inventory.exchange(materials, made):
		return Result.NO_ROOM
	var result := {rules.result(recipe_id): rules.count(recipe_id)}
	if is_slow:
		var minutes := roundi(rules.hours(recipe_id) * GameClock.MINUTES_PER_HOUR)
		StationWork.start(station, recipe_id, _state.clock.total_minutes() + minutes)
		_state.report(ActionOutcome.START_CRAFT, station.pos, station.type, result)
	else:
		var at: Vector2i = _state.player.tile() if station == null else station.pos
		_state.report(ActionOutcome.CRAFT, at, _station_type(station), result)
	_practise(recipe_id)
	return Result.STARTED if is_slow else Result.CRAFTED


## Whether the station holds work that is done.
func is_work_done(station: WorldObject) -> bool:
	return StationWork.is_done(station, _state.clock.total_minutes())


## The game minutes until the station's work is done (0 once it is).
func minutes_left(station: WorldObject) -> int:
	return maxi(StationWork.done_minute(station) - _state.clock.total_minutes(), 0)


## Takes the done work out of the station into the inventory. Returns false, and leaves it in the
## station, when it does not fit or the station is out of the player's reach.
func take_out(station: WorldObject) -> bool:
	assert(is_work_done(station), "Nothing done to take out")
	if not _is_station_in_reach(station):
		return false
	var result := StationWork.contents(station, _state.clock.total_minutes(), rules)
	if not _state.player.inventory.can_add(result):
		return false
	# The station is empty before the inventory tells of the result, so a listener never sees it
	# in both.
	StationWork.clear(station)
	_state.player.inventory.exchange({}, result)
	_state.report(ActionOutcome.TAKE_OUT, station.pos, station.type, result)
	return true


## WRONG_STATION or NO_STATION when `station` will not do for the recipe; CRAFTED (nothing is
## refused) when it will, or when the recipe is made by hand.
func _station_refusal(recipe_id: StringName, station: WorldObject) -> Result:
	var kind := rules.station_of(recipe_id)
	if kind == &"":
		return Result.CRAFTED
	if station != null and StationRules.default_rules().station_of(station.type) != kind:
		return Result.WRONG_STATION
	return Result.CRAFTED if _is_station_in_reach(station) else Result.NO_STATION


## Whether `station` is an object on the player's map within their reach.
func _is_station_in_reach(station: WorldObject) -> bool:
	if station == null:
		return false
	var found := Interaction.nearest_in_reach(
		_state, func(object: WorldObject) -> bool: return object == station
	)
	return found != null


## The type of the station a recipe is made at, or empty for one made by hand.
func _station_type(station: WorldObject) -> StringName:
	return &"" if station == null else station.type


func _practise(recipe_id: StringName) -> void:
	var skill := rules.skill(recipe_id)
	if skill == &"":
		return
	var skills := _state.player.skills
	var wanted := skills.gain_at(skill, rules.level(recipe_id))
	practised.emit(skill, skills.practise(skill, rules.level(recipe_id)), wanted)
