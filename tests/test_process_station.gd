extends ProcessStationCase
## A process station (ProcessStation) on the smelter of test config: loading its grid by hand and
## by a recipe click, the amount limits, the activation on whole loads only, the run on the game
## clock with the grid locked and the skill's bonus. Its results are test_process_station_out.gd's.

# --- The config ---


func test_the_test_station_is_valid_and_a_process_station() -> void:
	var stations := StationRules.new(STATIONS)
	assert_eq(stations.problems(), [] as Array[String])
	assert_true(stations.is_process(&"smelter"))
	assert_eq(stations.grid_size(&"smelter"), Vector2i(2, 2))
	assert_eq(stations.button_icon(&"smelter"), "res://assets/ui/process_fire.png")
	assert_eq(RecipeRules.new(RECIPES, stations).problems(), [] as Array[String])


func test_a_process_station_needs_its_grid_and_icon_and_only_it_has_them() -> void:
	var problems_of := func(values: Dictionary) -> Array[String]:
		var station := {"name": "Smelter", "objects": ["workbench"]}
		return StationRules.new({"smelter": station.merged(values)}).problems()
	assert_eq(
		problems_of.call({"process": true}),
		["[smelter] needs grid", "[smelter] needs button_icon"] as Array[String]
	)
	assert_eq(problems_of.call({"grid": Vector2i(3, 3)}).size(), 1, "not a process station")
	var bad := {"process": true, "grid": Vector2i(0, 3), "button_icon": "nothing"}
	assert_eq(problems_of.call(bad).size(), 2, "an empty grid and an icon with no picture")
	assert_eq(problems_of.call({"process": "yes"}).size(), 1)


# --- Loading the grid ---


func test_only_what_fits_a_recipe_goes_in() -> void:
	assert_eq(_put_in(ItemTypes.BERRIES), 0, "in no recipe")
	assert_eq(_put_in(ItemTypes.CLAY), 0, "the flour recipe is locked")
	assert_eq(_put_in(ItemTypes.STONE), 20)
	assert_eq(_grid(), {ItemTypes.STONE: 20})


func test_only_as_many_go_in_as_keep_a_recipe_open() -> void:
	# Bricks: 2x2 slots hold 99 loads at most, 198 stone and 99 logs (and the 297 bricks they make
	# at the bonus).
	_state.player.inventory.add(ItemTypes.STONE, 200)
	for _i in 3:
		_put_in(ItemTypes.STONE)
	assert_eq(_grid(), {ItemTypes.STONE: 198})
	assert_eq(_count(ItemTypes.STONE), 22)
	assert_eq(_station.room_for(ItemTypes.STONE), 0)


func test_a_recipe_click_moves_the_materials_counting_what_is_in_the_grid() -> void:
	_smelter.storage.add(ItemTypes.STONE, 3)
	assert_eq(_station.amounts(&"bricks"), Vector2i(2, 10), "two loads hold the stone, ten logs")
	assert_true(_station.fill(&"bricks", 2))
	assert_eq(_grid(), {ItemTypes.STONE: 4, ItemTypes.LOGS: 2})
	assert_eq(_count(ItemTypes.STONE), 19)
	assert_eq(_count(ItemTypes.LOGS), 8)


func test_an_amount_beyond_the_limits_is_refused() -> void:
	assert_eq(_station.amounts(&"bricks"), Vector2i(1, 10))
	assert_false(_station.fill(&"bricks", 11), "more than the stone and logs make")
	assert_false(_station.fill(&"bricks", 0))
	assert_true(_station.fill(&"bricks", 10), "the most")
	assert_eq(_grid(), {ItemTypes.STONE: 20, ItemTypes.LOGS: 10})


func test_a_locked_recipe_or_one_the_grid_rules_out_can_not_be_clicked() -> void:
	assert_false(_station.can_fill(&"flour"), "locked")
	_state.player.skills.set_points(&"masonry", 30.0)
	assert_true(_station.can_fill(&"flour"))
	_put_in(ItemTypes.STONE)
	assert_false(_station.is_open(&"flour"), "stone is not in flour")
	assert_false(_station.can_fill(&"flour"))
	assert_eq(_station.room_for(ItemTypes.CLAY), 0)
	assert_eq(_station.room_for(ItemTypes.LOGS), 99)


func test_taking_out_opens_recipes_again() -> void:
	_state.player.skills.set_points(&"masonry", 30.0)
	_put_in(ItemTypes.LOGS)
	_put_in(ItemTypes.STONE)
	assert_false(_station.is_open(&"flour"))
	_station.send_out(_smelter.storage.slots.find({"item": ItemTypes.STONE, "count": 20}))
	assert_true(_station.is_open(&"flour"))
	assert_gt(_station.room_for(ItemTypes.CLAY), 0)


# --- The run ---


func test_the_button_is_refused_on_a_part_load_and_says_what_is_missing() -> void:
	assert_false(_station.start(), "nothing in it")
	_put_in(ItemTypes.STONE)
	assert_eq(_station.runnable_recipe(), &"")
	assert_eq(_station.missing(), {ItemTypes.LOGS: 10})
	assert_false(_station.start())
	assert_false(_station.is_running())


func test_a_run_uses_up_the_whole_grid_and_gives_the_result_after_its_hours() -> void:
	_station.fill(&"bricks", 3)
	assert_eq(_station.runnable_recipe(), &"bricks")
	assert_true(_station.start())
	assert_true(_station.is_running())
	assert_eq(_station.minutes_left(), RUN_MINUTES)
	assert_eq(_state.player.skills.points(&"masonry"), 2.0, "practised")
	_state.simulation.advance(RUN_MINUTES - 1)
	assert_true(_station.is_running())
	assert_eq(_grid(), {ItemTypes.STONE: 6, ItemTypes.LOGS: 3}, "kept while it runs")
	_state.simulation.advance(1)
	assert_false(_station.is_running())
	assert_true(_station.holds_results())
	assert_eq(_grid(), {ItemTypes.BRICK: 6})


func test_the_grid_is_locked_while_it_runs() -> void:
	_station.fill(&"bricks", 1)
	_station.start()
	assert_eq(_station.room_for(ItemTypes.STONE), 0)
	assert_eq(_put_in(ItemTypes.STONE), 0)
	assert_false(_station.can_fill(&"bricks"))
	_station.send_out(0)
	_station.take_out(0, _smelter.storage, 3)
	assert_eq(_smelter.storage.slots[0], {"item": ItemTypes.STONE, "count": 2}, "nothing moves")
	assert_false(_station.start(), "one run at a time")


func test_the_run_goes_on_unseen_and_is_settled_by_whoever_looks() -> void:
	_station.fill(&"bricks", 1)
	_station.start()
	_state.simulation.advance(RUN_MINUTES)
	ProcessStation.settle(_smelter, _state.clock.total_minutes())
	assert_eq(_grid(), {ItemTypes.BRICK: 2})
	assert_false(_smelter.state[ProcessStation.RUN].has("products"))


func test_a_skilled_hand_makes_the_bonus_and_practises_at_its_level() -> void:
	_state.player.skills.set_points(&"masonry", 50.0)
	_station.fill(&"bricks", 3)
	_station.start()
	assert_eq(_state.player.skills.points(&"masonry"), 52.0, "as a recipe of level 50")
	_state.simulation.advance(RUN_MINUTES)
	assert_true(_station.holds_results())
	assert_eq(_grid(), {ItemTypes.BRICK: 9}, "6 and half of 6")


func test_a_locked_recipe_has_no_amounts() -> void:
	assert_eq(_station.amounts(&"flour"), Vector2i(1, 0))
	assert_false(_station.fill(&"flour", 1))


func test_a_put_in_tells_what_went_in() -> void:
	assert_eq(_put_in(ItemTypes.STONE), 20)
