class_name StationWork
extends RefCounted
## The slow craft a station holds: a recipe with `hours` (the kiln's firing, see recipes.cfg) that
## was started there and is done at a game minute (GameClock `total_minutes`). It lives in the
## station's `state`, so it is saved with the station and goes on while the player is away or the
## station's chunk is not loaded: nothing ticks, the clock is only compared with that minute.
## A station holds one at a time.

const KEY := "work"


static func is_busy(station: WorldObject) -> bool:
	return station.state.has(KEY)


## The recipe the station is working on.
static func recipe(station: WorldObject) -> StringName:
	return StringName(station.state[KEY]["recipe"])


## The game minute the work is done.
static func done_minute(station: WorldObject) -> int:
	# Saved as JSON, so it comes back as a float.
	return int(station.state[KEY]["done_minute"])


static func is_done(station: WorldObject, now: int) -> bool:
	return is_busy(station) and now >= done_minute(station)


static func start(station: WorldObject, recipe_id: StringName, done_at: int) -> void:
	assert(not is_busy(station), "The station is busy")
	station.state[KEY] = {"recipe": str(recipe_id), "done_minute": done_at}


static func clear(station: WorldObject) -> void:
	station.state.erase(KEY)


## What the station holds, item id to count: the result once the work is done, before that what
## went in (a kiln taken down while firing gives its load back).
static func contents(station: WorldObject, now: int, rules: RecipeRules) -> Dictionary:
	if not is_busy(station):
		return {}
	var recipe_id := recipe(station)
	if is_done(station, now):
		return {rules.result(recipe_id): rules.count(recipe_id)}
	return rules.materials(recipe_id)
