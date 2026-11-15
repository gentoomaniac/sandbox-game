class_name GameLoader
extends RefCounted
## Where the game of a run comes from when the game scene starts: the one F8 or the New game button
## has just made, else the newest save that can be loaded, else a new world.

const WORLD_SEED := 1

var _options: StartupOptions
var _save_questions: SaveQuestions


func _init(options: StartupOptions, save_questions: SaveQuestions) -> void:
	_options = options
	_save_questions = save_questions


static func new_world() -> GameState:
	return GameState.new_game(WORLD_SEED, true)


## `resumed_state` is the game a quick load or a new game has handed over (see QuickLoad), or null.
## Else the newest save that can be loaded, or a new game if there is none or `--new-game` is
## given. A save that is refused is moved aside, the player is told, and the save before it is
## tried. A save that holds content the game no longer has is up to the player: null if they
## cancel (the game then quits, with the file as it was).
func load_or_start(resumed_state: GameState) -> GameState:
	if resumed_state != null:
		return resumed_state
	if _options.new_game:
		return new_world()
	var paths := SaveList.paths_newest_first(_options.save_path)
	for index in paths.size():
		var loaded := SaveFile.load_game(paths[index])
		match loaded.outcome:
			LoadResult.Outcome.READY:
				return loaded.state
			LoadResult.Outcome.REFUSED:
				push_error("Can't load %s: %s" % [paths[index], "; ".join(loaded.problems)])
				var moved_to := SaveFile.move_aside(paths[index])
				var has_older_save := index < paths.size() - 1
				await _save_questions.tell_refused(loaded.reason, moved_to, has_older_save)
			LoadResult.Outcome.ASK:
				if await _save_questions.is_missing_content_loaded(
					loaded.missing, loaded.backup_path, "Cancel and quit the game"
				):
					var dropped := loaded.load_dropping_missing()
					if dropped == null:
						await _save_questions.tell_copy_failed(loaded.copy_error)
					return dropped
				return null
	return new_world()
