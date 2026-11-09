extends GutTest
## Every screen answers open(), close() and is_open(); close() is safe when it is closed.

var _state: GameState
var _chest: WorldObject


func before_each() -> void:
	_state = GameState.new_game(7)
	_chest = WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO)


func _character_screen() -> CharacterScreen:
	var screen := CharacterScreen.new(autofree(HotbarHud.new()))
	add_child_autofree(screen)
	screen.show_player(_state.player)
	return screen


func _crafting_screen() -> CraftingScreen:
	var screen := CraftingScreen.new()
	add_child_autofree(screen)
	screen.show_crafting(Crafting.new(_state), _state.player.inventory)
	return screen


func _pause_menu() -> PauseMenu:
	var menu := PauseMenu.new(GameSettings.new("user://test_screens_settings.cfg"))
	add_child_autofree(menu)
	return menu


func _opened_and_closed(screen: Node, open_screen: Callable) -> void:
	assert_false(screen.is_open(), "closed at first")
	screen.close()
	assert_false(screen.is_open(), "close when closed")
	open_screen.call()
	assert_true(screen.is_open())
	open_screen.call()
	assert_true(screen.is_open(), "open twice")
	screen.close()
	assert_false(screen.is_open())


func test_character_screen() -> void:
	var screen := _character_screen()
	_opened_and_closed(screen, screen.open)


func test_crafting_screen() -> void:
	var screen := _crafting_screen()
	_opened_and_closed(screen, screen.open)


func test_console_view() -> void:
	var screen := ConsoleView.new()
	add_child_autofree(screen)
	_opened_and_closed(screen, screen.open)


func test_pause_menu() -> void:
	var screen := _pause_menu()
	_opened_and_closed(screen, screen.open)


func test_closing_a_closed_pause_menu_does_not_resume() -> void:
	var menu := _pause_menu()
	watch_signals(menu)
	menu.close()
	assert_signal_not_emitted(menu, "resumed")
	menu.open()
	menu.close()
	assert_signal_emitted(menu, "resumed")


func test_storage_screen() -> void:
	var screen := StorageScreen.new(autofree(HotbarHud.new()))
	add_child_autofree(screen)
	_opened_and_closed(screen, screen.open_chest.bind(_chest, _state.player))


func test_storage_screen_listens_once_however_often_it_is_opened() -> void:
	var screen := StorageScreen.new(autofree(HotbarHud.new()))
	add_child_autofree(screen)
	screen.open_chest(_chest, _state.player)
	screen.open_chest(_chest, _state.player)
	assert_eq(_state.player.inventory.changed.get_connections().size(), 1)
	screen.close()
	assert_eq(_state.player.inventory.changed.get_connections().size(), 0)
	assert_eq(_chest.storage.changed.get_connections().size(), 0)
