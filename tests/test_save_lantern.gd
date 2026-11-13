extends SaveUpgradeCase
## Version 28 saves keep whether the lantern is lit (task 177): an older save loads with it out.


func test_a_lit_lantern_is_lit_after_loading_and_shines_in_the_hand() -> void:
	var state := GameState.new_game(7)
	state.player.inventory.replace_with_one(state.player.inventory.selected_slot, ItemTypes.LANTERN)
	state.player.is_lantern_lit = true
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_true(restored.player.is_lantern_lit)
	assert_true(restored.player.is_lantern_shining())
	assert_true(
		restored.player.appearance.layers.any(
			func(layer: Dictionary) -> bool: return layer.variant == "lantern_lit"
		)
	)


func test_a_lantern_put_out_stays_out() -> void:
	var state := GameState.new_game(7)
	assert_true(SaveFile.write(state, SAVE_PATH))
	assert_false(SaveFile.read(SAVE_PATH).player.is_lantern_lit)
