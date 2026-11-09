class_name SaveBeforeQuit
extends RefCounted
## The save that comes before quitting ("Save and quit", closing the window). When it works the
## game may quit. When it fails the player is asked what to do, and the game quits only if they
## choose to, with a plain word that the progress since the last save is lost: it never quits
## on a failed save by itself.

const TITLE := "The game could not be saved"
const TEXT := (
	"%s\n\nYour last save is still there, but nothing you have done since will be in it. If you"
	+ " quit now, that progress is lost."
)
const TRY_AGAIN := 0
const KEEP_PLAYING := 1
const QUIT_ANYWAY := 2
const CHOICES: Array[String] = [
	"Try saving again",
	"Keep playing",
	"Quit anyway and lose the progress since the last save",
]

var _saves: SaveService
var _state: GameState
var _path: String
var _dialog: ChoiceDialog


func _init(saves: SaveService, state: GameState, path: String, dialog: ChoiceDialog) -> void:
	_saves = saves
	_state = state
	_path = path
	_dialog = dialog


## Saves, asking what to do for as long as it fails. Returns whether the game may quit.
func is_quit_allowed() -> bool:
	while true:
		_saves.save_and_wait(_state, _path)
		if _saves.last_succeeded:
			return true
		_dialog.ask(TITLE, TEXT % _saves.last_error, CHOICES, KEEP_PLAYING)
		var choice: int = await _dialog.answered
		if choice != TRY_AGAIN:
			return choice == QUIT_ANYWAY
	# Not reached: the loop only ends by returning. GDScript wants a return after it.
	return false
