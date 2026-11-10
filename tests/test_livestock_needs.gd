extends LivestockCase
## The needs of the farm animals (task 122): hunger and thirst rise with game time, an animal meets
## thirst at fresh water or a trough with water and hunger at a hay rack (or by grazing, for those
## that graze), never at salt water, a stock goes down by what each kind takes, the console can
## switch the rise off, and a skip of time (sleeping) counts the meals of animals that could reach
## what they need.

## The tiles of the pen's middle row and the one above it that the tests put a trough or a rack on.
const STOCK_AT := Vector2i(-1, -1)
const WATCH_SECONDS := 60.0
## Game minutes in `WATCH_SECONDS`.
const WATCH_MINUTES := WATCH_SECONDS * GameClock.GAME_MINUTES_PER_REAL_SECOND

var _played_seconds := 0.0


func before_each() -> void:
	super()
	_played_seconds = 0.0


## The clock runs with the steps, as in play, from the minute a test names: the needs rise with it.
func _step(minute := NOON) -> void:
	_played_seconds += STEP_SECONDS
	super(minute + int(_played_seconds * GameClock.GAME_MINUTES_PER_REAL_SECOND))


func _animal(species: StringName, at := Vector2.ZERO) -> FarmAnimal:
	var animal := FarmAnimal.new(species, _livestock.rules.looks(species)[0], _pen_middle() + at)
	_livestock.add(animal)
	_livestock.stand_still(animal)
	return animal


## Turns the water that rings the pen into sea: salt, which nothing may drink.
func _make_the_ring_salty(terrain := Tile.Terrain.SEA) -> void:
	for y in range(-PEN_RADIUS - 1, PEN_RADIUS + 2):
		for x in range(-PEN_RADIUS - 1, PEN_RADIUS + 2):
			var tile := _middle + Vector2i(x, y)
			if _world.tile_at(tile).terrain == Tile.Terrain.WATER:
				_world.set_terrain(tile, terrain)


func _stock(type: StringName, units: int) -> WorldObject:
	var object := WorldObject.new(type, _middle + STOCK_AT)
	_world.add_object(object)
	ObjectStock.add(object, units)
	return object


func _is_beside_fresh_water(animal: FarmAnimal) -> bool:
	for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var tile := _world.tile_at(animal.tile() + step)
		if tile != null and tile.is_fresh_water():
			return true
	return false


func test_hunger_and_thirst_rise_with_game_time_by_the_hours_of_the_species() -> void:
	var cow := _animal(LivestockRules.COW)
	var dog := _animal(LivestockRules.DOG)
	_state.cheats.are_needs_off = false
	_run(WATCH_SECONDS)
	assert_almost_eq(cow.thirst, WATCH_MINUTES / (8.0 * 60.0), 0.01)
	assert_almost_eq(dog.thirst, WATCH_MINUTES / (8.0 * 60.0), 0.01)
	assert_almost_eq(dog.hunger, WATCH_MINUTES / (12.0 * 60.0), 0.01, "a dog does not graze")


func test_a_new_animal_is_fed_and_watered() -> void:
	var animal := _animal(LivestockRules.SHEEP)
	assert_eq(animal.hunger, 0.0)
	assert_eq(animal.thirst, 0.0)


func test_the_console_switches_the_rise_off_and_on_again() -> void:
	var console := Console.new(_state)
	assert_eq(console.run("noneeds"), ["No needs on"])
	assert_true(_state.cheats.are_needs_off)
	assert_true("No needs" in _state.cheats.active_names())
	var cow := _animal(LivestockRules.COW)
	_run(WATCH_SECONDS)
	assert_eq(cow.thirst, 0.0, "nothing rises while it is off")
	assert_eq(cow.hunger, 0.0)
	assert_eq(console.run("noneeds"), ["No needs off"])
	_run(WATCH_SECONDS)
	assert_gt(cow.thirst, 0.1)


func test_a_thirsty_animal_walks_to_fresh_water_and_drinks() -> void:
	var cow := _animal(LivestockRules.COW)
	cow.thirst = 0.6
	_state.cheats.are_needs_off = true
	for _step in int(40.0 / STEP_SECONDS):
		_step()
		if cow.thirst == 0.0:
			break
	assert_eq(cow.thirst, 0.0, "it drank")
	assert_true(_is_beside_fresh_water(cow), "at the water's edge")


func test_a_thirsty_animal_does_not_drink_from_the_sea_the_mud_or_the_salt_marsh() -> void:
	for salty: Tile.Terrain in [Tile.Terrain.SEA, Tile.Terrain.MUD, Tile.Terrain.SALT_MARSH]:
		before_each()
		_make_the_ring_salty()
		for x in range(-PEN_RADIUS, PEN_RADIUS + 1):
			_world.set_terrain(_middle + Vector2i(x, -PEN_RADIUS), salty)
		var cow := _animal(LivestockRules.COW)
		cow.thirst = 0.6
		_state.cheats.are_needs_off = true
		_run(40.0)
		assert_eq(cow.thirst, 0.6, "it did not drink at %s" % salty)


func test_a_thirsty_animal_drinks_from_a_trough_with_water_and_it_goes_down_by_a_drink() -> void:
	_make_the_ring_salty()
	var trough := _stock(WorldObjectTypes.TROUGH, 100)
	var cow := _animal(LivestockRules.COW)
	cow.thirst = 0.6
	_state.cheats.are_needs_off = true
	_run(40.0)
	assert_eq(cow.thirst, 0.0)
	assert_eq(ObjectStock.units(trough), 100 - 5, "a cow drinks 5")
	assert_eq(ObjectStock.look(trough), 3, "still full")


func test_each_kind_takes_its_own_amount_from_the_stock() -> void:
	_make_the_ring_salty()
	for species: StringName in [LivestockRules.CHICKEN, LivestockRules.SHEEP, LivestockRules.COW]:
		var trough := _stock(WorldObjectTypes.TROUGH, 100)
		var animal := _animal(species)
		animal.thirst = 0.6
		_state.cheats.are_needs_off = true
		_run(40.0)
		var drink := _livestock.yard.units_per_need(species, &"thirst")
		assert_eq(ObjectStock.units(trough), 100 - drink, str(species))
		assert_eq(animal.thirst, 0.0, str(species))
		_world.remove_object(_middle + STOCK_AT)
	assert_eq(_livestock.yard.units_per_need(LivestockRules.CHICKEN, &"thirst"), 3)
	assert_eq(_livestock.yard.units_per_need(LivestockRules.COW, &"thirst"), 5)


func test_an_empty_trough_gives_nothing_and_the_animal_waits_before_it_looks_again() -> void:
	_make_the_ring_salty()
	_stock(WorldObjectTypes.TROUGH, 0)
	var cow := _animal(LivestockRules.COW)
	cow.thirst = 0.6
	_state.cheats.are_needs_off = true
	_run(5.0)
	assert_eq(cow.thirst, 0.6)
	assert_gt(cow.search_seconds, 0.0, "a search that found nothing is not repeated at once")


func test_a_trough_shows_its_picture_for_what_is_left_as_the_animals_drink() -> void:
	_make_the_ring_salty()
	var trough := _stock(WorldObjectTypes.TROUGH, 38)
	var cow := _animal(LivestockRules.COW)
	_state.cheats.are_needs_off = true
	assert_eq(ObjectStock.look(trough), 2)
	for _drink in 2:
		cow.thirst = 0.6
		_run(40.0)
	assert_eq(ObjectStock.units(trough), 28)
	assert_eq(ObjectStock.look(trough), 1, "low")


func test_a_hungry_cow_eats_at_a_hay_rack_and_the_rack_goes_down_by_a_meal() -> void:
	var rack := _stock(WorldObjectTypes.HAY_RACK, 100)
	var cow := _animal(LivestockRules.COW)
	cow.hunger = 0.6
	_state.cheats.are_needs_off = true
	_run(40.0)
	assert_eq(cow.hunger, 0.0)
	assert_eq(ObjectStock.units(rack), 100 - 5, "a cow eats 5")


func test_what_has_no_feed_to_eat_there_does_not_go_to_the_rack() -> void:
	var rack := _stock(WorldObjectTypes.HAY_RACK, 100)
	var dog := _animal(LivestockRules.DOG)
	var hen := _animal(LivestockRules.CHICKEN)
	dog.hunger = 0.9
	hen.hunger = 0.9
	_state.cheats.are_needs_off = true
	_run(40.0)
	assert_eq(ObjectStock.units(rack), 100)
	assert_eq(dog.hunger, 0.9)


func test_a_trough_of_water_is_no_food_and_a_hay_rack_no_drink() -> void:
	_make_the_ring_salty()
	var rack := _stock(WorldObjectTypes.HAY_RACK, 100)
	var cow := _animal(LivestockRules.COW)
	cow.thirst = 0.6
	_state.cheats.are_needs_off = true
	_run(20.0)
	assert_eq(cow.thirst, 0.6)
	assert_eq(ObjectStock.units(rack), 100)


func test_grazing_feeds_the_animals_that_graze_and_not_the_dog() -> void:
	_state.cheats.are_needs_off = true
	var cow := _animal(LivestockRules.COW)
	var dog := _animal(LivestockRules.DOG)
	for animal in [cow, dog]:
		animal.hunger = 0.5
		animal.activity = FarmAnimal.Activity.GRAZE
		animal.seconds_left = 10.0
	_run(5.0)
	assert_almost_eq(
		cow.hunger, 0.5 - 5.0 * _livestock.yard.needs("graze_relief_per_second"), 0.001
	)
	assert_eq(dog.hunger, 0.5)


func test_an_animal_asleep_goes_nowhere_for_water() -> void:
	var cow := _animal(LivestockRules.COW)
	cow.thirst = 0.9
	_state.cheats.are_needs_off = true
	_run(10.0, MIDNIGHT)
	assert_eq(cow.activity, FarmAnimal.Activity.SLEEP)
	assert_false(cow.goal.is_finite())


func test_the_needs_and_the_stock_are_saved() -> void:
	var trough := _stock(WorldObjectTypes.TROUGH, 64)
	var cow := _animal(LivestockRules.COW)
	cow.thirst = 0.3
	cow.hunger = 0.7
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	for coords in _world.loaded_chunk_coords():
		restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	var animal := restored.livestock.all()[0]
	assert_eq(animal.thirst, 0.3)
	assert_eq(animal.hunger, 0.7)
	assert_eq(ObjectStock.units(restored.world.object_at(trough.pos)), 64)


func test_the_data_file_has_every_number_of_the_needs() -> void:
	assert_true(YardRules.default_rules().is_valid(), str(YardRules.default_rules().problems()))


func test_the_needs_follow_the_clock_not_the_frames() -> void:
	var cow := _animal(LivestockRules.COW)
	_state.clock.day = DAY
	_state.clock.minute_of_day = NOON
	_livestock.account_needs(_state.clock)
	cow.thirst = 0.0
	_state.clock.minute_of_day = NOON + 60
	_livestock.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
	assert_almost_eq(cow.thirst, 60.0 / (8.0 * 60.0), 0.0001, "an hour in one slow frame")


func test_the_needs_stand_still_while_the_clock_does() -> void:
	var cow := _animal(LivestockRules.COW)
	_state.clock.day = DAY
	_state.clock.minute_of_day = NOON
	for _frame in 600:
		_livestock.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
	assert_eq(cow.thirst, 0.0, "frozen time, no rise, however many frames")


func test_a_ridden_horse_gets_hungry_and_thirsty_too() -> void:
	var horse := _animal(LivestockRules.HORSE)
	horse.is_ridden = true
	_state.clock.day = DAY
	_state.clock.minute_of_day = NOON
	_livestock.account_needs(_state.clock)
	horse.thirst = 0.0
	_state.clock.minute_of_day = NOON + 120
	_livestock.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
	assert_almost_eq(horse.thirst, 120.0 / (8.0 * 60.0), 0.0001)
