extends SaveUpgradeCase
## The water in the watering can and the hunger and thirst of each farm animal are saved (task
## 122).


func test_the_can_and_the_needs_of_the_animals_are_kept() -> void:
	var state := GameState.new_game(7)
	state.player.can_water = 6
	var cow := FarmAnimal.new(LivestockRules.COW, &"red_pied", Vector2(3.25, -4.5))
	cow.hunger = 0.25
	cow.thirst = 0.75
	state.livestock.add(cow)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.can_water, 6)
	assert_eq(restored.livestock.all()[0].hunger, 0.25)
	assert_eq(restored.livestock.all()[0].thirst, 0.75)
