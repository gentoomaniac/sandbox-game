extends ProcessStationCase
## The window of a process station (ProcessScreen), on the smelter of test config
## (ProcessStationCase): the grid, the recipes with their amounts, the dimmed stacks of
## the inventory, the activation button, the run and the results.

var _hotbar: HotbarHud
var _screen: ProcessScreen


func before_each() -> void:
	super.before_each()
	var inventory := _state.player.inventory
	for slot in inventory.slots.size():
		inventory.slots[slot] = {}
	inventory.slots[Inventory.HOTBAR_SIZE] = {"item": ItemTypes.STONE, "count": 20}
	inventory.slots[Inventory.HOTBAR_SIZE + 1] = {"item": ItemTypes.LOGS, "count": 10}
	inventory.slots[Inventory.HOTBAR_SIZE + 2] = {"item": ItemTypes.BERRIES, "count": 5}
	inventory.slots[0] = {"item": ItemTypes.CLAY, "count": 5}
	_hotbar = HotbarCase.new_hotbar(inventory)
	add_child_autofree(_hotbar)
	_screen = ProcessScreen.new(_hotbar)
	add_child_autofree(_screen)
	_screen.open_station(_station)


func _backpack_view(slot: int) -> SlotView:
	return _screen._backpack_views[slot]


func _grid_view(slot: int) -> SlotView:
	return _screen._grid_views[slot]


func _row(recipe_id: StringName) -> ProcessRecipeRow:
	for row: ProcessRecipeRow in _screen.find_children("*", "ProcessRecipeRow", true, false):
		if row.recipe_id == recipe_id:
			return row
	return null


## Drags the stack of `from` onto `to` and lets go, as the mouse does.
func _drag(from: SlotView, to: SlotView) -> void:
	var data := {"from": from}
	if to._can_drop_data(Vector2.ZERO, data):
		to._drop_data(Vector2.ZERO, data)


func test_the_window_shows_the_grid_the_recipes_and_the_backpack() -> void:
	assert_eq(_screen._grid_views.size(), 4)
	assert_eq(_screen._title_label.text, "Smelter")
	assert_not_null(_row(&"bricks"))
	assert_not_null(_row(&"flour"))
	assert_eq(_screen._backpack_views.size(), Inventory.BACKPACK_SIZE)


func test_stacks_that_can_not_go_in_are_dimmed_from_the_start() -> void:
	assert_false(_backpack_view(Inventory.HOTBAR_SIZE).is_dimmed, "stone")
	assert_false(_backpack_view(Inventory.HOTBAR_SIZE + 1).is_dimmed, "logs")
	assert_true(_backpack_view(Inventory.HOTBAR_SIZE + 2).is_dimmed, "berries, in no recipe")
	assert_true(_hotbar._slot_views[0].is_dimmed, "clay, the flour is locked")


func test_a_drag_into_the_grid_moves_only_what_fits_a_recipe() -> void:
	_drag(_backpack_view(Inventory.HOTBAR_SIZE + 2), _grid_view(0))
	assert_eq(_grid(), {}, "no berries")
	_drag(_backpack_view(Inventory.HOTBAR_SIZE), _grid_view(3))
	assert_eq(_grid(), {ItemTypes.STONE: 20})
	assert_true(_row(&"flour")._button.disabled, "stone is not in flour")


func test_shift_click_puts_in_and_takes_out() -> void:
	_backpack_view(Inventory.HOTBAR_SIZE + 1).quick_move_requested.emit()
	assert_eq(_grid(), {ItemTypes.LOGS: 10})
	_grid_view(0).quick_move_requested.emit()
	assert_eq(_grid(), {})
	assert_eq(_state.player.inventory.count_of(ItemTypes.LOGS), 10)


func test_a_drag_out_of_the_grid_onto_another_item_swaps_nothing_in() -> void:
	_backpack_view(Inventory.HOTBAR_SIZE).quick_move_requested.emit()
	_drag(_grid_view(0), _backpack_view(Inventory.HOTBAR_SIZE + 2))
	assert_eq(_grid(), {ItemTypes.STONE: 20})
	_drag(_grid_view(0), _backpack_view(Inventory.HOTBAR_SIZE + 5))
	assert_eq(_grid(), {})


func test_max_sets_the_most_and_a_press_fills_the_grid() -> void:
	var row := _row(&"bricks")
	row._max.pressed.emit()
	assert_eq(row.amount(), 10)
	row._minus.pressed.emit()
	assert_eq(row.amount(), 9)
	row._button.pressed.emit()
	assert_eq(_grid(), {ItemTypes.STONE: 18, ItemTypes.LOGS: 9})


func test_a_typed_amount_is_held_to_the_limits() -> void:
	var row := _row(&"bricks")
	row._amount_field.text = "50"
	row._amount_field.text_submitted.emit("50")
	assert_eq(row.amount(), 10)
	row._amount_field.text = "x"
	row._amount_field.text_submitted.emit("x")
	assert_eq(row.amount(), 10, "kept")


func test_the_button_is_greyed_on_a_part_load_and_says_what_is_missing() -> void:
	assert_true(_screen._button.disabled)
	assert_eq(_screen._note_label.text, ProcessScreen.EMPTY_NOTE)
	_backpack_view(Inventory.HOTBAR_SIZE).quick_move_requested.emit()
	assert_true(_screen._button.disabled)
	assert_eq(_screen._note_label.text, ProcessScreen.MISSING_NOTE % "Logs x10")


func test_a_run_dims_and_locks_the_grid_and_shows_the_bar() -> void:
	_row(&"bricks")._button.pressed.emit()
	assert_false(_screen._button.disabled)
	_screen._button.pressed.emit()
	assert_true(_station.is_running())
	assert_true(_grid_view(0).is_dimmed)
	assert_false(_grid_view(0).is_clickable)
	assert_true(_screen._bar.visible)
	assert_true(_screen._button.disabled, "one run at a time")
	assert_true(_backpack_view(Inventory.HOTBAR_SIZE).is_dimmed, "nothing goes in")
	assert_eq(_screen._note_label.text, "+2.0 Masonry", "what starting it taught")
	_screen._process(0.0)
	assert_eq(_screen._note_label.text, "+2.0 Masonry", "kept while it runs")
	assert_eq(_screen._run_label.text, "Brick x2: ready in 3 h 0 min")


func test_once_done_the_results_come_out_and_nothing_goes_in_until_they_are_all_out() -> void:
	_row(&"bricks")._button.pressed.emit()
	_screen._button.pressed.emit()
	_state.simulation.advance(RUN_MINUTES)
	_screen._process(0.0)
	assert_eq(_grid(), {ItemTypes.BRICK: 2})
	assert_eq(_screen._note_label.text, ProcessScreen.RESULTS_NOTE)
	assert_true(_backpack_view(Inventory.HOTBAR_SIZE).is_dimmed)
	assert_true(_row(&"bricks")._button.disabled)
	_drag(_grid_view(0), _backpack_view(Inventory.HOTBAR_SIZE + 5))
	assert_eq(_state.player.inventory.count_of(ItemTypes.BRICK), 2)
	assert_false(_backpack_view(Inventory.HOTBAR_SIZE).is_dimmed, "open again")


func test_closing_lets_go_of_the_hotbar_and_its_dimming() -> void:
	_screen.close()
	assert_false(_hotbar._slot_views[0].is_dimmed)
	assert_false(_state.player.inventory.changed.is_connected(_screen._refresh))


func test_a_grid_no_recipe_fits_says_so() -> void:
	_smelter.storage.add(ItemTypes.BERRIES, 1)
	_screen._refresh()
	assert_eq(_screen._note_label.text, ProcessScreen.NO_RECIPE_NOTE)


## Presses an action on the focused amount field, as the keyboard does.
func _press_on_amount(row: ProcessRecipeRow, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	row._amount_field.gui_input.emit(event)


func test_escape_in_the_amount_field_closes_the_window() -> void:
	var row := _row(&"bricks")
	_press_on_amount(row, &"ui_cancel")
	assert_false(_screen.is_open())


func test_e_in_the_amount_field_closes_the_window_and_keeps_the_typed_amount() -> void:
	var row := _row(&"bricks")
	row._amount_field.text = "4"
	_press_on_amount(row, &"interact")
	assert_eq(row.amount(), 4)
	assert_false(_screen.is_open())
