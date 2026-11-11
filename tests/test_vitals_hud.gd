extends GutTest
## The energy and health bars sit in the top right corner, whatever the window size or UI scale,
## clear of the notifications at the top left, and the coordinates start below them.

const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(640, 360), Vector2i(320, 180)]


func _window_of(window_size: Vector2i) -> SubViewport:
	var window := SubViewport.new()
	window.size = window_size
	add_child_autofree(window)
	return window


func _hud_in(window: SubViewport) -> VitalsHud:
	var hud := VitalsHud.new()
	hud.show_state(GameState.new_game(7))
	window.add_child(hud)
	return hud


func _column_of(hud: VitalsHud) -> Control:
	return hud.find_children("*", "VBoxContainer", true, false)[0]


func test_the_bars_touch_the_top_right_corner_at_every_window_size() -> void:
	for window_size in WINDOW_SIZES:
		var bars := _column_of(_hud_in(_window_of(window_size))).get_rect()
		assert_eq(
			bars.end.x, float(window_size.x - VitalsHud.MARGIN), "right edge at %s" % window_size
		)
		assert_eq(bars.position.y, float(VitalsHud.MARGIN), "top edge at %s" % window_size)
		assert_eq(bars.end.y, float(VitalsHud.BOTTOM), "bottom edge at %s" % window_size)


func test_the_bars_stay_in_the_corner_when_the_window_is_resized() -> void:
	var window := _window_of(Vector2i(640, 360))
	var column := _column_of(_hud_in(window))
	window.size = Vector2i(1000, 500)
	await wait_process_frames(2)
	assert_eq(column.get_rect().end.x, 1000.0 - VitalsHud.MARGIN)


func test_a_wider_row_keeps_the_right_edge() -> void:
	var column := _column_of(_hud_in(_window_of(Vector2i(640, 360))))
	var right_edge := column.get_rect().end.x
	column.custom_minimum_size.x = column.size.x + 20
	await wait_process_frames(2)
	assert_eq(column.get_rect().end.x, right_edge)


func test_the_bars_do_not_cover_the_notifications() -> void:
	for window_size in WINDOW_SIZES:
		var window := _window_of(window_size)
		var bars := _column_of(_hud_in(window)).get_rect()
		var notifications := NotificationHud.new()
		window.add_child(notifications)
		for key in [&"a", &"b", &"c", &"d"]:
			notifications.post(key, "Saving the game now")
		await wait_process_frames(2)
		var lines: Control = notifications.find_children("*", "VBoxContainer", true, false)[0]
		assert_false(bars.intersects(lines.get_rect()), "overlap at %s" % window_size)
