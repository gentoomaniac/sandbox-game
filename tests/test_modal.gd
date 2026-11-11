extends GutTest
## The base of the windows: opening and closing, one window at a time, Escape and the hook that
## takes it first, the pause flag, a click on the backdrop, the panel's centring and the lists' fit.

const WINDOW := Vector2i(400, 300)


## A window with a label as its contents, and a growing part of `row_count` rows if asked for.
class TestWindow:
	extends Modal
	var escapes_taken := 0
	var is_taking_escape := false
	var opened_count := 0
	var growing_rows := VBoxContainer.new()

	func _init(row_count := 0) -> void:
		super()
		var column := VBoxContainer.new()
		var title := Label.new()
		title.text = "Title"
		column.add_child(title)
		column.add_child(_scrolling(growing_rows))
		_panel.add_child(column)
		for i in row_count:
			var row := Button.new()
			row.text = "Row %d" % i
			growing_rows.add_child(row)

	func _on_open() -> void:
		opened_count += 1

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
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false


func _window(row_count := 0) -> TestWindow:
	var window := TestWindow.new(row_count)
	_viewport.add_child(window)
	return window


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_viewport.push_input(event)


func _click_backdrop(window: TestWindow) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	window.backdrop().gui_input.emit(event)


func test_a_window_is_closed_at_first_and_opens_closes_and_toggles() -> void:
	var window := _window()
	assert_false(window.is_open())
	window.close()
	assert_false(window.is_open(), "close when closed")
	window.open()
	assert_true(window.is_open())
	window.toggle()
	assert_false(window.is_open())
	window.toggle()
	assert_true(window.is_open())


func test_opening_an_open_window_does_nothing() -> void:
	var window := _window()
	window.open()
	window.open()
	assert_eq(window.opened_count, 1)


func test_opening_and_closing_say_so() -> void:
	var window := _window()
	watch_signals(window)
	window.open()
	assert_signal_emit_count(window, "opened", 1)
	window.close()
	assert_signal_emit_count(window, "closed", 1)
	window.close()
	assert_signal_emit_count(window, "closed", 1)


func test_opening_a_window_closes_the_one_that_is_open() -> void:
	var first := _window()
	var second := _window()
	first.open()
	assert_true(Modal.is_any_open())
	second.open()
	assert_false(first.is_open())
	assert_true(second.is_open())
	Modal.close_open()
	assert_false(second.is_open())
	assert_false(Modal.is_any_open())


func test_a_window_freed_while_open_is_no_longer_open() -> void:
	var window := _window()
	window.open()
	window.free()
	assert_false(Modal.is_any_open())


func test_escape_closes_the_window() -> void:
	var window := _window()
	window.open()
	_press(&"ui_cancel")
	assert_false(window.is_open())


func test_escape_does_nothing_in_a_closed_window() -> void:
	var window := _window()
	_press(&"ui_cancel")
	assert_eq(window.escapes_taken, 0)


func test_a_registered_key_closes_the_window_and_another_does_not() -> void:
	var window := _window()
	window.close_actions = [&"interact"]
	window.open()
	_press(&"crafting")
	assert_true(window.is_open())
	_press(&"interact")
	assert_false(window.is_open())


func test_a_registered_key_does_not_ask_the_escape_hook() -> void:
	var window := _window()
	window.close_actions = [&"interact"]
	window.is_taking_escape = true
	window.open()
	_press(&"interact")
	assert_false(window.is_open())
	assert_eq(window.escapes_taken, 0)


func test_a_window_can_take_escape_before_the_base() -> void:
	var window := _window()
	window.is_taking_escape = true
	window.open()
	_press(&"ui_cancel")
	assert_true(window.is_open())
	assert_eq(window.escapes_taken, 1)
	window.is_taking_escape = false
	_press(&"ui_cancel")
	assert_false(window.is_open())


func test_the_game_pauses_only_while_a_pausing_window_is_open() -> void:
	var window := _window()
	window.open()
	assert_false(get_tree().paused)
	window.close()
	window.pauses_game = true
	window.open()
	assert_true(get_tree().paused)
	assert_eq(window.process_mode, Node.PROCESS_MODE_ALWAYS)
	window.close()
	assert_false(get_tree().paused)


func test_a_pausing_window_freed_while_open_leaves_the_game_running() -> void:
	var window := _window()
	window.pauses_game = true
	window.open()
	window.free()
	assert_false(get_tree().paused)


func test_the_pause_key_goes_through_the_escape_hook_too() -> void:
	var window := _window()
	window.is_taking_escape = true
	window.open()
	_press(&"pause")
	assert_true(window.is_open())
	assert_eq(window.escapes_taken, 1)
	window.is_taking_escape = false
	_press(&"pause")
	assert_false(window.is_open())


func test_a_click_on_the_backdrop_closes_only_if_the_window_wants_it() -> void:
	var window := _window()
	window.open()
	_click_backdrop(window)
	assert_true(window.is_open())
	window.closes_on_backdrop_click = true
	_click_backdrop(window)
	assert_false(window.is_open())


func test_the_panel_stays_centred_as_its_contents_change() -> void:
	var window := _window()
	window.open()
	# The panel is laid out a frame after it is shown.
	await wait_process_frames(1)
	var panel := window.panel()
	var small_size := panel.size
	assert_eq(panel.get_rect().get_center().round(), Vector2(WINDOW / 2))
	var big_label := Label.new()
	big_label.custom_minimum_size = Vector2(300, 100)
	window.growing_rows.add_child(big_label)
	await wait_process_frames(2)
	assert_gt(panel.size.y, small_size.y)
	assert_eq(panel.get_rect().get_center().round(), Vector2(WINDOW / 2))
	# Like a page of the pause menu going away: the panel gets smaller again.
	big_label.visible = false
	await wait_process_frames(2)
	assert_eq(panel.size, small_size)
	assert_eq(panel.get_rect().get_center().round(), Vector2(WINDOW / 2))
	window.close()
	big_label.visible = true
	window.open()
	await wait_process_frames(2)
	assert_gt(panel.size.x, small_size.x)
	assert_eq(panel.get_rect().get_center().round(), Vector2(WINDOW / 2))


func test_the_panel_follows_a_resize_of_the_window() -> void:
	var window := _window()
	window.open()
	_viewport.size = Vector2i(800, 600)
	await wait_process_frames(2)
	assert_eq(window.panel().get_rect().get_center().round(), Vector2(400, 300))


func test_the_growing_part_scrolls_when_the_window_is_too_small_for_it() -> void:
	var window := _window(60)
	window.open()
	await wait_process_frames(2)
	assert_lte(window.panel().size.y, WINDOW.y)
	var list: ScrollingList = window.find_children("*", "ScrollingList", true, false)[0]
	assert_gt(list.get_v_scroll_bar().max_value, list.size.y)


func test_the_growing_part_starts_at_the_top_each_time() -> void:
	var window := _window(60)
	window.open()
	await wait_process_frames(2)
	var list: ScrollingList = window.find_children("*", "ScrollingList", true, false)[0]
	list.scroll_vertical = 100
	window.close()
	window.open()
	assert_eq(list.scroll_vertical, 0)
