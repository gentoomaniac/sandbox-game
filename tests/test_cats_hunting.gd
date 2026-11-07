extends LivestockCase
## A cat on the hunt, as Livestock moves it: only a cat that is up and rested hunts; it crouches,
## creeps up on the mouse and pounces onto it, then rests; it gives up a mouse that is gone; sleep
## ends a hunt, and a game saved mid-hunt loads with the cat looking about.

var _cat: FarmAnimal


func before_each() -> void:
	super()
	_cat = FarmAnimal.new(LivestockRules.CAT, &"tabby", _pen_middle() + Vector2(-2.0, -1.0))
	_livestock.add(_cat)


## Where the mouse is: three tiles right of the cat, on open grass.
func _mouse() -> Vector2:
	return _pen_middle() + Vector2(1.0, -1.0)


## Lets time pass until the cat is done hunting (for at most 30 s), and returns what it did in
## turn, ending with what it did after.
func _run_hunt() -> Array[FarmAnimal.Activity]:
	var done: Array[FarmAnimal.Activity] = [_cat.activity]
	for _i in roundi(30.0 / STEP_SECONDS):
		_step()
		if _cat.activity != done.back():
			done.append(_cat.activity)
		if _cat.activity in LivestockRules.CHOSEN_ACTIVITIES:
			break
	return done


## Lets time pass until the cat does `activity`, for at most 30 s.
func _run_until(activity: FarmAnimal.Activity) -> void:
	for _i in roundi(30.0 / STEP_SECONDS):
		if _cat.activity == activity:
			return
		_step()


func test_only_a_cat_that_is_up_and_rested_hunts() -> void:
	assert_true(_livestock.can_hunt(_cat))
	var dog := FarmAnimal.new(LivestockRules.DOG, &"collie", _pen_middle())
	_livestock.add(dog)
	assert_false(_livestock.can_hunt(dog), "only cats hunt")
	_cat.hunt_rest_seconds = 1.0
	assert_false(_livestock.can_hunt(_cat), "resting")
	_cat.hunt_rest_seconds = 0.0
	_step(MIDNIGHT)
	assert_eq(_cat.activity, FarmAnimal.Activity.SLEEP)
	assert_false(_livestock.can_hunt(_cat), "asleep")


func test_a_cat_crouches_creeps_up_and_pounces_onto_its_mouse() -> void:
	var start := _cat.position
	_livestock.start_hunt(_cat, _mouse())
	assert_false(_livestock.can_hunt(_cat), "hunting already")
	var done := _run_hunt()
	assert_eq(
		done,
		(
			[
				FarmAnimal.Activity.CROUCH,
				FarmAnimal.Activity.CREEP,
				FarmAnimal.Activity.POUNCE,
				FarmAnimal.Activity.IDLE,
			]
			as Array[FarmAnimal.Activity]
		)
	)
	assert_ne(start, _cat.position)
	assert_almost_eq(_cat.position, _mouse(), Vector2(0.01, 0.01), "landed on the mouse")
	assert_eq(_cat.facing, 1.0)


func test_a_cat_crouches_a_while_then_creeps_slowly_and_pounces_from_near() -> void:
	var rules := _livestock.rules
	_livestock.start_hunt(_cat, _mouse())
	var start := _cat.position
	_run(rules.hunting("crouch_seconds") - STEP_SECONDS)
	assert_eq(_cat.activity, FarmAnimal.Activity.CROUCH)
	assert_eq(_cat.position, start, "still")
	_run(1.0 + STEP_SECONDS)
	assert_eq(_cat.activity, FarmAnimal.Activity.CREEP)
	var creep_start := _cat.position
	_run(1.0)
	assert_almost_eq(
		_cat.position.distance_to(creep_start), rules.hunting("creep_speed") * 1.0, 0.06
	)
	_run_until(FarmAnimal.Activity.POUNCE)
	assert_eq(_cat.activity, FarmAnimal.Activity.POUNCE)
	assert_lte(_cat.position.distance_to(_mouse()), rules.hunting("pounce_tiles"))


func test_a_cat_follows_its_mouse_until_it_pounces() -> void:
	_livestock.start_hunt(_cat, _mouse())
	var moved := _mouse() + Vector2(0.0, 1.0)
	_livestock.track_prey(_cat, moved)
	assert_eq(_cat.prey, moved)
	_run_until(FarmAnimal.Activity.POUNCE)
	assert_eq(_cat.activity, FarmAnimal.Activity.POUNCE)
	_livestock.track_prey(_cat, _mouse())
	assert_eq(_cat.prey, moved, "a leap is not turned in the air")


func test_a_cat_rests_after_a_hunt() -> void:
	_livestock.start_hunt(_cat, _mouse())
	_run_hunt()
	assert_false(_livestock.can_hunt(_cat))
	_run(_livestock.rules.hunting("rest_seconds") - 1.0)
	assert_false(_livestock.can_hunt(_cat))
	_run(1.0 + STEP_SECONDS)
	assert_true(_livestock.can_hunt(_cat))


func test_a_cat_gives_up_a_mouse_that_is_gone() -> void:
	_livestock.start_hunt(_cat, _mouse())
	_run(2.0)
	_livestock.stop_hunt(_cat)
	assert_eq(_cat.activity, FarmAnimal.Activity.IDLE)
	assert_false(_livestock.can_hunt(_cat), "it rests all the same")


func test_a_cat_goes_to_sleep_in_the_middle_of_a_hunt() -> void:
	_livestock.start_hunt(_cat, _mouse())
	_run(2.0)
	_step(MIDNIGHT)
	assert_eq(_cat.activity, FarmAnimal.Activity.SLEEP)


func test_a_game_saved_mid_hunt_loads_with_the_cat_looking_about() -> void:
	_livestock.start_hunt(_cat, _mouse())
	_run(2.0)
	assert_eq(_cat.activity, FarmAnimal.Activity.CREEP)
	var loaded := Livestock.new(_state.sun)
	loaded.load_array(JSON.parse_string(JSON.stringify(_livestock.to_array())))
	var cat := loaded.all()[0]
	assert_eq(cat.activity, FarmAnimal.Activity.IDLE)
	assert_eq(cat.position, _cat.position)
	assert_true(loaded.can_hunt(cat))
