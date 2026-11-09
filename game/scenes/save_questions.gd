class_name SaveQuestions
extends RefCounted
## What the player is told and asked about a save they load, in a ChoiceDialog: that a save is
## refused, and whether to load one without the content the game no longer has.

const REFUSED_TEXT := (
	"%s\n\nThe file was moved to %s and is not changed. A new game starts, and the next save"
	+ " makes a new save file."
)
const REFUSED_NOT_MOVED_TEXT := (
	"%s\n\nThe file could not be moved away, so the next save replaces it." + " A new game starts."
)
const MISSING_CONTENT_TEXT := (
	"These are not in the game any more:\n%s\n\nYou can load the save anyway: they are left out."
	+ " Playing on may run into problems. The save file only changes when the game next saves"
	+ " (it also does that by itself); a copy of the old save is kept as %s."
)

var _dialog: ChoiceDialog


func _init(dialog: ChoiceDialog) -> void:
	_dialog = dialog


## Says why a save is refused (`reason`) and where it was moved ("" if it could not be moved), and
## returns when the player has read it.
func tell_refused(reason: String, moved_to: String) -> void:
	var text := (
		REFUSED_TEXT % [reason, moved_to.get_file()]
		if moved_to != ""
		else REFUSED_NOT_MOVED_TEXT % reason
	)
	_dialog.ask("The save can't be loaded", text, ["Start a new game"] as Array[String], 0)
	await _dialog.answered


## Asks whether to load a save without the content the game no longer has (`missing`), and
## returns whether the player said yes. `backup_path` is where the old save is copied to then.
## `cancel_text` is the other button; it is the safe one.
func is_missing_content_loaded(
	missing: Array[String], backup_path: String, cancel_text: String
) -> bool:
	_dialog.ask(
		"The save has things the game no longer has",
		MISSING_CONTENT_TEXT % [LoadResult.lines(missing), backup_path.get_file()],
		["Load anyway, dropping what is missing", cancel_text] as Array[String],
		1
	)
	var choice: int = await _dialog.answered
	return choice == 0


## Says that a save was not loaded because the copy of the old save could not be made (`error`),
## and returns when the player has read it. The file is untouched.
func tell_copy_failed(error: String) -> void:
	var text := "The copy of the old save could not be made (%s), so the save was not loaded."
	_dialog.ask(
		"The save was not loaded",
		text % error + " The file is untouched.",
		["Quit the game"] as Array[String],
		0
	)
	await _dialog.answered
