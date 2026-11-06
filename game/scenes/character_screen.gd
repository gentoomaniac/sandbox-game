class_name CharacterScreen
extends CanvasLayer
## The character screen over the game: the character with the equipment slots around it on the
## left and the backpack with the carried weight on the right. The hotbar is the HUD's, which
## stays lit and clickable while the screen is open, and is used like the backpack's slots.
## Click an item to pick it up, then click a slot to put it down: a different item swaps places
## and is picked up in turn (it sticks to the mouse), the same item stacks, and an equipment
## slot only takes an item that fits (those light up while an item is picked up). Clicking the
## picked slot again, or outside the slots, drops the pick. Shift+click sends a whole stack from
## the backpack to the hotbar or back (onto the same item first), if there is room. Right click
## wears an inventory item, or takes a worn one off into the first free slot.
## A second tab beside it shows the skills (see SkillsPanel); Tab opens the screen on the
## character, K on the skills.

enum Tab { CHARACTER, SKILLS }

const SLOT_GAP := 2
const COLUMN_GAP := 4
const PANEL_GAP := 12
## The backpack is 5 slots wide and 4 rows high.
const BACKPACK_COLUMNS := 5
const MAX_PREVIEW_SCALE := 4
## Kept free round the panel, and the panel's own frame and padding (see ui_theme.tres).
const WINDOW_MARGIN := 8
const PANEL_PADDING := 20
const PICKED_ALPHA := 0.4
const PICKED_ICON_LAYER := 3
const HINT_PATH := "res://assets/ui/equip_%s.png"
const THEME := preload("res://game/scenes/ui_theme.tres")

## The equipment slots left and right of the character, top to bottom.
const LEFT_SLOTS := [Equipment.HEAD, Equipment.BODY, Equipment.LEGS, Equipment.FEET]
const RIGHT_SLOTS := [Equipment.COAT, Equipment.BACK, Equipment.MAIN_HAND, Equipment.OFF_HAND]

var _player: PlayerState
var _hotbar: HotbarHud
var _is_using_hotbar := false
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
var _tab := Tab.CHARACTER
## The page of each tab, and the button that shows it.
var _pages := {}
var _tab_buttons := {}
var _skills_panel := SkillsPanel.new()


func _init(hotbar: HotbarHud) -> void:
	_hotbar = hotbar
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
	for slot in Inventory.SLOT_COUNT:
		var view: SlotView
		if slot < Inventory.HOTBAR_SIZE:
			view = _hotbar.slot_view(slot)
		else:
			view = SlotView.new()
			view.tooltip_id = "inventory_%d" % slot
			backpack_grid.add_child(view)
			view.pressed.connect(_on_inventory_slot_pressed.bind(slot))
			view.secondary_pressed.connect(_on_inventory_slot_secondary_pressed.bind(slot))
		_inventory_views.append(view)
	var inventory_column := VBoxContainer.new()
	inventory_column.add_theme_constant_override("separation", SLOT_GAP)
	inventory_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [_weight_label, _note_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_column.add_child(backpack_grid)
	inventory_column.add_child(_weight_label)
	inventory_column.add_child(_note_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PANEL_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(character_row)
	row.add_child(inventory_column)
	_pages = {Tab.CHARACTER: row, Tab.SKILLS: _skills_panel}
	var tabs := HBoxContainer.new()
	var tab_group := ButtonGroup.new()
	for tab: Tab in [Tab.CHARACTER, Tab.SKILLS]:
		var button := Button.new()
		button.text = "Character" if tab == Tab.CHARACTER else "Skills"
		button.toggle_mode = true
		button.button_group = tab_group
		button.pressed.connect(_show_tab.bind(tab))
		tabs.add_child(button)
		_tab_buttons[tab] = button
	var page_column := VBoxContainer.new()
	page_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_column.add_child(tabs)
	page_column.add_child(row)
	page_column.add_child(_skills_panel)
	_panel.theme = THEME
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(page_column)
	_backdrop.add_child(_panel)

	_picked_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picked_icon.visible = false
	# On a layer of its own, so the dragged icon is drawn above the hotbar too.
	var icon_layer := CanvasLayer.new()
	icon_layer.layer = PICKED_ICON_LAYER
	icon_layer.add_child(_picked_icon)
	add_child(icon_layer)


func show_player(player: PlayerState) -> void:
	_player = player
	_preview.show_appearance(player.appearance)
	_skills_panel.show_skills(player.skills)
	player.inventory.changed.connect(_refresh)
	player.equipment.changed.connect(_refresh)
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	_refresh()


func is_open() -> bool:
	return visible


func open(tab := Tab.CHARACTER) -> void:
	_show_tab(tab)
	_show(true)


## Safe to call when it is closed.
func close() -> void:
	_show(false)


## Closes the screen if it is open on `tab`, else opens it there.
func toggle(tab := Tab.CHARACTER) -> void:
	if visible and _tab == tab:
		close()
	else:
		open(tab)


func current_tab() -> Tab:
	return _tab


func _show_tab(tab: Tab) -> void:
	_tab = tab
	_drop_pick()
	_note_label.text = ""
	for each: Tab in _pages:
		_pages[each].visible = each == tab
		_tab_buttons[each].set_pressed_no_signal(each == tab)
	_use_hotbar(visible and tab == Tab.CHARACTER)
	_refresh()
	if is_inside_tree():
		_fit_to_window()


func _show(is_shown: bool) -> void:
	visible = is_shown
	_use_hotbar(is_shown and _tab == Tab.CHARACTER)
	_drop_pick()
	_note_label.text = ""
	_refresh()


## Makes the HUD's hotbar this screen's quick bar, or gives it back: the screen listens to its
## clicks and marks its slots only while it is the one using it.
func _use_hotbar(is_used: bool) -> void:
	if is_used == _is_using_hotbar:
		return
	_is_using_hotbar = is_used
	_hotbar.set_clickable(is_used)
	if is_used:
		_hotbar.slot_pressed.connect(_on_inventory_slot_pressed)
		_hotbar.slot_secondary_pressed.connect(_on_inventory_slot_secondary_pressed)
	else:
		_hotbar.slot_pressed.disconnect(_on_inventory_slot_pressed)
		_hotbar.slot_secondary_pressed.disconnect(_on_inventory_slot_secondary_pressed)
		for slot in Inventory.HOTBAR_SIZE:
			_hotbar.slot_view(slot).modulate.a = 1.0


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
	if Input.is_key_pressed(KEY_SHIFT):
		_drop_pick()
		_player.inventory.move_to_other_part(slot)
	elif not _has_pick():
		_picked_inventory_slot = slot if not _player.inventory.slots[slot].is_empty() else -1
	elif _picked_inventory_slot != -1:
		# After a swap the picked slot holds what was in `slot`: that is the pick now.
		var is_swap := _player.inventory.move_to(_picked_inventory_slot, _player.inventory, slot)
		if not is_swap:
			_drop_pick()
	else:
		var is_swap := _player.inventory.item_in(slot) != ItemTypes.NONE
		var is_moved := _player.equipment.move_to_inventory(
			_player.inventory, _picked_equipment_slot, slot
		)
		if is_moved and not is_swap:
			_drop_pick()
	_refresh()


func _on_equipment_slot_pressed(slot: StringName) -> void:
	_note_label.text = ""
	if not _has_pick():
		_picked_equipment_slot = slot if _player.equipment.item_in(slot) != ItemTypes.NONE else &""
	elif _picked_inventory_slot != -1:
		var is_swap := _player.equipment.item_in(slot) != ItemTypes.NONE
		var is_moved := _player.equipment.move_to_equipment(
			_player.inventory, _picked_inventory_slot, slot
		)
		if is_moved and not is_swap:
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
		# The HUD draws its own hotbar slots while this screen doesn't use them.
		if slot < Inventory.HOTBAR_SIZE and not _is_using_hotbar:
			continue
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
	# A move that emptied the picked slot refreshes the screen before the pick is dropped.
	var picked_item := _picked_item() if _has_pick() else ItemTypes.NONE
	_picked_icon.visible = picked_item != ItemTypes.NONE
	if _picked_icon.visible:
		_picked_icon.texture = load(ItemTypes.icon_path(picked_item))
	_weight_label.text = "Carrying %.1f kg" % _player.carried_weight()
