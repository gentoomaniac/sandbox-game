extends GutTest
## ViewMath: zoom limits, the visible area and whole-pixel camera targets.

const WINDOW := Vector2(1920, 1080)


func test_zoom_is_clamped_to_the_allowed_range() -> void:
	assert_eq(ViewMath.clamp_zoom(0.1), 0.5)
	assert_eq(ViewMath.clamp_zoom(7.0), 2.0)
	assert_eq(ViewMath.clamp_zoom(1.37), 1.37)


func test_wheel_zooms_by_a_factor_per_notch_and_stays_clamped() -> void:
	assert_almost_eq(ViewMath.zoom_after_wheel(1.0, 1), 1.1, 0.0001)
	assert_almost_eq(ViewMath.zoom_after_wheel(1.1, -1), 1.0, 0.0001)
	assert_eq(ViewMath.zoom_after_wheel(1.9, 5), 2.0)
	assert_eq(ViewMath.zoom_after_wheel(0.55, -5), 0.5)


func test_default_view_is_320_by_180_art_pixels_at_1080p() -> void:
	assert_eq(ViewMath.visible_size(WINDOW, 1.0), Vector2(320, 180))
	assert_eq(ViewMath.screen_scale(WINDOW, 1.0), 6.0)


func test_widest_zoom_fills_the_viewport_minus_its_margin() -> void:
	assert_eq(ViewMath.visible_size(WINDOW, 0.5), Vector2(640, 360))


func test_a_wider_window_never_shows_more_than_the_viewport_holds() -> void:
	var ultrawide := Vector2(3440, 1080)
	assert_almost_eq(ViewMath.visible_size(ultrawide, 0.5).x, 640.0, 0.001)


func test_whole_pixel_target_shows_the_viewport_centre() -> void:
	var origin := ViewMath.region_origin(Vector2(100, 50), WINDOW, 1.0)
	assert_eq(origin, Vector2(ViewMath.VIEWPORT_SIZE) / 2.0 - Vector2(160, 90))


func test_fraction_of_the_target_shifts_the_shown_part() -> void:
	var whole := ViewMath.region_origin(Vector2(100, 50), WINDOW, 1.0)
	var shifted := ViewMath.region_origin(Vector2(100.25, 49.75), WINDOW, 1.0)
	assert_eq(shifted - whole, Vector2(0.25, -0.25))


func test_shown_part_stays_inside_the_viewport() -> void:
	var origin := ViewMath.region_origin(Vector2(0.5, 0.5), WINDOW, 0.5)
	var end := origin + ViewMath.visible_size(WINDOW, 0.5)
	assert_true(origin.x >= 0.0 and origin.y >= 0.0)
	assert_true(end.x <= ViewMath.VIEWPORT_SIZE.x and end.y <= ViewMath.VIEWPORT_SIZE.y)


func test_window_centre_is_the_camera_target() -> void:
	var target := Vector2(33.3, -12.7)
	assert_eq(ViewMath.window_to_world(WINDOW / 2.0, WINDOW, target, 1.37), target)


func test_window_and_world_positions_convert_back_and_forth() -> void:
	var target := Vector2(33.3, -12.7)
	for zoom in [0.5, 1.0, 1.37, 2.0]:
		var window_position := Vector2(1234, 321)
		var world := ViewMath.window_to_world(window_position, WINDOW, target, zoom)
		var back := ViewMath.world_to_window(world, WINDOW, target, zoom)
		assert_almost_eq(back, window_position, Vector2(0.001, 0.001))


func test_mouse_position_converts_at_every_ui_scale() -> void:
	# The base UI size is 640x360 (the project's), and a UI scale divides it.
	var target := Vector2(33.3, -12.7)
	for ui_scale in [0.5, 1.0, 2.0]:
		var ui_size: Vector2 = Vector2(640, 360) / ui_scale
		var window_position := ViewMath.ui_to_window(ui_size / 2.0, WINDOW, ui_size)
		assert_eq(window_position, WINDOW / 2.0)
		assert_eq(ViewMath.window_to_world(window_position, WINDOW, target, 1.0), target)
		# A quarter of the way across the UI is a quarter of the way across the window.
		assert_eq(ViewMath.ui_to_window(ui_size / 4.0, WINDOW, ui_size), WINDOW / 4.0)
