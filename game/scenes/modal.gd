class_name Modal
extends CanvasLayer
## The base of every window over the game (crafting, chest, character screen, chat, the pause
## menu): the dimmed backdrop, a themed panel centred in the window, opening and closing, Escape,
## and the rule that only one window is open at a time. A window only builds its contents.
##
## How to write one:
## - Extend Modal. In `_init`, call `super()`, set the flags below, build the contents and add
##   them to `_panel`. The part that grows (rows of recipes, items, settings) goes through
##   `_scrolling(part)`, which wraps it in a ScrollingList and returns that to add to the layout.
## - `open()`, `close()`, `toggle()` and `is_open()` are the base's; they take no arguments, so a
##   window that needs some (a chest, a station, a villager) has a method of its own that stores
##   them and calls `open()`, e.g. `open_chest(chest, player)`. If that window can already be open,
##   the method calls `close()` first, so the close hook still sees the old arguments and
##   `open()`, which does nothing for a window that is open, starts afresh.
## - Hooks, all optional: `_on_open()` (fill the contents; the panel is refitted after it),
##   `_on_close()`, `_takes_escape()` (return true to use Escape yourself, e.g. to go back a page
##   instead of closing) and `_on_backdrop_input(event)` (a click on the dimmed area).
## - Contents that change size need nothing: the panel refits when its minimum size changes, when
##   the window is resized and when the UI scale changes. `refit()` forces it.
## - Escape here is `ui_cancel` (not rebindable) or the rebindable pause key, as the pause menu
##   takes both. Windows must stay children of Main, so that Escape reaches them before Main.
## - Only Modals pause the game, once all windows are on this base (the pause menu is one).

## The window was opened, after `_on_open()`.
signal opened
## The window was closed, after `_on_close()`.
signal closed

const THEME := preload("res://game/scenes/ui_theme.tres")

## The window that is open, if any. Windows are not told about each other: opening closes it.
static var _open_modal: Modal

## Whether the game stands still while the window is open. Set it in `_init`.
var pauses_game := false
## Whether a click outside the panel closes the window. A window that uses those clicks itself
## overrides `_on_backdrop_input` instead.
var closes_on_backdrop_click := false

var _backdrop := ColorRect.new()
var _panel := PanelContainer.new()
var _lists: Array[ScrollingList] = []


func _init() -> void:
	visible = false
	_backdrop.color = UiColors.BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	_panel.theme = THEME
	_panel.minimum_size_changed.connect(_centre_panel)
	_backdrop.add_child(_panel)


func _exit_tree() -> void:
	if _open_modal == self:
		_open_modal = null
		if pauses_game:
			get_tree().paused = false


## Whether any window is open: then the player neither walks nor acts.
static func is_any_open() -> bool:
	return _open_modal != null


## Closes the open window, if any.
static func close_open() -> void:
	if _open_modal != null:
		_open_modal.close()


func is_open() -> bool:
	return visible


## Opens the window, closing the one that is open. Does nothing if this one is.
func open() -> void:
	if visible:
		return
	close_open()
	_open_modal = self
	visible = true
	if pauses_game:
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
	_on_open()
	for list in _lists:
		list.scroll_vertical = 0
	refit()
	opened.emit()


## Safe to call when it is closed.
func close() -> void:
	if not visible:
		return
	visible = false
	_open_modal = null
	if pauses_game:
		get_tree().paused = false
	_on_close()
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Sizes the panel round its contents and centres it. The lists size themselves only while the
## window is shown, and the CanvasLayer's visibility does not trigger it, so `open()` calls it.
func refit() -> void:
	for list in _lists:
		list.fit()
	_centre_panel()


## Fills the contents when the window opens.
func _on_open() -> void:
	pass


func _on_close() -> void:
	pass


## Called when Escape is pressed while the window is open: return true if the window used it
## (the window then stays open), false to let the base close it.
func _takes_escape() -> bool:
	return false


## A mouse event on the dimmed area (the panel takes its own unless a window lets them through).
func _on_backdrop_input(event: InputEvent) -> void:
	if closes_on_backdrop_click and _is_left_press(event):
		close()


func _is_left_press(event: InputEvent) -> bool:
	return (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	)


## Wraps the part of the window that grows in a ScrollingList, and returns that to put where
## the part belongs. The list starts at the top each time the window opens.
func _scrolling(growing_part: Control) -> ScrollingList:
	var list := ScrollingList.new(_panel, growing_part)
	_lists.append(list)
	return list


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		if not _takes_escape():
			close()


func _centre_panel() -> void:
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
