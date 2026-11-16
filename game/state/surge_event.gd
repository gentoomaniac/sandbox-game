class_name SurgeEvent
extends RefCounted
## The storm surge that is coming or running, if any: how high the sea rises and when (see
## design/world/storm-surge.md). SurgeUpkeep decides it from SurgeRoll; the flood that follows
## is FloodState's.

## A surge has been rolled for a high water and will come.
signal coming(level: float, start_minute: int)
## The church bell rings the alarm, told every hour from the warning on (SurgeUpkeep): three
## strokes in the warning, and without a break (`is_continuous`) once the sea runs over the dykes.
## The sound it needs, `church_bell_alarm` (a big bell, tolled), is for the sound designer to make:
## nobody plays it yet.
signal bell_rung(is_continuous: bool)

## How high the water rises over mean high water, in metres; 0 while no surge is expected or
## running.
var level := 0.0
## The game minute of the high water the surge comes with.
var peak_minute := 0
## How long it holds around the high water, in game minutes.
var hold_minutes := 0
## The number of the last high water a surge was rolled for (see SurgeRoll), so it is rolled once.
var last_rolled_tide := -1


## A surge of `new_level` metres is on for the high water at `new_peak_minute`.
func expect(new_level: float, new_peak_minute: int, new_hold_minutes: int) -> void:
	level = new_level
	peak_minute = new_peak_minute
	hold_minutes = new_hold_minutes
	coming.emit(level, start_minute())


## A surge that rises at once and holds for `new_hold_minutes` (the console's).
func start_now(new_level: float, now: int, new_hold_minutes: int) -> void:
	expect(new_level, now + new_hold_minutes / 2, new_hold_minutes)


## No surge is expected or running (it is over, or the console ends it).
func clear() -> void:
	level = 0.0


func has_surge() -> bool:
	return level > 0.0


## The game minute the sea starts to run over the dykes.
func start_minute() -> int:
	return peak_minute - hold_minutes / 2


## The game minute the water falls again.
func end_minute() -> int:
	return peak_minute + hold_minutes / 2


## Whether a surge is rolled and the sea has not risen yet at a game minute.
func is_expected_at(minutes: int) -> bool:
	return has_surge() and minutes < start_minute()


## Whether the sky is stormy at a game minute: from the warning, `warning_hours` before the sea
## rises, until the water falls.
func is_stormy_at(minutes: int) -> bool:
	var warning_minutes := WeatherRules.default_rules().value("surge", "warning_hours") * 60
	return has_surge() and minutes >= start_minute() - warning_minutes and minutes <= end_minute()


## Whether the water stands at its height at a game minute.
func is_holding_at(minutes: int) -> bool:
	return has_surge() and minutes >= start_minute() and minutes <= end_minute()


## The surge as save data, in whole numbers.
func to_dict() -> Dictionary:
	return {
		"level_cm": roundi(level * FloodState.METRES_TO_CM),
		"peak_minute": peak_minute,
		"hold_minutes": hold_minutes,
		"last_rolled_tide": last_rolled_tide,
	}


func load_dict(data: Dictionary) -> void:
	level = int(data["level_cm"]) / FloodState.METRES_TO_CM
	peak_minute = int(data["peak_minute"])
	hold_minutes = int(data["hold_minutes"])
	last_rolled_tide = int(data["last_rolled_tide"])
