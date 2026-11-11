extends GutTest
## The crafting menu that C opens: a row per recipe made by hand, greyed when it can't be
## afforded, a click crafts.

var _state: GameState
var _screen: CraftingScreen


func before_each() -> void:
	_state = GameState.new_game(7)
	_screen = CraftingScreen.new()
	add_child_autofree(_screen)
	_screen.show_crafting(Crafting.new(_state), _state.player.inventory)


func _row() -> RecipeRow:
	return _screen.find_children("*", "RecipeRow", true, false)[0]


func _tooltip(row: RecipeRow) -> String:
	return row.get_meta(TooltipView.TEXT_META)


func test_the_menu_is_closed_at_first_and_toggles() -> void:
	assert_false(_screen.is_open())
	_screen.toggle()
	assert_true(_screen.is_open())
	_screen.toggle()
	assert_false(_screen.is_open())


func test_there_is_a_row_for_every_recipe_made_by_hand() -> void:
	assert_eq(
		_screen.find_children("*", "RecipeRow", true, false).size(),
		RecipeRules.default_rules().recipes_at(&"").size()
	)
	assert_eq(_row().recipe_id, &"chest")


func test_a_recipe_that_cant_be_afforded_is_greyed_and_cannot_be_pressed() -> void:
	_state.player.inventory.add(ItemTypes.LOGS, 3)
	var row := _row()
	assert_true(row.disabled)
	assert_lt(row.modulate.a, 1.0)
	assert_string_contains(_tooltip(row), "Missing: 2 logs")


func test_an_affordable_recipe_is_bright_and_its_tooltip_is_that_of_the_item() -> void:
	_state.player.inventory.add(ItemTypes.LOGS, 5)
	var row := _row()
	assert_false(row.disabled)
	assert_eq(row.modulate.a, 1.0)
	assert_eq(_tooltip(row), ItemTooltip.text_for(ItemTypes.CHEST, 1))


func test_clicking_an_affordable_recipe_crafts_it() -> void:
	_state.player.inventory.add(ItemTypes.LOGS, 6)
	_row().pressed.emit()
	assert_eq(_state.player.inventory.count_of(ItemTypes.CHEST), 1)
	assert_eq(_state.player.inventory.count_of(ItemTypes.LOGS), 1)
	assert_true(_row().disabled, "and the rest no longer pays for another")


func test_a_craft_with_no_room_says_the_rest_was_dropped() -> void:
	for slot in Inventory.SLOT_COUNT:
		_state.player.inventory.slots[slot] = {"item": ItemTypes.HOE, "count": 1}
	_state.player.inventory.slots[3] = {"item": ItemTypes.LOGS, "count": 6}
	_row().pressed.emit()
	var notes := _screen.find_children("*", "Label", true, false).filter(
		func(label: Label) -> bool: return label.text == CraftingScreen.DROPPED_NOTE
	)
	assert_eq(notes.size(), 1)
	assert_true(notes[0].visible)


func test_the_panel_never_gets_taller_than_the_window() -> void:
	var window := SubViewport.new()
	window.size = Vector2i(320, 120)
	add_child_autofree(window)
	remove_child(_screen)
	window.add_child(_screen)
	_screen.open()
	await wait_process_frames(2)
	var list: ScrollingList = _screen.find_children("*", "ScrollingList", true, false)[0]
	assert_true(list.get_v_scroll_bar().visible, "the window is too small for the rows")
	var panel: Control = _screen.find_children("*", "PanelContainer", true, false)[0]
	assert_lte(panel.size.y, float(window.size.y - 2 * ScrollingList.MARGIN))


func test_a_station_menu_shows_its_recipes_and_the_hand_menu_those_made_by_hand() -> void:
	_screen.open_station(WorldObject.new(WorldObjectTypes.WORKBENCH, Vector2i.ZERO))
	assert_ne(_row().recipe_id, &"chest")
	_screen.close()
	_screen.toggle()
	assert_eq(_row().recipe_id, &"chest")


func test_e_closes_the_menu() -> void:
	_screen.open()
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	_screen._unhandled_input(event)
	assert_false(_screen.is_open())
