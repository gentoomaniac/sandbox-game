class_name StorageScreen
extends Modal
## The storage screen over the game, for a chest: the player's backpack on the left (no
## equipment) and the chest's slots on the right (as many as the chest has, 5 to a row), each
## under a small icon. The hotbar is the HUD's, which stays lit and clickable while the screen is
## open, and is used like the backpack's slots. Click an item to pick it up, then click a
## slot of either side to put it down: a different item swaps places and is picked up in turn
## (it sticks to the mouse), the same item stacks.
## Clicking the picked slot again, or on the panel outside the slots, lets go of the pick; a left
## click outside the panel puts a picked inventory stack on the ground. A click on the trash can
## under the backpack with a stack picked (of either side) asks "Destroy Logs (12)?" (see
## TrashCan); a click elsewhere or Escape answers Keep, and the stack stays picked. Shift+click
## sends a whole stack to the other side (from the chest into the backpack first, so the hotbar
## isn't flooded).
## Like the character screen, it takes the input while it is open (Main sees to that, and closes it
## on E; Escape is the Modal's).

## The player let go of a picked backpack or hotbar stack outside the screen (see GameState
## `drop_from_inventory`).
signal drop_requested(slot: int)

## Which side of the screen a slot is on.
const INVENTORY := 0
const CHEST := 1

const SLOT_GAP := 2
const PANEL_GAP := 16
const COLUMNS := 5
## The backpack is 5 slots wide and 4 rows high.
const INVENTORY_COLUMNS := 5
const PICKED_ALPHA := 0.4
const PICKED_ICON_LAYER := 3
const BACKPACK_ICON := preload("res://assets/ui/backpack_icon.png")
const CHEST_ICON := preload("res://assets/ui/chest_icon.png")

var _hotbar: HotbarHud
var _inventory: Inventory
var _chest: ItemSlots
## The slot views of each side, by slot.
var _views := {INVENTORY: {}, CHEST: {}}
## The slot that is picked up, as {side, slot}; empty for none.
var _pick := {}
var _picked_icon := ItemIcon.new()
## What the chest's grid of slots is swapped in and out of: the part that grows.
var _chest_holder := VBoxContainer.new()
var _trash_can := TrashCan.new()


func _init(hotbar: HotbarHud) -> void:
	super()
	close_actions = [&"interact"]
	_hotbar = hotbar

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PANEL_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inventory_column := _new_column(BACKPACK_ICON)
	inventory_column.add_child(
		_new_grid(INVENTORY, Inventory.HOTBAR_SIZE, Inventory.SLOT_COUNT, INVENTORY_COLUMNS)
	)
	inventory_column.add_child(_trash_can)
	_trash_can.pressed.connect(_on_trash_can_pressed)
	_trash_can.destroy_confirmed.connect(_on_destroy_confirmed)
	for slot in Inventory.HOTBAR_SIZE:
		var view := _hotbar.slot_view(slot)
		_views[INVENTORY][slot] = view
	row.add_child(inventory_column)
	var chest_column := _new_column(CHEST_ICON)
	_chest_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest_column.add_child(_scrolling(_chest_holder))
	row.add_child(chest_column)
	# Clicks on the panel outside the slots let go of the pick, so they reach the backdrop.
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_picked_icon.visible = false
	# On a layer of its own, so the dragged icon is drawn above the hotbar too.
	var icon_layer := CanvasLayer.new()
	icon_layer.layer = PICKED_ICON_LAYER
	icon_layer.add_child(_picked_icon)
	add_child(icon_layer)


## Shows the chest next to the player's inventory. Opening it again moves it to that chest.
func open_chest(chest: WorldObject, player: PlayerState) -> void:
	assert(chest.storage != null, "Not a chest: %s" % chest.type)
	close()
	_inventory = player.inventory
	_chest = chest.storage
	open()


func _on_open() -> void:
	if _views[CHEST].size() != _chest.slots.size():
		_show_chest_slots(_chest.slots.size())
	_inventory.changed.connect(_refresh)
	_chest.changed.connect(_refresh)
	_pick = {}
	_trash_can.keep()
	_hotbar.set_clickable(true)
	_hotbar.slot_pressed.connect(_on_hotbar_slot_pressed)
	_refresh()


## The screen listens to the inventory and the chest only while it is open.
func _on_close() -> void:
	_inventory.changed.disconnect(_refresh)
	_chest.changed.disconnect(_refresh)
	_pick = {}
	_trash_can.keep()
	_picked_icon.visible = false
	_hotbar.set_clickable(false)
	_hotbar.slot_pressed.disconnect(_on_hotbar_slot_pressed)
	# The screen no longer refreshes, so a picked hotbar slot would stay faded.
	for slot in Inventory.HOTBAR_SIZE:
		_hotbar.slot_view(slot).modulate.a = 1.0


func _process(_delta: float) -> void:
	if _picked_icon.visible:
		var middle := _picked_icon.size / 2
		_picked_icon.position = (_backdrop.get_local_mouse_position() - middle).round()


## Makes the grid of the chest's side, for a chest of this many slots. A chest of many slots is
## taller than a small window, so its grid scrolls.
func _show_chest_slots(slot_count: int) -> void:
	for grid in _chest_holder.get_children():
		grid.free()
	_views[CHEST] = {}
	_chest_holder.add_child(_new_grid(CHEST, 0, slot_count, COLUMNS))


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


## A grid of the slots `first` to `last` - 1 of a side.
func _new_grid(side: int, first: int, last: int, columns: int) -> GridContainer:
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
	return grid


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
		var is_swap: bool = _slots_of(picked["side"]).move_to(picked["slot"], slots, slot)
		# After a swap the picked slot holds what was in `slot`: that is the pick now.
		if is_swap:
			_pick = picked
	_refresh()


func _on_hotbar_slot_pressed(slot: int) -> void:
	_on_slot_pressed(INVENTORY, slot)


func _on_trash_can_pressed() -> void:
	if not _pick.is_empty():
		var slots := _slots_of(_pick["side"])
		_trash_can.ask(slots.item_in(_pick["slot"]), slots.slots[_pick["slot"]]["count"])


func _on_destroy_confirmed() -> void:
	_slots_of(_pick["side"]).destroy(_pick["slot"])
	_pick = {}
	_refresh()


## Escape answers the trash can's question with Keep, and only then closes the screen.
func _takes_escape() -> bool:
	return _trash_can.keep()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var is_drop: bool = (
			event.button_index == MOUSE_BUTTON_LEFT
			and not _panel.get_rect().has_point(event.position)
			and not _hotbar.covers(event.position)
		)
		if not _pick.is_empty() and _pick["side"] == INVENTORY and is_drop:
			drop_requested.emit(_pick["slot"])
		_pick = {}
		_refresh()


func _refresh() -> void:
	# Keeps the picked icon valid whatever changed underneath.
	if not _pick.is_empty() and _slots_of(_pick["side"]).item_in(_pick["slot"]) == ItemTypes.NONE:
		_pick = {}
		_trash_can.keep()
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
		_picked_icon.show_item(_slots_of(_pick["side"]).item_in(_pick["slot"]))
