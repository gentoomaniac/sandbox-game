class_name HotbarHud
extends CanvasLayer
## The hotbar at the bottom centre of the window: the first slots of the inventory, the
## selected one marked. On its own canvas layer like the clock, so the day/night tint doesn't
## touch it. While the character or the storage screen is open the hotbar moves above their
## dimmed backdrop: it stays lit and is their quick bar, its slots clickable (see `acquire`);
## otherwise clicks on it go to the game. The hotbar owns its slot views: a screen borrows the
## whole bar with `acquire` and gives it back with `release`.

## A slot was Shift+clicked, or right clicked, while the slots are clickable; one screen at a
## time listens (while open).
signal slot_quick_move_requested(slot: int)
signal slot_secondary_pressed(slot: int)

## While the slots are clickable: above the screens (1), under the fade (2, added later) and
## the menus. Otherwise the hotbar is on layer 1 with the other HUDs.
const CLICKABLE_LAYER := 2
const IDLE_LAYER := 1
const BOTTOM_MARGIN := 4
const SLOT_GAP := 2
const WIDTH := Inventory.HOTBAR_SIZE * SlotView.SIZE + (Inventory.HOTBAR_SIZE - 1) * SLOT_GAP
const THEME := preload("res://game/scenes/ui_theme.tres")

var _inventory: Inventory
## The screen that has the bar as its quick bar, if any.
var _borrower: Object
var _slot_views: Array[SlotView] = []
var _row := HBoxContainer.new()


func _init() -> void:
	layer = IDLE_LAYER
	_row.theme = THEME
	_row.add_theme_constant_override("separation", SLOT_GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot in Inventory.HOTBAR_SIZE:
		var view := SlotView.new()
		# Passes clicks on to the game, but is still hovered for its tooltip.
		view.mouse_filter = Control.MOUSE_FILTER_PASS
		view.is_clickable = false
		view.tooltip_id = "hotbar_%d" % slot
		view.quick_move_requested.connect(slot_quick_move_requested.emit.bind(slot))
		view.secondary_pressed.connect(slot_secondary_pressed.emit.bind(slot))
		_row.add_child(view)
		_slot_views.append(view)
	add_child(_row)
	# Offsets from the bottom centre are set by hand, so the row is centred exactly.
	_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_row.offset_left = -WIDTH / 2.0
	_row.offset_right = WIDTH / 2.0
	_row.offset_top = -BOTTOM_MARGIN - SlotView.SIZE
	_row.offset_bottom = -BOTTOM_MARGIN


## Whether a point of the window (in canvas coordinates) is on the hotbar, between slots too.
func covers(point: Vector2) -> bool:
	return _row.get_global_rect().has_point(point)


## Makes the bar the quick bar of `borrower` (a screen that moves items): its slots take clicks
## and are dragged from and onto, and it is lit above the screen. The borrower listens to the
## signals of the bar while it has it. Asking again takes it over from the one that had it.
func acquire(borrower: Object) -> void:
	assert(_inventory != null, "the hotbar shows an inventory before a screen borrows it")
	_borrower = borrower
	layer = CLICKABLE_LAYER
	for slot in Inventory.HOTBAR_SIZE:
		_slot_views[slot].bind_to(_inventory, slot)
		_slot_views[slot].is_clickable = true


## Gives the bar back to the game, whatever the borrower left on its slots (a stack picked up).
## Does nothing for one that doesn't have it.
func release(borrower: Object) -> void:
	if borrower != _borrower:
		return
	_borrower = null
	layer = IDLE_LAYER
	for view in _slot_views:
		view.unbind()
		view.is_clickable = false
		view.stop_dragging()


func show_inventory(inventory: Inventory) -> void:
	_inventory = inventory
	inventory.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for slot in Inventory.HOTBAR_SIZE:
		_slot_views[slot].show_stack(_inventory.slots[slot], slot == _inventory.selected_slot)
