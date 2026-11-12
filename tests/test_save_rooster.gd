extends SaveUpgradeCase
## The rooster is saved like any chicken. A save from before (version 31) loads with one rooster in
## each flock of chickens (task 204).


func _chicken(look: String, x: float) -> Dictionary:
	return FarmAnimal.new(LivestockRules.CHICKEN, StringName(look), Vector2(x, 3.5)).to_dict()


func _load_version_31(chickens: Array) -> Array[FarmAnimal]:
	var game := _current_game()
	game["livestock"] = chickens
	_write_save(31, game)
	return SaveFile.read(SAVE_PATH).livestock.all()


func _count_roosters(animals: Array[FarmAnimal]) -> int:
	return animals.filter(func(animal: FarmAnimal) -> bool: return animal.is_rooster()).size()


func test_the_rooster_is_kept() -> void:
	var state := GameState.new_game(7)
	state.livestock.add(FarmAnimal.new(LivestockRules.CHICKEN, &"rooster", Vector2(1.5, 2.5)))
	assert_true(SaveFile.write(state, SAVE_PATH))

	var animals := SaveFile.read(SAVE_PATH).livestock.all()

	assert_true(animals[0].is_rooster())


func test_a_flock_with_no_rooster_gets_one_where_its_first_hen_stands() -> void:
	var animals := _load_version_31([_chicken("brown", 2.5), _chicken("white", 4.5)])

	assert_eq(animals.size(), 3)
	assert_eq(_count_roosters(animals), 1)
	assert_eq(animals[2].position, Vector2(2.5, 3.5))


func test_two_far_flocks_get_a_rooster_each() -> void:
	var animals := _load_version_31([_chicken("brown", 2.5), _chicken("white", 100.5)])

	assert_eq(animals.size(), 4)
	assert_eq(_count_roosters(animals), 2)


func test_a_rooster_look_chicken_is_the_rooster_and_the_extra_ones_become_hens() -> void:
	var animals := _load_version_31(
		[_chicken("rooster", 2.5), _chicken("brown", 3.5), _chicken("rooster", 4.5)]
	)

	assert_eq(animals.size(), 3)
	assert_eq(_count_roosters(animals), 1)
	assert_true(animals[0].is_rooster(), "the first of the flock stays")
	assert_eq(animals[2].look, &"brown")


func test_other_animals_are_left_alone() -> void:
	var cow := FarmAnimal.new(LivestockRules.COW, &"angler", Vector2(2.5, 3.5)).to_dict()

	var animals := _load_version_31([cow])

	assert_eq(animals.size(), 1)


func test_a_coop_between_two_far_chickens_makes_them_one_flock_with_one_rooster() -> void:
	var game := _current_game()
	game["livestock"] = [_chicken("brown", 2.5), _chicken("white", 20.5)]
	var coop := Building.new(BuildingTypes.CHICKEN_COOP, Vector2i(11, 3))
	game["world"]["buildings"].append(coop.to_dict())
	_write_save(31, game)

	var animals := SaveFile.read(SAVE_PATH).livestock.all()

	assert_eq(animals.size(), 3)
	assert_eq(_count_roosters(animals), 1)
