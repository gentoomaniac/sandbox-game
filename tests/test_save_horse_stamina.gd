extends SaveUpgradeCase
## A horse's stamina is saved with it (#66).


func test_a_horse_keeps_its_stamina() -> void:
	var state := GameFactory.new_game(7)
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"bay", Vector2(3.5, 4.5))
	horse.stamina = 0.25
	state.livestock.add(horse)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.livestock.all()[0].stamina, 0.25)
