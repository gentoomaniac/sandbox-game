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
## - Hooks, all optional: `_on_open()` (fill the contents; the lists are fitted after it),
##   `_on_close()`, `_takes_escape()` (return true to use Escape yourself, e.g. to go back a page
##   instead of closing) and `_on_backdrop_input(event)` (a click on the dimmed area).
## - Contents that change size need nothing: the panel is anchored to the middle of the window and
##   grows round its contents, so it stays there through resizes and UI scale changes.
##   The scrolling lists fit themselves; `refit()` makes them fit now.
## - The player drags the window by what is not content: the panel's frame and the gaps and labels
##   in it that take no clicks. Never by a button, slider, text field or slot, or by the rows of a
##   list (the empty area of a list and the gaps between its rows do drag). It stays on the
##   screen, and opens in its place (the middle unless `opening_shift` says otherwise) each time.
##   A window that must stay put (the pause menu, a question) sets `is_movable` to false in `_init`.
## - Escape here is `ui_cancel` (not rebindable) or the rebindable pause key, as the pause menu
##   takes both. Other keys that close the window (E on the chest) are named in `close_actions`;
##   they close it at once, without `_takes_escape()`. Windows must stay children of Main, so that
##   these keys reach them before Main.
## - Only Modals pause the game (the pause menu is one).

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
## The input actions, besides Escape and the pause key, that close the window. Set it in `_init`.
var close_actions: Array[StringName] = []
## Whether the player can drag the window about. Set it in `_init`.
var is_movable := true
## How far from the middle of the window the panel opens, in canvas pixels (kept on the screen).
## Set it in `_init`.
var opening_shift := Vector2.ZERO

var _backdrop := ColorRect.new()
var _centre := Control.new()
var _panel := PanelContainer.new()
var _lists: Array[ScrollingList] = []
## How far the panel is from the middle of the window: where it opened plus the player's drag.
var _drag_shift := Vector2.ZERO
var _is_dragging := false
## Where the panel was when the drag started, and where the mouse was.
var _drag_start_shift := Vector2.ZERO
var _drag_start_mouse := Vector2.ZERO


func _init() -> void:
	visible = false
	_backdrop.color = UiColors.BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	# Clicks beside the panel reach the backdrop.
	_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_child(_centre)
	_panel.theme = THEME
	# Anchored to the middle and growing both ways, the panel stays centred round its contents;
	# the offsets are the drag.
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.gui_input.connect(_on_frame_input)
	_panel.minimum_size_changed.connect(_apply_drag_shift)
	_backdrop.gui_input.connect(_on_frame_input)
	_centre.add_child(_panel)


## Removing an open window cleans up as closing it does (borrowed HUD, listeners, the pause).
func _exit_tree() -> void:
	close()


## Whether any window is open: then the player neither walks nor acts.
static func is_any_open() -> bool:
	return _open_modal != null


## Closes the open window, if any.
static func close_open() -> void:
	if _open_modal != null:
		_open_modal.close()


func is_open() -> bool:
	return visible


## Whether the window's own key may act on it: not while another window is open, as that one has
## the input. The key of the open window itself still works (it closes it, or switches its tab).
func can_open_on_key() -> bool:
	return visible or not Modal.is_any_open()


## Opens the window, closing the one that is open. Does nothing if this one is.
func open() -> void:
	if visible:
		return
	close_open()
	_open_modal = self
	visible = true
	_drag_shift = opening_shift
	_apply_drag_shift()
	get_viewport().size_changed.connect(_apply_drag_shift)
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
	_is_dragging = false
	get_viewport().size_changed.disconnect(_apply_drag_shift)
	if pauses_game:
		get_tree().paused = false
	_on_close()
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Sizes the lists to the window. They size themselves only while the window is shown, and the
## CanvasLayer's visibility does not trigger it, so `open()` calls it. The panel stays round its
## contents and in the middle of the window by itself.
func refit() -> void:
	for list in _lists:
		list.fit()


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


## For a window where stacks are dragged (see SlotView): `on_drop.call(source)` runs when the
## stack of the SlotView `source` is let go on the dimmed area outside the panel and outside the
## HUD's `hotbar`. Let go anywhere else, such as between the panel's slots, it stays where it was.
func _drop_outside_panel(hotbar: HotbarHud, on_drop: Callable) -> void:
	_backdrop.set_drag_forwarding(
		Callable(),
		func(at_position: Vector2, data: Variant) -> bool:
			return (
				SlotView.source_of(data) != null
				and not _panel.get_rect().has_point(at_position)
				and not hotbar.covers(at_position)
			),
		func(_at_position: Vector2, data: Variant) -> void: on_drop.call(SlotView.source_of(data))
	)


## A press the content did not take, on the panel itself or (for a panel that lets clicks through
## to the backdrop) on the backdrop over the panel: the player has hold of the window.
func _on_frame_input(event: InputEvent) -> void:
	if not is_movable or not _is_left_press(event):
		return
	var press := event as InputEventMouseButton
	if not _panel.get_global_rect().has_point(press.global_position):
		return
	_is_dragging = true
	_drag_start_shift = _drag_shift
	_drag_start_mouse = press.global_position


## The drag goes on outside the panel, so it listens to the whole window.
func _input(event: InputEvent) -> void:
	if not _is_dragging:
		return
	if event is InputEventMouseMotion:
		_drag_shift = _drag_start_shift + event.global_position - _drag_start_mouse
		_apply_drag_shift()
	elif _is_left_release(event):
		_is_dragging = false


## Places the panel at the drag, keeping it on the screen: also after the window or the panel
## changed size. The offsets give the panel exactly its minimum size, which is what it takes.
func _apply_drag_shift() -> void:
	var panel_size := _panel.get_combined_minimum_size()
	var room := ((get_viewport().get_visible_rect().size - panel_size) / 2).max(Vector2.ZERO)
	_drag_shift = _drag_shift.clamp(-room, room)
	_panel.offset_left = _drag_shift.x - panel_size.x / 2
	_panel.offset_right = _drag_shift.x + panel_size.x / 2
	_panel.offset_top = _drag_shift.y - panel_size.y / 2
	_panel.offset_bottom = _drag_shift.y + panel_size.y / 2


func _is_left_press(event: InputEvent) -> bool:
	return (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	)


func _is_left_release(event: InputEvent) -> bool:
	return (
		event is InputEventMouseButton
		and not event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	)


## Wraps the part of the window that grows in a ScrollingList, and returns that to put where
## the part belongs. The list starts at the top each time the window opens.
func _scrolling(growing_part: Control) -> ScrollingList:
	var list := ScrollingList.new(growing_part)
	_lists.append(list)
	return list


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if not _takes_escape():
			close()
	elif close_actions.any(
		func(action: StringName) -> bool: return event.is_action_pressed(action)
	):
		get_viewport().set_input_as_handled()
		close()
