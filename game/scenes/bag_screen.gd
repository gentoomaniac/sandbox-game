class_name BagScreen
extends HotbarWindow
## The bag over the game, opened with B or the bag button on the hotbar: the backpack with the
## carried weight and the trash can. The character with the equipment is the CharacterScreen's.
## The hotbar is the HUD's, which stays lit and clickable while the bag is open, and is used like
## the backpack's slots.
## Items are moved by dragging them (see SlotView): onto another slot, where a different item
## swaps places and the same item stacks. Let go outside the panel, a backpack or hotbar stack
## lands on the ground; let go on the trash can, a stack is asked about, "Destroy Logs (12)?"
## (see TrashCan); let go anywhere else it stays where it was. Shift+click sends a whole stack
## from the backpack to the hotbar or back (onto the same item first), if there is room. Right
## click wears an inventory item. It is docked at the bottom right, above the hotbar, and can be
## open beside the character window (see Modal `dock`).

## The player let go of the picked backpack or hotbar stack outside the screen (see
## GameState `drop_from_inventory`).
signal drop_requested(slot: int)

const SLOT_GAP := 2
## The backpack is 5 slots wide and 4 rows high.
const BACKPACK_COLUMNS := 5
## The longest the weight label gets, to give it room for.
const WIDEST_WEIGHT_TEXT := "Carrying 999.9 / 999.9 kg"

## The views of the backpack's slots below the hotbar, by slot; the hotbar draws its own.
var _backpack_views := {}
var _weight_label := Label.new()
var _trash_can := TrashCan.new()


func _init(hotbar: HotbarHud) -> void:
	super(hotbar)
	dock = Vector2(1, 1)
	dock_inset = Vector2(DOCK_MARGIN, DOCK_MARGIN + HotbarHud.BOTTOM_MARGIN + SlotView.SIZE)
	_drop_outside_panel(_hotbar, _on_dropped_outside)
	_hotbar.bag_requested.connect(_on_bag_requested)

	var backpack_grid := GridContainer.new()
	backpack_grid.columns = BACKPACK_COLUMNS
	backpack_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	backpack_grid.add_theme_constant_override("v_separation", SLOT_GAP)
	backpack_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot in range(Inventory.HOTBAR_SIZE, Inventory.SLOT_COUNT):
		var view := SlotView.new()
		view.tooltip_id = "inventory_%d" % slot
		backpack_grid.add_child(view)
		view.quick_move_requested.connect(_on_inventory_slot_quick_move_requested.bind(slot))
		view.secondary_pressed.connect(_on_inventory_slot_secondary_pressed.bind(slot))
		_backpack_views[slot] = view
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SLOT_GAP)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weight_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(backpack_grid)
	column.add_child(_weight_label)
	column.add_child(_trash_can)
	# Stacks let go on the panel outside the slots reach the backdrop, which sends them back.
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)


## Showing another player lets go of the old one.
func show_player(player: PlayerState) -> void:
	if _player != null:
		close()
		_player.inventory.changed.disconnect(_refresh)
		_player.equipment.changed.disconnect(_refresh)
		_player.attributes.changed.disconnect(_refresh)
	_player = player
	for slot: int in _backpack_views:
		_backpack_views[slot].bind_to(player.inventory, slot)
	player.inventory.changed.connect(_refresh)
	player.equipment.changed.connect(_refresh)
	player.attributes.changed.connect(_refresh)
	_refresh()


func _on_open() -> void:
	_use_hotbar(true)
	_refresh()


func _on_close() -> void:
	_use_hotbar(false)
	_trash_can.keep()
	_refresh()


## The bag button on the hotbar does what the bag's key does (see Main `_screens_take`).
func _on_bag_requested() -> void:
	if can_open_on_key():
		toggle()


## Escape answers the trash can's question with Keep, and only then closes the screen.
func _takes_escape() -> bool:
	return _trash_can.keep()


## A stack was let go outside the panel: a backpack or hotbar one lands on the ground.
func _on_dropped_outside(source: SlotView) -> void:
	if source.container == _player.inventory:
		drop_requested.emit(source.slot)


func _refresh() -> void:
	if _player == null:
		return
	var inventory := _player.inventory
	for slot: int in _backpack_views:
		_backpack_views[slot].show_stack(inventory.slots[slot], slot == inventory.selected_slot)
	_weight_label.text = (
		"Carrying %.1f / %s kg"
		% [_player.carried_weight(), Attributes.number_text(_player.attributes.carry_capacity())]
	)
	# The label is wider than the slots, so it keeps the room of its longest text and the panel
	# does not resize every time the load changes.
	var font := _weight_label.get_theme_font("font")
	var font_size := _weight_label.get_theme_font_size("font_size")
	_weight_label.custom_minimum_size.x = (
		font.get_string_size(WIDEST_WEIGHT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
