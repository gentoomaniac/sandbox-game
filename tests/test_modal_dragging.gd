extends GutTest
## Dragging a window by its frame: it follows the mouse while the button is held, stays on the
## screen, starts in the middle each time, and only where the content took no click.

const WINDOW := Vector2i(400, 300)


class TestWindow:
	extends Modal
	var rows := VBoxContainer.new()

	func _init(row_count := 0) -> void:
		super()
		var column := VBoxContainer.new()
		var title := Label.new()
		title.text = "Title"
		column.add_child(title)
		column.add_child(rows)
		_panel.add_child(column)
		for i in row_count:
			var row := Button.new()
			row.text = "Row %d" % i
			rows.add_child(row)

	func panel() -> PanelContainer:
		return _panel

	func backdrop() -> ColorRect:
		return _backdrop


var _viewport: SubViewport


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = WINDOW
	add_child_autofree(_viewport)


func _window(row_count := 0) -> TestWindow:
	var window := TestWindow.new(row_count)
	_viewport.add_child(window)
	return window


func _frame_press(window: TestWindow, at: Vector2, on_panel := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.global_position = at
	if on_panel:
		window.panel().gui_input.emit(event)
	else:
		window.backdrop().gui_input.emit(event)


func _mouse_to(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	_viewport.push_input(event)


func _release(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = at
	event.global_position = at
	_viewport.push_input(event)


## Opens a window, lets it settle (its lists fit a frame later) and drags it by `by`, from the
## panel's corner.
func _drag(window: TestWindow, by: Vector2) -> void:
	window.open()
	await wait_process_frames(2)
	var grip := window.panel().global_position + Vector2(2, 2)
	_frame_press(window, grip)
	_mouse_to(grip + by)
	_release(grip + by)


func test_dragging_the_panel_moves_the_window() -> void:
	var window := _window()
	await _drag(window, Vector2(20, -10))
	assert_eq(
		window.panel().get_rect().get_center().round(), Vector2(WINDOW / 2) + Vector2(20, -10)
	)


func test_the_window_follows_the_mouse_only_while_the_button_is_held() -> void:
	var window := _window()
	await _drag(window, Vector2(20, 0))
	var moved_to := window.panel().position
	_mouse_to(Vector2(100, 100))
	assert_eq(window.panel().position, moved_to)


func test_a_drag_that_is_let_go_outside_the_panel_does_not_close_the_window() -> void:
	var window := _window()
	window.open()
	await wait_process_frames(2)
	var grip := window.panel().global_position + Vector2(2, 2)
	_frame_press(window, grip)
	_mouse_to(Vector2(WINDOW) - Vector2.ONE)
	_release(Vector2(WINDOW) - Vector2.ONE)
	assert_true(window.is_open())


func test_dragging_can_be_pressed_on_the_backdrop_over_a_panel_that_lets_clicks_through() -> void:
	var window := _window()
	window.open()
	await wait_process_frames(1)
	var grip := window.panel().global_position + Vector2(2, 2)
	_frame_press(window, grip, false)
	_mouse_to(grip + Vector2(0, 15))
	assert_eq(window.panel().get_rect().get_center().round(), Vector2(WINDOW / 2) + Vector2(0, 15))
	_release(grip)
	_frame_press(window, Vector2(1, 1), false)
	_mouse_to(Vector2(50, 50))
	assert_eq(window.panel().get_rect().get_center().round(), Vector2(WINDOW / 2) + Vector2(0, 15))


func test_a_window_with_is_movable_off_stays_put() -> void:
	var window := _window()
	window.is_movable = false
	await _drag(window, Vector2(20, 20))
	assert_eq(window.panel().get_rect().get_center().round(), Vector2(WINDOW / 2))


func test_the_window_stays_on_the_screen() -> void:
	var window := _window()
	await _drag(window, Vector2(-179, 165))
	var panel_rect := window.panel().get_global_rect()
	assert_eq(panel_rect.position.x, 0.0)
	assert_eq(panel_rect.end.y, float(WINDOW.y))


func test_a_resize_of_the_game_window_brings_a_dragged_window_back_on_screen() -> void:
	var window := _window()
	await _drag(window, Vector2(219, 0))
	_viewport.size = Vector2i(200, 300)
	await wait_process_frames(2)
	var screen := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	assert_true(screen.encloses(window.panel().get_global_rect()))


func test_reopening_puts_the_window_back_in_the_middle() -> void:
	var window := _window()
	await _drag(window, Vector2(20, 20))
	window.close()
	window.open()
	await wait_process_frames(1)
	assert_eq(window.panel().get_rect().get_center().round(), Vector2(WINDOW / 2))


## Presses on `content` with a real mouse event and moves the mouse on with the button held.
func _press_and_pull(content: Control) -> void:
	var inside := content.get_global_rect().get_center()
	_mouse_to(inside)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = inside
	press.global_position = inside
	_viewport.push_input(press)
	var pull := InputEventMouseMotion.new()
	pull.position = inside + Vector2(30, 30)
	pull.global_position = pull.position
	pull.relative = Vector2(30, 30)
	pull.button_mask = MOUSE_BUTTON_MASK_LEFT
	_viewport.push_input(pull)


func _assert_in_the_middle(window: TestWindow) -> void:
	assert_eq(window.panel().get_rect().get_center().round(), Vector2(WINDOW / 2))


func test_a_button_in_the_window_takes_the_press_so_it_does_not_start_a_drag() -> void:
	var window := _window(1)
	window.open()
	await wait_process_frames(2)
	_press_and_pull(window.rows.get_child(0))
	_assert_in_the_middle(window)


func test_a_text_field_takes_the_press_so_it_does_not_start_a_drag() -> void:
	var window := _window()
	var field := LineEdit.new()
	window.rows.add_child(field)
	window.open()
	await wait_process_frames(2)
	_press_and_pull(field)
	_assert_in_the_middle(window)


func test_a_slot_does_its_own_drag_and_does_not_move_the_window() -> void:
	var window := _window()
	var slot := SlotView.new()
	slot.bind_to(Inventory.new(), 0)
	slot.show_stack({"item": ItemTypes.AXE, "count": 1}, false)
	window.rows.add_child(slot)
	window.open()
	await wait_process_frames(2)
	_press_and_pull(slot)
	assert_true(_viewport.gui_is_dragging(), "the stack is being dragged")
	_assert_in_the_middle(window)
