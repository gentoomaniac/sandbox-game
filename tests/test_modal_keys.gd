extends GutTest
## The keys that open the windows: one does nothing while another window is open.


func after_each() -> void:
	get_tree().paused = false


func _window() -> Modal:
	var window := Modal.new()
	add_child_autofree(window)
	return window


func _bag(hotbar: HotbarHud, state: GameState) -> BagScreen:
	var bag := BagScreen.new(hotbar)
	add_child_autofree(bag)
	bag.show_player(state.player)
	return bag


func _character(hotbar: HotbarHud, state: GameState) -> CharacterScreen:
	var character := CharacterScreen.new(hotbar)
	add_child_autofree(character)
	character.show_player(state.player)
	return character


func test_a_windows_key_does_nothing_while_another_window_is_open() -> void:
	var first := _window()
	var second := _window()
	assert_true(first.can_open_on_key())
	first.open()
	assert_true(first.can_open_on_key(), "the open window's own key still works")
	assert_false(second.can_open_on_key())
	first.close()
	assert_true(second.can_open_on_key())


## The rule with the real windows: what Main asks before it acts on Shift+C, C, B and K.
func test_the_real_windows_keys_do_nothing_over_each_other_but_close_themselves() -> void:
	var state := GameState.new_game(7)
	var hotbar: HotbarHud = autofree(HotbarCase.new_hotbar())
	var bag := _bag(hotbar, state)
	var character := _character(hotbar, state)
	var crafting := CraftingScreen.new()
	add_child_autofree(crafting)
	crafting.show_crafting(Crafting.new(state), state.player.inventory)
	var storage := StorageScreen.new(hotbar)
	add_child_autofree(storage)
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO)

	bag.open()
	assert_false(crafting.can_open_on_key(), "Shift+C does nothing over the bag")
	assert_true(character.can_open_on_key(), "C and K open the character window beside the bag")
	assert_true(bag.can_open_on_key(), "B closes it")
	bag.close()
	character.open()
	assert_false(crafting.can_open_on_key(), "Shift+C does nothing over the character window")
	assert_true(bag.can_open_on_key(), "B opens the bag beside it")
	assert_true(character.can_open_on_key(), "C and K switch or close it")
	character.close()
	crafting.open()
	assert_false(bag.can_open_on_key(), "B does nothing over crafting")
	assert_false(character.can_open_on_key(), "C and K do nothing over crafting")
	assert_true(crafting.can_open_on_key(), "Shift+C closes crafting")
	crafting.close()
	storage.open_chest(chest, state.player)
	assert_false(character.can_open_on_key(), "everything is swallowed with a chest open")
	assert_false(bag.can_open_on_key())
	assert_false(crafting.can_open_on_key())


func test_the_bag_and_the_character_window_open_together_and_close_on_their_own_keys() -> void:
	var state := GameState.new_game(7)
	var hotbar: HotbarHud = autofree(HotbarCase.new_hotbar())
	var bag := _bag(hotbar, state)
	var character := _character(hotbar, state)
	bag.open()
	character.open()
	assert_true(bag.is_open())
	assert_true(character.is_open())
	bag.close()
	assert_true(character.is_open(), "closing one leaves the other")
	assert_true(Modal.is_any_open())
	character.close()
	assert_false(Modal.is_any_open())


func test_opening_another_window_closes_both_docked_ones() -> void:
	var state := GameState.new_game(7)
	var hotbar: HotbarHud = autofree(HotbarCase.new_hotbar())
	var bag := _bag(hotbar, state)
	var character := _character(hotbar, state)
	var crafting := CraftingScreen.new()
	add_child_autofree(crafting)
	crafting.show_crafting(Crafting.new(state), state.player.inventory)
	bag.open()
	character.open()
	crafting.open()
	assert_false(bag.is_open())
	assert_false(character.is_open())
	assert_true(crafting.is_open())
	bag.open()
	assert_false(crafting.is_open(), "a docked window opened by code closes the other kind")
