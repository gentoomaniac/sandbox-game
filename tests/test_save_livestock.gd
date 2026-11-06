extends SaveUpgradeCase
## The farm animals are saved with their species, look, tint, place and how long they follow the
## player; a save from before them (version 12) loads without any, and one from before the bone
## (version 15) with none following.


func test_the_farm_animals_are_kept() -> void:
	var state := GameState.new_game(7)
	var cow := FarmAnimal.new(LivestockRules.COW, &"red_pied", Vector2(3.25, -4.5))
	cow.tint = Color.html("f4e8dc")
	state.livestock.add(cow)
	state.livestock.add(FarmAnimal.new(LivestockRules.CHICKEN, &"rooster", Vector2(1.5, 2.75)))
	assert_true(SaveFile.write(state, SAVE_PATH))

	var animals := SaveFile.read(SAVE_PATH).livestock.all()

	assert_eq(animals.size(), 2)
	assert_eq(animals[0].species, LivestockRules.COW)
	assert_eq(animals[0].look, &"red_pied")
	assert_eq(animals[0].tint.to_html(false), "f4e8dc")
	assert_eq(animals[0].position, Vector2(3.25, -4.5))
	assert_eq(animals[1].look, &"rooster")


func test_a_version_12_save_loads_with_no_farm_animals() -> void:
	var game := _current_game()
	game.erase("livestock")
	_write_save(12, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_eq(restored.livestock.all().size(), 0)


func test_a_version_15_save_loads_with_no_animal_following() -> void:
	var game := _current_game()
	var dog := FarmAnimal.new(LivestockRules.DOG, &"spitz", Vector2(2.5, 3.5)).to_dict()
	dog.erase("follow_until_minute")
	game["livestock"] = [dog]
	_write_save(15, game)

	var animals := SaveFile.read(SAVE_PATH).livestock.all()

	assert_eq(animals.size(), 1)
	assert_eq(animals[0].follow_until_minute, 0)
