extends CoopCase
## The hens and eggs of a chicken coop through a save, the night and the dawn, a demolition and a
## chunk that is unloaded and loaded again (task 122).


func test_the_eggs_and_the_hens_inside_are_saved() -> void:
	var hens := _hens(2)
	_run(30.0, NIGHT)
	assert_eq(_housed(hens).size(), 2)
	var restored := _reloaded()
	var coop := restored.world.building_at(_coop.origin)
	assert_eq(_eggs_of(coop), _eggs())
	assert_eq(_eggs_of(coop), 2)
	for hen in restored.livestock.all():
		assert_eq(restored.world.building_at(hen.tile()), coop, "still in the coop")


func test_a_game_saved_at_midnight_goes_on_through_the_night_and_the_dawn() -> void:
	_hens(2)
	_run(30.0, NIGHT)
	var restored := _reloaded()
	restored.livestock.yard = _yard_with("egg_chance", 1.0)
	restored.cheats.are_needs_off = true
	var coop := restored.world.building_at(_coop.origin)
	_run_in(restored, 20.0, 0)
	for hen in restored.livestock.all():
		assert_true(hen.is_housed, "inside and hidden through the night")
		assert_eq(hen.activity, FarmAnimal.Activity.SLEEP)
	assert_eq(_eggs_of(coop), 2, "no second egg for the same night")
	_run_in(restored, 0.2, MORNING)
	for hen in restored.livestock.all():
		assert_false(hen.is_housed)
		assert_lt(hen.position.distance_to(Coop.door_front(coop)), 1.0, "out in front of the door")


func test_taking_the_coop_down_with_hens_in_it_leaves_them_standing_where_it_was() -> void:
	var hens := _hens(2)
	_run(30.0, NIGHT)
	_world.remove_building(_coop)
	_run(1.0, NIGHT)
	for hen in hens:
		assert_false(hen.is_housed)
		assert_null(_world.building_at(hen.tile()))
	_run(3.0, MORNING)
	for hen in hens:
		assert_ne(hen.activity, FarmAnimal.Activity.SLEEP)


func test_a_coop_whose_chunk_is_unloaded_and_loaded_again_keeps_its_hens_and_eggs() -> void:
	_hens(2)
	_run(30.0, NIGHT)
	var coords := Chunk.world_to_chunk(_coop.origin)
	var saved := _state.to_dict()
	_world.remove_chunk(coords)
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(saved)))
	for loaded in _world.loaded_chunk_coords() + [coords]:
		restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(loaded))
	var coop := restored.world.building_at(_coop.origin)
	assert_eq(_eggs_of(coop), 2)
	_run_in(restored, 1.0, 0)
	for hen in restored.livestock.all():
		assert_true(hen.is_housed)
