extends SaveUpgradeCase
## The farm animals are saved with their species, look, tint, place and how long they follow the
## player and whether they wear a saddle. Their friendship and the days they were petted are kept
## too (task 173).


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


func test_the_friendship_and_the_days_of_petting_are_kept() -> void:
	var state := GameState.new_game(7)
	var dog := FarmAnimal.new(LivestockRules.DOG, &"spitz", Vector2(1.5, 2.5))
	dog.friendship = 65
	dog.last_petted_day = 12
	dog.last_petted_asleep_day = 11
	state.livestock.add(dog)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH).livestock.all()[0]

	assert_eq(loaded.friendship, 65)
	assert_eq(loaded.last_petted_day, 12)
	assert_eq(loaded.last_petted_asleep_day, 11)


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
