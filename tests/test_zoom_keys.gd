extends GutTest
## The zoom keys: CameraController zooms in and out on them, a rebound key included.

var _controller: CameraController


func before_each() -> void:
	# Not added to the tree: its _ready wants the scene's viewport, and the keys need none.
	_controller = autofree(CameraController.new())


func _press(code: Key, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	return event


func _settle() -> void:
	for _frame in 300:
		_controller.rig.advance(0.016)


func test_the_plus_key_zooms_in_and_the_minus_key_out() -> void:
	_controller.rig.set_zoom_clamped(1.0)
	_controller._unhandled_input(_press(KEY_EQUAL))
	_settle()
	assert_gt(_controller.rig.zoom, 1.0)
	var zoomed_in := _controller.rig.zoom
	_controller._unhandled_input(_press(KEY_MINUS))
	_settle()
	assert_lt(_controller.rig.zoom, zoomed_in)


func test_the_keypad_keys_zoom_too() -> void:
	_controller.rig.set_zoom_clamped(1.0)
	_controller._unhandled_input(_press(KEY_KP_ADD))
	_settle()
	assert_gt(_controller.rig.zoom, 1.0)
	_controller._unhandled_input(_press(KEY_KP_SUBTRACT))
	_controller._unhandled_input(_press(KEY_KP_SUBTRACT))
	_settle()
	assert_lt(_controller.rig.zoom, 1.0)


func test_holding_a_key_keeps_zooming_until_the_limit() -> void:
	_controller.rig.set_zoom_clamped(ViewMath.MIN_ZOOM)
	for _repeat in 30:
		_controller._unhandled_input(_press(KEY_EQUAL, true))
	_settle()
	assert_almost_eq(_controller.rig.zoom, ViewMath.MAX_ZOOM, 0.001)
	for _repeat in 60:
		_controller._unhandled_input(_press(KEY_MINUS, true))
	_settle()
	assert_almost_eq(_controller.rig.zoom, ViewMath.MIN_ZOOM, 0.001)


func test_a_sequence_playing_keeps_the_zoom_to_itself() -> void:
	_controller.rig.set_zoom_clamped(1.0)
	_controller.rig.zoom_to(1.0, 5.0)
	_controller._unhandled_input(_press(KEY_EQUAL))
	_settle()
	assert_eq(_controller.rig.zoom, 1.0)
