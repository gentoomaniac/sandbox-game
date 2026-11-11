extends ClickCase
## Every button of the crafting, storage and character screens and of the pause menu's pages
## answers the mouse over its whole area, with the game's other layers in the tree.

var _state: GameState


func before_each() -> void:
	_state = GameState.new_game(7)
	_make_window()


## What takes clicks on a screen: buttons, sliders and item slots.
func _clickables_in(screen: Node) -> Array[Control]:
	var found: Array[Control] = []
	for control: Control in screen.find_children("*", "Control", true, false):
		if control is BaseButton or control is Range or control is SlotView:
			if control.is_visible_in_tree():
				found.append(control)
	return found


func _assert_all_buttons_hit(screen: Node, what: String) -> void:
	await wait_process_frames(2)
	var buttons := _clickables_in(screen)
	assert_gt(buttons.size(), 0, "%s has buttons" % what)
	for button in buttons:
		_assert_hit_all_over(button, "%s: %s" % [what, button])


func test_every_recipe_row_of_the_hand_menu_is_hit_all_over() -> void:
	var screen := CraftingScreen.new()
	_window.add_child(screen)
	screen.show_crafting(Crafting.new(_state), _state.player.inventory)
	screen.open()
	await _assert_all_buttons_hit(screen, "crafting by hand")


func test_every_recipe_row_of_a_station_menu_is_hit_all_over() -> void:
	var screen := CraftingScreen.new()
	_window.add_child(screen)
	screen.show_crafting(Crafting.new(_state), _state.player.inventory)
	screen.open_station(WorldObject.new(WorldObjectTypes.KILN, Vector2i.ZERO))
	await _assert_all_buttons_hit(screen, "crafting at the kiln")


func test_every_slot_of_the_storage_screen_is_hit_all_over() -> void:
	var hotbar := HotbarCase.new_hotbar()
	_window.add_child(hotbar)
	hotbar.show_inventory(_state.player.inventory)
	var screen := StorageScreen.new(hotbar)
	_window.add_child(screen)
	screen.open_chest(WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO), _state.player)
	await _assert_all_buttons_hit(screen, "storage")


func test_every_button_of_the_bag_is_hit_all_over() -> void:
	var hotbar := HotbarCase.new_hotbar()
	_window.add_child(hotbar)
	hotbar.show_inventory(_state.player.inventory)
	var screen := BagScreen.new(hotbar)
	_window.add_child(screen)
	screen.show_player(_state.player)
	screen.open()
	await _assert_all_buttons_hit(screen, "bag")


func test_every_button_of_the_character_screen_tabs_is_hit_all_over() -> void:
	var hotbar := HotbarCase.new_hotbar()
	_window.add_child(hotbar)
	hotbar.show_inventory(_state.player.inventory)
	var screen := CharacterScreen.new(hotbar)
	_window.add_child(screen)
	screen.show_player(_state.player)
	for tab in [CharacterScreen.Tab.CHARACTER, CharacterScreen.Tab.SKILLS]:
		screen.open_tab(tab)
		await _assert_all_buttons_hit(screen, "character tab %d" % tab)


func test_every_button_of_every_pause_menu_page_is_hit_all_over() -> void:
	var menu := PauseMenu.new(GameSettings.new("user://test_click_areas_settings.cfg"))
	menu.pauses_game = false
	_window.add_child(menu)
	for page in PauseMenu.Page.values():
		menu.open_page(page)
		await _assert_all_buttons_hit(menu, "pause menu page %d" % page)


## A box that only passes the mouse on (`MOUSE_FILTER_PASS`, the default of containers) leaves
## the click to the game, so only a stopping control is a fault.
func test_the_huds_that_need_a_game_state_stop_no_clicks() -> void:
	for hud: Node in [VitalsHud.new(), CheatHud.new()]:
		for control: Control in hud.find_children("*", "Control", true, false):
			assert_ne(control.mouse_filter, Control.MOUSE_FILTER_STOP, "%s of %s" % [control, hud])
		hud.free()
