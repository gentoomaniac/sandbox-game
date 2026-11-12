extends GutTest
## The close button in a window's corner does what Escape does there, and takes no part in the
## window drag.

const WINDOW := Vector2i(400, 300)


class TestWindow:
	extends Modal
	var escapes_taken := 0
	var is_taking_escape := false

	func _init() -> void:
		super()
		var title := Label.new()
		title.text = "A title long enough to give the panel some width"
		_panel.add_child(title)

	func _takes_escape() -> bool:
		escapes_taken += 1
		return is_taking_escape

	func panel() -> PanelContainer:
		return _panel

	func close_button() -> TextureButton:
		return _close_button


var _viewport: SubViewport


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = WINDOW
	add_child_autofree(_viewport)


func _open_window() -> TestWindow:
	var window := TestWindow.new()
	_viewport.add_child(window)
	window.open()
	await wait_process_frames(2)
	return window


func _mouse(at: Vector2, is_pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = is_pressed
	event.position = at
	event.global_position = at
	_viewport.push_input(event)


func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	_mouse(at, true)
	_mouse(at, false)


func test_the_button_sits_in_the_top_right_corner_of_the_panel() -> void:
	var window := await _open_window()
	var panel := window.panel().get_global_rect()
	var button := window.close_button().get_global_rect()
	assert_true(panel.encloses(button))
	assert_lt(button.position.y - panel.position.y, 10.0)
	assert_lt(panel.end.x - button.end.x, 10.0)


func test_the_button_follows_the_panel_when_the_window_is_dragged() -> void:
	var window := await _open_window()
	window._drag_shift += Vector2(20, 10)
	window._apply_drag_shift()
	var panel := window.panel().get_global_rect()
	assert_true(panel.encloses(window.close_button().get_global_rect()))
	assert_lt(window.close_button().get_global_rect().position.y - panel.position.y, 10.0)


func test_the_button_closes_the_window() -> void:
	var window := await _open_window()
	_click(window.close_button())
	assert_false(window.is_open())


func test_the_button_goes_through_the_escape_hook() -> void:
	var window := await _open_window()
	window.is_taking_escape = true
	_click(window.close_button())
	assert_true(window.is_open())
	assert_eq(window.escapes_taken, 1)
	window.is_taking_escape = false
	_click(window.close_button())
	assert_false(window.is_open())


func test_pressing_the_button_does_not_start_a_drag() -> void:
	var window := await _open_window()
	window.is_taking_escape = true
	var at := window.close_button().get_global_rect().get_center()
	_mouse(at, true)
	var pull := InputEventMouseMotion.new()
	pull.position = at + Vector2(30, 30)
	pull.global_position = pull.position
	pull.relative = Vector2(30, 30)
	pull.button_mask = MOUSE_BUTTON_MASK_LEFT
	_viewport.push_input(pull)
	assert_eq(window.panel().get_rect().get_center().round(), Vector2(WINDOW / 2))
