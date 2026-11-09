extends SaveValidationCase
## A damaged save is refused with the place of the damage before anything is built from it;
## reading it changes no file (SaveFile `load_game`).

# --- Damaged saves are refused ---


func test_logs_of_minus_seven_and_a_selected_slot_999_are_refused_with_their_places() -> void:
	var game := _current_game()
	_slots(game)[4]["count"] = -7
	game["player"]["inventory"]["selected_slot"] = 999

	var result := _refusal_of(game)

	assert_string_contains(result.reason, "player inventory slot 4: count -7 is not between 1 and")
	assert_string_contains(result.reason, "player inventory: selected_slot 999")


func test_a_count_over_the_stack_limit_is_refused() -> void:
	var game := _current_game()
	_slots(game)[0]["count"] = 2

	var result := _refusal_of(game)

	assert_string_contains(result.reason, "player inventory slot 0: count 2 is not between 1 and 1")


func test_a_wrong_number_of_slots_is_refused() -> void:
	var game := _current_game()
	_slots(game).pop_back()

	assert_string_contains(_refusal_of(game).reason, "player inventory: slots has 27 slots, not 28")


func test_a_missing_field_is_refused() -> void:
	var game := _current_game()
	game["player"].erase("energy")

	assert_string_contains(_refusal_of(game).reason, "player: no energy")


func test_a_field_of_the_wrong_type_is_refused() -> void:
	var game := _current_game()
	game["player"]["energy"] = "full"
	game["clock"]["minute_of_day"] = 2.5

	var result := _refusal_of(game)

	assert_string_contains(result.reason, "player energy: should be a number")
	assert_string_contains(result.reason, "clock minute_of_day: should be a whole number")


func test_a_game_of_the_wrong_type_is_refused() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string('{"version": %d, "game": []}' % SaveFile.VERSION)
	file.close()

	var result := SaveFile.load_game(SAVE_PATH)

	assert_eq(result.outcome, LoadResult.Outcome.REFUSED)
	assert_true(FileAccess.file_exists(SAVE_PATH))


func test_a_map_reference_to_no_building_is_refused() -> void:
	var game := _current_game()
	game["current_map"] = {"kind": "interior", "building": [5, 5]}

	assert_string_contains(
		_refusal_of(game).reason, "current_map: no building with an inside at (5, 5)"
	)


func test_an_unknown_kind_of_map_is_refused() -> void:
	var game := _current_game()
	game["home_map"] = {"kind": "moon"}

	assert_string_contains(_refusal_of(game).reason, "home_map: unknown kind of map moon")


func test_equipment_that_does_not_fit_its_slot_is_refused() -> void:
	var game := _current_game()
	game["player"]["equipment"]["head"] = "axe"

	assert_string_contains(_refusal_of(game).reason, "player equipment head: axe can't be worn")


func test_a_station_working_on_a_recipe_that_is_not_slow_is_refused() -> void:
	var game := _current_game()
	_with_object_edit(game, _kiln_object({"recipe": "planks", "done_minute": 100}))

	assert_string_contains(_refusal_of(game).reason, "recipe planks is not made at a station")


func test_a_station_work_without_its_recipe_is_refused() -> void:
	var game := _current_game()
	_with_object_edit(game, _kiln_object({"done_minute": 100}))

	assert_string_contains(_refusal_of(game).reason, "state work: no recipe")


func test_a_chest_with_a_bad_stack_is_refused_with_its_place() -> void:
	var game := _current_game()
	var chest := {"type": "chest", "pos": [3, 4], "state": {}, "storage": []}
	for slot in WorldObjectTypes.TYPES[WorldObjectTypes.CHEST]["storage_slots"]:
		chest["storage"].append(null)
	chest["storage"][2] = {"item": "logs", "count": 0}
	_with_object_edit(game, chest)

	assert_string_contains(_refusal_of(game).reason, "object slot 2: count 0 is not between 1")


func test_an_object_state_that_is_not_a_number_is_refused() -> void:
	var game := _current_game()
	_with_object_edit(game, {"type": "kiln", "pos": [3, 4], "state": {"damage": "much"}})

	assert_string_contains(_refusal_of(game).reason, "state: damage should be a number")


func test_the_problems_are_listed_with_how_many_more_there_are() -> void:
	var game := _current_game()
	for key: String in ["energy", "health", "is_debuffed", "position", "facing", "home_bed"]:
		game["player"].erase(key)

	var result := _refusal_of(game)

	assert_string_contains(result.reason, "and 2 more")


func test_reading_a_refused_save_moves_it_aside() -> void:
	var game := _current_game()
	game["player"].erase("energy")
	_write_save(SaveFile.VERSION, game)

	assert_null(SaveFile.read(SAVE_PATH))

	assert_push_error_count(1)
	assert_false(FileAccess.file_exists(SAVE_PATH))
	assert_eq(SaveFile.backups_of(SAVE_PATH).size(), 1)


func test_a_save_moved_aside_never_replaces_an_earlier_backup() -> void:
	var game := _current_game()
	game["player"].erase("energy")
	for attempt in 2:
		_write_save(SaveFile.VERSION, game)
		SaveFile.read(SAVE_PATH)

	assert_eq(SaveFile.backups_of(SAVE_PATH).size(), 2, "even in the same second")
	assert_push_error_count(2)


func test_a_damaged_save_of_the_oldest_version_is_refused_too() -> void:
	var game := _current_game()
	_slots(game)[4]["count"] = -7
	_write_save(SaveFile.OLDEST_VERSION, game)

	assert_eq(SaveFile.load_game(SAVE_PATH).outcome, LoadResult.Outcome.REFUSED)


# --- Whole saves ---


func test_the_oldest_and_the_newest_version_load_without_a_question() -> void:
	for version in [SaveFile.OLDEST_VERSION, SaveFile.VERSION]:
		_write_save(version, _current_game())

		var result := SaveFile.load_game(SAVE_PATH)

		assert_eq(result.outcome, LoadResult.Outcome.READY, "version %d" % version)


func test_a_lived_in_game_passes_the_validator_and_round_trips() -> void:
	var state := GameState.new_game(7)
	state.world.drop_items(state.player.tile(), {ItemTypes.LOGS: 3})
	state.player.inventory.add(ItemTypes.LOGS, 40)
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	_with_object_edit(game, _kiln_object({"recipe": "bricks", "done_minute": 100}))

	var validator := SaveValidator.check(game)

	assert_eq(validator.problems, [] as Array[String])
	assert_eq(validator.missing, [] as Array[String])
	_write_save(SaveFile.VERSION, game)
	assert_eq(SaveFile.load_game(SAVE_PATH).outcome, LoadResult.Outcome.READY)
