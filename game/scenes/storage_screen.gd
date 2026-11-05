class_name StorageScreen
extends CanvasLayer
## The storage screen over the game, for a chest: the player's backpack on the left (no
## equipment) with the hotbar as a row below it, and the chest's slots on the right, each under
## a small icon. Click an item to pick
## it up, then click a slot of either side to put it down: a different item swaps places, the
## same item stacks. Clicking the picked slot again, or outside the slots, drops the pick.
## Shift+click sends a whole stack to the other side (from the chest into the backpack first,
## so the hotbar isn't flooded). Like the character screen, it takes the
## input while it is open (Main sees to that, and closes it on E and Escape).

## Which side of the screen a slot is on.
const INVENTORY := 0
const CHEST := 1

const SLOT_GAP := 2
const PANEL_GAP := 16
const COLUMNS := 5
## The inventory side: backpack rows as wide as the hotbar row below them.
const INVENTORY_COLUMNS := Inventory.HOTBAR_SIZE
## Space between the backpack and the hotbar row below it.
const HOTBAR_GAP := 8
const PICKED_ALPHA := 0.4
## Palette colour ink (see tools/art/generate.py), see-through.
const BACKDROP_COLOR := Color(0.114, 0.106, 0.149, 0.6)
const THEME := preload("res://game/scenes/ui_theme.tres")
const BACKPACK_ICON := preload("res://assets/ui/backpack_icon.png")
const CHEST_ICON := preload("res://assets/ui/chest_icon.png")

var _inventory: Inventory
var _chest: ItemSlots
## The slot views of each side, by slot.
var _views := {INVENTORY: {}, CHEST: {}}
## The slot that is picked up, as {side, slot}; empty for none.
var _pick := {}
var _backdrop := ColorRect.new()
var _panel := PanelContainer.new()
var _picked_icon := TextureRect.new()


func _init() -> void:
	visible = false
	_backdrop.color = BACKDROP_COLOR
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PANEL_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inventory_column := _new_column(BACKPACK_ICON)
	_add_grid(
		inventory_column, INVENTORY, Inventory.HOTBAR_SIZE, Inventory.SLOT_COUNT, INVENTORY_COLUMNS
	)
	var hotbar_gap := Control.new()
	hotbar_gap.custom_minimum_size.y = HOTBAR_GAP - SLOT_GAP
	hotbar_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_column.add_child(hotbar_gap)
	_add_grid(inventory_column, INVENTORY, 0, Inventory.HOTBAR_SIZE, INVENTORY_COLUMNS)
	row.add_child(inventory_column)
	var chest_column := _new_column(CHEST_ICON)
	var chest_slots: int = WorldObjectTypes.TYPES[WorldObjectTypes.CHEST]["storage_slots"]
	_add_grid(chest_column, CHEST, 0, chest_slots, COLUMNS)
	row.add_child(chest_column)
	_panel.theme = THEME
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_backdrop.add_child(_panel)

	_picked_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picked_icon.visible = false
	_backdrop.add_child(_picked_icon)


func is_open() -> bool:
	return visible


## Shows the chest next to the player's inventory.
func open(chest: WorldObject, player: PlayerState) -> void:
	assert(chest.storage != null, "Not a chest: %s" % chest.type)
	_inventory = player.inventory
	_chest = chest.storage
	_inventory.changed.connect(_refresh)
	_chest.changed.connect(_refresh)
	_pick = {}
	visible = true
	_refresh()
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func close() -> void:
	_inventory.changed.disconnect(_refresh)
	_chest.changed.disconnect(_refresh)
	visible = false


func _process(_delta: float) -> void:
	if _picked_icon.visible:
		var icon_size := _picked_icon.texture.get_size()
		_picked_icon.position = (_backdrop.get_local_mouse_position() - icon_size / 2).round()


## A column with an icon at the top.
func _new_column(icon: Texture2D) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := TextureRect.new()
	header.texture = icon
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	return column


## Adds a grid of the slots `first` to `last` - 1 of a side to a column.
func _add_grid(column: VBoxContainer, side: int, first: int, last: int, columns: int) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", SLOT_GAP)
	grid.add_theme_constant_override("v_separation", SLOT_GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot in range(first, last):
		var view := SlotView.new()
		view.tooltip_id = "%s_%d" % ["inventory" if side == INVENTORY else "chest", slot]
		view.pressed.connect(_on_slot_pressed.bind(side, slot))
		grid.add_child(view)
		_views[side][slot] = view
	column.add_child(grid)


func _slots_of(side: int) -> ItemSlots:
	return _inventory if side == INVENTORY else _chest


func _on_slot_pressed(side: int, slot: int) -> void:
	var slots := _slots_of(side)
	if Input.is_key_pressed(KEY_SHIFT):
		_pick = {}
		if side == CHEST:
			slots.send(slot, _inventory, _inventory.backpack_first_order())
		else:
			slots.send(slot, _chest)
	elif _pick.is_empty():
		if not slots.slots[slot].is_empty():
			_pick = {"side": side, "slot": slot}
	else:
		# Dropped first: the move refreshes the screen, which shows a pick that is still there.
		var picked := _pick
		_pick = {}
		_slots_of(picked["side"]).move_to(picked["slot"], slots, slot)
	_refresh()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_pick = {}
		_refresh()


func _refresh() -> void:
	# Keeps the picked icon valid whatever changed underneath.
	if not _pick.is_empty() and _slots_of(_pick["side"]).item_in(_pick["slot"]) == ItemTypes.NONE:
		_pick = {}
	for side: int in _views:
		var slots := _slots_of(side)
		for slot in slots.slots.size():
			var view: SlotView = _views[side][slot]
			var is_held := side == INVENTORY and slot == _inventory.selected_slot
			view.show_stack(slots.slots[slot], is_held)
			var is_picked: bool = (
				not _pick.is_empty() and _pick["side"] == side and _pick["slot"] == slot
			)
			view.modulate.a = PICKED_ALPHA if is_picked else 1.0
	_picked_icon.visible = not _pick.is_empty()
	if not _pick.is_empty():
		_picked_icon.texture = load(
			ItemTypes.icon_path(_slots_of(_pick["side"]).item_in(_pick["slot"]))
		)
