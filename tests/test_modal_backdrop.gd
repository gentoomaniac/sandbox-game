extends GutTest
## A left click on the dimmed area outside a window's panel does what Escape does there.

const WINDOW := Vector2i(400, 300)


class TestWindow:
	extends Modal
	var escapes_taken := 0
	var is_taking_escape := false

	func _init() -> void:
		super()
		var title := Label.new()
		title.text = "Title"
		_panel.add_child(title)

	func _takes_escape() -> bool:
		escapes_taken += 1
		return is_taking_escape

	func panel() -> PanelContainer:
		return _panel

	func backdrop() -> ColorRect:
		return _backdrop


var _viewport: SubViewport


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = WINDOW
	add_child_autofree(_viewport)


func _window() -> TestWindow:
	var window := TestWindow.new()
	_viewport.add_child(window)
	return window


## A press of `button` on the backdrop at `at`; by default in a corner, outside the panel.
func _press_backdrop(window: TestWindow, button := MOUSE_BUTTON_LEFT, at := Vector2.ONE) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.global_position = at
	window.backdrop().gui_input.emit(event)


func test_a_click_outside_the_panel_closes_the_window() -> void:
	var window := _window()
	window.open()
	await wait_process_frames(1)
	_press_backdrop(window)
	assert_false(window.is_open())


func test_a_click_outside_the_panel_goes_through_the_escape_hook() -> void:
	var window := _window()
	window.is_taking_escape = true
	window.open()
	await wait_process_frames(1)
	_press_backdrop(window)
	assert_true(window.is_open())
	assert_eq(window.escapes_taken, 1)
	window.is_taking_escape = false
	_press_backdrop(window)
	assert_false(window.is_open())


func test_a_click_on_the_panel_that_reaches_the_backdrop_does_not_close() -> void:
	var window := _window()
	window.open()
	await wait_process_frames(1)
	_press_backdrop(window, MOUSE_BUTTON_LEFT, window.panel().get_global_rect().get_center())
	assert_true(window.is_open())
	assert_eq(window.escapes_taken, 0)


func test_another_mouse_button_does_not_close() -> void:
	var window := _window()
	window.open()
	await wait_process_frames(1)
	_press_backdrop(window, MOUSE_BUTTON_RIGHT)
	assert_true(window.is_open())
