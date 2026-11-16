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

const SLOT_GAP := 2
const PANEL_GAP := 16
const COLUMNS := 5
const CHEST_ICON := preload("res://assets/ui/chest_icon.png")

var _inventory: Inventory
var _chest: ItemSlots
## Moves the goods and tells what was taken out of the chest.
var _transfers: ChestTransfers
var _backpack: BackpackGrid
## The chest's slot views, by slot.
var _chest_views := {}
## What the chest's grid of slots is swapped in and out of: the part that grows.
var _chest_holder := VBoxContainer.new()
var _trash_can := TrashCan.new()


func _init(hotbar: HotbarHud) -> void:
	super()
	close_actions = [&"interact"]
	_drop_outside_panel(hotbar, _on_dropped_outside)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PANEL_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inventory_column := VBoxContainer.new()
	inventory_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backpack = BackpackGrid.new(hotbar)
	_backpack.quick_move_requested.connect(_on_backpack_quick_move_requested)
	inventory_column.add_child(_backpack)
	_trash_can.destroy_rule = _destroy
	inventory_column.add_child(_trash_can)
	row.add_child(inventory_column)
	var chest_column := _new_chest_column()
	_chest_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest_column.add_child(_scrolling(_chest_holder))
	row.add_child(chest_column)
	# Stacks let go on the panel outside the slots reach the backdrop, which sends them back.
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)


## Shows the chest next to the player's inventory. Opening it again moves it to that chest.
func open_chest(chest: WorldObject, state: GameState) -> void:
	close()
	_inventory = state.player.inventory
	_chest = chest.storage
	_transfers = ChestTransfers.new(state, chest)
	open()


func _on_open() -> void:
	if _chest_views.size() != _chest.slots.size():
		_show_chest_slots(_chest.slots.size())
	for slot: int in _chest_views:
		_chest_views[slot].bind_to(_chest, slot)
	_inventory.changed.connect(_refresh)
	_chest.changed.connect(_refresh)
	_trash_can.keep()
	_backpack.bind(_inventory)
	_refresh()


## The screen listens to the inventory and the chest only while it is open.
func _on_close() -> void:
	_inventory.changed.disconnect(_refresh)
	_chest.changed.disconnect(_refresh)
	_trash_can.keep()
	_backpack.unbind()


## Makes the grid of the chest's side, for a chest of this many slots. A chest of many slots is
## taller than a small window, so its grid scrolls.
func _show_chest_slots(slot_count: int) -> void:
	for grid in _chest_holder.get_children():
		grid.free()
	_chest_views.clear()
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", SLOT_GAP)
	grid.add_theme_constant_override("v_separation", SLOT_GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot in slot_count:
		var view := SlotView.new()
		view.tooltip_id = "chest_%d" % slot
		view.quick_move_requested.connect(_on_chest_slot_quick_move_requested.bind(slot))
		view.move_rule = _move
		grid.add_child(view)
		_chest_views[slot] = view
	_chest_holder.add_child(grid)


## The chest's column: its icon over the grid that scrolls.
func _new_chest_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := TextureRect.new()
	header.texture = CHEST_ICON
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	return column


func _on_chest_slot_quick_move_requested(slot: int) -> void:
	_transfers.take_to_backpack(slot)


func _on_backpack_quick_move_requested(slot: int) -> void:
	_transfers.put_in(slot)


## The move rule of the chest's slots (see SlotView `move_rule`): any drag from or onto them moves.
func _move(source: SlotView, target: SlotView, is_dropping: bool) -> bool:
	if is_dropping:
		_transfers.drag(source.container, source.slot, target.container, target.slot)
	return true


## What the trash can destroys: a stack of the chest is told as taken, one of the backpack is not.
func _destroy(source: SlotView) -> void:
	if source.container == _chest:
		_transfers.destroy(source.slot)
	else:
		source.destroy()


## Escape answers the trash can's question with Keep, and only then closes the screen.
func _takes_escape() -> bool:
	return _trash_can.keep()


## A stack was let go outside the panel: a backpack or hotbar one lands on the ground.
func _on_dropped_outside(source: SlotView) -> void:
	if source.container == _inventory:
		drop_requested.emit(source.slot)


func _refresh() -> void:
	for slot: int in _chest_views:
		_chest_views[slot].show_stack(_chest.slots[slot], false)
	_backpack.refresh()
