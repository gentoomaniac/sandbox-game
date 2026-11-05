class_name PauseMenu
extends CanvasLayer
## The pause menu and the settings under it. It keeps running while the game is paused;
## Main pauses the game when it opens the menu and resumes when `resumed` comes. Escape (or
## the pause key) goes back one level, and closes the menu from the first one.

signal resumed
signal save_and_quit_requested

enum Page { PAUSE, SETTINGS, CONTROLS, DISPLAY, GAME }

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
var _ui_scale_label: Label
var _ui_scale_slider: HSlider
var _is_dragging_slider := false
var _drain_button: Button


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
	_add_button(settings_page, "Game", _go_to.bind(Page.GAME))
	_add_button(settings_page, "Display", _go_to.bind(Page.DISPLAY))
	_add_button(settings_page, "Back", _back)

	var display := _add_page(pages, Page.DISPLAY, "Display")
	_display_button = _add_button(display, "", _toggle_fullscreen)
	_first_focus[Page.DISPLAY] = _display_button
	_add_button(display, "Back", _back)

	var game := _add_page(pages, Page.GAME, "Game")
	_ui_scale_label = Label.new()
	_ui_scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.add_child(_ui_scale_label)
	_ui_scale_slider = HSlider.new()
	_ui_scale_slider.min_value = GameSettings.MIN_UI_SCALE
	_ui_scale_slider.max_value = GameSettings.MAX_UI_SCALE
	_ui_scale_slider.step = GameSettings.UI_SCALE_STEP
	_ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	_ui_scale_slider.drag_started.connect(func() -> void: _is_dragging_slider = true)
	_ui_scale_slider.drag_ended.connect(_on_slider_released)
	game.add_child(_ui_scale_slider)
	_first_focus[Page.GAME] = _ui_scale_slider
	_drain_button = _add_button(game, "", _cycle_energy_drain)
	_add_button(game, "Back", _back)

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
	elif page == Page.GAME:
		_show_game_settings()
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


func _show_game_settings() -> void:
	_ui_scale_slider.set_value_no_signal(_settings.ui_scale)
	_show_ui_scale(_settings.ui_scale)
	_drain_button.text = (
		"Energy drain: " + GameSettings.ENERGY_DRAIN_NAMES[_settings.energy_drain].capitalize()
	)


func _show_ui_scale(value: float) -> void:
	_ui_scale_label.text = "UI scale %s\u00d7" % String.num(value)


## While the slider is being dragged only the label follows: scaling the UI under the mouse
## would move the slider away from it. The scale applies on release.
func _on_ui_scale_changed(value: float) -> void:
	_show_ui_scale(value)
	if not _is_dragging_slider:
		_settings.set_ui_scale(value)


func _on_slider_released(_value_changed: bool) -> void:
	_is_dragging_slider = false
	_settings.set_ui_scale(_ui_scale_slider.value)


func _cycle_energy_drain() -> void:
	_settings.set_energy_drain(GameSettings.next_drain(_settings.energy_drain))
	_show_game_settings()
