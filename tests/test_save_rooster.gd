extends SaveUpgradeCase
## The rooster is saved like any chicken.


func test_the_rooster_is_kept() -> void:
	var state := GameState.new_game(7)
	state.livestock.add(FarmAnimal.new(LivestockRules.CHICKEN, &"rooster", Vector2(1.5, 2.5)))
	assert_true(SaveFile.write(state, SAVE_PATH))

	var animals := SaveFile.read(SAVE_PATH).livestock.all()

	assert_true(animals[0].is_rooster())
