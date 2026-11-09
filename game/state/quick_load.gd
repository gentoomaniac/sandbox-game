class_name QuickLoad
extends RefCounted
## The handoff of F8: the game read from the save waits here while the game scene starts again,
## and the new scene takes it (see Main `_quick_load`).

enum Outcome { NO_SAVE, UNREADABLE, READY }

static var _waiting: GameState


## Reads the save at `path` and keeps it for `take`. Nothing is kept unless the outcome is READY.
static func prepare(path: String) -> Outcome:
	_waiting = null
	if not FileAccess.file_exists(path):
		return Outcome.NO_SAVE
	_waiting = SaveFile.read(path)
	return Outcome.READY if _waiting != null else Outcome.UNREADABLE


## The game that `prepare` kept, or null; it is given only once.
static func take() -> GameState:
	var game := _waiting
	_waiting = null
	return game
