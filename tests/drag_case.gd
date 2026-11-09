class_name DragCase
extends GutTest
## Helpers for tests that drag stacks between inventory slots with real mouse events pushed into a
## viewport of the game's size of its own, so they need no window.

var _window: SubViewport


func _make_window() -> void:
	_window = SubViewport.new()
	_window.size = Vector2i(640, 360)
	add_child_autofree(_window)


func _centre_of(view: Control) -> Vector2:
	return view.get_global_rect().get_center()


func _press(position: Vector2, button := MOUSE_BUTTON_LEFT, is_shift_held := false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	_window.push_input(motion)
	_push_button(position, button, true, is_shift_held)


func _release(position: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	_push_button(position, button, false, false)


func _click(position: Vector2, button := MOUSE_BUTTON_LEFT, is_shift_held := false) -> void:
	_press(position, button, is_shift_held)
	_release(position, button)


## Presses on `from`, moves the mouse well past the drag threshold, then on to `to`.
func _drag_to(from: Vector2, to: Vector2) -> void:
	_press(from)
	_move_held(from, from + Vector2(20, 20))
	_move_held(from + Vector2(20, 20), to)


func _move_held(from: Vector2, to: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.relative = to - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_window.push_input(motion)


## A whole drag, the button let go over `to`.
func _drag(from: Vector2, to: Vector2) -> void:
	_drag_to(from, to)
	_release(to)


func _push_button(position: Vector2, button: MouseButton, is_pressed: bool, is_shift: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = is_pressed
	event.position = position
	event.shift_pressed = is_shift
	_window.push_input(event)
