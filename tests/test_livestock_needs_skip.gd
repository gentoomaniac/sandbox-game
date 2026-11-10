extends LivestockCase
## A skip of time (sleeping) and the needs of the farm animals (task 122): an animal that could
## reach what it needs has met it, one that could not stays as risen, and the cheat holds them.

const STOCK_AT := Vector2i(-1, -1)


func _animal(species: StringName) -> FarmAnimal:
	var animal := FarmAnimal.new(species, _livestock.rules.looks(species)[0], _pen_middle())
	_livestock.add(animal)
	_livestock.stand_still(animal)
	return animal


func _make_the_ring_salty() -> void:
	for y in range(-PEN_RADIUS - 1, PEN_RADIUS + 2):
		for x in range(-PEN_RADIUS - 1, PEN_RADIUS + 2):
			var tile := _middle + Vector2i(x, y)
			if _world.tile_at(tile).terrain == Tile.Terrain.WATER:
				_world.set_terrain(tile, Tile.Terrain.SEA)


func _stock(type: StringName, units: int) -> WorldObject:
	var object := WorldObject.new(type, _middle + STOCK_AT)
	_world.add_object(object)
	ObjectStock.add(object, units)
	return object


func test_a_skip_counts_the_drinks_of_an_animal_that_could_reach_water() -> void:
	var cow := _animal(LivestockRules.COW)
	_state.clock.day = DAY
	_state.clock.set_time(12, 0)
	_state.simulation.skip(14 * GameClock.MINUTES_PER_HOUR)
	assert_lt(cow.thirst, _livestock.yard.needs("seek_at"), "it drank in the night")
	assert_lt(cow.hunger, _livestock.yard.needs("seek_at"), "and grazed")


func test_a_skip_leaves_an_animal_with_no_water_to_reach_as_thirsty_as_the_time_made_it() -> void:
	_make_the_ring_salty()
	var cow := _animal(LivestockRules.COW)
	var dog := _animal(LivestockRules.DOG)
	_state.clock.day = DAY
	_state.clock.set_time(12, 0)
	_state.simulation.skip(14 * GameClock.MINUTES_PER_HOUR)
	assert_eq(cow.thirst, 1.0)
	assert_eq(dog.thirst, 1.0)
	assert_eq(dog.hunger, 1.0, "a dog has nothing to eat yet, and hunger stops at its most")


func test_a_skip_takes_the_drinks_out_of_a_trough_and_the_meals_out_of_a_rack() -> void:
	_make_the_ring_salty()
	var trough := _stock(WorldObjectTypes.TROUGH, 100)
	var cow := _animal(LivestockRules.COW)
	_state.clock.day = DAY
	_state.clock.set_time(12, 0)
	_state.simulation.skip(14 * GameClock.MINUTES_PER_HOUR)
	assert_lt(cow.thirst, _livestock.yard.needs("seek_at"))
	assert_lt(ObjectStock.units(trough), 100, "it drank at the trough")
	assert_eq((100 - ObjectStock.units(trough)) % 5, 0, "in cow's drinks")


func test_a_skip_with_the_needs_off_changes_no_need() -> void:
	_state.cheats.are_needs_off = true
	var cow := _animal(LivestockRules.COW)
	_state.clock.day = DAY
	_state.clock.set_time(12, 0)
	_state.simulation.skip(14 * GameClock.MINUTES_PER_HOUR)
	assert_eq(cow.thirst, 0.0)
	assert_eq(cow.hunger, 0.0)


func test_the_hours_spent_indoors_are_in_a_save_and_in_the_game_loaded_from_it() -> void:
	var cow := _animal(LivestockRules.COW)
	_state.clock.day = DAY
	_state.clock.set_time(12, 0)
	_livestock.account_needs(_state.clock)
	cow.thirst = 0.0
	# The player is in a house for five hours: no update of the animals, but the clock runs.
	_state.clock.advance(5 * GameClock.MINUTES_PER_HOUR)
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	for coords in _world.loaded_chunk_coords():
		restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	assert_almost_eq(restored.livestock.all()[0].thirst, 300.0 / (8.0 * 60.0), 0.0001)
	assert_almost_eq(cow.thirst, 300.0 / (8.0 * 60.0), 0.0001, "and the saved game's own")


func test_a_game_loaded_indoors_counts_the_hours_it_stays_indoors() -> void:
	var cow := _animal(LivestockRules.COW)
	_state.clock.day = DAY
	_state.clock.set_time(12, 0)
	_livestock.account_needs(_state.clock)
	cow.thirst = 0.0
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	for coords in _world.loaded_chunk_coords():
		loaded.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	# No update of the animals while the player stays in a house for four hours, then a save.
	loaded.clock.advance(4 * GameClock.MINUTES_PER_HOUR)
	var again := GameState.from_dict(JSON.parse_string(JSON.stringify(loaded.to_dict())))
	assert_almost_eq(again.livestock.all()[0].thirst, 240.0 / (8.0 * 60.0), 0.0001)
