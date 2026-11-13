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
##   `_on_close()` and `_takes_escape()` (return true to use Escape yourself, e.g. to go back a
##   page instead of closing).
## - Contents that change size need nothing: the panel is anchored to the middle of the window and
##   grows round its contents, so it stays there through resizes and UI scale changes.
##   The scrolling lists fit themselves; `refit()` makes them fit now.
## - The player drags the window by what is not content: the panel's frame and the gaps and labels
##   in it that take no clicks. Never by a button, slider, text field or slot, or by the rows of a
##   list (the empty area of a list and the gaps between its rows do drag). It stays on the
##   screen, and opens in its place (the middle unless `opening_shift` says otherwise) each time.
##   A window that must stay put (the pause menu, a question) sets `is_movable` to false in `_init`.
## - Every window has a close button in the panel's top right corner: it does what Escape does
##   (and so does a click outside the panel, below).
## - Escape here is `ui_cancel` (not rebindable) or the rebindable pause key, as the pause menu
##   takes both. A left click on the dimmed area outside the panel does what Escape does, in every
##   window (`request_close()` is the one path for both). Other keys that close the window (E on the
##   chest) are named in `close_actions`; they close it at once, without `_takes_escape()`. Windows
##   must stay children of Main, so that these keys reach them before Main.
## - Only Modals pause the game (the pause menu is one).
## - Two windows may be docked (`dock`, the bag and the character window): they open at the side of
##   the screen, are not dimmed, stay open together (each on its own key), and Escape closes
##   them both. Any other window closes what is open when it opens.

## The window was opened, after `_on_open()`.
signal opened
## The window was closed, after `_on_close()`.
signal closed

const THEME := preload("res://game/scenes/ui_theme.tres")
## How far the close button sits from the panel's top and right edges, in canvas pixels.
const CLOSE_BUTTON_INSET := 3
const DOCK_MARGIN := 8

## The window that is open and not docked, if any. Windows are not told about each other: opening
## closes it.
static var _open_modal: Modal
## The docked windows that are open.
static var _open_docked: Array[Modal] = []

## Whether the game stands still while the window is open. Set it in `_init`.
var pauses_game := false
## The input actions, besides Escape and the pause key, that close the window. Set it in `_init`.
var close_actions: Array[StringName] = []
## Whether the player can drag the window about. Set it in `_init`.
var is_movable := true
## How far from the middle of the window the panel opens, in canvas pixels (kept on the screen).
## Set it in `_init`.
var opening_shift := Vector2.ZERO
## The side of the screen a docked window opens at, per axis: -1 left or top, 1 right or bottom,
## 0 the middle. Zero on both is a window that is not docked. Set it in `_init`, before
## `_drop_outside_panel`.
var dock := Vector2.ZERO:
	set(value):
		dock = value
		# The game is not dimmed beside a docked window, and clicks beside it go on to the game.
		_backdrop.color = Color.TRANSPARENT
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
## How far a docked window stays from the edges it is docked to, in canvas pixels.
var dock_inset := Vector2(DOCK_MARGIN, DOCK_MARGIN)

var _backdrop := ModalBackdrop.new()
var _centre := Control.new()
var _panel := PanelContainer.new()
## Whether a point of the window (canvas coordinates) keeps its clicks while the window is open,
## such as the HUD's hotbar: a click there is not outside the panel. Set it in `_init`.
var _keeps_clicks_at := func(_point: Vector2) -> bool: return false
var _close_button := TextureButton.new()
var _lists: Array[ScrollingList] = []
## How far the panel is from the middle of the window: where it opened plus the player's drag.
var _drag_shift := Vector2.ZERO
var _is_dragging := false
## Whether a docked window is still where it opened, and so follows its edge when it changes size.
var _is_at_dock := false
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
	# A sibling of the panel, drawn over its top right corner: pressing it never starts a drag.
	_close_button.texture_normal = preload("res://assets/ui/close_normal.png")
	_close_button.texture_hover = preload("res://assets/ui/close_hover.png")
	_close_button.texture_pressed = preload("res://assets/ui/close_pressed.png")
	# Space is the game's use key: a focused button would take it.
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.set_anchors_preset(Control.PRESET_CENTER)
	_close_button.pressed.connect(request_close)
	TooltipView.set_text(_close_button, "Close", "close")
	_centre.add_child(_close_button)


## Removing an open window cleans up as closing it does (borrowed HUD, listeners, the pause).
func _exit_tree() -> void:
	close()


## Whether any window is open.
static func is_any_open() -> bool:
	return _open_modal != null or not _open_docked.is_empty()


## Whether a window that takes the input is open: then the player neither walks nor acts. The
## docked windows are played beside.
static func is_blocking_open() -> bool:
	return _open_modal != null


## Closes the open windows, if any.
static func close_open() -> void:
	if _open_modal != null:
		_open_modal.close()
	for window in _open_docked.duplicate():
		window.close()


func is_open() -> bool:
	return visible


## Whether the window's own key may act on it: not while another window is open, as that one has
## the input. The key of the open window itself still works (it closes it, or switches its tab).
## A docked window also opens beside the other docked one.
func can_open_on_key() -> bool:
	if is_docked():
		return visible or _open_modal == null
	return visible or not Modal.is_any_open()


## Whether the window docks at a side of the screen (see `dock`).
func is_docked() -> bool:
	return dock != Vector2.ZERO


## Opens the window, closing the one that is open (a docked window leaves the other docked one
## open). Does nothing if this one is.
func open() -> void:
	if visible:
		return
	if is_docked():
		if _open_modal != null:
			_open_modal.close()
		_open_docked.append(self)
	else:
		close_open()
		_open_modal = self
	visible = true
	_drag_shift = opening_shift
	_is_at_dock = is_docked()
	_apply_drag_shift()
	get_viewport().size_changed.connect(_apply_drag_shift)
	if pauses_game:
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
	_on_open()
	for list in _lists:
		list.scroll_vertical = 0
	refit()
	if is_docked():
		_close_first_docked_if_cramped()
	opened.emit()


## Safe to call when it is closed.
func close() -> void:
	if not visible:
		return
	visible = false
	if _open_modal == self:
		_open_modal = null
	_open_docked.erase(self)
	_is_dragging = false
	get_viewport().size_changed.disconnect(_apply_drag_shift)
	if pauses_game:
		get_tree().paused = false
	_on_close()
	closed.emit()


## What Escape does: the window's own step if it has one (`_takes_escape()`), else closing.
func request_close() -> void:
	if not _takes_escape():
		close()


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


## A click outside the panel is Escape. The panel of some windows lets clicks through to the
## backdrop, so where the click is decides.
func _on_backdrop_input(event: InputEvent) -> void:
	if is_docked() or not _is_left_press(event):
		return
	var at: Vector2 = event.global_position
	if not _panel.get_global_rect().has_point(at) and not _keeps_clicks_at.call(at):
		request_close()


## For a window where stacks are dragged (see SlotView): `on_drop.call(source)` runs when the
## stack of the SlotView `source` is let go on the dimmed area outside the panel and outside the
## HUD's `hotbar`. Let go anywhere else, such as between the panel's slots, it stays where it was.
func _drop_outside_panel(hotbar: HotbarHud, on_drop: Callable) -> void:
	if is_docked():
		_backdrop.takes_mouse_while_dragging = true
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
	_is_at_dock = false
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
	if _is_at_dock:
		_drag_shift = dock * (room - dock_inset).max(Vector2.ZERO)
	_drag_shift = _drag_shift.clamp(-room, room)
	_panel.offset_left = _drag_shift.x - panel_size.x / 2
	_panel.offset_right = _drag_shift.x + panel_size.x / 2
	_panel.offset_top = _drag_shift.y - panel_size.y / 2
	_panel.offset_bottom = _drag_shift.y + panel_size.y / 2
	var button_size := _close_button.get_combined_minimum_size()
	_close_button.offset_right = _panel.offset_right - CLOSE_BUTTON_INSET
	_close_button.offset_left = _close_button.offset_right - button_size.x
	_close_button.offset_top = _panel.offset_top + CLOSE_BUTTON_INSET
	_close_button.offset_bottom = _close_button.offset_top + button_size.y
	if is_docked():
		_close_first_docked_if_cramped.call_deferred()


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
		if is_docked():
			_escape_docked()
		else:
			request_close()
	elif close_actions.any(
		func(action: StringName) -> bool: return event.is_action_pressed(action)
	):
		get_viewport().set_input_as_handled()
		close()


## Where the panel sits at its dock, in canvas pixels.
func _docked_rect() -> Rect2:
	var panel_size := _panel.get_combined_minimum_size()
	var screen_size := get_viewport().get_visible_rect().size
	var centre := screen_size / 2 + dock * ((screen_size - panel_size) / 2 - dock_inset)
	return Rect2(centre - panel_size / 2, panel_size)


## Two docked windows that overlap, or one that does not fit on the screen, at their docks (a
## small window or a large UI scale) are too many: the one opened first closes, as the windows of
## the old one-at-a-time rule did. Windows the player has moved are left where they were put.
func _close_first_docked_if_cramped() -> void:
	if (
		_open_docked.size() < 2
		or _open_docked.any(func(window: Modal) -> bool: return not window._is_at_dock)
	):
		return
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var first := _open_docked[0]._docked_rect()
	var second := _open_docked[1]._docked_rect()
	if first.intersects(second) or not screen.encloses(first) or not screen.encloses(second):
		_open_docked[0].close()


## Escape closes all the docked windows, unless one has a step of its own to take first. That
## step is the call itself: `_takes_escape()` also answers the bag's trash can question.
func _escape_docked() -> void:
	if not _open_docked.any(func(window: Modal) -> bool: return window._takes_escape()):
		close_open()
