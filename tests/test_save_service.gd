extends GutTest
## Saving in the background: the game of the moment of asking, one save at a time, and waiting
## for the one that runs.

const DIR := "user://test_save_service"
const PATH := DIR + "/world.json"

var _state: GameState
var _service := SaveService.new()


func before_each() -> void:
	_state = GameState.new_game(7)


func after_each() -> void:
	_service.wait()
	DirAccess.remove_absolute(PATH + ".tmp")
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


func test_a_background_save_writes_a_save_that_loads() -> void:
	watch_signals(_service)
	assert_true(_service.save_in_background(_state, PATH))
	assert_true(_service.is_running())
	await wait_for_signal(_service.finished, 5.0)
	assert_false(_service.is_running())
	assert_true(_service.last_succeeded)
	assert_signal_emitted_with_parameters(_service, "finished", [true])
	assert_not_null(SaveFile.read(PATH))


func test_it_saves_the_game_of_the_moment_of_asking() -> void:
	_state.player.position = Vector2(12.5, 9.5)
	_service.save_in_background(_state, PATH)
	_state.player.position = Vector2(30.5, 30.5)
	_service.wait()
	assert_eq(SaveFile.read(PATH).player.position, Vector2(12.5, 9.5))


func test_a_second_request_while_one_runs_is_skipped() -> void:
	assert_true(_service.save_in_background(_state, PATH))
	assert_false(_service.save_in_background(_state, PATH))
	_service.wait()
	assert_true(_service.save_in_background(_state, PATH))


func test_wait_returns_when_the_save_is_done_and_reports_it_once() -> void:
	watch_signals(_service)
	_service.save_in_background(_state, PATH)
	_service.wait()
	assert_false(_service.is_running())
	assert_not_null(SaveFile.read(PATH))
	await wait_frames(3)
	assert_signal_emit_count(_service, "finished", 1)


func test_save_and_wait_waits_for_the_running_save_and_writes_the_game_now() -> void:
	_service.save_in_background(_state, PATH)
	_state.player.position = Vector2(20.5, 20.5)
	assert_true(_service.save_and_wait(_state, PATH))
	assert_false(_service.is_running())
	assert_eq(SaveFile.read(PATH).player.position, Vector2(20.5, 20.5))


func test_a_failing_write_is_reported_and_leaves_the_previous_save() -> void:
	assert_true(_service.save_and_wait(_state, PATH))
	var before := FileAccess.get_file_as_string(PATH)
	# A folder where the temporary file should go: it can't be opened for writing.
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	_state.player.position = Vector2(20.5, 20.5)
	watch_signals(_service)
	_service.save_in_background(_state, PATH)
	_service.wait()
	assert_false(_service.last_succeeded)
	assert_signal_emitted_with_parameters(_service, "finished", [false])
	assert_eq(FileAccess.get_file_as_string(PATH), before)
	assert_string_contains(_service.last_error, "Can't write")
	assert_push_error_count(1)


func test_a_failing_rename_is_reported_and_leaves_nothing_behind() -> void:
	# A folder with something in it where the save should go: nothing can be renamed over it.
	var blocker := PATH.path_join("keep.txt")
	DirAccess.make_dir_recursive_absolute(PATH)
	FileAccess.open(blocker, FileAccess.WRITE).close()
	assert_false(_service.save_and_wait(_state, PATH))
	assert_string_contains(_service.last_error, "Can't replace")
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "the temporary file is removed")
	assert_true(FileAccess.file_exists(blocker))
	assert_push_error_count(1)
	DirAccess.remove_absolute(blocker)
	DirAccess.remove_absolute(PATH)


func test_a_save_that_works_clears_the_last_error() -> void:
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	_service.save_and_wait(_state, PATH)
	DirAccess.remove_absolute(PATH + ".tmp")
	assert_true(_service.save_and_wait(_state, PATH))
	assert_eq(_service.last_error, "")
	assert_push_error_count(1)


func test_the_workers_call_of_a_save_already_waited_for_does_not_end_the_next_one() -> void:
	watch_signals(_service)
	_service.save_in_background(_state, PATH)
	_service.wait()
	_service.save_in_background(_state, PATH)
	await wait_for_signal(_service.finished, 5.0)
	_service.wait()
	await wait_frames(3)
	assert_signal_emit_count(_service, "finished", 2)


## The worker makes the text of the snapshot while the game goes on, so the snapshot must share no
## array or dictionary with the game.
func test_the_snapshot_shares_nothing_with_the_game_that_goes_on() -> void:
	var npc := Npc.create(42, Vector2(3.25, -4.5), _state.npcs.rules)
	npc.add_chat_line(3, 495, true, "hello")
	npc.add_memory("A memory.", 1, MemoryWeight.MEDIUM, 20)
	_state.npcs.add(npc)
	var tree := WorldObject.new(&"oak", Vector2i(2, 2))
	tree.state["damage"] = 1.0
	_state.world.add_chunk(WorldGenerator.new(7).generate_chunk(Vector2i.ZERO))
	_state.world.add_object(tree)

	var before := SaveFile.snapshot(_state)
	var text_before := SaveFile.text_of(before)
	npc.add_chat_line(3, 496, false, "and more")
	npc.add_memory("Another.", 2, MemoryWeight.MEDIUM, 20)
	npc.samples.append("a new line")
	tree.state["damage"] = 5.0

	assert_eq(SaveFile.text_of(before), text_before)


func test_a_save_without_stalling_waits_for_the_running_save_and_saves_the_game_of_then() -> void:
	watch_signals(_service)
	_service.save_in_background(_state, PATH)
	_state.player.position = Vector2(30.5, 30.5)
	_service.save_without_stalling(_state, PATH)
	assert_signal_emit_count(_service, "started", 1, "no second snapshot while one save runs")
	var is_second_done := func() -> bool: return get_signal_emit_count(_service, "finished") == 2
	await wait_until(is_second_done, 5.0)
	assert_eq(get_signal_emit_count(_service, "started"), 2)
	assert_eq(SaveFile.read(PATH).player.position, Vector2(30.5, 30.5))
