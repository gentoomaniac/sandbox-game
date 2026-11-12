class_name ProcessScreen
extends Modal
## The window of a process station (task 199; see ProcessStation), such as the kiln: its recipes
## on the left, each with the amount of loads a press fills the grid to (ProcessRecipeRow); in the
## middle the station's grid, the progress bar over it and the activation button with the
## station's picture under it, beside a short note; the player's backpack on the right. The hotbar
## is the HUD's, lit and clickable while it is open, as in the chest's window.
##
## Stacks move between the backpack or the hotbar and the grid by dragging and by Shift+click,
## but only as many as the station lets in; the stacks that can't go in now are dimmed. The button
## starts the run when the grid holds whole loads, and says what is missing when it does not.
## While it runs the grid is dimmed and locked, and the bar fills. Once done the grid holds what
## was made, which comes out like a chest's; until it is all out the recipes and the backpack are
## dimmed and the note says so. E or Escape closes it (Main sees to E).

const PANEL_GAP := 12
const SLOT_GAP := 2
const INVENTORY_COLUMNS := 5
const BACKPACK_ICON := preload("res://assets/ui/backpack_icon.png")
const FILL := preload("res://assets/ui/energy_fill.png")
const START_TIP := "Start: %s"
const EMPTY_NOTE := "Put in what a recipe takes."
const MISSING_NOTE := "Still needed for a whole load: %s"
const READY_NOTE := "Ready to start"
const RUNNING_NOTE := "%s: ready in %s"
const RESULTS_NOTE := "Take out what was made first."
const NO_RECIPE_NOTE := "No recipe fits what is in the station."

var _hotbar: HotbarHud
var _station: ProcessStation
var _title_label := Label.new()
var _skills_label := Label.new()
var _rows_column := VBoxContainer.new()
var _rows: Array[ProcessRecipeRow] = []
var _bar: VitalBar
var _bar_holder := CenterContainer.new()
var _grid_holder := CenterContainer.new()
var _grid_views: Array[SlotView] = []
var _button := Button.new()
## What the run makes and when, on a line of its own, so the note beside it stays.
var _run_label := Label.new()
var _note_label := Label.new()
## The backpack's slot views, by inventory slot.
var _backpack_views := {}


func _init(hotbar: HotbarHud) -> void:
	super()
	close_actions = [&"interact"]
	_hotbar = hotbar

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PANEL_GAP)
	var recipes_column := VBoxContainer.new()
	for label in [_title_label, _skills_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		recipes_column.add_child(label)
	recipes_column.add_child(_scrolling(_rows_column))
	row.add_child(recipes_column)

	var grid_column := VBoxContainer.new()
	grid_column.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_column.add_child(_bar_holder)
	grid_column.add_child(_grid_holder)
	# Space is the game's use key: a focused button would take it.
	_button.focus_mode = Control.FOCUS_NONE
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_start)
	grid_column.add_child(_button)
	for label in [_run_label, _note_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = ProcessRecipeRow.ROW_WIDTH / 2.0
		grid_column.add_child(label)
	row.add_child(grid_column)

	var backpack_column := VBoxContainer.new()
	var header := TextureRect.new()
	header.texture = BACKPACK_ICON
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	backpack_column.add_child(header)
	var backpack := _new_grid(INVENTORY_COLUMNS)
	for slot in range(Inventory.HOTBAR_SIZE, Inventory.SLOT_COUNT):
		var view := SlotView.new()
		view.tooltip_id = "inventory_%d" % slot
		view.quick_move_requested.connect(_put_in.bind(slot))
		backpack.add_child(view)
		_backpack_views[slot] = view
	backpack_column.add_child(backpack)
	row.add_child(backpack_column)
	_panel.add_child(row)


## Opens the window of a process station. Opening it again moves it to that station.
func open_station(station: ProcessStation) -> void:
	close()
	_station = station
	open()


func _on_open() -> void:
	_title_label.text = _station.title
	var icon: Texture2D = load(_station.button_icon)
	_button.icon = icon
	_show_bar(icon)
	_show_grid(_station.grid_size)
	_show_recipes()
	_note_label.text = ""
	var inventory := _station.inventory
	for slot: int in _backpack_views:
		_backpack_views[slot].bind_to(inventory, slot)
	inventory.changed.connect(_refresh)
	_station.grid.changed.connect(_refresh)
	_station.crafting.player_skills().changed.connect(_refresh)
	_station.crafting.practised.connect(_on_practised)
	_hotbar.acquire(self)
	_hotbar.slot_quick_move_requested.connect(_put_in)
	_refresh()


## The window listens only while it is open.
func _on_close() -> void:
	_station.inventory.changed.disconnect(_refresh)
	_station.grid.changed.disconnect(_refresh)
	_station.crafting.player_skills().changed.disconnect(_refresh)
	_station.crafting.practised.disconnect(_on_practised)
	# The hotbar may have been freed first, when the whole scene goes.
	if is_instance_valid(_hotbar):
		for slot in Inventory.HOTBAR_SIZE:
			_hotbar.dim(slot, false)
		_hotbar.release(self)
		_hotbar.slot_quick_move_requested.disconnect(_put_in)


## The bar fills and the time counts down while a run goes on, also with nothing else changing.
func _process(_delta: float) -> void:
	if visible and _station != null and _station.is_running():
		_bar.show_value(_station.progress())
		var running_text := _running_note()
		if _run_label.text != running_text:
			_run_label.text = running_text
	elif visible and _station != null and _bar.visible:
		# Done while the window is open.
		_refresh()


func _show_bar(icon: Texture2D) -> void:
	if _bar != null:
		_bar.free()
	_bar = VitalBar.new(icon, FILL)
	_bar_holder.add_child(_bar)


## Makes the grid's slot views, as many as the station has.
func _show_grid(size_in_slots: Vector2i) -> void:
	for grid in _grid_holder.get_children():
		grid.free()
	_grid_views.clear()
	var grid := _new_grid(size_in_slots.x)
	for slot in size_in_slots.x * size_in_slots.y:
		var view := SlotView.new()
		view.tooltip_id = "grid_%d" % slot
		view.bind_to(_station.grid, slot)
		view.move_rule = _move
		view.quick_move_requested.connect(_station.send_out.bind(slot))
		grid.add_child(view)
		_grid_views.append(view)
	_grid_holder.add_child(grid)


func _show_recipes() -> void:
	for row in _rows:
		row.free()
	_rows.clear()
	for recipe_id in _station.recipe_ids:
		var row := ProcessRecipeRow.new(
			recipe_id, _station, _station.crafting.rules, _station.crafting.player_skills()
		)
		row.fill_requested.connect(_fill.bind(recipe_id))
		row.close_key_pressed.connect(_on_close_key)
		_rows_column.add_child(row)
		_rows.append(row)


func _new_grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", SLOT_GAP)
	grid.add_theme_constant_override("v_separation", SLOT_GAP)
	return grid


## The move rule of the grid's slots (see SlotView `move_rule`): into the grid only as many as may
## go in; out of it only onto an empty slot or one of the same item; nothing while it runs.
func _move(source: SlotView, target: SlotView, is_dropping: bool) -> bool:
	var grid := _station.grid
	if target.container == grid and source.container != grid:
		var may_go_in := _station.room_for(source.item()) > 0
		if may_go_in and is_dropping:
			_station.put_in(source.container, source.slot)
		return may_go_in
	var may_come_out := (
		not _station.is_running()
		and (target.container == grid or target.item() in [ItemTypes.NONE, source.item()])
	)
	if may_come_out and is_dropping:
		_station.take_out(source.slot, target.container, target.slot)
	return may_come_out


## Shift+click on a backpack or hotbar slot.
func _put_in(slot: int) -> void:
	_station.put_in(_station.inventory, slot)


## Escape (or the pause key) and E, pressed in an amount field, close the window as they would
## anywhere else in it.
func _on_close_key(action: StringName) -> void:
	if action in close_actions:
		close()
	else:
		request_close()


func _fill(amount: int, recipe_id: StringName) -> void:
	_station.fill(recipe_id, amount)


func _start() -> void:
	_station.start()
	_refresh()


func _on_practised(skill: StringName, gained: float, wanted: float) -> void:
	var skills := _station.crafting.player_skills()
	_skills_label.text = _skills_text()
	_note_label.text = CraftingScreen.practised_note(skills, skill, gained, wanted)


func _refresh() -> void:
	var is_running := _station.is_running()
	var holds_results := _station.holds_results()
	_skills_label.text = _skills_text()
	var available := _station.inventory.totals()
	var held := _station.grid.totals()
	for item: StringName in held:
		available[item] = available.get(item, 0) + held[item]
	for row in _rows:
		row.refresh(available)
	for slot in _grid_views.size():
		var view := _grid_views[slot]
		view.show_stack(_station.grid.slots[slot], false)
		view.is_dimmed = is_running
		view.is_clickable = not is_running
	var inventory := _station.inventory
	for slot: int in _backpack_views:
		var view: SlotView = _backpack_views[slot]
		view.show_stack(inventory.slots[slot], false)
		view.is_dimmed = not inventory.slots[slot].is_empty() and not _can_put_in(slot)
	for slot in Inventory.HOTBAR_SIZE:
		_hotbar.dim(slot, not inventory.slots[slot].is_empty() and not _can_put_in(slot))
	_bar.visible = is_running
	_bar.show_value(_station.progress() if is_running else 0.0)
	var runnable := _station.runnable_recipe()
	_button.disabled = runnable == &""
	var tip := (
		"" if runnable == &"" else START_TIP % RecipeRow.title_of(runnable, _station.crafting.rules)
	)
	TooltipView.set_text(_button, tip, "process_start")
	_run_label.text = _running_note() if is_running else ""
	_run_label.visible = is_running
	# While it runs the note keeps what starting it taught.
	if not is_running:
		_note_label.text = _idle_note(holds_results, runnable)


## What the note says while nothing runs.
func _idle_note(holds_results: bool, runnable: StringName) -> String:
	if holds_results:
		return RESULTS_NOTE
	if runnable != &"":
		return READY_NOTE
	if _station.grid.is_empty():
		return EMPTY_NOTE
	var missing := _station.missing()
	return NO_RECIPE_NOTE if missing.is_empty() else MISSING_NOTE % _items_text(missing)


func _can_put_in(slot: int) -> bool:
	return _station.room_for(_station.inventory.item_in(slot)) > 0


## "Brick x22: ready in 7 h 20 min".
func _running_note() -> String:
	var minutes := _station.minutes_left()
	var hours := minutes / GameClock.MINUTES_PER_HOUR
	var rest := minutes % GameClock.MINUTES_PER_HOUR
	var time := "%d h %d min" % [hours, rest] if hours > 0 else "%d min" % rest
	return RUNNING_NOTE % [_items_text(_station.products()), time]


## "Logs x1, Raw brick x2": named as the recipes name what they make, so a count of one reads
## right too (an item has one name, "Logs" or "Raw brick", not a singular and a plural).
func _items_text(items: Dictionary) -> String:
	var parts: Array[String] = []
	for item: StringName in items:
		parts.append("%s x%d" % [ItemTypes.TYPES[item]["name"], items[item]])
	return ", ".join(parts)


## "Masonry 23.5": the player's points in the skills the recipes practise.
func _skills_text() -> String:
	var skills := _station.crafting.player_skills()
	var parts: Array[String] = []
	for recipe_id in _station.recipe_ids:
		var skill := _station.crafting.rules.skill(recipe_id)
		if skill == &"":
			continue
		var part := "%s %.1f" % [skills.rules.skill_name(skill), skills.points(skill)]
		if not parts.has(part):
			parts.append(part)
	return "  ".join(parts)
