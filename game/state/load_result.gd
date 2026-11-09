class_name LoadResult
extends RefCounted
## What reading a save file came to (see SaveFile `load_game`): nothing to load, a save that is
## refused, one that holds things the game no longer has and waits for the player's answer, or a
## game. It changes no file but for the backup copy of `load_dropping_missing`; moving a refused
## save aside is the caller's (`SaveFile.move_aside`).

enum Outcome {
	## There is no save file.
	NO_SAVE,
	## The save is damaged or of a version we don't read; `reason` says why.
	REFUSED,
	## The save is whole but holds content the game no longer has (`missing`); `state` is built
	## only if the player agrees to load it without (`load_dropping_missing`).
	ASK,
	## `state` is the game.
	READY,
}

## How many problems a text lists before it says how many more there are (see `lines`).
const LINES_SHOWN := 4

var outcome := Outcome.NO_SAVE
var state: GameState
## Why a refused save is refused: every problem, and the first few as text for the player.
var problems: Array[String] = []
var reason := ""
## What the game no longer has (outcome ASK).
var missing: Array[String] = []

## Where the old save is copied to if the player loads it without what is missing (outcome ASK).
var backup_path := ""

## Why the backup copy could not be made, after `load_dropping_missing` gave null.
var copy_error := ""

var _path: String
var _game: Dictionary
var _validator: SaveValidator


static func no_save() -> LoadResult:
	return LoadResult.new()


static func refused(why: Array[String]) -> LoadResult:
	var result := LoadResult.new()
	result.outcome = Outcome.REFUSED
	result.problems = why
	result.reason = lines(why)
	return result


static func ready(game_state: GameState) -> LoadResult:
	var result := LoadResult.new()
	result.outcome = Outcome.READY
	result.state = game_state
	return result


## A save of `game` data that `validator` found whole but for content the game no longer has.
static func asking(game: Dictionary, validator: SaveValidator, path: String) -> LoadResult:
	var result := LoadResult.new()
	result.outcome = Outcome.ASK
	result.missing = validator.missing.duplicate()
	result.backup_path = SaveFile.free_backup_path(path)
	result._path = path
	result._game = game
	result._validator = validator
	return result


## The first of `entries`, one to a line, and how many more there are.
static func lines(entries: Array[String]) -> String:
	var shown := entries.slice(0, LINES_SHOWN)
	if entries.size() > LINES_SHOWN:
		shown.append("and %d more" % (entries.size() - LINES_SHOWN))
	return "\n".join(shown)


## The player agreed: the game without what is missing. Only for outcome ASK. What was missing
## is gone from this game, and from the file only once the game is saved (which it also does by
## itself), so the file is copied to a backup first (`SaveFile.copy_aside`; `backup_path` is where
## it goes). Returns null, and loads nothing, if that copy can't be made.
func load_dropping_missing() -> GameState:
	assert(outcome == Outcome.ASK, "Nothing is missing from this save")
	copy_error = SaveFile.copy_aside(_path, backup_path)
	if copy_error != "":
		return null
	_validator.drop_missing()
	state = GameState.from_dict(_game)
	outcome = Outcome.READY
	return state
