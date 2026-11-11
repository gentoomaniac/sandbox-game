extends LivestockCase
## Petting the farm animals (task 173): the first petting of a day while it is awake adds 10 to
## its friendship (up to 100) and shows a heart, one while it sleeps takes 5 (down to 0) and shows a
## anger mark, and each day with no petting takes 5, over a skip as well.


func _animal(species := LivestockRules.COW) -> FarmAnimal:
	var animal := FarmAnimal.new(species, _livestock.rules.looks(species)[0], _pen_middle())
	_livestock.add(animal)
	_livestock.stand_still(animal)
	return animal


func _put_asleep(animal: FarmAnimal) -> void:
	animal.activity = FarmAnimal.Activity.SLEEP


func _start_of_day(day: int) -> void:
	_state.clock.day = day
	_state.clock.set_time(8, 0)


func test_an_animal_starts_with_no_friendship() -> void:
	assert_eq(_animal().friendship, 0)


func test_the_first_petting_of_the_day_adds_ten_and_shows_a_heart() -> void:
	var cow := _animal()

	assert_eq(_livestock.pet(cow, _state.clock), Livestock.PetShows.HEART)

	assert_eq(cow.friendship, 10)
	assert_eq(cow.last_petted_day, DAY)


func test_more_pettings_the_same_day_show_nothing_and_change_nothing() -> void:
	var cow := _animal()
	_livestock.pet(cow, _state.clock)

	assert_eq(_livestock.pet(cow, _state.clock), Livestock.PetShows.NOTHING)
	assert_eq(_livestock.pet(cow, _state.clock), Livestock.PetShows.NOTHING)

	assert_eq(cow.friendship, 10)


func test_a_new_day_allows_another_heart() -> void:
	var cow := _animal()
	_livestock.pet(cow, _state.clock)
	_start_of_day(DAY + 1)

	assert_eq(_livestock.pet(cow, _state.clock), Livestock.PetShows.HEART)

	assert_eq(cow.friendship, 20, "the day between had a petting, so it cost nothing")


func test_friendship_stops_at_a_hundred() -> void:
	var cow := _animal()
	cow.friendship = 95

	_livestock.pet(cow, _state.clock)

	assert_eq(cow.friendship, 100)


func test_petting_tells_what_it_shows() -> void:
	var cow := _animal()
	var shown: Array = []
	_livestock.petted.connect(
		func(animal: FarmAnimal, shows: Livestock.PetShows) -> void: shown.append([animal, shows])
	)

	_livestock.pet(cow, _state.clock)
	_livestock.pet(cow, _state.clock)

	assert_eq(shown, [[cow, Livestock.PetShows.HEART]])


func test_petting_a_sleeping_animal_takes_five_and_shows_the_anger_mark() -> void:
	var cow := _animal()
	cow.friendship = 20
	_put_asleep(cow)

	assert_eq(_livestock.pet(cow, _state.clock), Livestock.PetShows.ANNOYED)

	assert_eq(cow.friendship, 15)


func test_a_sleeping_animal_is_petted_once_a_day_for_the_mark_and_the_loss() -> void:
	var cow := _animal()
	cow.friendship = 20
	_put_asleep(cow)
	_livestock.pet(cow, _state.clock)

	assert_eq(_livestock.pet(cow, _state.clock), Livestock.PetShows.NOTHING)

	assert_eq(cow.friendship, 15)


func test_petting_asleep_does_not_count_as_the_days_petting() -> void:
	var cow := _animal()
	_put_asleep(cow)
	_livestock.pet(cow, _state.clock)
	cow.activity = FarmAnimal.Activity.IDLE

	assert_eq(
		_livestock.pet(cow, _state.clock), Livestock.PetShows.HEART, "awake it still gets one"
	)


func test_friendship_never_goes_below_zero() -> void:
	var cow := _animal()
	cow.friendship = 3
	_put_asleep(cow)

	_livestock.pet(cow, _state.clock)
	assert_eq(cow.friendship, 0)

	_start_of_day(DAY + 3)
	_livestock.account_friendship(_state.clock)
	assert_eq(cow.friendship, 0)


func test_a_day_without_a_petting_takes_five() -> void:
	var cow := _animal()
	cow.friendship = 30

	_start_of_day(DAY + 1)
	_livestock.account_friendship(_state.clock)

	assert_eq(cow.friendship, 25)


func test_the_frames_of_the_next_day_take_it_once() -> void:
	var cow := _animal()
	cow.friendship = 30
	_start_of_day(DAY + 1)

	for _frame in 3:
		_livestock.update(STEP_SECONDS, _world, _state.player.position, _state.clock)

	assert_eq(cow.friendship, 25)


func test_a_day_that_had_an_awake_petting_takes_nothing() -> void:
	var cow := _animal()
	cow.friendship = 30
	_livestock.pet(cow, _state.clock)

	_start_of_day(DAY + 1)
	_livestock.account_friendship(_state.clock)

	assert_eq(cow.friendship, 40)


func test_a_day_with_only_a_sleeping_petting_takes_its_five_too() -> void:
	var cow := _animal()
	cow.friendship = 30
	_put_asleep(cow)
	_livestock.pet(cow, _state.clock)

	_start_of_day(DAY + 1)
	_livestock.account_friendship(_state.clock)

	assert_eq(cow.friendship, 20)


func test_a_petting_after_midnight_counts_the_day_that_ended_first() -> void:
	var cow := _animal()
	cow.friendship = 30
	_start_of_day(DAY + 1)

	_livestock.pet(cow, _state.clock)

	assert_eq(cow.friendship, 35, "the unpetted day took 5 before the petting added 10")


func test_a_skip_takes_five_for_each_day_it_covers_but_the_petted_one() -> void:
	var cow := _animal()
	cow.friendship = 50
	_livestock.pet(cow, _state.clock)
	_state.clock.set_time(20, 0)

	_state.simulation.skip(3 * GameClock.MINUTES_PER_DAY)

	assert_eq(_state.clock.day, DAY + 3)
	assert_eq(cow.friendship, 50, "60 from the petting, less 5 for each of the 2 days unpetted")


func test_a_skip_over_frames_takes_the_same() -> void:
	var cow := _animal()
	cow.friendship = 50
	_state.clock.set_time(20, 0)

	await _state.simulation.skip_over_frames(
		2 * GameClock.MINUTES_PER_DAY, func() -> Signal: return get_tree().process_frame
	)

	assert_eq(cow.friendship, 40)


func test_a_night_in_the_bed_takes_five_from_an_animal_nobody_petted() -> void:
	var cow := _animal()
	cow.friendship = 30
	_state.clock.set_time(22, 0)

	_state.simulation.skip(10 * GameClock.MINUTES_PER_HOUR)

	assert_eq(cow.friendship, 25)


func test_every_farm_animal_and_pet_can_be_petted() -> void:
	for species in LivestockRules.SPECIES:
		assert_true(_livestock.rules.is_pettable(species), str(species))


func test_a_hen_in_a_coop_and_a_ridden_horse_are_not_there_to_pet() -> void:
	var hen := _animal(LivestockRules.CHICKEN)
	hen.is_housed = true
	var horse := _animal(LivestockRules.HORSE)
	horse.is_ridden = true

	assert_null(_livestock.nearest_pettable(_pen_middle(), 2.0))
