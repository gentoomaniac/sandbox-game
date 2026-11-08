class_name SlotView
extends Control
## One inventory slot on screen: the slot art, the item's icon and, for more than one, its
## count. Left click emits `pressed`, right click `secondary_pressed` (unless it is not
## `is_clickable`, then the click goes on to the game). An empty slot can show
## a faint `hint` of what belongs in it. A slot with an item has its tooltip (see TooltipView);
## `tooltip_id` names it for the debug flag.

signal pressed
signal secondary_pressed

const SIZE := 20
const ICON_OFFSET := Vector2(2, 2)
## Palette colour ink (see tools/art/palette.py); the pixel font is already cream.
const COUNT_SHADOW_COLOR := Color("1d1b26")

const SLOT_TEXTURE := preload("res://assets/ui/slot.png")
const SELECTED_SLOT_TEXTURE := preload("res://assets/ui/slot_selected.png")

## Drawn in an empty slot, if set.
var hint: Texture2D
var tooltip_id := ""
## The hotbar of the HUD is not clickable until a screen that moves items is open.
var is_clickable := true

var _stack := {}
var _icon: Texture2D
var _is_selected := false


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	add_to_group(ArtSet.VIEWS)


func show_stack(stack: Dictionary, is_selected: bool) -> void:
	_stack = stack
	_icon = null if stack.is_empty() else load(ArtSet.path(ItemTypes.icon_path(stack["item"])))
	_is_selected = is_selected
	var text := "" if stack.is_empty() else ItemTooltip.text_for(stack["item"], stack["count"])
	TooltipView.set_text(self, text, tooltip_id)
	queue_redraw()


func show_art_set() -> void:
	show_stack(_stack, _is_selected)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if not is_clickable:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		secondary_pressed.emit()
		accept_event()


func _draw() -> void:
	draw_texture(SELECTED_SLOT_TEXTURE if _is_selected else SLOT_TEXTURE, Vector2.ZERO)
	if _stack.is_empty():
		if hint != null:
			draw_texture(hint, ICON_OFFSET)
		return
	draw_texture(_icon, ICON_OFFSET)
	if _stack["count"] > 1:
		# The font comes from the theme set on a parent (see ui_theme.tres).
		var font := get_theme_default_font()
		var font_size := get_theme_default_font_size()
		var baseline := Vector2(1, SIZE - 3)
		var text := str(_stack["count"])
		draw_string(
			font,
			baseline + Vector2.ONE,
			text,
			HORIZONTAL_ALIGNMENT_RIGHT,
			SIZE - 2,
			font_size,
			COUNT_SHADOW_COLOR
		)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_RIGHT, SIZE - 2, font_size)
