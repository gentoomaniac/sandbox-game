extends SaveUpgradeCase
## Version 25 saves keep the water in the watering can and the hunger and thirst of each farm
## animal (task 122): an older save loads with the can full and the animals fed and watered.


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


func test_a_version_24_save_loads_with_the_can_full_and_the_animals_fed_and_watered() -> void:
	var game := _current_game()
	var hen := FarmAnimal.new(LivestockRules.CHICKEN, &"brown", Vector2(2.5, 3.5)).to_dict()
	hen.erase("hunger")
	hen.erase("thirst")
	game["livestock"] = [hen]
	game["player"].erase("can_water")
	_write_save(24, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.can_water, EnergyRules.default_rules().can_capacity())
	assert_eq(restored.livestock.all()[0].hunger, 0.0)
	assert_eq(restored.livestock.all()[0].thirst, 0.0)
