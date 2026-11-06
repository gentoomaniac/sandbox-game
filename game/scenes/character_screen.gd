class_name CharacterScreen
extends CanvasLayer
## The character screen over the game: the character with the equipment slots around it on the
## left, the backpack with the hotbar as a row below it and the carried weight on the right.
## Click an item to pick it up, then click a slot to put it down: a different item swaps places,
## the same item stacks, and an equipment slot only takes an item that fits (those light up
## while an item is picked up). Clicking the picked slot again, or outside the slots, drops the
## pick. Right click wears an inventory item, or takes a worn one off into the first free slot.

const SLOT_GAP := 2
const COLUMN_GAP := 4
const PANEL_GAP := 12
## Backpack rows as wide as the hotbar row below them.
const BACKPACK_COLUMNS := Inventory.HOTBAR_SIZE
## Space between the backpack and the hotbar row below it.
const HOTBAR_GAP := 8
const MAX_PREVIEW_SCALE := 4
## Kept free round the panel, and the panel's own frame and padding (see ui_theme.tres).
const WINDOW_MARGIN := 8
const PANEL_PADDING := 20
const PICKED_ALPHA := 0.4
const HINT_PATH := "res://assets/ui/equip_%s.png"
const THEME := preload("res://game/scenes/ui_theme.tres")

## The equipment slots left and right of the character, top to bottom.
const LEFT_SLOTS := [Equipment.HEAD, Equipment.BODY, Equipment.LEGS, Equipment.FEET]
const RIGHT_SLOTS := [Equipment.COAT, Equipment.BACK, Equipment.MAIN_HAND, Equipment.OFF_HAND]

var _player: PlayerState
var _inventory_views: Array[SlotView] = []
var _equipment_views := {}
## What is picked up: an inventory slot (an index) or an equipment slot (a name), else none.
var _picked_inventory_slot := -1
var _picked_equipment_slot := ItemTypes.NONE
var _backdrop := ColorRect.new()
var _panel := PanelContainer.new()
var _preview := CharacterPreview.new()
var _left_column := VBoxContainer.new()
var _right_column := VBoxContainer.new()
var _weight_label := Label.new()
var _note_label := Label.new()
var _picked_icon := TextureRect.new()


func _init() -> void:
	visible = false
	_backdrop.color = UiColors.BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	var character_row := HBoxContainer.new()
	character_row.add_theme_constant_override("separation", COLUMN_GAP)
	character_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_equipment_column(_left_column, LEFT_SLOTS, character_row)
	_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_row.add_child(_preview)
	_add_equipment_column(_right_column, RIGHT_SLOTS, character_row)

	var backpack_grid := _new_slot_grid(BACKPACK_COLUMNS)
	var hotbar_grid := _new_slot_grid(Inventory.HOTBAR_SIZE)
	for slot in Inventory.SLOT_COUNT:
		var view := SlotView.new()
		view.tooltip_id = "inventory_%d" % slot
		view.pressed.connect(_on_inventory_slot_pressed.bind(slot))
		view.secondary_pressed.connect(_on_inventory_slot_secondary_pressed.bind(slot))
		(hotbar_grid if slot < Inventory.HOTBAR_SIZE else backpack_grid).add_child(view)
		_inventory_views.append(view)
	var inventory_column := VBoxContainer.new()
	inventory_column.add_theme_constant_override("separation", SLOT_GAP)
	inventory_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [_weight_label, _note_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_column.add_child(backpack_grid)
	var hotbar_gap := Control.new()
	hotbar_gap.custom_minimum_size.y = HOTBAR_GAP - SLOT_GAP
	hotbar_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_column.add_child(hotbar_gap)
	inventory_column.add_child(hotbar_grid)
	inventory_column.add_child(_weight_label)
	inventory_column.add_child(_note_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PANEL_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(character_row)
	row.add_child(inventory_column)
	_panel.theme = THEME
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_backdrop.add_child(_panel)

	_picked_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picked_icon.visible = false
	_backdrop.add_child(_picked_icon)


func show_player(player: PlayerState) -> void:
	_player = player
	_preview.show_appearance(player.appearance)
	player.inventory.changed.connect(_refresh)
	player.equipment.changed.connect(_refresh)
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	_refresh()


func is_open() -> bool:
	return visible


func open() -> void:
	_show(true)


## Safe to call when it is closed.
func close() -> void:
	_show(false)


func toggle() -> void:
	_show(not visible)


func _show(is_shown: bool) -> void:
	visible = is_shown
	_drop_pick()
	_note_label.text = ""
	_refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	# The held tool is synced into the appearance by PlayerView every frame.
	_preview.queue_redraw()
	if _picked_icon.visible:
		var icon_size := _picked_icon.texture.get_size()
		_picked_icon.position = (_backdrop.get_local_mouse_position() - icon_size / 2).round()


func _new_slot_grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", SLOT_GAP)
	grid.add_theme_constant_override("v_separation", SLOT_GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return grid


func _add_equipment_column(column: VBoxContainer, slots: Array, parent: Container) -> void:
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot: StringName in slots:
		var view := SlotView.new()
		view.hint = load(HINT_PATH % slot)
		view.tooltip_id = "equipment_%s" % slot
		view.pressed.connect(_on_equipment_slot_pressed.bind(slot))
		view.secondary_pressed.connect(_on_equipment_slot_secondary_pressed.bind(slot))
		column.add_child(view)
		_equipment_views[slot] = view
	parent.add_child(column)


## Makes the character as large as the window allows (the window gets smaller with the UI
## scale), spreads the equipment slots over its height, and centres the panel.
func _fit_to_window() -> void:
	var room := get_viewport().get_visible_rect().size.y - 2 * (WINDOW_MARGIN + PANEL_PADDING / 2)
	_preview.pixel_scale = clampi(int(room / CharacterPreview.FRAME_SIZE.y), 1, MAX_PREVIEW_SCALE)
	for column: VBoxContainer in [_left_column, _right_column]:
		var slot_count := column.get_child_count()
		var column_height := maxi(int(_preview.custom_minimum_size.y), _tallest_column_height())
		var free_height := column_height - slot_count * SlotView.SIZE
		column.add_theme_constant_override("separation", int(free_height / float(slot_count - 1)))
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## The height of the column with the most slots, with its slots packed closely.
func _tallest_column_height() -> int:
	var slot_count := maxi(LEFT_SLOTS.size(), RIGHT_SLOTS.size())
	return slot_count * SlotView.SIZE + (slot_count - 1) * SLOT_GAP


func _on_inventory_slot_pressed(slot: int) -> void:
	_note_label.text = ""
	if not _has_pick():
		_picked_inventory_slot = slot if not _player.inventory.slots[slot].is_empty() else -1
	elif _picked_inventory_slot != -1:
		_player.inventory.move_to(_picked_inventory_slot, _player.inventory, slot)
		_drop_pick()
	elif _player.equipment.move_to_inventory(_player.inventory, _picked_equipment_slot, slot):
		_drop_pick()
	_refresh()


func _on_equipment_slot_pressed(slot: StringName) -> void:
	_note_label.text = ""
	if not _has_pick():
		_picked_equipment_slot = slot if _player.equipment.item_in(slot) != ItemTypes.NONE else &""
	elif _picked_inventory_slot != -1:
		if _player.equipment.move_to_equipment(_player.inventory, _picked_inventory_slot, slot):
			_drop_pick()
	else:
		_drop_pick()
	_refresh()


func _on_inventory_slot_secondary_pressed(slot: int) -> void:
	_drop_pick()
	_player.equipment.quick_equip(_player.inventory, slot)
	_refresh()


func _on_equipment_slot_secondary_pressed(slot: StringName) -> void:
	_drop_pick()
	var is_worn := _player.equipment.item_in(slot) != ItemTypes.NONE
	var is_off := _player.equipment.quick_unequip(_player.inventory, slot)
	_note_label.text = "Inventory full" if is_worn and not is_off else ""
	_refresh()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_drop_pick()
		_note_label.text = ""
		_refresh()


func _has_pick() -> bool:
	return _picked_inventory_slot != -1 or _picked_equipment_slot != ItemTypes.NONE


func _drop_pick() -> void:
	_picked_inventory_slot = -1
	_picked_equipment_slot = ItemTypes.NONE


func _picked_item() -> StringName:
	if _picked_inventory_slot != -1:
		return _player.inventory.item_in(_picked_inventory_slot)
	return _player.equipment.item_in(_picked_equipment_slot)


func _refresh() -> void:
	if _player == null:
		return
	var inventory := _player.inventory
	for slot in Inventory.SLOT_COUNT:
		var view := _inventory_views[slot]
		view.show_stack(inventory.slots[slot], slot == inventory.selected_slot)
		view.modulate.a = PICKED_ALPHA if slot == _picked_inventory_slot else 1.0
	for slot: StringName in _equipment_views:
		var item := _player.equipment.item_in(slot)
		var view: SlotView = _equipment_views[slot]
		var stack := {} if item == ItemTypes.NONE else {"item": item, "count": 1}
		var fits_picked := _picked_inventory_slot != -1 and Equipment.fits(slot, _picked_item())
		view.show_stack(stack, fits_picked)
		view.modulate.a = PICKED_ALPHA if slot == _picked_equipment_slot else 1.0
	_picked_icon.visible = _has_pick()
	if _has_pick():
		_picked_icon.texture = load(ItemTypes.icon_path(_picked_item()))
	_weight_label.text = "Carrying %.1f kg" % _player.carried_weight()
