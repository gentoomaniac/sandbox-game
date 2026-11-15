class_name QuickLoadFlow
extends RefCounted
## What F8 does in the game scene: puts the player into the newest save, without asking (but for a
## save that holds content the game no longer has: then the player decides, and Cancel keeps the
## game they are in). The whole scene starts again from it, which leaves no view, window or paused
## state of the game before behind. Waits for a save that runs, so the file read is the newest.
## The handoff of the loaded game is QuickLoad.

## The key of the notification about a load (see NotificationHud).
const LOAD_NOTE := &"load"

var _saves: SaveService
var _save_questions: SaveQuestions
var _notifications: NotificationHud
var _tree: SceneTree


func _init(
	saves: SaveService,
	save_questions: SaveQuestions,
	notifications: NotificationHud,
	tree: SceneTree
) -> void:
	_saves = saves
	_save_questions = save_questions
	_notifications = notifications
	_tree = tree


## Loads the newest save of the world at `base`.
func run_newest(base: String) -> void:
	_saves.wait()
	await run(SaveList.newest_path(base))


## Loads the save in the file `save_path`.
func run(save_path: String) -> void:
	_saves.wait()
	var outcome := QuickLoad.prepare(save_path)
	if outcome == QuickLoad.Outcome.MISSING_CONTENT:
		if not await _save_questions.is_missing_content_loaded(
			QuickLoad.missing(), QuickLoad.backup_path(), "Cancel"
		):
			QuickLoad.cancel()
			return
		if not QuickLoad.load_dropping_missing():
			_notifications.post(
				LOAD_NOTE, "Can't keep a copy of the save", NotificationHud.Tone.ERROR
			)
			return
		outcome = QuickLoad.Outcome.READY
	match outcome:
		QuickLoad.Outcome.NO_SAVE:
			_notifications.post(LOAD_NOTE, "No save to load")
		QuickLoad.Outcome.UNREADABLE:
			var note := "The save can't be loaded"
			if QuickLoad.moved_to != "":
				note += ": moved to %s" % QuickLoad.moved_to.get_file()
			_notifications.post(LOAD_NOTE, note, NotificationHud.Tone.ERROR)
		QuickLoad.Outcome.READY:
			if _tree.reload_current_scene() != OK:
				QuickLoad.take()
				_notifications.post(LOAD_NOTE, "Can't restart the game", NotificationHud.Tone.ERROR)
