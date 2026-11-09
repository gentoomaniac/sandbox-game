extends GutTest
## The keys that open the windows: one does nothing while another window is open.


func after_each() -> void:
	get_tree().paused = false


func _window() -> Modal:
	var window := Modal.new()
	add_child_autofree(window)
	return window


func test_a_windows_key_does_nothing_while_another_window_is_open() -> void:
	var first := _window()
	var second := _window()
	assert_true(first.can_open_on_key())
	first.open()
	assert_true(first.can_open_on_key(), "the open window's own key still works")
	assert_false(second.can_open_on_key())
	first.close()
	assert_true(second.can_open_on_key())
