extends SaveUpgradeCase
## A horse's stamina is saved with it (#66); a save of version 41 gives every animal a full one.


func test_a_horse_keeps_its_stamina() -> void:
	var state := GameState.new_game(7)
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"bay", Vector2(3.5, 4.5))
	horse.stamina = 0.25
	state.livestock.add(horse)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.livestock.all()[0].stamina, 0.25)


func test_a_save_of_version_41_gives_the_horses_full_stamina() -> void:
	var game := _current_game()
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"bay", Vector2(3.5, 4.5)).to_dict()
	horse.erase("stamina")
	game["livestock"] = [horse]
	_write_save(41, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.livestock.all()[0].stamina, 1.0)
