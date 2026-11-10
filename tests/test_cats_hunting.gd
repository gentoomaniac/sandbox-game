extends LivestockCase
## A cat on the hunt, as Livestock moves it: only a cat that is up and rested hunts; it crouches,
## creeps up on the mouse and pounces onto it, then rests; it gives up a mouse that is gone; sleep
## ends a hunt, and a game saved mid-hunt loads with the cat looking about. No view is made: the
## hunt is all Livestock's, and the mouse is a Prey standing where it is told.

var _cat: FarmAnimal
var _prey: Prey


func before_each() -> void:
	super()
	_cat = FarmAnimal.new(LivestockRules.CAT, &"tabby", _pen_middle() + Vector2(-2.0, -1.0))
	_livestock.add(_cat)
	_prey = Prey.new()
	_prey.position = _mouse()


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


## What six hunts of one cat come to, with a catch roll that goes either way, on fresh dice. Each
## reaches the pounce and ends with the mouse caught or scared.
func _fates_of_six_hunts() -> Array[Prey.Fate]:
	var values := DataFile.read_sections(LivestockRules.DEFAULT_PATH)
	values["hunting"]["catch_chance"] = 0.5
	var herd := Livestock.new(_state.sun)
	herd.rules = LivestockRules.new(values)
	herd.rng.seed = SEED
	var cat := FarmAnimal.new(LivestockRules.CAT, &"tabby", _pen_middle())
	herd.add(cat)
	_state.clock.day = DAY
	_state.clock.minute_of_day = NOON
	var fates: Array[Prey.Fate] = []
	for _hunt in 6:
		var mouse := Prey.new()
		mouse.position = cat.position + Vector2(2.0, 0.0)
		cat.hunt_rest_seconds = 0.0
		herd.start_hunt(cat, mouse)
		var has_pounced := false
		for _i in roundi(30.0 / STEP_SECONDS):
			herd.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
			has_pounced = has_pounced or cat.activity == FarmAnimal.Activity.POUNCE
			if cat.activity in LivestockRules.CHOSEN_ACTIVITIES:
				break
		assert_true(has_pounced, "hunt %d reached the pounce" % _hunt)
		assert_ne(mouse.fate, Prey.Fate.NONE, "hunt %d came to something" % _hunt)
		fates.append(mouse.fate)
		cat.position = _pen_middle()
	return fates


## The upkeep of a skip, the player far from everything.
func _upkeep() -> ActorsUpkeep:
	var far_off := func() -> Vector2: return Vector2(1e6, 1e6)
	return ActorsUpkeep.new(_world, _livestock, _state.npcs, far_off)


## Rules whose pounces always catch (1) or never do (0).
func _set_catch_chance(chance: float) -> void:
	var values := DataFile.read_sections(LivestockRules.DEFAULT_PATH)
	values["hunting"]["catch_chance"] = chance
	_livestock.rules = LivestockRules.new(values)


## Lets time pass until the cat does `activity`, for at most 30 s.
func _run_until(activity: FarmAnimal.Activity) -> void:
	for _i in roundi(30.0 / STEP_SECONDS):
		if _cat.activity == activity:
			return
		_step()


## Lets time pass until the cat has a mouse it hunts, for at most 60 s.
func _run_until_hunting() -> void:
	for _i in roundi(60.0 / STEP_SECONDS):
		if _cat.hunted != null:
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
	_livestock.start_hunt(_cat, _prey)
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
	_livestock.start_hunt(_cat, _prey)
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
	_livestock.start_hunt(_cat, _prey)
	var moved := _mouse() + Vector2(0.0, 1.0)
	_prey.position = moved
	_run(STEP_SECONDS)
	assert_eq(_cat.pounce_at, moved)
	_run_until(FarmAnimal.Activity.POUNCE)
	assert_eq(_cat.activity, FarmAnimal.Activity.POUNCE)
	_prey.position = _mouse()
	_run(STEP_SECONDS)
	assert_eq(_cat.pounce_at, moved, "a leap is not turned in the air")


func test_a_cat_rests_after_a_hunt() -> void:
	_livestock.start_hunt(_cat, _prey)
	_run_hunt()
	assert_false(_livestock.can_hunt(_cat))
	_run(_livestock.rules.hunting("rest_seconds") - 1.0)
	assert_false(_livestock.can_hunt(_cat))
	_run(1.0 + STEP_SECONDS)
	assert_true(_livestock.can_hunt(_cat))


func test_a_cat_gives_up_a_mouse_that_is_gone() -> void:
	_livestock.start_hunt(_cat, _prey)
	_run(2.0)
	_prey.is_about = false
	_run(STEP_SECONDS)
	assert_eq(_cat.activity, FarmAnimal.Activity.IDLE)
	assert_null(_cat.hunted)
	assert_false(_livestock.can_hunt(_cat), "it rests all the same")


func test_a_cat_looks_about_for_a_mouse_when_it_picks_what_to_do_next() -> void:
	_livestock.add_prey(_prey)
	_run(60.0)
	assert_gt(_cat.hunt_rest_seconds, 0.0, "it hunted, and is resting")


func test_a_cat_with_no_mouse_about_hunts_nothing() -> void:
	_prey.is_about = false
	_livestock.add_prey(_prey)
	var activities := {}
	for _i in roundi(60.0 / STEP_SECONDS):
		_step()
		activities[_cat.activity] = true
	assert_false(activities.has(FarmAnimal.Activity.CROUCH))


func test_a_cat_hunts_the_nearest_mouse_in_sight_only() -> void:
	var sight := _livestock.rules.hunting("sight_tiles")
	var far := Prey.new()
	far.position = _cat.position + Vector2(sight + 0.5, 0.0)
	var in_sight := Prey.new()
	in_sight.position = _cat.position + Vector2(sight - 0.5, 0.0)
	var nearest := Prey.new()
	nearest.position = _cat.position + Vector2(1.0, 0.0)
	for mouse in [far, in_sight, nearest]:
		_livestock.add_prey(mouse)
	_run_until_hunting()
	assert_eq(_cat.hunted, nearest)


func test_a_pounce_that_misses_scares_the_mouse_off_from_where_the_cat_stood() -> void:
	_set_catch_chance(0.0)
	_livestock.start_hunt(_cat, _prey)
	_run_until(FarmAnimal.Activity.POUNCE)
	assert_eq(_prey.fate, Prey.Fate.SCARED)
	assert_false(_prey.is_about)
	assert_almost_eq(_prey.scare_point, _cat.position, Vector2(0.001, 0.001))
	_run_hunt()
	assert_eq(_prey.fate, Prey.Fate.SCARED, "left for the mouse to show")


func test_a_pounce_that_catches_takes_the_mouse_it_lands_on() -> void:
	_set_catch_chance(1.0)
	_livestock.start_hunt(_cat, _prey)
	_run_hunt()
	assert_eq(_prey.fate, Prey.Fate.CAUGHT)
	assert_false(_prey.is_about)


func test_a_mouse_that_has_moved_off_by_the_landing_is_not_caught() -> void:
	_set_catch_chance(1.0)
	_livestock.start_hunt(_cat, _prey)
	_run_until(FarmAnimal.Activity.POUNCE)
	_prey.position += Vector2(0.0, 3.0)
	_run_hunt()
	assert_eq(_prey.fate, Prey.Fate.NONE)
	assert_true(_prey.is_about)


func test_the_same_dice_give_the_same_hunts() -> void:
	assert_eq(_fates_of_six_hunts(), _fates_of_six_hunts())


func test_a_cat_goes_to_sleep_in_the_middle_of_a_hunt() -> void:
	_livestock.start_hunt(_cat, _prey)
	_run(2.0)
	_step(MIDNIGHT)
	assert_eq(_cat.activity, FarmAnimal.Activity.SLEEP)


func test_a_game_saved_mid_hunt_loads_with_the_cat_looking_about() -> void:
	_livestock.start_hunt(_cat, _prey)
	_run(2.0)
	assert_eq(_cat.activity, FarmAnimal.Activity.CREEP)
	var loaded := Livestock.new(_state.sun)
	loaded.load_array(JSON.parse_string(JSON.stringify(_livestock.to_array())))
	var cat := loaded.all()[0]
	assert_eq(cat.activity, FarmAnimal.Activity.IDLE)
	assert_eq(cat.position, _cat.position)
	assert_true(loaded.can_hunt(cat))


func test_a_cat_wakes_to_a_mouse_in_sight_and_hunts_it() -> void:
	_livestock.add_prey(_prey)
	_cat.activity = FarmAnimal.Activity.SLEEP
	_step()
	assert_eq(_cat.activity, FarmAnimal.Activity.CROUCH)


func test_the_walked_minutes_of_a_skip_give_up_a_hunt_with_no_outcome() -> void:
	_set_catch_chance(1.0)
	_livestock.start_hunt(_cat, _prey)
	_cat.activity = FarmAnimal.Activity.CREEP
	_cat.position = _mouse() - Vector2(1.0, 0.0)
	_state.clock.minute_of_day = NOON
	var upkeep := _upkeep()
	upkeep.walked_minute(_state.clock)
	assert_eq(_prey.fate, Prey.Fate.NONE)
	assert_true(_prey.is_about)
	assert_null(_cat.hunted)
	assert_false(_cat.activity in Livestock.HUNT_ACTIVITIES)


func test_the_walked_minutes_of_a_skip_start_no_hunt() -> void:
	_livestock.add_prey(_prey)
	_state.clock.minute_of_day = NOON
	var upkeep := _upkeep()
	for _minute in 3:
		upkeep.walked_minute(_state.clock)
	assert_null(_cat.hunted)
	assert_eq(_prey.fate, Prey.Fate.NONE)
