class_name BlackoutFlow
extends Node
## The things that fade the game screen to black while the world changes under it: a door, a sleep
## in a bed, and passing out. While one runs the player neither walks nor acts (`is_in_transition`),
## and no window, console command or drag gets through it. The sleep and the pass-out make up for
## their time over frames, with the world held (`is_making_up_time`), and save under the black.
## Main adds it as a child (its coroutines end with the tree) and reads the two flags.

## A fade (a door, sleep) or passing out is running.
var is_in_transition := false
## The time of a sleep is being made up for over some frames (see Simulation `skip_over_frames`),
## up to the player's waking: the world is held, and quitting waits (see `_hold_world`).
var is_making_up_time := false

## What it needs from Main is set after `new()`.
var state: GameState
var view: WorldView
var residency: ChunkResidency
var player_view: PlayerView
var console_view: ConsoleView
var fade_screen: FadeScreen
var saves: SaveService
var save_path: String
## Main's `_show_current_map` and `_show_clock`, as `func()`.
var show_current_map: Callable
var show_clock: Callable


## Fades to black, runs `change` while the screen is black (it may await), and fades back in. A
## `change` that returns text has it shown on the black for a moment first.
func fade_through(change: Callable) -> void:
	is_in_transition = true
	# No command runs during a fade: a teleport would meet a door half way through. No window or
	# drag goes through a door or a sleep.
	console_view.close()
	Modal.close_open()
	get_viewport().gui_cancel_drag()
	await fade_screen.fade_out()
	var note: Variant = await change.call()
	if note is String:
		await fade_screen.show_note(note)
	await fade_screen.fade_in()
	is_in_transition = false


## Out of energy or up too late: the player collapses where they stand (the world keeps
## running), the screen goes black, and a message says what happened until a key or a click.
## Then they wake in their home bed (see GameState `pass_out`).
func pass_out() -> void:
	is_in_transition = true
	# Nothing else may move the player meanwhile.
	Modal.close_open()
	console_view.close()
	# They slide off the horse first, if there is room beside it; else they collapse in the saddle.
	if state.player.horse != null:
		state.dismount()
	var was_up_too_late := state.is_up_too_late
	player_view.collapse()
	await get_tree().create_timer(PlayerView.COLLAPSE_SECONDS).timeout
	await fade_screen.fade_out()
	_hold_world(true)
	var minutes_slept: int = await state.pass_out_over_frames(_next_frame)
	_hold_world(false)
	player_view.stand_up()
	show_current_map.call()
	# The sleep takes some frames and the save one, under the black screen.
	await get_tree().process_frame
	await saves.save_without_stalling(state, save_path)
	await fade_screen.show_message(PassOutMessage.text(state, was_up_too_late, minutes_slept))
	await fade_screen.fade_in()
	is_in_transition = false


## Sleeps in the bed in reach until the morning, and saves: the new day shows on the black for a
## moment. As when passing out, the sleep takes some frames and the save one, under the black
## screen.
func try_sleep() -> void:
	var bed := state.bed_in_reach()
	if bed == null:
		return
	fade_through(
		func() -> String:
			_hold_world(true)
			await state.sleep_in_over_frames(bed, _next_frame)
			_hold_world(false)
			show_clock.call()
			await get_tree().process_frame
			await saves.save_without_stalling(state, save_path)
			return state.clock.date_text()
	)


## Holds everything that changes the world by itself while the time of a sleep is made up for
## over frames, or lets it go: the views (the wildlife) and the animals (their hunts too) and
## villagers of the state; `_process` doesn't stream chunks meanwhile, and the residency's own
## streaming (`update`) is held as well, a guard for anything else that would call it
## (`require` still loads what an action needs). So the world is the one a skip in one go would
## have, and the game is not saved or quit half way (see Main `_is_saved_for_quit`).
func _hold_world(is_held: bool) -> void:
	is_making_up_time = is_held
	residency.is_held = is_held or state.is_inside()
	view.process_mode = (
		Node.PROCESS_MODE_DISABLED if is_held or state.is_inside() else Node.PROCESS_MODE_INHERIT
	)


## The signal of the next frame, for the work that is spread over frames.
func _next_frame() -> Signal:
	return get_tree().process_frame
