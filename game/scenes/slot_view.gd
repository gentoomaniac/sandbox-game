class_name SlotView
extends Control
## One inventory slot on screen: the slot art, the item's icon and, for more than one, its
## count. A slot that is bound (`bind_to`) to a row of item slots (a backpack, a chest) or to the
## equipment is where stacks are moved, by dragging, which is all the inventory screens do with
## the left mouse button: press on a stack and drag it (its icon follows the mouse while the
## button is held), and let go over a slot to put it there. A different item swaps places, the
## same item merges, and an equipment slot only takes an item that fits (those light up while
## one is dragged). Letting go anywhere else is up to the screen (see Modal `_drop_outside_panel`)
## and the TrashCan; a stack let go over nothing stays where it was. Shift+left click emits
## `quick_move_requested` and right click `secondary_pressed` (unless it is not `is_clickable`,
## then the click goes on to the game). An empty slot can show a faint `hint` of what belongs in
## it. A slot with an item has its tooltip (see TooltipView); `tooltip_id` names it for the debug
## flag. A screen may take over the moves onto and off a slot (`move_rule`) and dim its stack
## (`is_dimmed`), as a process station's window does.

## A stack was dragged onto this slot and moved.
signal stack_dropped_here
signal quick_move_requested
signal secondary_pressed

const SIZE := 20
## Where the item's icon is drawn, fitted into ItemIcon.SIZE whatever its own size.
const ICON_RECT := Rect2(2, 2, ItemIcon.SIZE, ItemIcon.SIZE)
## Palette colour ink (see tools/art/palette.py); the pixel font is already cream.
const COUNT_SHADOW_COLOR := Color("1d1b26")
## A dimmed stack's icon.
const DIMMED_COLOR := Color(0.5, 0.5, 0.5, 0.35)
## The small number on a watering can (foam of the palette) and its size.
const BADGE_COLOR := Color("92b4bd")
const BADGE_FONT_SIZE := 8
## The slot a stack is dragged from fades, as it is the icon that moves.
const DRAGGED_ALPHA := 0.4
## The layer of the dragged icon: above the screens and the HUD's hotbar, which Godot's own drag
## preview would not be (it stays on the canvas layer of the slot it comes from).
const DRAG_ICON_LAYER := 3

const SLOT_TEXTURE := preload("res://assets/ui/slot.png")
const SELECTED_SLOT_TEXTURE := preload("res://assets/ui/slot_selected.png")

## Drawn in an empty slot, if set.
var hint: Texture2D
var tooltip_id := ""
## A small number in the top left corner, if not empty (see `show_stack`).
var badge := ""
## The hotbar of the HUD is not clickable until a screen that moves items is open.
var is_clickable := true
## Set by a screen that moves stacks to or from this slot its own way (a process station's grid,
## which takes only some and never swaps): func(source: SlotView, target: SlotView,
## is_dropping: bool) -> bool, asked whether `source`'s stack may be let go on `target`, and
## told to move it when it is. A drag uses the rule of the slot it ends on, or else of the one it
## came from.
var move_rule: Callable
## Drawn faded: the stack can't be used here now.
var is_dimmed := false:
	set(value):
		is_dimmed = value
		queue_redraw()
## What the slot shows and moves stacks of: an ItemSlots (`slot` is an index) or an Equipment
## (`slot` is a slot name). Without a container, nothing is dragged from or onto the slot.
var container: Object
var slot: Variant

var _stack := {}
var _icon: Texture2D
var _is_selected := false
## Lit while a stack that fits this slot is dragged.
var _is_drop_target := false
var _drag_icon_layer: CanvasLayer


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	add_to_group(ArtSet.VIEWS)
	ItemIcon.sharpen(self)


## Only a dragged stack's icon needs following the mouse every frame.
func _ready() -> void:
	set_process(false)


## The slot a drag came from, or null if `data` is not a drag of a slot's stack.
static func source_of(data: Variant) -> SlotView:
	return data.get("from") if data is Dictionary else null


func bind_to(slots: Object, slot_key: Variant) -> void:
	container = slots
	slot = slot_key


## Leaves the container, so nothing is dragged from or onto the slot.
func unbind() -> void:
	container = null
	slot = null


## Ends a pick-up of the slot's stack: the slot looks as it did before, the dragged icon is gone.
func stop_dragging() -> void:
	_is_drop_target = false
	modulate.a = 1.0
	if _drag_icon_layer != null:
		_drag_icon_layer.queue_free()
		_drag_icon_layer = null
		set_process(false)
	queue_redraw()


func item() -> StringName:
	return _stack.get("item", ItemTypes.NONE)


func count() -> int:
	return _stack.get("count", 0)


## Destroys the stack for good (the trash can).
func destroy() -> void:
	container.destroy(slot)


## `badge`, if given, is drawn small in the top left corner: the water in a watering can.
func show_stack(stack: Dictionary, is_selected: bool, new_badge := "") -> void:
	_stack = stack
	badge = new_badge
	_icon = null if stack.is_empty() else load(ArtSet.path(ItemTypes.icon_path(stack["item"])))
	_is_selected = is_selected
	var text := "" if stack.is_empty() else ItemTooltip.text_for(stack["item"], stack["count"])
	TooltipView.set_text(self, text, tooltip_id)
	queue_redraw()


func show_art_set() -> void:
	show_stack(_stack, _is_selected, badge)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if not is_clickable:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.shift_pressed:
			quick_move_requested.emit()
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		secondary_pressed.emit()
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_clickable or container == null or _stack.is_empty():
		return null
	var icon := ItemIcon.new()
	icon.show_item(item())
	_drag_icon_layer = CanvasLayer.new()
	_drag_icon_layer.layer = DRAG_ICON_LAYER
	_drag_icon_layer.add_child(icon)
	add_child(_drag_icon_layer)
	_center_drag_icon_on_mouse()
	set_process(true)
	modulate.a = DRAGGED_ALPHA
	return {"from": self}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var source := source_of(data)
	if container == null or source == null or source == self or source.item() == ItemTypes.NONE:
		return false
	var rule := _move_rule_with(source)
	if rule.is_valid():
		return rule.call(source, self, false)
	if container is Equipment:
		return source.container is Inventory and Equipment.fits(slot, source.item())
	if source.container is Equipment:
		return container is Inventory and (_stack.is_empty() or Equipment.fits(source.slot, item()))
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source := source_of(data)
	var rule := _move_rule_with(source)
	if rule.is_valid():
		rule.call(source, self, true)
	elif container is Equipment:
		container.move_to_equipment(source.container, source.slot, slot)
	elif source.container is Equipment:
		source.container.move_to_inventory(container, source.slot, slot)
	else:
		source.container.move_to(source.slot, container, slot)
	stack_dropped_here.emit()


## The rule of a drag from `source` onto this slot: this slot's, or else the source's.
func _move_rule_with(source: SlotView) -> Callable:
	return move_rule if move_rule.is_valid() else source.move_rule


func _process(_delta: float) -> void:
	_center_drag_icon_on_mouse()


func _center_drag_icon_on_mouse() -> void:
	var icon: ItemIcon = _drag_icon_layer.get_child(0)
	icon.position = (icon.get_global_mouse_position() - icon.size / 2).round()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_is_drop_target = (
			container is Equipment
			and _can_drop_data(Vector2.ZERO, get_viewport().gui_get_drag_data())
		)
		queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		stop_dragging()


func _draw() -> void:
	draw_texture(
		SELECTED_SLOT_TEXTURE if _is_selected or _is_drop_target else SLOT_TEXTURE, Vector2.ZERO
	)
	if _stack.is_empty():
		if hint != null:
			draw_texture_rect(hint, ICON_RECT, false)
		return
	draw_texture_rect(_icon, ICON_RECT, false, DIMMED_COLOR if is_dimmed else Color.WHITE)
	if badge != "":
		var badge_font := get_theme_default_font()
		var top_left := Vector2(2, badge_font.get_ascent(BADGE_FONT_SIZE) + 1)
		draw_string(
			badge_font,
			top_left + Vector2.ONE,
			badge,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			BADGE_FONT_SIZE,
			COUNT_SHADOW_COLOR
		)
		draw_string(
			badge_font, top_left, badge, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT_SIZE, BADGE_COLOR
		)
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
