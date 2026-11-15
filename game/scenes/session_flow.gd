class_name SessionFlow
extends Node
## What starts or ends the game being played, in the game scene: the quick save and load keys, the
## load dialog's pick, the pause menu's New game, and the save before quitting. A load or a new
## game starts the whole scene again (see QuickLoadFlow). Main adds it as a child, so that its
## coroutines end with the tree.

## The key of the notification about a save (see NotificationHud).
const SAVE_NOTE := &"save"

## What it needs from Main is set after `new()`.
var state: GameState
var saves: SaveService
var save_path: String
var save_questions: SaveQuestions
var choice_dialog: ChoiceDialog
var load_dialog: LoadDialog
var notifications: NotificationHud
var blackout: BlackoutFlow


## Quits once the game is saved, or the player chose to quit without (see SaveBeforeQuit).
func save_and_quit() -> void:
	if await is_saved_for_quit():
		get_tree().quit()


## Whether quitting may go on: the game is saved, or the player chose to quit without (see
## SaveBeforeQuit). A sleep that is being made up for ends first, the waking included, so that the
## save is of a whole morning.
func is_saved_for_quit() -> bool:
	while blackout.is_making_up_time:
		await get_tree().process_frame
	var saving := SaveBeforeQuit.new(saves, state, save_path, choice_dialog)
	return await saving.is_quit_allowed()


func show_save_result(succeeded: bool) -> void:
	if succeeded:
		notifications.post(SAVE_NOTE, "Saved")
	else:
		notifications.post(SAVE_NOTE, "Could not save the game", NotificationHud.Tone.ERROR)


## F9 saves now, F8 loads; whether it was one of those keys. Both work with a window open too.
## F8 puts the player into the newest save (see QuickLoadFlow).
func quick_save_or_load(event: InputEvent) -> bool:
	if event.is_action_pressed("quick_save"):
		saves.save_in_background(state, save_path, SaveHeader.Kind.QUICK_SAVE)
	elif event.is_action_pressed("quick_load"):
		_quick_load_flow().run_newest(save_path)
	else:
		return false
	return true


## The save picked in the load dialog: after a question about the game now being played, the
## player goes into it. Cancel goes back to the list.
func load_picked(entry: SaveEntry) -> void:
	if await save_questions.is_load_confirmed(entry.header):
		await _quick_load_flow().run(entry.path)
	else:
		load_dialog.open_saves(save_path)


## The pause menu's New game: after a question, the game is saved and a new world starts, the whole
## scene again as for a load. A save that fails keeps the game as it is.
func start_new_game() -> void:
	if not await save_questions.is_new_game_confirmed():
		return
	while blackout.is_making_up_time:
		await get_tree().process_frame
	if not saves.save_and_wait(state, save_path, SaveHeader.Kind.QUICK_SAVE):
		var note := "Not saved, so no new game: %s" % saves.last_error
		notifications.post(QuickLoadFlow.LOAD_NOTE, note, NotificationHud.Tone.ERROR)
		return
	QuickLoad.start_new(GameLoader.new_world())
	if get_tree().reload_current_scene() != OK:
		QuickLoad.take()
		var error := "Can't restart the game"
		notifications.post(QuickLoadFlow.LOAD_NOTE, error, NotificationHud.Tone.ERROR)


func _quick_load_flow() -> QuickLoadFlow:
	return QuickLoadFlow.new(saves, save_questions, notifications, get_tree())
