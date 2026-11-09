class_name StorageScreen
extends Modal
## The storage screen over the game, for a chest: the player's backpack on the left (no
## equipment) and the chest's slots on the right (as many as the chest has, 5 to a row), each
## under a small icon. The hotbar is the HUD's, which stays lit and clickable while the screen is
## open, and is used like the backpack's slots. Items are moved by dragging them onto a slot of
## either side (see SlotView): a different item swaps places, the same item stacks. Let go
## outside the panel, a backpack or hotbar stack lands on the ground; let go on the trash can
## under the backpack, a stack of either side is asked about, "Destroy Logs (12)?" (see
## TrashCan); let go anywhere else it stays where it was. Shift+click sends a whole stack to the
## other side (from the chest into the backpack first, so the hotbar isn't flooded).
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
const BACKPACK_ICON := preload("res://assets/ui/backpack_icon.png")
const CHEST_ICON := preload("res://assets/ui/chest_icon.png")

var _hotbar: HotbarHud
var _inventory: Inventory
var _chest: ItemSlots
## The slot views of each side, by slot.
var _views := {INVENTORY: {}, CHEST: {}}
## What the chest's grid of slots is swapped in and out of: the part that grows.
var _chest_holder := VBoxContainer.new()
var _trash_can := TrashCan.new()


func _init(hotbar: HotbarHud) -> void:
	super()
	close_actions = [&"interact"]
	_hotbar = hotbar
	_drop_outside_panel(_hotbar, _on_dropped_outside)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PANEL_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inventory_column := _new_column(BACKPACK_ICON)
	inventory_column.add_child(
		_new_grid(INVENTORY, Inventory.HOTBAR_SIZE, Inventory.SLOT_COUNT, INVENTORY_COLUMNS)
	)
	inventory_column.add_child(_trash_can)
	row.add_child(inventory_column)
	var chest_column := _new_column(CHEST_ICON)
	_chest_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest_column.add_child(_scrolling(_chest_holder))
	row.add_child(chest_column)
	# Stacks let go on the panel outside the slots reach the backdrop, which sends them back.
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)


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
	for side: int in _views:
		for slot: int in _views[side]:
			_views[side][slot].bind_to(_slots_of(side), slot)
	_inventory.changed.connect(_refresh)
	_chest.changed.connect(_refresh)
	_trash_can.keep()
	_hotbar.acquire(self)
	_hotbar.slot_quick_move_requested.connect(_on_hotbar_slot_quick_move_requested)
	_refresh()


## The screen listens to the inventory and the chest only while it is open.
func _on_close() -> void:
	_inventory.changed.disconnect(_refresh)
	_chest.changed.disconnect(_refresh)
	_trash_can.keep()
	# The hotbar may have been freed first, when the whole scene goes.
	if is_instance_valid(_hotbar):
		_hotbar.release(self)
		_hotbar.slot_quick_move_requested.disconnect(_on_hotbar_slot_quick_move_requested)


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
		view.quick_move_requested.connect(_on_slot_quick_move_requested.bind(side, slot))
		grid.add_child(view)
		_views[side][slot] = view
	return grid


func _slots_of(side: int) -> ItemSlots:
	return _inventory if side == INVENTORY else _chest


func _on_slot_quick_move_requested(side: int, slot: int) -> void:
	if side == CHEST:
		_chest.send(slot, _inventory, _inventory.backpack_first_order())
	else:
		_inventory.send(slot, _chest)


func _on_hotbar_slot_quick_move_requested(slot: int) -> void:
	_on_slot_quick_move_requested(INVENTORY, slot)


## Escape answers the trash can's question with Keep, and only then closes the screen.
func _takes_escape() -> bool:
	return _trash_can.keep()


## A stack was let go outside the panel: a backpack or hotbar one lands on the ground.
func _on_dropped_outside(source: SlotView) -> void:
	if source.container == _inventory:
		drop_requested.emit(source.slot)


func _refresh() -> void:
	for side: int in _views:
		var slots := _slots_of(side)
		# The hotbar draws its own slots, which are the first of the backpack's.
		for slot: int in _views[side]:
			var is_held := side == INVENTORY and slot == _inventory.selected_slot
			_views[side][slot].show_stack(slots.slots[slot], is_held)
