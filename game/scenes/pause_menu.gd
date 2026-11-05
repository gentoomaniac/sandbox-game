class_name PauseMenu
extends CanvasLayer
## The pause menu and the settings under it. It keeps running while the game is paused;
## Main pauses the game when it opens the menu and resumes when `resumed` comes. Escape (or
## the pause key) goes back one level, and closes the menu from the first one.

signal resumed
signal save_and_quit_requested

enum Page { PAUSE, SETTINGS, CONTROLS, DISPLAY }

const THEME := preload("res://game/scenes/ui_theme.tres")
const PANEL_WIDTH := 280
const DIM_COLOUR := Color(0.114, 0.106, 0.149, 0.6)

var _settings: GameSettings
var _pages := {}
var _first_focus := {}
## The pages left behind on the way to the current one.
var _history: Array[Page] = []
var _current: Page
var _display_button: Button


func _init(settings: GameSettings) -> void:
	_settings = settings
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var root := Control.new()
	root.theme = THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = DIM_COLOUR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	centre.add_child(panel)
	var pages := VBoxContainer.new()
	panel.add_child(pages)

	var pause := _add_page(pages, Page.PAUSE, "Paused")
	_first_focus[Page.PAUSE] = _add_button(pause, "Resume", close)
	_add_button(pause, "Settings", _go_to.bind(Page.SETTINGS))
	_add_button(pause, "Save and quit", save_and_quit_requested.emit)

	var settings_page := _add_page(pages, Page.SETTINGS, "Settings")
	_first_focus[Page.SETTINGS] = _add_button(settings_page, "Controls", _go_to.bind(Page.CONTROLS))
	_add_button(settings_page, "Display", _go_to.bind(Page.DISPLAY))
	_add_button(settings_page, "Back", _back)

	var display := _add_page(pages, Page.DISPLAY, "Display")
	_display_button = _add_button(display, "", _toggle_fullscreen)
	_first_focus[Page.DISPLAY] = _display_button
	_add_button(display, "Back", _back)

	var controls := ControlsPage.new(_settings)
	controls.back_requested.connect(_back)
	pages.add_child(controls)
	_pages[Page.CONTROLS] = controls
	_first_focus[Page.CONTROLS] = controls.first_focus


## Opens the menu on the pause page, or on `page` (a debug flag uses that).
func open(page: Page = Page.PAUSE) -> void:
	visible = true
	_history.clear()
	_show_page(page)


func close() -> void:
	visible = false
	resumed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# ui_cancel is Escape and not rebindable, so Escape still leaves the menu when the
	# pause action has been moved to another key.
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_back()


func _add_page(parent: Control, page: Page, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	parent.add_child(box)
	_pages[page] = box
	return box


func _add_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


func _show_page(page: Page) -> void:
	_current = page
	for other in _pages:
		_pages[other].visible = other == page
	if page == Page.DISPLAY:
		_show_display_mode()
	elif page == Page.CONTROLS:
		_pages[page].show_bindings()
	_first_focus[page].grab_focus()


func _go_to(page: Page) -> void:
	_history.append(_current)
	_show_page(page)


func _back() -> void:
	if _history.is_empty():
		close()
	else:
		_show_page(_history.pop_back())


func _toggle_fullscreen() -> void:
	_settings.set_fullscreen(not _settings.is_fullscreen)
	_show_display_mode()


func _show_display_mode() -> void:
	_display_button.text = "Mode: " + ("Fullscreen" if _settings.is_fullscreen else "Windowed")
