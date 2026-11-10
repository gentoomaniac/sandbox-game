extends LivestockCase
## The farm animals: their data file, their looks, where they are put, and how they go about
## their day (they keep to ground they can stand on, some run about, rabbits run from the player,
## and all sleep at night).

# --- The data file ---


func test_the_data_file_holds_every_required_key() -> void:
	var rules := LivestockRules.default_rules()
	assert_true(rules.is_valid(), "problems: %s" % [rules.problems()])


func test_every_missing_or_malformed_key_is_reported() -> void:
	var rules := (
		LivestockRules
		. new(
			{
				"general": {},
				"cow":
				{
					"looks": ["angler"],
					"look_weights": [1.0, 2.0],
					"tints": ["ffffff", "not a colour"],
					"activity_weights": [1.0],
					"idle_seconds": [5.0, 2.0],
					"walk_seconds": [1.0, 2.0],
					"graze_seconds": [1.0, 2.0],
					"run_seconds": [1.0, 2.0],
					"walk_speed": 1.0,
					"body_tiles": 0.5,
					"flee_tiles": 0.0,
					"run_speed": 0.0,
					"sleep_minutes": 0.0,
					"wake_minutes": 0.0,
				},
			}
		)
	)
	var problems := rules.problems()
	assert_has(problems, "[general] no calm_extra_tiles")
	assert_has(problems, "[sheep] no looks")
	assert_has(problems, "[cow] looks and look_weights differ in length or are empty")
	assert_has(problems, "[cow] tints needs one colour or more, as hex")
	assert_has(problems, "[cow] activity_weights needs idle, walk, graze and run")
	assert_has(problems, "[cow] idle_seconds needs [shortest, longest]")
	assert_does_not_have(problems, "[cow] walk_seconds needs [shortest, longest]")


# --- Looks ---


func test_the_same_seed_gives_the_same_look_and_tint() -> void:
	for species in LivestockRules.SPECIES:
		for seed_value in [1, 99, 123456]:
			var first := FarmAnimal.create(species, seed_value, Vector2.ZERO, _livestock.rules)
			var second := FarmAnimal.create(species, seed_value, Vector2.ZERO, _livestock.rules)
			assert_eq(first.look, second.look, "%s with seed %d" % [species, seed_value])
			assert_eq(first.tint, second.tint, "%s with seed %d" % [species, seed_value])


func test_the_animals_of_a_herd_differ_in_tint() -> void:
	var tints := {}
	for seed_value in 50:
		var sheep := FarmAnimal.create(
			LivestockRules.SHEEP, seed_value, Vector2.ZERO, _livestock.rules
		)
		tints[sheep.tint] = true
	assert_gt(tints.size(), 2)


func test_every_look_of_a_species_comes_up() -> void:
	for species in LivestockRules.SPECIES:
		var seen := {}
		for seed_value in 200:
			seen[FarmAnimal.create(species, seed_value, Vector2.ZERO, _livestock.rules).look] = true
		for look: String in _livestock.rules.looks(species):
			assert_true(seen.has(StringName(look)), "%s %s" % [species, look])


# --- Spawning ---


func test_spawned_animals_stand_on_walkable_ground_near_the_point() -> void:
	var placed := _livestock.spawn(LivestockRules.COW, 5, _pen_middle(), _world)

	assert_eq(placed, 5)
	assert_eq(_livestock.all().size(), 5)
	for animal in _livestock.all():
		assert_eq(animal.species, LivestockRules.COW)
		assert_true(_world.is_walkable(animal.tile()), "on %s" % animal.tile())
		assert_lte(animal.position.distance_to(_pen_middle()), Livestock.SPAWN_DISTANCE.y)


func test_spawned_animals_can_all_be_of_one_look() -> void:
	_livestock.spawn(LivestockRules.HORSE, 6, _pen_middle(), _world, &"pony")

	assert_eq(_livestock.all().size(), 6)
	for animal in _livestock.all():
		assert_eq(animal.look, &"pony")


func test_no_animal_is_put_where_nothing_can_stand() -> void:
	for y in range(-PEN_RADIUS, PEN_RADIUS + 1):
		for x in range(-PEN_RADIUS, PEN_RADIUS + 1):
			_world.set_terrain(_middle + Vector2i(x, y), Tile.Terrain.WATER)

	assert_eq(_livestock.spawn(LivestockRules.SHEEP, 3, _pen_middle(), _world), 0)
	assert_eq(_livestock.all().size(), 0)


func test_spawning_tells_whoever_listens() -> void:
	watch_signals(_livestock)
	_livestock.spawn(LivestockRules.CHICKEN, 2, _pen_middle(), _world)
	assert_signal_emit_count(_livestock, "added", 2)


# --- Going about the day ---


func test_animals_wander_but_never_onto_water_or_stones() -> void:
	for species in LivestockRules.SPECIES:
		_livestock.spawn(species, 3, _pen_middle(), _world)
	var starts := {}
	for animal in _livestock.all():
		starts[animal] = animal.position
	for _second in 120:
		_run(1.0)
		for animal in _livestock.all():
			assert_true(
				_world.is_walkable(animal.tile()), "%s on %s" % [animal.species, animal.tile()]
			)
	var moved := _livestock.all().filter(
		func(animal: FarmAnimal) -> bool: return animal.position.distance_to(starts[animal]) > 0.5
	)
	assert_gt(moved.size(), 6, "most of them walked about")


func test_an_animal_grazes_now_and_then() -> void:
	_livestock.spawn(LivestockRules.SHEEP, 1, _pen_middle(), _world)
	var sheep: FarmAnimal = _livestock.all()[0]
	var activities := {}
	for _step in 1200:
		_step()
		activities[sheep.activity] = true
	assert_true(activities.has(FarmAnimal.Activity.GRAZE))
	assert_true(activities.has(FarmAnimal.Activity.WALK))
	assert_true(activities.has(FarmAnimal.Activity.IDLE))


func test_dogs_cats_and_horses_pick_running_now_and_then_but_cows_never() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for species in [LivestockRules.DOG, LivestockRules.CAT, LivestockRules.HORSE]:
		var picks := range(1000).map(
			func(_pick: int) -> FarmAnimal.Activity:
				return _livestock.rules.pick_activity(species, rng)
		)
		assert_has(picks, FarmAnimal.Activity.RUN, species)
	var cow_picks := range(1000).map(
		func(_pick: int) -> FarmAnimal.Activity:
			return _livestock.rules.pick_activity(LivestockRules.COW, rng)
	)
	assert_does_not_have(cow_picks, FarmAnimal.Activity.RUN)


func test_a_running_dog_goes_faster_than_a_walking_one() -> void:
	var walker := FarmAnimal.new(LivestockRules.DOG, &"collie", _pen_middle() + Vector2(-1.0, -1.0))
	var runner := FarmAnimal.new(LivestockRules.DOG, &"spitz", _pen_middle() + Vector2(-1.0, 0.0))
	for dog in [walker, runner]:
		_livestock.add(dog)
		dog.heading = Vector2.RIGHT
		dog.seconds_left = 10.0
	walker.activity = FarmAnimal.Activity.WALK
	runner.activity = FarmAnimal.Activity.RUN
	var starts := [walker.position, runner.position]

	_run(0.25)

	assert_gt(walker.position.x - starts[0].x, 0.0, "the walker walked")
	assert_gt(runner.position.x - starts[1].x, 2.0 * (walker.position.x - starts[0].x))


func test_a_rabbit_runs_from_the_player_and_calms_down_further_off() -> void:
	var rabbit := FarmAnimal.new(LivestockRules.RABBIT, &"agouti", _pen_middle())
	_livestock.add(rabbit)
	_state.player.position = _pen_middle() + Vector2(1.0, 0.0)

	_step()
	assert_eq(rabbit.activity, FarmAnimal.Activity.FLEE)
	_run(1.0)

	assert_lt(rabbit.position.x, _pen_middle().x - 0.5, "away from the player, to the left")
	_state.player.position = _pen_middle() + Vector2(20.0, 0.0)
	_step()
	assert_ne(rabbit.activity, FarmAnimal.Activity.FLEE)


func test_a_cow_takes_no_notice_of_the_player() -> void:
	var cow := FarmAnimal.new(LivestockRules.COW, &"angler", _pen_middle())
	_livestock.add(cow)
	_state.player.position = _pen_middle() + Vector2(0.5, 0.0)
	_run(1.0)
	assert_ne(cow.activity, FarmAnimal.Activity.FLEE)


# --- Sleeping ---


func test_at_midnight_every_animal_sleeps_where_it_is() -> void:
	for species in LivestockRules.SPECIES:
		_livestock.spawn(species, 2, _pen_middle(), _world)
	var before := _livestock.all().map(func(animal: FarmAnimal) -> Vector2: return animal.position)

	_run(5.0, MIDNIGHT)

	for animal in _livestock.all():
		assert_eq(animal.activity, FarmAnimal.Activity.SLEEP, animal.species)
	var after := _livestock.all().map(func(animal: FarmAnimal) -> Vector2: return animal.position)
	assert_eq(after, before)


func test_they_wake_in_the_morning() -> void:
	_livestock.spawn(LivestockRules.COW, 3, _pen_middle(), _world)
	_run(1.0, MIDNIGHT)
	var morning := roundi(_state.sun.sunrise(DAY)) + 60

	_step(morning)

	for animal in _livestock.all():
		assert_ne(animal.activity, FarmAnimal.Activity.SLEEP)


func test_hens_go_to_roost_before_sunset_and_cows_lie_down_after_it() -> void:
	var hen := FarmAnimal.new(LivestockRules.CHICKEN, &"brown", _pen_middle())
	var cow := FarmAnimal.new(LivestockRules.COW, &"angler", _pen_middle())
	_livestock.add(hen)
	_livestock.add(cow)
	var sunset := roundi(_state.sun.sunset(DAY))

	assert_true(_livestock.is_sleep_time(hen, DAY, sunset))
	assert_false(_livestock.is_sleep_time(cow, DAY, sunset))


func test_a_sleeping_rabbit_does_not_run() -> void:
	var rabbit := FarmAnimal.new(LivestockRules.RABBIT, &"agouti", _pen_middle())
	_livestock.add(rabbit)
	_state.player.position = _pen_middle() + Vector2(1.0, 0.0)

	_run(1.0, MIDNIGHT)

	assert_eq(rabbit.activity, FarmAnimal.Activity.SLEEP)
	assert_eq(rabbit.position, _pen_middle())


func test_cows_wear_the_grass_they_walk_onto() -> void:
	_livestock.spawn(LivestockRules.COW, 3, _pen_middle(), _world)
	_run(60.0)
	var worn: Array = _world.to_dict()["wear"]
	assert_false(worn.is_empty(), "tracks in the pen")
	for entry: Array in worn:
		var tile := Vector2i(entry[0], entry[1])
		assert_lte((tile - _middle).abs().x, PEN_RADIUS, "in the pen: %s" % tile)
		assert_lte((tile - _middle).abs().y, PEN_RADIUS, "in the pen: %s" % tile)
		var steps: float = entry[2]
		assert_almost_eq(
			fmod(steps, PathRules.default_rules().animal_step()), 0.0, 0.0001, "hoof steps"
		)
