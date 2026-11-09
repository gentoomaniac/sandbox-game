extends GutTest
## The keys that open the windows: one does nothing while another window is open.


func after_each() -> void:
	get_tree().paused = false


func _window() -> Modal:
	var window := Modal.new()
	add_child_autofree(window)
	return window


func test_a_windows_key_does_nothing_while_another_window_is_open() -> void:
	var first := _window()
	var second := _window()
	assert_true(first.can_open_on_key())
	first.open()
	assert_true(first.can_open_on_key(), "the open window's own key still works")
	assert_false(second.can_open_on_key())
	first.close()
	assert_true(second.can_open_on_key())


## The rule with the real windows: what Main asks before it acts on C, Tab and K.
func test_the_real_windows_keys_do_nothing_over_each_other_but_close_themselves() -> void:
	var state := GameState.new_game(7)
	var hotbar: HotbarHud = autofree(HotbarCase.new_hotbar())
	var character := CharacterScreen.new(hotbar)
	add_child_autofree(character)
	character.show_player(state.player)
	var crafting := CraftingScreen.new()
	add_child_autofree(crafting)
	crafting.show_crafting(Crafting.new(state), state.player.inventory)
	var storage := StorageScreen.new(hotbar)
	add_child_autofree(storage)
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO)

	character.open()
	assert_false(crafting.can_open_on_key(), "C does nothing over the inventory")
	assert_true(character.can_open_on_key(), "Tab and K still switch or close it")
	character.close()
	crafting.open()
	assert_false(character.can_open_on_key(), "Tab and K do nothing over crafting")
	assert_true(crafting.can_open_on_key(), "C closes crafting")
	crafting.close()
	storage.open_chest(chest, state.player)
	assert_false(character.can_open_on_key(), "everything is swallowed with a chest open")
	assert_false(crafting.can_open_on_key())
