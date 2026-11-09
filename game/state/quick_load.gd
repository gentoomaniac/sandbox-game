class_name QuickLoad
extends RefCounted
## The handoff of F8: the game read from the save waits here while the game scene starts again,
## and the new scene takes it (see Main `_quick_load`). A save that holds content the game no
## longer has waits for the player's answer first (`missing`, then `load_dropping_missing` or
## `cancel`).

enum Outcome { NO_SAVE, UNREADABLE, MISSING_CONTENT, READY }

## Where `prepare` moved a save it can't load to ("" if it could not).
static var moved_to := ""

static var _waiting: GameState
static var _asking: LoadResult


## Reads the save at `path` and keeps it for `take`. Nothing is kept for `take` unless the
## outcome is READY. A save that can't be loaded is reported and moved aside (`moved_to`), as at
## the start.
static func prepare(path: String) -> Outcome:
	_waiting = null
	_asking = null
	moved_to = ""
	var result := SaveFile.load_game(path)
	match result.outcome:
		LoadResult.Outcome.NO_SAVE:
			return Outcome.NO_SAVE
		LoadResult.Outcome.REFUSED:
			push_error("Can't load %s: %s" % [path, "; ".join(result.problems)])
			moved_to = SaveFile.move_aside(path)
			return Outcome.UNREADABLE
		LoadResult.Outcome.ASK:
			_asking = result
			return Outcome.MISSING_CONTENT
	_waiting = result.state
	return Outcome.READY


## What the game no longer has, of a save the outcome MISSING_CONTENT waits on.
static func missing() -> Array[String]:
	return _asking.missing


## Where the old save is copied to if the player agrees (see LoadResult `backup_path`).
static func backup_path() -> String:
	return _asking.backup_path


## The player agreed: the game without what is missing is kept for `take`. Returns false, and
## keeps nothing, if the backup copy of the old save could not be made.
static func load_dropping_missing() -> bool:
	_waiting = _asking.load_dropping_missing()
	_asking = null
	return _waiting != null


## The player did not agree: nothing is kept.
static func cancel() -> void:
	_asking = null


## The game that `prepare` kept, or null; it is given only once.
static func take() -> GameState:
	var game := _waiting
	_waiting = null
	return game
