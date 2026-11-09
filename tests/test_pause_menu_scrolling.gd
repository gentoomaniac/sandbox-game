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
	_window.add_child(_menu)


func after_each() -> void:
	DirAccess.remove_absolute(SETTINGS_PATH)


func _panel() -> Control:
	return _menu.find_children("*", "PanelContainer", true, false)[0]


func _bar_of(page: Control) -> VScrollBar:
	var list: ScrollingList = page.find_children("*", "ScrollingList", true, false)[0]
	return list.get_v_scroll_bar()


func _check_page(page: PauseMenu.Page) -> void:
	_menu.open(page)
	await wait_process_frames(2)
	assert_true(_bar_of(_menu._pages[page]).visible, "the window is too small for the page")
	assert_lte(_panel().size.y, float(SMALL_WINDOW.y - 2 * ScrollingList.MARGIN))


func test_the_controls_page_scrolls_in_a_small_window() -> void:
	await _check_page(PauseMenu.Page.CONTROLS)
