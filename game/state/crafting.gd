class_name Crafting
extends RefCounted
## What the crafting menu does: `craft` takes a recipe's materials from the inventory and puts
## its result in. Plain logic; CraftingScreen only shows the recipes and sends the click. The
## materials go first, so the room they leave is used; what of the result does not fit lies on the
## ground (see World `drop_items`): at the player's feet for a craft, by the station for work taken
## out of it. Inside a building nothing lies on the ground, so there a craft or take-out that does
## not fit is refused (NO_ROOM) and changes nothing. A recipe with a skill needs its
## level in that skill (it is locked below it), and each craft practises the skill (see Skills).
## A slow recipe (with `hours`, the kiln's firing) is started at its station instead, which holds
## it until it is done (see StationWork); `take_out` then puts the result in the inventory.

## A craft practised `skill`: it grew by `gained` points of the `wanted` the recipe teaches (less
## at the total cap, see Skills).
signal practised(skill: StringName, gained: float, wanted: float)

## WRONG_STATION: the recipe is made at a station of another kind than the one given. NO_STATION:
## it is made at a station and there is none, or the one given is not on the player's map or is out
## of their reach. DROPPED: crafted, but some of the result did not fit and lies on the ground.
## TAKEN_OUT and DROPPED_OUT are the same for `take_out`.
enum Result {
	CRAFTED,
	DROPPED,
	TAKEN_OUT,
	DROPPED_OUT,
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
	if _state.is_inside() and not _state.player.inventory.can_exchange(materials, made):
		return Result.NO_ROOM
	var dropped := _exchange_dropping_rest(materials, made, _state.player.tile())
	var result := {rules.result(recipe_id): rules.count(recipe_id)}
	var outcome := Result.STARTED
	if is_slow:
		var minutes := roundi(rules.hours(recipe_id) * GameClock.MINUTES_PER_HOUR)
		StationWork.start(station, recipe_id, _state.clock.total_minutes() + minutes)
		_state.report(ActionOutcome.START_CRAFT, station.pos, station.type, result)
	else:
		var at: Vector2i = _state.player.tile() if station == null else station.pos
		_state.report(ActionOutcome.CRAFT, at, _station_type(station), result)
		outcome = Result.CRAFTED if dropped.is_empty() else Result.DROPPED
	_practise(recipe_id)
	return outcome


## Whether the station holds work that is done.
func is_work_done(station: WorldObject) -> bool:
	return StationWork.is_done(station, _state.clock.total_minutes())


## The game minutes until the station's work is done (0 once it is).
func minutes_left(station: WorldObject) -> int:
	return maxi(StationWork.done_minute(station) - _state.clock.total_minutes(), 0)


## Takes the done work out of the station into the inventory: TAKEN_OUT, or DROPPED_OUT when some
## of it did not fit and lies by the station, on the player's side. NO_STATION when the station is
## out of the player's reach; NO_ROOM, with the work left in the station, when it does not fit
## and the player is inside.
func take_out(station: WorldObject) -> Result:
	assert(is_work_done(station), "Nothing done to take out")
	if not _is_station_in_reach(station):
		return Result.NO_STATION
	var result := StationWork.contents(station, _state.clock.total_minutes(), rules)
	if _state.is_inside() and not _state.player.inventory.can_add(result):
		return Result.NO_ROOM
	# The station is empty before the inventory tells of the result, so a listener never sees it
	# in both.
	StationWork.clear(station)
	var side := station.pos + (_state.player.tile() - station.pos).sign()
	var dropped := _exchange_dropping_rest({}, result, side)
	_state.report(ActionOutcome.TAKE_OUT, station.pos, station.type, result)
	return Result.TAKEN_OUT if dropped.is_empty() else Result.DROPPED_OUT


## Takes `paid` out of the inventory and puts `received` in, as one change; what does not fit
## is dropped around `drop_source`. Returns what was dropped (item id to count).
func _exchange_dropping_rest(
	paid: Dictionary, received: Dictionary, drop_source: Vector2i
) -> Dictionary:
	var inventory := _state.player.inventory
	var dropped := {}
	inventory.hold_notifications(
		func() -> void:
			if not paid.is_empty():
				inventory.exchange(paid, {})
			for item: StringName in received:
				var left := inventory.add(item, received[item])
				if left > 0:
					dropped[item] = left
			if not dropped.is_empty():
				_state.world.drop_items(drop_source, dropped)
	)
	return dropped


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
