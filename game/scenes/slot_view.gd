class_name SlotView
extends Control
## One inventory slot on screen: the slot art, the item's icon and, for more than one, its
## count. Left click emits `pressed`.

signal pressed

const SIZE := 20
const ICON_OFFSET := Vector2(2, 2)
const FONT_SIZE := 8
const COUNT_OUTLINE_SIZE := 2
## Palette colours cream and ink (see tools/art/generate.py).
const COUNT_COLOR := Color("f1e6c2")
const COUNT_OUTLINE_COLOR := Color("1d1b26")

const SLOT_TEXTURE := preload("res://assets/ui/slot.png")
const SELECTED_SLOT_TEXTURE := preload("res://assets/ui/slot_selected.png")

var _stack := {}
var _icon: Texture2D
var _is_selected := false


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)


func show_stack(stack: Dictionary, is_selected: bool) -> void:
	_stack = stack
	_icon = null if stack.is_empty() else load(ItemTypes.icon_path(stack["item"]))
	_is_selected = is_selected
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _draw() -> void:
	draw_texture(SELECTED_SLOT_TEXTURE if _is_selected else SLOT_TEXTURE, Vector2.ZERO)
	if _stack.is_empty():
		return
	draw_texture(_icon, ICON_OFFSET)
	if _stack["count"] > 1:
		var font := ThemeDB.fallback_font
		var baseline := Vector2(1, SIZE - 2)
		var text := str(_stack["count"])
		draw_string_outline(
			font,
			baseline,
			text,
			HORIZONTAL_ALIGNMENT_RIGHT,
			SIZE - 2,
			FONT_SIZE,
			COUNT_OUTLINE_SIZE,
			COUNT_OUTLINE_COLOR
		)
		draw_string(
			font, baseline, text, HORIZONTAL_ALIGNMENT_RIGHT, SIZE - 2, FONT_SIZE, COUNT_COLOR
		)
