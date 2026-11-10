extends GutTest
## Sleeping in a bed (Main): the game is saved in the background under the black screen, as when
## passing out: the sleep and the snapshot a frame apart, the write on a worker.

const MAIN_SCENE := preload("res://game/scenes/main.tscn")
const SETTLE_SECONDS := 30.0
const SLEEP_SECONDS := 10.0

var _main: Node


func before_each() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await wait_until(
		func() -> bool: return _main._view != null and _main._view.is_settled, SETTLE_SECONDS
	)


func after_each() -> void:
	_main._saves.wait()
	get_tree().auto_accept_quit = true
	_main.free()


func test_the_save_of_a_sleep_is_a_background_save_of_the_new_day_under_the_black_screen() -> void:
	var saves: SaveService = _main._saves
	var state: GameState = _main._state
	var was_black_at_start: Array[bool] = []
	var frames_of_sleep: Array[int] = []
	var frames_of_snapshot: Array[int] = []
	state.simulation.skipped.connect(
		func(_minutes: int) -> void: frames_of_sleep.append(Engine.get_process_frames())
	)
	saves.started.connect(
		func() -> void:
			was_black_at_start.append(_main._fade_screen.is_black())
			frames_of_snapshot.append(Engine.get_process_frames())
	)
	state.clock.set_time(22, 0)
	state.player.position = Vector2(state.player.home_bed) + Vector2(0.5, 0.5)
	var day_before := state.clock.day

	_main._try_sleep()
	await wait_until(func() -> bool: return not was_black_at_start.is_empty(), SLEEP_SECONDS)
	await wait_until(func() -> bool: return not _main._is_in_transition, SLEEP_SECONDS)

	assert_eq(was_black_at_start, [true] as Array[bool], "one save, begun on the black")
	assert_gt(frames_of_snapshot[0], frames_of_sleep[0], "the snapshot is a frame after the sleep")
	assert_true(saves.last_succeeded)
	assert_eq(state.clock.day, day_before + 1)
	assert_eq(SaveFile.read(_main._options.save_path).clock.day, day_before + 1)
