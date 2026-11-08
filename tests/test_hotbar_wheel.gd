extends GutTest
## The mouse wheel steps through the hotbar (Main): a notch is a slot each way, a touchpad's small
## turns count for less, and Ctrl leaves the wheel to the zoom.

const MAIN := preload("res://game/scenes/main.gd")


func _wheel(down: bool, factor: float, ctrl := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	event.factor = factor
	event.ctrl_pressed = ctrl
	return event


func test_a_notch_is_one_slot_each_way() -> void:
	assert_eq(MAIN._wheel_turn(_wheel(true, 1.0)), 1.0)
	assert_eq(MAIN._wheel_turn(_wheel(false, 1.0)), -1.0)
	assert_eq(MAIN._wheel_turn(_wheel(true, 0.0)), 1.0, "a wheel that reports no factor")


func test_a_touchpad_s_small_turns_count_for_less() -> void:
	assert_almost_eq(MAIN._wheel_turn(_wheel(false, 0.3)), -0.3, 0.0001)


func test_ctrl_leaves_the_wheel_to_the_zoom() -> void:
	assert_false(MAIN._is_hotbar_wheel(_wheel(true, 1.0, true)))
	assert_true(MAIN._is_hotbar_wheel(_wheel(true, 1.0)))


func test_turns_add_up_to_whole_slots() -> void:
	var progress := 0.0
	for _i in 10:
		progress = MAIN._wheel_turned(progress, 0.1)
	assert_eq(MAIN._whole_slots(progress), 1, "ten turns of 0.1 are one slot")
	assert_eq(MAIN._whole_slots(MAIN._wheel_turned(0.6, 1.0)), 1, "0.6 left and a notch")


func test_a_notch_the_other_way_drops_what_is_left() -> void:
	var progress: float = MAIN._wheel_turned(0.6, -1.0)
	assert_eq(MAIN._whole_slots(progress), -1, "a whole slot back, not none")
