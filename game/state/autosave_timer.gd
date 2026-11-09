class_name AutosaveTimer
extends RefCounted
## Counts the seconds of play since the last save, to tell when the next timed autosave is due.
## Whoever ticks it decides what counts: Main ticks it every frame, which does not run while a
## window pauses the game. Once due, it stays due until `restart`, so a save held back by a fade
## or an open window happens at the next safe moment.

var _seconds := 0.0


func tick(delta: float) -> void:
	_seconds += delta


func is_due(interval_minutes: int) -> bool:
	return _seconds >= interval_minutes * 60.0


## Called when any save starts: a quick save or a sleep puts the next timed one off.
func restart() -> void:
	_seconds = 0.0
