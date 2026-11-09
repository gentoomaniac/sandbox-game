extends GutTest
## A window removed from the tree while open is closed as `close()` closes it: its own clean-up
## runs, `closed` is sent and the game runs again.


class CountingWindow:
	extends Modal
	var closed_count := 0

	func _on_close() -> void:
		closed_count += 1


func after_each() -> void:
	get_tree().paused = false


func test_a_window_freed_while_open_runs_its_close_clean_up_once() -> void:
	var window := CountingWindow.new()
	window.pauses_game = true
	add_child(window)
	var closes: Array[int] = []
	window.closed.connect(func() -> void: closes.append(window.closed_count))
	window.open()
	window.free()
	assert_eq(closes, [1] as Array[int], "closed once, after the clean-up")
	assert_false(Modal.is_any_open())
	assert_false(get_tree().paused)


func test_a_window_freed_after_closing_is_not_closed_again() -> void:
	var window := CountingWindow.new()
	add_child(window)
	var closes: Array[int] = []
	window.closed.connect(func() -> void: closes.append(1))
	window.open()
	window.close()
	window.free()
	assert_eq(closes.size(), 1)
