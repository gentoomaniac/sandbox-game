extends CoopCase
## The rooster (task 204): the chicken of the look `rooster`, one in each flock, that comes with the
## flock's hens, lays no eggs and is petted and housed like a hen.


func _roosters() -> Array[FarmAnimal]:
	return _livestock.all().filter(func(animal: FarmAnimal) -> bool: return animal.is_rooster())


func test_a_random_chicken_is_never_a_rooster() -> void:
	for seed_value in 500:
		var chicken := FarmAnimal.create(
			LivestockRules.CHICKEN, seed_value, Vector2.ZERO, _livestock.rules
		)
		assert_false(chicken.is_rooster())


func test_only_a_chicken_of_the_rooster_look_is_a_rooster() -> void:
	assert_true(FarmAnimal.new(LivestockRules.CHICKEN, &"rooster", Vector2.ZERO).is_rooster())
	assert_false(FarmAnimal.new(LivestockRules.CHICKEN, &"white", Vector2.ZERO).is_rooster())
	assert_false(FarmAnimal.new(LivestockRules.COW, &"rooster", Vector2.ZERO).is_rooster())


func test_the_first_hens_of_a_flock_bring_a_rooster() -> void:
	_livestock.spawn(LivestockRules.CHICKEN, 4, _pen_middle(), _world)

	assert_eq(_livestock.all().size(), 5)
	assert_eq(_roosters().size(), 1)


func test_more_hens_in_the_same_flock_bring_no_second_rooster() -> void:
	_livestock.spawn(LivestockRules.CHICKEN, 3, _pen_middle(), _world)
	_livestock.spawn(LivestockRules.CHICKEN, 3, _pen_middle(), _world)

	assert_eq(_livestock.all().size(), 7)
	assert_eq(_roosters().size(), 1)


func test_a_far_flock_gets_a_rooster_of_its_own() -> void:
	var values := DataFile.read_sections(LivestockRules.DEFAULT_PATH)
	values["rooster"]["flock_tiles"] = 2.0
	_livestock.rules = LivestockRules.new(values)
	for corner in [Vector2(-2.5, -2.5), Vector2(2.5, 2.5)]:
		_livestock.add(FarmAnimal.new(LivestockRules.CHICKEN, &"brown", _pen_middle() + corner))

	_livestock.spawn(LivestockRules.CHICKEN, 0, _pen_middle(), _world)

	assert_eq(_roosters().size(), 2, "one for each flock")


func test_spawning_a_rooster_puts_only_roosters() -> void:
	_livestock.spawn(LivestockRules.CHICKEN, 2, _pen_middle(), _world, LivestockRules.ROOSTER_LOOK)

	assert_eq(_roosters().size(), 2)
	assert_eq(_livestock.all().size(), 2)


func test_a_rooster_lays_no_egg_going_into_the_coop() -> void:
	var rooster := FarmAnimal.new(
		LivestockRules.CHICKEN, &"rooster", _pen_middle() + Vector2(0.0, 2.0)
	)
	_livestock.add(rooster)
	_livestock.stand_still(rooster)

	_run(30.0, NIGHT)

	assert_true(rooster.is_housed, "he sleeps in the coop")
	assert_eq(_eggs(), 0)


func test_a_hen_with_the_rooster_still_lays_her_egg() -> void:
	var rooster := FarmAnimal.new(
		LivestockRules.CHICKEN, &"rooster", _pen_middle() + Vector2(0.0, 2.0)
	)
	_livestock.add(rooster)
	_hens(1)

	_run(30.0, NIGHT)

	assert_eq(_eggs(), 1)


func test_a_rooster_can_be_petted_like_a_hen() -> void:
	var rooster := FarmAnimal.new(LivestockRules.CHICKEN, &"rooster", _pen_middle())
	_livestock.add(rooster)

	assert_eq(_livestock.pet(rooster, _state.clock), Livestock.PetShows.HEART)
	assert_eq(rooster.friendship, _livestock.rules.friendship("pet_gain"))
