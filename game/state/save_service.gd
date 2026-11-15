class_name SaveService
extends RefCounted
## Saves the game without freezing it. A save takes a snapshot of the game at once (on the main
## thread, so it is the game of that moment) and makes its text and writes it on a worker thread,
## as a new save, through a temporary file that is then renamed (see SaveFile `store`). Only one
## save runs at a time: asking for another while one runs is skipped, not queued, as the one
## running holds the game of a moment ago and the next timed or quick save follows soon. Whoever
## must not lose a save (quitting, loading) calls `wait` or `save_and_wait`.

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
## What the worker's write came to (see SaveFile `store`), read after it is done.
var _write_error := ""


func is_running() -> bool:
	return _task_id != -1


## Starts saving `state` as a new save of the world at `base`, made by `kind`, and returns at once.
## Returns false, doing nothing, while a save is running.
func save_in_background(state: GameState, base: String, kind: SaveHeader.Kind) -> bool:
	if is_running():
		return false
	started.emit()
	_save_number += 1
	var header := SaveHeader.of(state, kind)
	_task_id = WorkerThreadPool.add_task(
		_write.bind(SaveFile.snapshot(state), header, base, _save_number)
	)
	return true


## Saves `state` before returning, after the save that is running, if any. Returns whether it was
## written.
func save_and_wait(state: GameState, base: String, kind: SaveHeader.Kind) -> bool:
	wait()
	started.emit()
	_end_with(SaveFile.store(SaveFile.encode(state), SaveHeader.of(state, kind), base))
	return last_succeeded


## Returns when the game of now is saved, for a moment when nothing else runs (under a fade). The
## main thread only takes the snapshot, in a frame of its own: a save that is still running is
## waited for first, not joined by blocking.
func save_without_stalling(state: GameState, base: String, kind: SaveHeader.Kind) -> void:
	if is_running():
		await finished
	save_in_background(state, base, kind)
	await finished


## Returns when no save is running.
func wait() -> void:
	if is_running():
		_finish()


## Runs on the worker; tells the main thread when it is done.
func _write(snapshot: Dictionary, header: SaveHeader, base: String, save_number: int) -> void:
	_write_error = SaveFile.store(SaveFile.text_of(snapshot), header, base)
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
