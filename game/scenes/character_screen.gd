class_name CharacterScreen
extends Modal
## The character screen over the game: the character with the equipment slots around it on the
## left and the backpack with the carried weight on the right. The hotbar is the HUD's, which
## stays lit and clickable while the screen is open, and is used like the backpack's slots.
## Items are moved by dragging them (see SlotView): onto another slot, where a different item
## swaps places and the same item stacks, and an equipment slot only takes an item that fits
## (those light up while one is dragged). Let go outside the panel, a backpack or hotbar stack
## lands on the ground; let go on the trash can, a stack is asked about, "Destroy Logs (12)?"
## (see TrashCan); let go anywhere else it stays where it was. Shift+click sends a whole stack
## from the backpack to the hotbar or back (onto the same item first), if there is room. Right
## click wears an inventory item, or takes a worn one off into the first free slot.
## A second tab beside it shows the skills (see SkillsPanel); Tab opens the screen on the
## character, K on the skills (`open_tab`, `toggle_tab`; `open()` opens the character).

## The player let go of the picked backpack or hotbar stack outside the screen (see
## GameState `drop_from_inventory`).
signal drop_requested(slot: int)

enum Tab { CHARACTER, SKILLS }

const SLOT_GAP := 2
const COLUMN_GAP := 4
const PANEL_GAP := 12
## The backpack is 5 slots wide and 4 rows high.
const BACKPACK_COLUMNS := 5
const MAX_PREVIEW_SCALE := 2
## Kept free round the character, and the panel's own frame and padding (see ui_theme.tres).
const WINDOW_MARGIN := 8
const PANEL_PADDING := 20
const HINT_PATH := "res://assets/ui/equip_%s.png"

## The equipment slots left and right of the character, top to bottom.
const LEFT_SLOTS := [Equipment.HEAD, Equipment.BODY, Equipment.LEGS, Equipment.FEET]
const RIGHT_SLOTS := [Equipment.COAT, Equipment.BACK, Equipment.MAIN_HAND, Equipment.OFF_HAND]

var _player: PlayerState
var _hotbar: HotbarHud
var _is_using_hotbar := false
## The views of the backpack's slots below the hotbar, by slot; the hotbar draws its own.
var _backpack_views := {}
var _equipment_views := {}
var _preview := CharacterPreview.new()
var _left_column := VBoxContainer.new()
var _right_column := VBoxContainer.new()
var _weight_label := Label.new()
var _note_label := Label.new()
var _trash_can := TrashCan.new()
var _tab := Tab.CHARACTER
## The page of each tab, and the button that shows it.
var _pages := {}
var _tab_buttons := {}
var _skills_panel := SkillsPanel.new()


func _init(hotbar: HotbarHud) -> void:
	super()
	_hotbar = hotbar
	_drop_outside_panel(_hotbar, _on_dropped_outside)

	var character_row := HBoxContainer.new()
	character_row.add_theme_constant_override("separation", COLUMN_GAP)
	character_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_equipment_column(_left_column, LEFT_SLOTS, character_row)
	_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_row.add_child(_preview)
	_add_equipment_column(_right_column, RIGHT_SLOTS, character_row)

	var backpack_grid := _new_slot_grid(BACKPACK_COLUMNS)
	for slot in range(Inventory.HOTBAR_SIZE, Inventory.SLOT_COUNT):
		var view := SlotView.new()
		view.tooltip_id = "inventory_%d" % slot
		backpack_grid.add_child(view)
		view.quick_move_requested.connect(_on_inventory_slot_quick_move_requested.bind(slot))
		view.secondary_pressed.connect(_on_inventory_slot_secondary_pressed.bind(slot))
		_backpack_views[slot] = view
	var inventory_column := VBoxContainer.new()
	inventory_column.add_theme_constant_override("separation", SLOT_GAP)
	inventory_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [_weight_label, _note_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_column.add_child(backpack_grid)
	inventory_column.add_child(_weight_label)
	inventory_column.add_child(_note_label)
	inventory_column.add_child(_trash_can)

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
	# Stacks let go on the panel outside the slots reach the backdrop, which sends them back.
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(page_column)


func show_player(player: PlayerState) -> void:
	_player = player
	_preview.show_appearance(player.appearance)
	_skills_panel.show_skills(player.skills)
	for slot: int in _backpack_views:
		_backpack_views[slot].bind_to(player.inventory, slot)
	for slot: StringName in _equipment_views:
		_equipment_views[slot].bind_to(player.equipment, slot)
	player.inventory.changed.connect(_refresh)
	player.equipment.changed.connect(_refresh)
	get_viewport().size_changed.connect(_fit_character)
	_fit_character()
	_refresh()


## Opens the screen on `tab`, or switches to it when the screen is open.
func open_tab(tab: Tab) -> void:
	if visible:
		_show_tab(tab)
	else:
		_tab = tab
		open()


## Closes the screen if it is open on `tab`, else opens it there.
func toggle_tab(tab: Tab) -> void:
	if visible and _tab == tab:
		close()
	else:
		open_tab(tab)


func current_tab() -> Tab:
	return _tab


func _show_tab(tab: Tab) -> void:
	_tab = tab
	_trash_can.keep()
	for each: Tab in _pages:
		_pages[each].visible = each == tab
		_tab_buttons[each].set_pressed_no_signal(each == tab)
	_use_hotbar(visible and tab == Tab.CHARACTER)
	_refresh()
	if is_inside_tree():
		_fit_character()


func _on_open() -> void:
	_show_tab(_tab)


## `open()` opens the character, so the tab is back to it once the screen is closed.
func _on_close() -> void:
	_tab = Tab.CHARACTER
	_use_hotbar(false)
	_trash_can.keep()
	_refresh()


## Makes the HUD's hotbar this screen's quick bar, or gives it back: the screen listens to its
## clicks only while it is the one using it.
func _use_hotbar(is_used: bool) -> void:
	# The hotbar may have been freed first, when the whole scene goes.
	if is_used == _is_using_hotbar or not is_instance_valid(_hotbar):
		return
	_is_using_hotbar = is_used
	if is_used:
		_hotbar.acquire(self)
		_hotbar.slot_quick_move_requested.connect(_on_inventory_slot_quick_move_requested)
		_hotbar.slot_secondary_pressed.connect(_on_inventory_slot_secondary_pressed)
	else:
		_hotbar.release(self)
		_hotbar.slot_quick_move_requested.disconnect(_on_inventory_slot_quick_move_requested)
		_hotbar.slot_secondary_pressed.disconnect(_on_inventory_slot_secondary_pressed)


func _process(_delta: float) -> void:
	if not visible:
		return
	# The held tool is synced into the appearance by PlayerView every frame.
	_preview.queue_redraw()


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
		view.secondary_pressed.connect(_on_equipment_slot_secondary_pressed.bind(slot))
		column.add_child(view)
		_equipment_views[slot] = view
	parent.add_child(column)


## Makes the character as large as the window allows (the window gets smaller with the UI
## scale) and spreads the equipment slots over its height. The panel follows its contents and
## stays centred by itself (see Modal).
func _fit_character() -> void:
	var room := get_viewport().get_visible_rect().size.y - 2 * (WINDOW_MARGIN + PANEL_PADDING / 2)
	_preview.pixel_scale = clampi(int(room / CharacterPreview.SHOWN_SIZE.y), 1, MAX_PREVIEW_SCALE)
	for column: VBoxContainer in [_left_column, _right_column]:
		var slot_count := column.get_child_count()
		var column_height := maxi(int(_preview.custom_minimum_size.y), _tallest_column_height())
		var free_height := column_height - slot_count * SlotView.SIZE
		column.add_theme_constant_override("separation", int(free_height / float(slot_count - 1)))


## The height of the column with the most slots, with its slots packed closely.
func _tallest_column_height() -> int:
	var slot_count := maxi(LEFT_SLOTS.size(), RIGHT_SLOTS.size())
	return slot_count * SlotView.SIZE + (slot_count - 1) * SLOT_GAP


func _on_inventory_slot_quick_move_requested(slot: int) -> void:
	_player.inventory.move_to_other_part(slot)


func _on_inventory_slot_secondary_pressed(slot: int) -> void:
	_player.equipment.quick_equip(_player.inventory, slot)


func _on_equipment_slot_secondary_pressed(slot: StringName) -> void:
	var is_worn := _player.equipment.item_in(slot) != ItemTypes.NONE
	var is_off := _player.equipment.quick_unequip(_player.inventory, slot)
	_note_label.text = "Inventory full" if is_worn and not is_off else ""


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
	_note_label.text = ""
	var inventory := _player.inventory
	for slot: int in _backpack_views:
		_backpack_views[slot].show_stack(inventory.slots[slot], slot == inventory.selected_slot)
	for slot: StringName in _equipment_views:
		var item := _player.equipment.item_in(slot)
		var stack := {} if item == ItemTypes.NONE else {"item": item, "count": 1}
		_equipment_views[slot].show_stack(stack, false)
	_weight_label.text = "Carrying %.1f kg" % _player.carried_weight()
