class_name BackpackGrid
extends VBoxContainer
## The player's backpack on a container screen (a campfire, a process station, a chest): the
## backpack icon over the 5-column grid of its slots, and the HUD's hotbar as the screen's quick
## bar. The screen owns the rules and gives them in: it connects `quick_move_requested` (Shift+click
## on a backpack or hotbar slot) to what that means there, and may set `dims_item` to dim the stacks
## that can't be used now. It calls `bind` when it opens, `refresh` when it opens and when the
## inventory changes, and `unbind` when it closes. Moving stacks about is the slots' business (see
## SlotView, ItemSlots).

## Shift+click on the backpack's or the hotbar's slot of this inventory slot.
signal quick_move_requested(slot: int)

const COLUMNS := 5
const SLOT_GAP := 2
const ICON := preload("res://assets/ui/backpack_icon.png")

## Asked with the item of each non-empty stack, backpack and hotbar, whether to dim it. Without it
## nothing is dimmed.
var dims_item := Callable()
## The backpack's slot views, by inventory slot (the hotbar draws its own).
var views := {}

var _hotbar: HotbarHud
var _inventory: Inventory


func _init(hotbar: HotbarHud) -> void:
	_hotbar = hotbar
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := TextureRect.new()
	header.texture = ICON
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", SLOT_GAP)
	grid.add_theme_constant_override("v_separation", SLOT_GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot in range(Inventory.HOTBAR_SIZE, Inventory.SLOT_COUNT):
		var view := SlotView.new()
		view.tooltip_id = "inventory_%d" % slot
		view.quick_move_requested.connect(quick_move_requested.emit.bind(slot))
		grid.add_child(view)
		views[slot] = view
	add_child(grid)


## Shows `inventory` and takes the hotbar as the quick bar. Does not listen to the
## inventory or draw it (see `refresh`).
func bind(inventory: Inventory) -> void:
	_inventory = inventory
	for slot: int in views:
		views[slot].bind_to(inventory, slot)
	_hotbar.acquire(self)
	_hotbar.slot_quick_move_requested.connect(quick_move_requested.emit)


## Gives the hotbar back, plain again.
func unbind() -> void:
	# The hotbar may have been freed first, when the whole scene goes.
	if is_instance_valid(_hotbar):
		for slot in Inventory.HOTBAR_SIZE:
			_hotbar.dim(slot, false)
		_hotbar.release(self)
		_hotbar.slot_quick_move_requested.disconnect(quick_move_requested.emit)


func refresh() -> void:
	for slot: int in views:
		views[slot].show_stack(_inventory.slots[slot], false)
		views[slot].is_dimmed = _is_dimmed(slot)
	for slot in Inventory.HOTBAR_SIZE:
		_hotbar.dim(slot, _is_dimmed(slot))


func _is_dimmed(slot: int) -> bool:
	return (
		dims_item.is_valid()
		and not _inventory.slots[slot].is_empty()
		and dims_item.call(_inventory.item_in(slot))
	)
