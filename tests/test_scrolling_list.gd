extends GutTest
## The growing part of a panel: as tall as its content until the window has no more room.

const WINDOW := Vector2i(400, 300)

var _window: SubViewport
var _frame: PanelContainer
var _rows: VBoxContainer
var _list: ScrollingList
var _title: Label


func before_each() -> void:
	_window = SubViewport.new()
	_window.size = WINDOW
	add_child_autofree(_window)
	_frame = PanelContainer.new()
	var column := VBoxContainer.new()
	_title = Label.new()
	_title.text = "Title"
	column.add_child(_title)
	_rows = VBoxContainer.new()
	_list = ScrollingList.new(_frame, _rows)
	column.add_child(_list)
	_frame.add_child(column)
	_window.add_child(_frame)


func _add_rows(count: int) -> void:
	for i in count:
		var row := Button.new()
		row.text = "Row %d" % i
		_rows.add_child(row)
	_list.fit()


func _panel_height() -> float:
	return _frame.get_combined_minimum_size().y


func test_a_list_that_fits_is_as_tall_as_its_rows_and_has_no_bar() -> void:
	_add_rows(2)
	assert_eq(_list.custom_minimum_size.y, _rows.get_combined_minimum_size().y)
	assert_false(_list.get_v_scroll_bar().visible)


func test_the_height_is_the_window_less_the_rest_of_the_panel_and_the_margins() -> void:
	assert_eq(
		ScrollingList.height_for(1000.0, 60.0, 300.0), 300.0 - 60.0 - 2 * ScrollingList.MARGIN
	)
	assert_eq(ScrollingList.height_for(50.0, 60.0, 300.0), 50.0)


func test_a_window_too_small_still_leaves_the_list_some_height() -> void:
	assert_eq(ScrollingList.height_for(1000.0, 500.0, 300.0), ScrollingList.MIN_HEIGHT)


func test_a_panel_with_many_rows_stays_inside_the_window_and_scrolls() -> void:
	_add_rows(40)
	await wait_process_frames(2)
	assert_lte(_panel_height(), WINDOW.y - 2 * ScrollingList.MARGIN)
	assert_true(_list.get_v_scroll_bar().visible)
	assert_gt(_list.get_v_scroll_bar().max_value, _list.get_v_scroll_bar().page)


func test_the_list_gives_way_when_the_rest_of_the_panel_grows() -> void:
	_add_rows(40)
	await wait_process_frames(2)
	var before := _list.custom_minimum_size.y
	_title.text = "Title\nand a note of\nthree lines"
	await wait_process_frames(2)
	assert_lt(_list.custom_minimum_size.y, before)
	assert_lte(_panel_height(), WINDOW.y - 2 * ScrollingList.MARGIN)


func test_the_list_follows_the_window_being_resized() -> void:
	_add_rows(12)
	var tall := _list.custom_minimum_size.y
	_window.size = Vector2i(WINDOW.x, WINDOW.y / 2)
	await wait_process_frames(2)
	assert_lt(_list.custom_minimum_size.y, tall)
	_window.size = Vector2i(WINDOW.x, WINDOW.y * 4)
	await wait_process_frames(2)
	assert_eq(_list.custom_minimum_size.y, _rows.get_combined_minimum_size().y)


func test_focus_moving_to_a_row_scrolls_it_into_view() -> void:
	_add_rows(40)
	await wait_process_frames(2)
	assert_true(_list.follow_focus)
	var last: Control = _rows.get_child(_rows.get_child_count() - 1)
	last.grab_focus()
	await wait_process_frames(3)
	assert_gt(_list.scroll_vertical, 0)


func test_the_bar_does_not_squeeze_the_rows() -> void:
	_add_rows(40)
	assert_gt(_list.custom_minimum_size.x, _rows.get_combined_minimum_size().x)
