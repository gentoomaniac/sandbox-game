class_name SaveService
extends RefCounted
## Saves the game without freezing it. A save takes the game's text at once (on the main thread,
## so it is the game of that moment) and writes it on a worker thread, to the temporary file that
## is then renamed (see SaveFile). Only one save runs at a time: asking for another while one runs
## is skipped, not queued, as the one running holds the game of a moment ago and the next timed
## or quick save follows soon. Whoever must not lose a save (quitting, loading) calls `wait`
## or `save_and_wait`.

## A save began (also one that `save_and_wait` writes at once).
signal started
## A save ended, written or not. `last_succeeded` has the result.
signal finished(succeeded: bool)

## Whether the last save that ended was written; true before any. It is what the question about a
## failed save on quit reads (see SaveBeforeQuit).
var last_succeeded := true
## What went wrong in the last save that failed, for the player to read; "" if it did not.
var last_error := ""

var _task_id := -1
## Counts the saves, so that the worker's call of a save already joined by `wait` does not
## end the next one.
var _save_number := 0
## What the worker's write came to (see SaveFile `write_text`), read after it is done.
var _write_error := ""


func is_running() -> bool:
	return _task_id != -1


## Starts saving `state` to `path` and returns at once. Returns false, doing nothing, while a
## save is running.
func save_in_background(state: GameState, path: String) -> bool:
	if is_running():
		return false
	started.emit()
	_save_number += 1
	_task_id = WorkerThreadPool.add_task(_write.bind(SaveFile.encode(state), path, _save_number))
	return true


## Saves `state` to `path` before returning, after the save that is running, if any. Returns
## whether it was written.
func save_and_wait(state: GameState, path: String) -> bool:
	wait()
	started.emit()
	_end_with(SaveFile.write_text(SaveFile.encode(state), path))
	return last_succeeded


## Returns when no save is running.
func wait() -> void:
	if is_running():
		_finish()


## Runs on the worker; tells the main thread when it is done.
func _write(text: String, path: String, save_number: int) -> void:
	_write_error = SaveFile.write_text(text, path)
	_finish_save.call_deferred(save_number)


## The worker's call: ends the save `save_number` unless `wait` has done so already.
func _finish_save(save_number: int) -> void:
	if save_number == _save_number:
		wait()


## Runs on the main thread, once per save.
func _finish() -> void:
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	_end_with(_write_error)


## Records how the save came out (`error` is "" for a written one) and tells whoever listens.
func _end_with(error: String) -> void:
	last_error = error
	last_succeeded = error == ""
	finished.emit(last_succeeded)
