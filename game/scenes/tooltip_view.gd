class_name TooltipView
extends CanvasLayer
## The tooltip: a framed panel with text that appears by the cursor after it rests on a control
## with a tooltip for a moment. Controls get theirs with `TooltipView.set_text`; this watches
## which control is under the mouse. It hides when the mouse leaves, on any click (so while
## dragging), and when the control goes away (its screen closes). Above every other UI layer.

const THEME := preload("res://game/scenes/ui_theme.tres")
const DELAY_SECONDS := 0.4
## Where the panel's corner sits from the cursor, and how wide its text gets before wrapping.
const CURSOR_OFFSET := Vector2(10, 12)
const MAX_TEXT_WIDTH := 150
const TEXT_META := &"tooltip_text"
const ID_META := &"tooltip_id"
## Every control that has a tooltip, so a debug flag can find one by its id.
const GROUP := &"tooltip_controls"

var _panel := PanelContainer.new()
var _label := Label.new()
var _hovered: Control
var _hover_seconds := 0.0
## Set by a click: no tooltip until the mouse is over another control.
var _is_suppressed := false
## Debug: the tooltip to show without hovering (see `--tooltip` in main.gd).
var _debug_id := ""


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.theme = THEME
	_panel.theme_type_variation = &"TooltipPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_label)
	add_child(_panel)


## Gives `control` a tooltip (none for empty text). The `id` names it for the debug flag.
static func set_text(control: Control, text: String, id := "") -> void:
	control.set_meta(TEXT_META, text)
	if id != "":
		control.set_meta(ID_META, id)
	if not control.is_in_group(GROUP):
		control.add_to_group(GROUP)


## Debug: shows the tooltip of the control with this id as if the mouse were on it.
func show_by_id(id: String) -> void:
	_debug_id = id


func _input(event: InputEvent) -> void:
	# A click or drag hides the tooltip; the wheel (zooming) doesn't.
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	):
		_is_suppressed = true
		_panel.visible = false


func _process(delta: float) -> void:
	if _debug_id != "":
		_show_debug_tooltip()
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != _hovered:
		_hovered = hovered
		_hover_seconds = 0.0
		_is_suppressed = false
	var text := _text_of(hovered)
	if text == "" or _is_suppressed:
		_panel.visible = false
		return
	_hover_seconds += delta
	if _hover_seconds >= DELAY_SECONDS:
		_show(text, _panel.get_global_mouse_position())


func _show_debug_tooltip() -> void:
	for control: Control in get_tree().get_nodes_in_group(GROUP):
		if control.get_meta(ID_META, "") == _debug_id and control.is_visible_in_tree():
			var text := _text_of(control)
			if text != "":
				_show(text, control.get_global_rect().get_center())


func _text_of(control: Control) -> String:
	return "" if control == null else control.get_meta(TEXT_META, "")


## Puts the panel by `cursor`: right of and below it, or on the other side where that would leave
## the window, and in any case inside it.
func _show(text: String, cursor: Vector2) -> void:
	if _label.text != text:
		_label.text = text
		var font := _label.get_theme_font("font")
		var font_size := _label.get_theme_font_size("font_size")
		var width := minf(font.get_multiline_string_size(text, 0, -1, font_size).x, MAX_TEXT_WIDTH)
		_label.custom_minimum_size.x = ceilf(width)
		_label.reset_size()
	_panel.visible = true
	# After the label has wrapped to its width, which takes a frame, the panel shrinks to fit.
	_panel.reset_size()
	var window := get_viewport().get_visible_rect().size
	var panel_size := _panel.get_combined_minimum_size()
	var corner := cursor + CURSOR_OFFSET
	if corner.x + panel_size.x > window.x:
		corner.x = cursor.x - CURSOR_OFFSET.x - panel_size.x
	if corner.y + panel_size.y > window.y:
		corner.y = cursor.y - CURSOR_OFFSET.y - panel_size.y
	var inside := Vector2(
		clampf(corner.x, 0.0, maxf(window.x - panel_size.x, 0.0)),
		clampf(corner.y, 0.0, maxf(window.y - panel_size.y, 0.0))
	)
	_panel.position = inside.round()
