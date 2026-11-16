extends GutTest
## The pages of the settings that grow, in a window too small for them: the panel stays in the
## window and the page's list scrolls.

const SETTINGS_PATH := "user://test_pause_menu_scrolling/settings.cfg"
const SMALL_WINDOW := Vector2i(320, 180)

var _menu: PauseMenu
var _window: SubViewport


func before_each() -> void:
	_window = SubViewport.new()
	_window.size = SMALL_WINDOW
	add_child_autofree(_window)
	_menu = PauseMenu.new(GameSettings.new(SETTINGS_PATH))
	# The test waits for frames, which stand still while the game is paused.
	_menu.pauses_game = false
	_window.add_child(_menu)


func after_each() -> void:
	DirAccess.remove_absolute(SETTINGS_PATH)


func _panel() -> Control:
	return _menu.find_children("*", "PanelContainer", true, false)[0]


func _bar_of(page: Control) -> VScrollBar:
	var list: ScrollingList = page.find_children("*", "ScrollingList", true, false)[0]
	return list.get_v_scroll_bar()


func _check_page(page: PauseMenu.Page) -> void:
	_menu.open_page(page)
	await wait_process_frames(2)
	assert_true(_bar_of(_menu._pages[page]).visible, "the window is too small for the page")
	assert_lte(_panel().size.y, float(SMALL_WINDOW.y - 2 * ScrollingList.MARGIN))


func test_the_controls_page_scrolls_in_a_small_window() -> void:
	await _check_page(PauseMenu.Page.CONTROLS)


func test_the_language_model_page_scrolls_in_a_small_window() -> void:
	await _check_page(PauseMenu.Page.LANGUAGE_MODEL)


func test_a_page_opens_scrolled_to_the_top() -> void:
	_menu.open_page(PauseMenu.Page.CONTROLS)
	await wait_process_frames(2)
	var list: ScrollingList = (
		_menu._pages[PauseMenu.Page.CONTROLS].find_children("*", "ScrollingList", true, false)[0]
	)
	list.scroll_vertical = 40
	_menu.open_page(PauseMenu.Page.CONTROLS)
	assert_eq(list.scroll_vertical, 0)


func test_the_audio_page_scrolls_in_a_small_window() -> void:
	await _check_page(PauseMenu.Page.AUDIO)


func test_the_audio_page_keeps_the_first_slider_focused() -> void:
	_menu.open_page(PauseMenu.Page.AUDIO)
	await wait_process_frames(2)
	assert_true(_menu._pages[PauseMenu.Page.AUDIO].first_focus.has_focus())


func _check_page_reopened_after_the_window_shrank(page: PauseMenu.Page) -> void:
	_window.size = Vector2i(320, 400)
	_menu.open_page(page)
	await wait_process_frames(2)
	_menu.close()
	_window.size = SMALL_WINDOW
	await wait_process_frames(2)

	_menu.open_page(page)

	var room := float(SMALL_WINDOW.y - 2 * ScrollingList.MARGIN)
	assert_lte(_panel().get_combined_minimum_size().y, room, "fitted when the page is shown")


func test_the_audio_page_reopened_after_the_window_shrank_fits_it() -> void:
	await _check_page_reopened_after_the_window_shrank(PauseMenu.Page.AUDIO)
