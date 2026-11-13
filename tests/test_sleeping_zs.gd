extends WildlifeCase
## The "z"s over a sleeping farm animal's head (task 211): they show now and then while it sleeps
## on screen, never while it is awake, and go when it wakes or is petted.

const SPOT := Vector2(2.5, 5.5)

var _cow: FarmAnimal
var _cow_view: FarmAnimalView


func before_each() -> void:
	super()
	_cow = FarmAnimal.new(LivestockRules.COW, &"angler", SPOT)
	_state.livestock.add(_cow)
	_wildlife._show_farm_animal_if_near(_cow)
	_cow_view = _wildlife._farm_animals[_cow]
	_state.livestock.petted.connect(_wildlife._show_pet_reaction)


func _longest_gap() -> float:
	return DataFile.read_sections(LivestockRules.DEFAULT_PATH)["zs"]["gap_seconds"][1]


func _longest_shown() -> float:
	return DataFile.read_sections(LivestockRules.DEFAULT_PATH)["zs"]["shown_seconds"][1]


## Steps the view for this many seconds and a little more, as its first step only notices whether
## it sleeps. Returns whether its "z"s showed at any step.
func _run_view(seconds: float) -> bool:
	var was_shown := false
	for _i in roundi(seconds / STEP) + 3:
		_cow_view._process(STEP)
		was_shown = was_shown or (_cow_view._zs != null and _cow_view._zs.is_sleeping)
	return was_shown


## Steps the view until its "z"s show, for the longest gap at the most.
func _run_until_shown() -> void:
	for _i in roundi(_longest_gap() / STEP) + 3:
		_cow_view._process(STEP)
		if _cow_view._zs != null and _cow_view._zs.is_sleeping:
			return


func _reactions() -> Array[Node]:
	return _cow_view.get_children().filter(func(child: Node) -> bool: return child is PetReaction)


func test_a_sleeping_animal_shows_zs_within_the_longest_gap() -> void:
	_cow.activity = FarmAnimal.Activity.SLEEP

	assert_true(_run_view(_longest_gap()), "shown")
	assert_eq(_cow_view._zs.position, Vector2(26, -29), "over the head of a cow lying down")


func test_it_stops_showing_the_zs_within_the_longest_shown_time() -> void:
	_cow.activity = FarmAnimal.Activity.SLEEP
	_run_until_shown()
	assert_true(_cow_view._zs.is_sleeping)

	_run_view(_longest_shown())

	assert_false(_cow_view._zs.is_sleeping)


func test_it_shows_them_again_after_a_gap() -> void:
	_cow.activity = FarmAnimal.Activity.SLEEP
	_run_until_shown()
	_run_view(_longest_shown())

	assert_true(_run_view(_longest_gap()))


func test_an_awake_animal_makes_no_zs() -> void:
	_cow_view._process(STEP)
	_cow_view._process(STEP)

	assert_null(_cow_view._zs)


func test_waking_takes_the_zs_away_even_one_mid_rise() -> void:
	_cow.activity = FarmAnimal.Activity.SLEEP
	_run_until_shown()
	_cow_view._zs._process(STEP)
	assert_eq(_cow_view._zs.get_child_count(), 1, "a z is rising")

	_cow.activity = FarmAnimal.Activity.IDLE
	_run_view(STEP)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(_cow_view._zs.is_sleeping)
	assert_eq(_cow_view._zs.get_child_count(), 0, "the one rising is gone too")
	assert_false(_run_view(_longest_gap() + _longest_shown()), "and no new ones")


func test_petting_takes_the_zs_away_and_the_anger_mark_shows() -> void:
	_cow.activity = FarmAnimal.Activity.SLEEP
	_run_until_shown()
	assert_true(_cow_view._zs.is_sleeping)

	_state.livestock.pet(_cow, _state.clock)

	assert_false(_cow_view._zs.is_sleeping)
	assert_eq(_reactions().size(), 1)
	assert_eq(_reactions()[0].texture.resource_path, "res://assets/effects/pet_annoyed.png")


func test_an_animal_in_a_coop_shows_none() -> void:
	_cow.activity = FarmAnimal.Activity.SLEEP
	_cow.is_housed = true

	assert_false(_run_view(_longest_gap()))


func test_an_animal_off_screen_does_nothing() -> void:
	_cow.activity = FarmAnimal.Activity.SLEEP
	_cow.position = Vector2(2000.0, 2000.0)

	assert_false(_run_view(_longest_gap()))
	assert_null(_cow_view._zs, "not even made")


func test_every_species_has_a_rise() -> void:
	for species in LivestockRules.SPECIES:
		assert_gt(FarmAnimalView.ZS_RISES[species], 0.0, str(species))


func test_the_small_animals_rise_less_far_than_the_cow() -> void:
	for species in [LivestockRules.CHICKEN, LivestockRules.RABBIT, LivestockRules.CAT]:
		var rise: float = FarmAnimalView.ZS_RISES[species]
		assert_lt(rise, FarmAnimalView.ZS_RISES[LivestockRules.COW], str(species))
