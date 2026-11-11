extends SaveUpgradeCase
## The farm animals are saved with their species, look, tint, place and how long they follow the
## player and whether they wear a saddle; a save from before the saddle (version 21) loads with
## none saddled.


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


func test_a_version_21_save_loads_with_no_horse_saddled() -> void:
	var game := _current_game()
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"grey", Vector2(2.5, 3.5)).to_dict()
	horse.erase("is_saddled")
	game["livestock"] = [horse]
	_write_save(21, game)

	var animals := SaveFile.read(SAVE_PATH).livestock.all()

	assert_eq(animals.size(), 1)
	assert_false(animals[0].is_saddled)


func test_a_pig_is_kept_with_its_look_and_its_needs() -> void:
	var state := GameState.new_game(7)
	var pig := FarmAnimal.new(LivestockRules.PIG, &"saddleback", Vector2(1.5, -2.25))
	pig.hunger = 0.25
	pig.thirst = 0.75
	state.livestock.add(pig)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var animals := SaveFile.read(SAVE_PATH).livestock.all()

	assert_eq(animals[0].species, LivestockRules.PIG)
	assert_eq(animals[0].look, &"saddleback")
	assert_almost_eq(animals[0].hunger, 0.25, 0.001)
	assert_almost_eq(animals[0].thirst, 0.75, 0.001)
