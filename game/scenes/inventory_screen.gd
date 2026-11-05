class_name InventoryScreen
extends CanvasLayer
## All inventory slots in rows of Inventory.HOTBAR_SIZE, over the game. Click an item to pick
## it up, then click a slot to put it down there: a different item swaps places, the same
## item stacks. Clicking the picked slot again, or outside the slots, drops the pick.

const SLOT_GAP := 2
const ROW_GAP := 2
const PICKED_ALPHA := 0.4
## Palette colour ink (see tools/art/generate.py), see-through.
const BACKDROP_COLOR := Color(0.114, 0.106, 0.149, 0.6)
const TEXT_COLOR := Color("f1e6c2")
const TEXT_OUTLINE_COLOR := Color("1d1b26")

var _inventory: Inventory
var _slot_views: Array[SlotView] = []
var _picked_slot := -1
var _weight_label := Label.new()
var _picked_icon := TextureRect.new()
var _backdrop := ColorRect.new()


func _init() -> void:
	visible = false
	_backdrop.color = BACKDROP_COLOR
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer
	for slot in Inventory.SLOT_COUNT:
		if slot % Inventory.HOTBAR_SIZE == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", SLOT_GAP)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(row)
		var view := SlotView.new()
		view.pressed.connect(_on_slot_pressed.bind(slot))
		row.add_child(view)
		_slot_views.append(view)

	_weight_label.add_theme_color_override("font_color", TEXT_COLOR)
	_weight_label.add_theme_color_override("font_outline_color", TEXT_OUTLINE_COLOR)
	_weight_label.add_theme_constant_override("outline_size", 2)
	_weight_label.add_theme_font_size_override("font_size", 8)
	_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weight_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_weight_label)
	_backdrop.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

	_picked_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picked_icon.visible = false
	_backdrop.add_child(_picked_icon)


func show_inventory(inventory: Inventory) -> void:
	_inventory = inventory
	inventory.changed.connect(_refresh)
	_refresh()


func is_open() -> bool:
	return visible


func toggle() -> void:
	visible = not visible
	_picked_slot = -1
	_refresh()


func _process(_delta: float) -> void:
	if _picked_icon.visible:
		var icon_size := _picked_icon.texture.get_size()
		_picked_icon.position = (_backdrop.get_local_mouse_position() - icon_size / 2).round()


func _on_slot_pressed(slot: int) -> void:
	if _picked_slot == -1:
		_picked_slot = slot if not _inventory.slots[slot].is_empty() else -1
	else:
		_inventory.move(_picked_slot, slot)
		_picked_slot = -1
	_refresh()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_picked_slot = -1
		_refresh()


func _refresh() -> void:
	if _inventory == null:
		return
	for slot in Inventory.SLOT_COUNT:
		var view := _slot_views[slot]
		view.show_stack(_inventory.slots[slot], slot == _inventory.selected_slot)
		view.modulate.a = PICKED_ALPHA if slot == _picked_slot else 1.0
	_picked_icon.visible = _picked_slot != -1
	if _picked_slot != -1:
		_picked_icon.texture = load(ItemTypes.icon_path(_inventory.item_in(_picked_slot)))
	_weight_label.text = "Carrying %.1f kg" % _inventory.total_weight()
