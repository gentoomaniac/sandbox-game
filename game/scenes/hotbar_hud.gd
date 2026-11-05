class_name HotbarHud
extends CanvasLayer
## The hotbar at the bottom centre of the window: the first slots of the inventory, the
## selected one marked. On its own canvas layer like the clock, so the day/night tint doesn't
## touch it.

const BOTTOM_MARGIN := 4
const SLOT_GAP := 2
const THEME := preload("res://game/scenes/ui_theme.tres")

var _inventory: Inventory
var _slot_views: Array[SlotView] = []


func _init() -> void:
	var row := HBoxContainer.new()
	row.theme = THEME
	row.add_theme_constant_override("separation", SLOT_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot in Inventory.HOTBAR_SIZE:
		var view := SlotView.new()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(view)
		_slot_views.append(view)
	add_child(row)
	row.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, BOTTOM_MARGIN
	)


func show_inventory(inventory: Inventory) -> void:
	_inventory = inventory
	inventory.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for slot in Inventory.HOTBAR_SIZE:
		_slot_views[slot].show_stack(_inventory.slots[slot], slot == _inventory.selected_slot)
