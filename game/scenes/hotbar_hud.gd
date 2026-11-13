class_name HotbarHud
extends CanvasLayer
## The hotbar at the bottom centre of the window: the first slots of the inventory, the
## selected one marked. On its own canvas layer like the clock, so the day/night tint doesn't
## touch it. While the character or the storage screen is open the hotbar moves above their
## dimmed backdrop: it stays lit and is their quick bar, its slots clickable (see `acquire`);
## otherwise clicks on it go to the game. The hotbar owns its slot views: a screen borrows the
## whole bar with `acquire` and gives it back with `release`. The bag button sits beside the bar,
## set a little apart from it: clicking it asks for the bag (`bag_requested`).

## A slot was Shift+clicked, or right clicked, while the slots are clickable; the screens that
## have the bar all hear it, and the one that took it last answers (see `is_borrowed_by`).
signal slot_quick_move_requested(slot: int)
signal slot_secondary_pressed(slot: int)
## The bag button was clicked.
signal bag_requested

## While the slots are clickable: above the screens (1), under the fade (2, added later) and
## the menus. Otherwise the hotbar is on layer 1 with the other HUDs.
const CLICKABLE_LAYER := 2
const IDLE_LAYER := 1
const BOTTOM_MARGIN := 4
const SLOT_GAP := 2
## Between the last slot and the bag button.
const BAG_GAP := 8
const WIDTH := Inventory.HOTBAR_SIZE * SlotView.SIZE + (Inventory.HOTBAR_SIZE - 1) * SLOT_GAP
const THEME := preload("res://game/scenes/ui_theme.tres")
const BAG_ICON := preload("res://assets/ui/bag_icon.png")

var _inventory: Inventory
## The screens that have the bar as their quick bar, the one that took it last at the end.
var _borrowers: Array[Object] = []
var _slot_views: Array[SlotView] = []
var _row := HBoxContainer.new()
var _bag_button := Button.new()


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

	# Space is the game's use key: a focused button would take it.
	_bag_button.theme = THEME
	_bag_button.focus_mode = Control.FOCUS_NONE
	# The picture is a child, not the button's icon, which the button's frame would shrink.
	var picture := TextureRect.new()
	picture.texture = BAG_ICON
	picture.position = SlotView.ICON_RECT.position
	picture.size = SlotView.ICON_RECT.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ItemIcon.sharpen(picture)
	_bag_button.add_child(picture)
	_bag_button.pressed.connect(bag_requested.emit)
	TooltipView.set_text(_bag_button, "Open the bag", "bag")
	add_child(_bag_button)
	_bag_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bag_button.offset_left = WIDTH / 2.0 + BAG_GAP
	_bag_button.offset_right = _bag_button.offset_left + SlotView.SIZE
	_bag_button.offset_top = _row.offset_top
	_bag_button.offset_bottom = _row.offset_bottom


## Whether a point of the window (in canvas coordinates) is on the hotbar strip: the slots and the
## gaps between them, the bag button and the gap before it.
func covers(point: Vector2) -> bool:
	return _row.get_global_rect().merge(_bag_button.get_global_rect()).has_point(point)


## Makes the bar the quick bar of `borrower` (a screen that moves items): its slots take clicks
## and are dragged from and onto, and it is lit above the screen. The borrower listens to the
## signals of the bar while it has it. Screens open together (the bag and the
## character window) share the bar: the one that took it last answers the clicks, and the one
## before it again when that closes. The chest and the stations are never open beside another
## screen, so their screens answer the bar's signals without asking.
func acquire(borrower: Object) -> void:
	assert(_inventory != null, "the hotbar shows an inventory before a screen borrows it")
	_borrowers.erase(borrower)
	_borrowers.append(borrower)
	_bind_slots()


## Whether `borrower` is the screen that answers the clicks on the bar.
func is_borrowed_by(borrower: Object) -> bool:
	return not _borrowers.is_empty() and _borrowers.back() == borrower


## Gives the bar back to the game once the last borrower lets go, whatever it left on the slots
## (a stack picked up). Does nothing for one that doesn't have it.
func release(borrower: Object) -> void:
	if not _borrowers.has(borrower):
		return
	_borrowers.erase(borrower)
	for view in _slot_views:
		view.stop_dragging()
	if not _borrowers.is_empty():
		return
	layer = IDLE_LAYER
	for view in _slot_views:
		view.unbind()
		view.is_clickable = false


## Dims the stack in a slot, or shows it plainly again (see SlotView `is_dimmed`). For the
## borrower, which undoes it before `release`.
func dim(slot: int, is_dimmed: bool) -> void:
	_slot_views[slot].is_dimmed = is_dimmed


## Showing another inventory lets go of the old one; a screen that has the bar gets the new one.
func show_inventory(inventory: Inventory) -> void:
	if _inventory != null:
		_inventory.changed.disconnect(_refresh)
	_inventory = inventory
	if not _borrowers.is_empty():
		_bind_slots()
	inventory.changed.connect(_refresh)
	_refresh()


func _bind_slots() -> void:
	layer = CLICKABLE_LAYER
	for slot in Inventory.HOTBAR_SIZE:
		_slot_views[slot].bind_to(_inventory, slot)
		_slot_views[slot].is_clickable = true


func _refresh() -> void:
	for slot in Inventory.HOTBAR_SIZE:
		var stack := _inventory.slots[slot]
		var is_can: bool = (
			not stack.is_empty()
			and ItemTypes.TYPES[stack["item"]].get("tool") == ItemTypes.WATERING_CAN
		)
		_slot_views[slot].show_stack(
			stack, slot == _inventory.selected_slot, str(_inventory.can_water) if is_can else ""
		)
