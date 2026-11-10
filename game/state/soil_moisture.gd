class_name SoilMoisture
extends RefCounted
## How wet the tilled soil of a world is (0 to 1). It changes every hour with the weather (see
## FarmingUpkeep), but a world has tens of thousands of tilled tiles, so no hour visits them all:
## a tile keeps its moisture as of the hour it was last looked at and catches up the hours since
## when it is asked (`at`). The hours' changes are the same for every tile of a region, and
## adding a change and keeping within 0 to 1 compose into one such step however many hours
## there are, so tiles that were last looked at in the same hour share one step per region:
## a month passes in the time of a day. Whatever the order of the questions, a tile has the
## moisture of the weather's hours it has lived through.

## The moisture of tilled soil that nothing has watered or rained on yet (see data/crops.cfg).
var default_moisture: float = CropRules.default_rules().farming("default_moisture")
## How much the moisture of the soil at a tile changes in a game hour (counted from the start of
## day 1), before it is kept within 0 to 1: `func(pos: Vector2i, hour: int) -> float`.
var hourly_change := func(_pos: Vector2i, _hour: int) -> float: return 0.0

var _clock: GameClock
## Per tile: its moisture and the hour that is as of.
var _moisture: Dictionary[Vector2i, float] = {}
var _as_of_hour: Dictionary[Vector2i, int] = {}
## The step from an hour to `_steps_to_hour`, by region and from-hour, filled backwards from
## that hour as far as a tile asks for.
var _steps: Dictionary[Vector3i, Step] = {}
var _earliest_step_hour: Dictionary[Vector2i, int] = {}
var _steps_to_hour := -1


func _init(game_clock: GameClock) -> void:
	_clock = game_clock


## A tile that is not soil, or whose moisture nothing has changed, has the default.
func at(pos: Vector2i) -> float:
	if not _moisture.has(pos):
		return default_moisture
	_catch_up(pos)
	return _moisture[pos]


## Sets the moisture of a tile (kept between 0 and 1) as of now.
func set_at(pos: Vector2i, moisture: float) -> void:
	_moisture[pos] = clampf(moisture, 0.0, 1.0)
	_as_of_hour[pos] = _now()


## A tile that has just become soil starts at the default, and from now on follows the weather.
func start(pos: Vector2i) -> void:
	if not _moisture.has(pos):
		set_at(pos, default_moisture)


## The tiles that have a moisture.
func tiles() -> Array[Vector2i]:
	return _moisture.keys()


## A tile that is soil no more has no moisture to keep: it starts again at the default when it is
## tilled again.
func forget(pos: Vector2i) -> void:
	_moisture.erase(pos)
	_as_of_hour.erase(pos)


## Brings every tile up to now, so that what is saved is as of the save.
func catch_up_all() -> void:
	var now := _now()
	for pos in _moisture:
		if _as_of_hour[pos] != now:
			_catch_up(pos)


func to_array() -> Array[Array]:
	var entries: Array[Array] = []
	for pos in _moisture:
		entries.append(SaveCodec.vector_to_json(pos) + [_moisture[pos]])
	return entries


## Takes a saved entry of `to_array`, as of now.
func load_entry(entry: Array) -> void:
	set_at(SaveCodec.vector_from_json(entry), float(entry[2]))


func _now() -> int:
	return _clock.total_minutes() / GameClock.MINUTES_PER_HOUR


func _catch_up(pos: Vector2i) -> void:
	var now := _now()
	var from: int = _as_of_hour[pos]
	if from == now:
		return
	if from < now:
		_moisture[pos] = _step_between(pos, from, now).apply(_moisture[pos])
	_as_of_hour[pos] = now


func _step_between(pos: Vector2i, from: int, now: int) -> Step:
	if now != _steps_to_hour:
		_steps.clear()
		_earliest_step_hour.clear()
		_steps_to_hour = now
	var region := Weather.region_of(pos)
	var hour: int = _earliest_step_hour.get(region, now)
	while hour > from:
		hour -= 1
		var later: Step = _steps.get(Vector3i(region.x, region.y, hour + 1), Step.new())
		_steps[Vector3i(region.x, region.y, hour)] = later.after_hour(hourly_change.call(pos, hour))
	_earliest_step_hour[region] = hour
	return _steps[Vector3i(region.x, region.y, from)]


## What the hours from one to another do to a moisture: it becomes
## clampf(moisture + change, lowest, highest), as adding a change and keeping within 0 to 1,
## hour after hour, is the same as adding all the changes and keeping within where the last of
## them leaves 0 and 1.
class Step:
	extends RefCounted
	var change := 0.0
	var lowest := 0.0
	var highest := 1.0

	func apply(moisture: float) -> float:
		return clampf(moisture + change, lowest, highest)

	## The step of an hour that comes before these hours, with `hour_change` for its change.
	func after_hour(hour_change: float) -> Step:
		var step := Step.new()
		step.change = hour_change + change
		step.lowest = clampf(change, lowest, highest)
		step.highest = clampf(1.0 + change, lowest, highest)
		return step
