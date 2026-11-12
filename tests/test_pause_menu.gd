extends GutTest
## The pause menu as a window: it pauses the game while open, and Escape goes back a page before
## it closes the menu.

const SETTINGS_PATH := "user://test_pause_menu/settings.cfg"

var _menu: PauseMenu


func before_each() -> void:
	_menu = PauseMenu.new(GameSettings.new(SETTINGS_PATH))
	add_child_autofree(_menu)


func after_each() -> void:
	get_tree().paused = false
	DirAccess.remove_absolute(SETTINGS_PATH)


func _press_escape() -> void:
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	_menu._unhandled_input(escape)


func test_the_game_is_paused_while_the_menu_is_open() -> void:
	_menu.open()
	assert_true(get_tree().paused)
	_menu.close()
	assert_false(get_tree().paused)


func test_the_menu_opens_on_the_pause_page_or_on_the_page_asked_for() -> void:
	_menu.open()
	assert_true(_menu._pages[PauseMenu.Page.PAUSE].visible)
	_menu.close()
	_menu.open_page(PauseMenu.Page.AUDIO)
	assert_true(_menu._pages[PauseMenu.Page.AUDIO].visible)
	assert_false(_menu._pages[PauseMenu.Page.PAUSE].visible)
	_menu.close()
	_menu.open()
	assert_true(_menu._pages[PauseMenu.Page.PAUSE].visible, "the page asked for is not kept")


func test_escape_goes_back_a_page_at_a_time_and_then_closes_the_menu() -> void:
	_menu.open()
	_menu._go_to(PauseMenu.Page.SETTINGS)
	_menu._go_to(PauseMenu.Page.AUDIO)
	_press_escape()
	assert_true(_menu._pages[PauseMenu.Page.SETTINGS].visible)
	_press_escape()
	assert_true(_menu._pages[PauseMenu.Page.PAUSE].visible)
	assert_true(_menu.is_open())
	_press_escape()
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)


func _click_outside() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.global_position = Vector2.ONE
	_menu._backdrop.gui_input.emit(click)


func test_a_click_outside_goes_back_a_page_at_a_time_and_then_closes_the_menu() -> void:
	_menu.open()
	_menu._go_to(PauseMenu.Page.SETTINGS)
	_click_outside()
	assert_true(_menu._pages[PauseMenu.Page.PAUSE].visible)
	assert_true(_menu.is_open())
	_click_outside()
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)


func test_the_menu_is_fixed_in_place_on_every_page() -> void:
	assert_false(_menu.is_movable)
