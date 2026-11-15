extends EnergyCase
## The console's log: it scrolls, keeps the bottom unless the player read up, wraps long lines
## and has a cap.

var _view: ConsoleView
var _list: ScrollingList


func before_each() -> void:
	super.before_each()
	_view = ConsoleView.new()
	add_child_autofree(_view)
	_view.show_state(_state)
	_view.open()
	_list = _view._log_list


func _bottom() -> int:
	var bar := _list.get_v_scroll_bar()
	return int(bar.max_value - bar.page)


func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_view._input.gui_input.emit(event)


func test_long_output_can_be_scrolled_to_its_first_line() -> void:
	_view.run_line("help")
	await wait_process_frames(3)
	assert_gt(_bottom(), 0, "help is longer than the visible lines")
	assert_eq(_list.scroll_vertical, _bottom())
	_list.scroll_vertical = 0
	assert_eq(_list.scroll_vertical, 0)
	assert_true(_view._log.get_parsed_text().begins_with("> help"))


func test_the_log_takes_half_the_window_and_never_fewer_than_its_least_lines() -> void:
	_view.run_line("help")
	await wait_process_frames(3)
	var window_height := get_viewport().get_visible_rect().size.y
	assert_gte(_list.size.y, ConsoleView.MIN_LOG_LINES * _view.line_height() - 0.5)
	assert_lte(_list.size.y, maxf(window_height * ConsoleView.HEIGHT_SHARE, _list.size.y))
	assert_eq(_list.fixed_height, _list.size.y)


func test_typed_lines_and_usages_stand_out_and_the_text_stays_as_it_is() -> void:
	_view.run_line("help tp")
	assert_string_contains(_view._log.text, "[color=%s]> help tp" % ConsoleView.TYPED_COLOUR)
	assert_string_contains(_view._log.text, "[color=%s]tp <x> <y>" % ConsoleView.USAGE_COLOUR)
	assert_true(_view._log.get_parsed_text().begins_with("> help tp\ntp <x> <y>"))


func test_a_bracket_in_a_line_is_shown_and_not_read_as_markup() -> void:
	_view._log_line("[b]not bold[/b]")
	assert_string_ends_with(_view._log.get_parsed_text(), "[b]not bold[/b]")


func test_a_new_line_keeps_the_view_at_the_bottom() -> void:
	_view.run_line("help")
	await wait_process_frames(3)
	_view.run_line("help")
	await wait_process_frames(3)
	assert_eq(_list.scroll_vertical, _bottom())


func test_scrolled_up_the_view_stays_when_a_line_comes() -> void:
	_view.run_line("help")
	await wait_process_frames(3)
	_list.scroll_vertical = 0
	_view.run_line("help")
	await wait_process_frames(3)
	assert_eq(_list.scroll_vertical, 0)


func test_opening_the_console_shows_the_bottom() -> void:
	_view.run_line("help")
	await wait_process_frames(3)
	_list.scroll_vertical = 0
	_view.close()
	_view.open()
	await wait_process_frames(3)
	assert_eq(_list.scroll_vertical, _bottom())


func test_page_up_and_page_down_scroll_by_a_page() -> void:
	_view.run_line("help")
	await wait_process_frames(3)
	var bottom := _list.scroll_vertical
	_press(KEY_PAGEUP)
	assert_eq(_list.scroll_vertical, bottom - int(_list.size.y))
	_press(KEY_PAGEDOWN)
	assert_eq(_list.scroll_vertical, bottom)


func test_up_and_down_still_browse_the_history() -> void:
	_view.run_line("help")
	_press(KEY_UP)
	assert_eq(_view._input.text, "help")


func test_the_log_keeps_only_the_newest_lines() -> void:
	for i in ConsoleView.MAX_LOG_LINES:
		_view.run_line("help skip")
	assert_eq(_view._log_lines.size(), ConsoleView.MAX_LOG_LINES)
	assert_eq(_view._log.get_parsed_text().count("\n") + 1, ConsoleView.MAX_LOG_LINES)


func test_a_line_wider_than_the_panel_wraps_onto_more_lines() -> void:
	_view._log_line("word ".repeat(80))
	await wait_process_frames(2)
	var lines := _view._log.get_line_count()
	assert_gt(lines, 1, "a long line is wrapped, not cut off")
	assert_lt(lines, 20, "at the panel's width, not a word to a line")
	assert_gt(_view._log.size.x, _list.size.x / 2.0, "the log is as wide as its panel")
	assert_lte(_view._log.size.x, _list.size.x, "and no wider")
