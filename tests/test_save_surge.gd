extends SaveValidationCase
## The storm surge and the water it left are saved with the world (#103); a save of version 55 has
## none, and the validator wants whole numbers in range and a known phase.

const NOW := 1000


func _restored(world: World) -> World:
	var data: Dictionary = JSON.parse_string(JSON.stringify(world.to_dict()))
	return World.from_dict(data, world.clock)


func _flooded_world() -> World:
	var world := CoastWorld.make()
	world.flood.begin(world, 3.4, NOW, 1)
	world.flood.settle(world)
	return world


func test_the_surge_that_is_coming_is_saved() -> void:
	var world := World.new(7)
	world.surge.expect(2.7, 5000, 180)
	world.surge.last_rolled_tide = 6

	var restored := _restored(world)

	assert_eq(restored.surge.to_dict(), world.surge.to_dict())
	assert_almost_eq(restored.surge.level, 2.7, 0.001)
	assert_eq(restored.surge.start_minute(), 4910)
	assert_eq(restored.surge.last_rolled_tide, 6)


func test_the_standing_water_its_salt_and_the_dykes_to_mend_are_saved() -> void:
	var world := _flooded_world()
	assert_gt(world.flood.wet_count(), 100)

	var restored := _restored(world)

	assert_eq(restored.flood.snapshot(), world.flood.snapshot())
	assert_eq(restored.flood.phase, FloodState.Phase.STANDING)
	assert_almost_eq(restored.flood.level, 3.4, 0.001)
	assert_eq(restored.flood.wet_count(), world.flood.wet_count())


func test_the_flood_of_a_game_loads_through_the_real_loader() -> void:
	var state := GameState.new_game(CoastWorld.SEED)
	CoastWorld.load_chunks(state.world)
	state.world.surge.expect(2.7, 5000, 180)
	state.world.flood.begin(state.world, 3.4, NOW, 1)
	state.world.flood.settle(state.world)

	var restored := RealLoad.of(self, state).world

	assert_eq(restored.flood.snapshot(), state.world.flood.snapshot())
	assert_eq(restored.flood.phase, FloodState.Phase.STANDING)
	assert_eq(restored.surge.to_dict(), state.world.surge.to_dict())


func test_a_flood_saved_while_filling_stands_as_far_as_it_got() -> void:
	var world := CoastWorld.make()
	world.flood.begin(world, 3.4, NOW, 1)
	world.flood.step_tiles(world, 20)

	var restored := _restored(world)

	assert_eq(restored.flood.wet_count(), 20)
	assert_eq(restored.flood.phase, FloodState.Phase.STANDING)


func test_a_draining_flood_drains_on_after_loading_with_the_mud_it_left() -> void:
	var world := _flooded_world()
	world.flood.advance(world, world.flood.drain_minute, false)
	var count := world.flood.wet_count()
	world.flood.step_tiles(world, count / 2)

	var restored := _restored(world)

	assert_eq(restored.flood.phase, FloodState.Phase.DRAINING)
	assert_eq(restored.flood.snapshot()["mud"], world.flood.snapshot()["mud"])
	restored.flood.settle(restored)
	assert_eq(restored.flood.wet_count(), 0)
	assert_eq(restored.flood.phase, FloodState.Phase.IDLE)


func test_a_load_during_the_hold_does_not_break_the_dykes_again() -> void:
	var world := _flooded_world()
	var dykes := CoastWorld.sea_dykes(world)
	assert_almost_eq(world.dykes.height_of(dykes[0]), 0.3, 0.001)
	var restored := _restored(world)
	var generator := WorldGenerator.new(CoastWorld.SEED)
	for coords in world.loaded_chunk_coords():
		restored.add_chunk(generator.generate_chunk(coords))
	var repairs_before: Dictionary = restored.flood.snapshot()["repairs"].duplicate()
	var breaches: Array[int] = []
	restored.flood.breached.connect(func(count: int) -> void: breaches.append(count))

	restored.flood.advance(restored, NOW + 30, true)

	assert_eq(breaches.size(), 0, "no dyke breaks twice")
	assert_eq(restored.flood.snapshot()["repairs"], repairs_before, "the repairs keep their time")
	assert_false(restored.flood.has_work(), "nothing more to fill")


func test_a_version_55_save_loads_with_no_surge_and_no_water() -> void:
	var data := _current_game()
	for key in [
		"surge",
		"flood",
		"flood_wet",
		"flood_salt",
		"flood_mud",
		"flood_repairs",
		"flood_met_chunks"
	]:
		data["world"].erase(key)
	_write_save(55, data)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_false(restored.world.surge.has_surge())
	assert_eq(restored.world.surge.last_rolled_tide, -1)
	assert_eq(restored.world.flood.wet_count(), 0)
	assert_false(restored.world.flood.is_active())


func test_a_current_save_without_the_fields_is_refused() -> void:
	for key in ["surge", "flood", "flood_wet"]:
		var data := _current_game()
		data["world"].erase(key)
		assert_string_contains(_refusal_of(data).reason, key)


func test_a_flood_with_an_unknown_phase_or_a_depth_out_of_range_is_refused() -> void:
	var data := _current_game()
	data["world"]["flood"]["phase"] = "rising"
	assert_string_contains(_refusal_of(data).reason, "phase")
	data = _current_game()
	data["world"]["flood_wet"] = [[1, 2, 0]]
	assert_string_contains(_refusal_of(data).reason, "depth")
	data["world"]["flood_wet"] = [[1, 2, 1001]]
	assert_string_contains(_refusal_of(data).reason, "depth")
	data["world"]["flood_wet"] = [[1, 2, 2.5]]
	assert_string_contains(_refusal_of(data).reason, "flood_wet")


func test_a_surge_with_a_level_out_of_range_is_refused() -> void:
	var data := _current_game()
	data["world"]["surge"]["level_cm"] = -5
	assert_string_contains(_refusal_of(data).reason, "level_cm")
	data["world"]["surge"]["level_cm"] = 5000
	assert_string_contains(_refusal_of(data).reason, "level_cm")
