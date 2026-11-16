class_name CharacterScreen
extends HotbarWindow
## The character window over the game, opened with C: the character with the equipment slots
## around it. The items are the bag's (see BagScreen). The hotbar is the HUD's, which stays lit and
## clickable while the window is open on the character: a stack dragged from it onto an equipment
## slot is worn, a worn item dragged onto it is taken off, and right click wears or takes off.
## An equipment slot only takes an item that fits (those light up while one is dragged).
## Below them the attributes and what they give (see AttributesPanel).
## A second tab beside it shows the skills (see SkillsPanel), a third the quests the player has
## taken (see QuestsPanel) and a fourth the neighbours and how well they know the player (see
## NeighboursPanel); C opens the window on the character, K on the skills, J on the quests
## (`open_tab`, `toggle_tab`; `open()` opens the character). The neighbours have no key yet.
## It is docked in the middle of the screen, and can be open beside the bag (see Modal `dock`).

enum Tab { CHARACTER, SKILLS, QUESTS, NEIGHBOURS }

const SLOT_GAP := 2
const COLUMN_GAP := 4
const MAX_PREVIEW_SCALE := 2
## Kept free round the character, and the panel's own frame and padding (see ui_theme.tres).
const WINDOW_MARGIN := 8
const PANEL_PADDING := 20
const HINT_PATH := "res://assets/ui/equip_%s.png"

## The equipment slots left and right of the character, top to bottom.
const LEFT_SLOTS := [Equipment.HEAD, Equipment.BODY, Equipment.LEGS, Equipment.FEET]
const RIGHT_SLOTS := [Equipment.COAT, Equipment.BACK, Equipment.MAIN_HAND, Equipment.OFF_HAND]

var _equipment_views := {}
var _preview := CharacterPreview.new()
var _left_column := VBoxContainer.new()
var _right_column := VBoxContainer.new()
var _note_label := Label.new()
var _tab: Variant = Tab.CHARACTER
## The page of each tab by its id, with its button, lists and on-show (see `add_page`).
var _pages := {}
var _tab_row := HBoxContainer.new()
var _tab_group := ButtonGroup.new()
var _page_column := VBoxContainer.new()
var _skills_panel := SkillsPanel.new()
var _quests_panel := QuestsPanel.new()
var _neighbours_panel := NeighboursPanel.new()
var _attributes_panel := AttributesPanel.new()


func _init(hotbar: HotbarHud) -> void:
	super(hotbar)
	is_docked = true

	var character_row := HBoxContainer.new()
	character_row.add_theme_constant_override("separation", COLUMN_GAP)
	character_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_equipment_column(_left_column, LEFT_SLOTS, character_row)
	_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_row.add_child(_preview)
	_add_equipment_column(_right_column, RIGHT_SLOTS, character_row)
	_note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var character_page := VBoxContainer.new()
	character_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_page.add_child(character_row)
	character_page.add_child(_attributes_panel)
	character_page.add_child(_note_label)

	_page_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_column.add_child(_tab_row)
	_panel.add_child(_page_column)
	add_page(Tab.CHARACTER, "Character", character_page)
	add_page(Tab.SKILLS, "Skills", _skills_panel, [_skills_panel.list])
	add_page(Tab.QUESTS, "Quests", _quests_panel, [_quests_panel.list], _quests_panel.refresh)
	add_page(
		Tab.NEIGHBOURS,
		"Neighbours",
		_neighbours_panel,
		[_neighbours_panel.list],
		_neighbours_panel.refresh
	)


## Adds a tab: its button, titled `title`, and its `page`, shown in place of the others when the
## button is pressed or `open_tab(id)` is called. `lists` are the scrolling lists in the page, which
## start at the top and fit the window when it is shown; `on_show` runs after they are fitted, to
## fill the page. The tabs are in the order they were added. `id` is what `open_tab` takes: a Tab
## for the tabs here, any other value for a tab a feature adds.
func add_page(
	id: Variant,
	title: String,
	page: Control,
	lists: Array[ScrollingList] = [],
	on_show := Callable()
) -> void:
	var button := Button.new()
	button.text = title
	button.toggle_mode = true
	button.button_group = _tab_group
	button.pressed.connect(_show_tab.bind(id))
	_tab_row.add_child(button)
	_page_column.add_child(page)
	_pages[id] = {"page": page, "button": button, "lists": lists, "on_show": on_show}
	_lists.append_array(lists)


## Showing another player lets go of the old one.
func show_player(player: PlayerState) -> void:
	if _player != null:
		close()
		_player.equipment.changed.disconnect(_refresh)
		get_viewport().size_changed.disconnect(_fit_character)
	_player = player
	_preview.show_appearance(player.appearance)
	_skills_panel.show_skills(player.skills)
	_attributes_panel.show_attributes(player.attributes)
	for slot: StringName in _equipment_views:
		_equipment_views[slot].bind_to(player.equipment, slot)
	player.equipment.changed.connect(_refresh)
	get_viewport().size_changed.connect(_fit_character)
	_fit_character()
	_refresh()


## Shows the quests of the game of `state` on the quests tab.
func show_quests(state: GameState) -> void:
	_quests_panel.show_quests(state)


## Shows the villagers of the game of `state` on the neighbours tab.
func show_neighbours(state: GameState) -> void:
	_neighbours_panel.show_neighbours(state)


## Opens the window on `tab`, or switches to it when the window is open.
func open_tab(tab: Variant) -> void:
	if visible:
		_show_tab(tab)
	else:
		_tab = tab
		open()


## Closes the window if it is open on `tab`, else opens it there.
func toggle_tab(tab: Variant) -> void:
	if visible and _tab == tab:
		close()
	else:
		open_tab(tab)


func current_tab() -> Variant:
	return _tab


func _show_tab(tab: Variant) -> void:
	_tab = tab
	for id: Variant in _pages:
		_pages[id]["page"].visible = id == tab
		_pages[id]["button"].set_pressed_no_signal(id == tab)
	_use_hotbar(visible and tab == Tab.CHARACTER)
	# The list of the tab now shown starts at the top. It is sized before the page is filled:
	# new rows change the list's minimum size, which fits it again by itself.
	for list: ScrollingList in _pages[tab]["lists"]:
		list.scroll_vertical = 0
	refit()
	var on_show: Callable = _pages[tab]["on_show"]
	if on_show.is_valid():
		on_show.call()
	_refresh()
	if is_inside_tree():
		_fit_character()


func _on_open() -> void:
	_show_tab(_tab)


## `open()` opens the character, so the tab is back to it once the window is closed.
func _on_close() -> void:
	_tab = Tab.CHARACTER
	_use_hotbar(false)
	_refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	_preview.queue_redraw()


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
## stays at its dock by itself (see Modal).
func _fit_character() -> void:
	var room := get_viewport().get_visible_rect().size.y - 2 * (WINDOW_MARGIN + PANEL_PADDING / 2)
	room -= _attributes_panel.get_combined_minimum_size().y
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


func _on_equipment_slot_secondary_pressed(slot: StringName) -> void:
	var is_worn := _player.equipment.item_in(slot) != ItemTypes.NONE
	var is_off := _player.equipment.quick_unequip(_player.inventory, slot)
	_note_label.text = "Inventory full" if is_worn and not is_off else ""


func _refresh() -> void:
	if _player == null:
		return
	_note_label.text = ""
	for slot: StringName in _equipment_views:
		var item := _player.equipment.item_in(slot)
		var stack := {} if item == ItemTypes.NONE else {"item": item, "count": 1}
		_equipment_views[slot].show_stack(stack, false)
