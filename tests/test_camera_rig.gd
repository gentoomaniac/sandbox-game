extends GutTest
## CameraRig: following a target, timed moves and zooms, and sequences of steps.

var _rig := CameraRig.new()
var _target := Vector2.ZERO


func before_each() -> void:
	_rig = CameraRig.new()


func test_follow_jumps_to_the_target_and_tracks_it() -> void:
	_target = Vector2(10, 20)
	_rig.follow(func() -> Vector2: return _target)
	assert_eq(_rig.position, Vector2(10, 20))
	_target = Vector2(30, 40)
	_rig.advance(0.016)
	assert_eq(_rig.position, Vector2(30, 40))


func test_move_takes_its_duration_and_stops_following() -> void:
	_rig.follow(func() -> Vector2: return Vector2.ZERO)
	_rig.move_to(Vector2(100, 0), 2.0)
	_rig.advance(1.0)
	assert_almost_eq(_rig.position.x, 50.0, 0.001)
	assert_true(_rig.is_playing())
	_rig.advance(1.0)
	assert_eq(_rig.position, Vector2(100, 0))
	assert_false(_rig.is_playing())
	_rig.advance(1.0)
	assert_eq(_rig.position, Vector2(100, 0))


func test_zoom_to_is_clamped_and_reaches_its_value() -> void:
	_rig.zoom_to(5.0, 1.0)
	_rig.advance(1.0)
	assert_almost_eq(_rig.zoom, 2.0, 0.0001)


func test_sequence_runs_its_steps_in_order() -> void:
	(
		_rig
		. play_sequence(
			[
				CameraRig.Step.move(Vector2(10, 0), 1.0),
				CameraRig.Step.wait(2.0),
				CameraRig.Step.zoom_to(2.0, 1.0),
			]
		)
	)
	_rig.advance(1.0)
	assert_eq(_rig.position, Vector2(10, 0))
	assert_eq(_rig.zoom, 1.0)
	_rig.advance(2.0)
	assert_eq(_rig.zoom, 1.0)
	assert_true(_rig.is_playing())
	_rig.advance(1.0)
	assert_almost_eq(_rig.zoom, 2.0, 0.0001)
	assert_false(_rig.is_playing())


func test_leftover_time_of_a_frame_goes_to_the_next_step() -> void:
	_rig.play_sequence(
		[CameraRig.Step.move(Vector2(10, 0), 1.0), CameraRig.Step.move(Vector2(10, 10), 1.0)]
	)
	_rig.advance(1.5)
	assert_almost_eq(_rig.position.y, 5.0, 0.001)


func test_sequence_finished_is_emitted_once_after_the_last_step() -> void:
	watch_signals(_rig)
	_rig.play_sequence([CameraRig.Step.wait(1.0), CameraRig.Step.wait(1.0)])
	_rig.advance(1.5)
	assert_signal_not_emitted(_rig, "sequence_finished")
	_rig.advance(1.0)
	assert_signal_emit_count(_rig, "sequence_finished", 1)


func test_wheel_zoom_glides_toward_the_clamped_goal() -> void:
	_rig.zoom_by_wheel(1)
	_rig.advance(0.016)
	assert_between(_rig.zoom, 1.0, 1.1)
	for i in 120:
		_rig.advance(0.016)
	assert_almost_eq(_rig.zoom, 1.1, 0.001)
	_rig.zoom_by_wheel(100)
	for i in 300:
		_rig.advance(0.016)
	assert_almost_eq(_rig.zoom, 2.0, 0.001)


func test_set_zoom_clamped_applies_at_once() -> void:
	_rig.set_zoom_clamped(1.5)
	assert_eq(_rig.zoom, 1.5)
	_rig.set_zoom_clamped(0.1)
	assert_eq(_rig.zoom, ViewMath.MIN_ZOOM)


func test_the_view_rect_is_what_the_window_shows_around_the_camera() -> void:
	var window := Vector2(1280, 720)
	_rig.position = Vector2(100, 50)
	var view := _rig.view_rect(window)
	assert_eq(view.get_center(), Vector2(100, 50))
	assert_eq(view.size, ViewMath.visible_size(window, _rig.zoom))
	_rig.set_zoom_clamped(2.0)
	assert_lt(_rig.view_rect(window).size.x, view.size.x, "zoomed in shows less")
