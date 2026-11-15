class_name WorldWear
extends RefCounted
## The wear of the grass: how often tiles were walked on, and the days of wear that makes (desire
## paths, see design/world/desire-paths.md). The world owns it (`World.wear`) and decides which
## tiles may wear; this only counts.

## The days in a row on which each tile that is worn towards a desire path was walked on enough
## (see `end_day`), by world position. A tile without wear is not here.
var days: Dictionary[Vector2i, int] = {}
## The steps each tile took today (see `add_steps`), by world position; counted at midnight.
var steps_today: Dictionary[Vector2i, float] = {}

## `days` as it was when `days_copy` last made a copy, or null when it has changed since.
var _days_copy: Variant


## A copy of `days` that nobody changes: workers read it while the main thread goes on. Wear days
## change at midnight and when the debug views make worn ground, so the copy is kept until then
## and every snapshot of a day shares it, instead of copying every worn tile each time.
func days_copy() -> Dictionary[Vector2i, int]:
	if _days_copy == null:
		_days_copy = days.duplicate()
	return _days_copy


## Gives a tile `new_days` of wear as it was saved (see `set_days` for the rules of play).
func restore_days(world_pos: Vector2i, saved_days: int) -> void:
	days[world_pos] = saved_days
	_days_copy = null


## Adds `steps` to the steps the tile at `world_pos` took today.
func add_steps(world_pos: Vector2i, steps: float) -> void:
	steps_today[world_pos] = steps_today.get(world_pos, 0.0) + steps


## How worn the grass of a tile is (see PathRules).
func stage_of(world_pos: Vector2i) -> PathRules.Stage:
	return PathRules.default_rules().stage_of(days.get(world_pos, 0))


## Gives a tile `new_days` of wear, as if it had been walked on enough for that many days in a row.
## Returns whether the tile looks different now.
func set_days(world_pos: Vector2i, new_days: int) -> bool:
	_days_copy = null
	var stage := stage_of(world_pos)
	if new_days > 0:
		days[world_pos] = mini(new_days, PathRules.default_rules().most_days())
	else:
		days.erase(world_pos)
	return stage_of(world_pos) != stage


## Takes all wear off a tile, today's steps included. Returns whether it was worn.
func forget(world_pos: Vector2i) -> bool:
	steps_today.erase(world_pos)
	_days_copy = null
	return days.erase(world_pos)


## The day that has just ended counts for every tile that was walked on: a busy day adds a day of
## wear, any other takes some off, and a tile whose days are used up is grass again. Returns the
## tiles that look different now.
func end_day() -> Array[Vector2i]:
	var rules := PathRules.default_rules()
	_days_copy = null
	var walked := steps_today
	steps_today = {}
	var tiles := days.keys()
	for pos: Vector2i in walked:
		if not days.has(pos):
			tiles.append(pos)
	var changed: Array[Vector2i] = []
	for pos: Vector2i in tiles:
		var days_before: int = days.get(pos, 0)
		var days_after := days_before - rules.quiet_day_loss()
		if walked.get(pos, 0.0) >= rules.busy_steps():
			days_after = mini(days_before + 1, rules.most_days())
		if days_after > 0:
			days[pos] = days_after
		else:
			days.erase(pos)
		if rules.stage_of(days_after) != rules.stage_of(days_before):
			changed.append(pos)
	return changed


## Wears the `tiles` that `is_free_to_wear(tile)` accepts to the most there is, as if they were
## walked on every day (the lanes and the square of the village, which do not grow back). Returns
## the tiles that look different now.
func keep_worn(tiles: Array[Vector2i], is_free_to_wear: Callable) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	var most_days := PathRules.default_rules().most_days()
	for pos in tiles:
		if is_free_to_wear.call(pos) and set_days(pos, most_days):
			changed.append(pos)
	return changed
