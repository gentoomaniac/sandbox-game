extends SaveValidationCase
## A save that holds content the game no longer has is asked about, never loaded half: the player
## decides, and the file on disk stays as it is until the game is saved.


func test_an_item_the_game_no_longer_has_is_asked_about_and_dropped_on_agreement() -> void:
	var game := _current_game()
	_slots(game)[4] = {"item": "old_seeds", "count": 3}
	game["player"]["equipment"]["head"] = "old_hat"

	var result := _question_about(game)

	assert_eq(result.missing.size(), 2)
	assert_true(result.missing.has("item old_seeds in player inventory slot 4"))
	assert_true(result.missing.has("item old_hat in player equipment head"))
	var state := result.load_dropping_missing()
	assert_eq(state.player.inventory.item_in(4), ItemTypes.NONE)
	assert_eq(state.player.equipment.item_in(Equipment.HEAD), ItemTypes.NONE)
	assert_eq(state.player.inventory.item_in(0), ItemTypes.HOE, "the rest stays")
	assert_eq(result.outcome, LoadResult.Outcome.READY)


func test_agreeing_does_not_change_the_file_and_keeps_a_copy_of_it() -> void:
	var game := _current_game()
	_slots(game)[4] = {"item": "old_seeds", "count": 3}
	var result := _question_about(game)
	var before := FileAccess.get_file_as_string(SAVE_PATH)
	assert_true(result.backup_path.ends_with(".json.bak"), "the dialog can name it")
	assert_string_contains(result.backup_path.get_file(), "world.20")

	result.load_dropping_missing()

	assert_eq(FileAccess.get_file_as_string(SAVE_PATH), before)
	assert_eq(FileAccess.get_file_as_string(result.backup_path), before)


func test_a_copy_never_replaces_an_earlier_backup() -> void:
	var game := _current_game()
	_slots(game)[4] = {"item": "old_seeds", "count": 3}
	_write_save(SaveFile.VERSION, game)
	var taken := SaveFile.free_backup_path(SAVE_PATH)
	FileAccess.open(taken, FileAccess.WRITE).store_string("earlier")
	var result := SaveFile.load_game(SAVE_PATH)

	result.load_dropping_missing()

	assert_ne(result.backup_path, taken)
	assert_eq(FileAccess.get_file_as_string(taken), "earlier")
	assert_true(FileAccess.file_exists(result.backup_path))


func test_an_object_the_game_no_longer_has_is_asked_about_and_leaves_its_tile_empty() -> void:
	var game := _current_game()
	_with_object_edit(game, {"type": "old_statue", "pos": [3, 4], "state": {}})
	game["world"]["buildings"].append(_house_with_interior_object("old_statue"))

	var result := _question_about(game)

	assert_eq(result.missing.size(), 2)
	var state := result.load_dropping_missing()
	assert_eq(state.world.buildings()[-1].interior.objects().size(), 0)


func test_a_pile_a_tree_a_recipe_and_an_animal_the_game_no_longer_has_are_asked_about() -> void:
	var game := _current_game()
	game["world"]["ground_items"].append({"item": "old_gem", "count": 1, "position": [1.5, 2.5]})
	_with_object_edit(game, {"type": "stump", "pos": [7, 7], "state": {"tree": "old_tree"}})
	_with_object_edit(game, _kiln_object({"recipe": "old_firing", "done_minute": 100}))
	(
		game["livestock"]
		. append(
			{
				"species": "unicorn",
				"look": "white",
				"tint": "ffffff",
				"position": [1.5, 2.5],
				"follow_until_minute": 0,
				"is_saddled": false,
			}
		)
	)

	var result := _question_about(game)

	assert_eq(result.missing.size(), 4)
	var state := result.load_dropping_missing()
	assert_eq(state.world.ground_items.all().size(), 0)
	assert_eq(state.livestock.all().size(), 0)


func test_content_that_is_missing_beside_damage_is_refused_not_asked_about() -> void:
	var game := _current_game()
	_slots(game)[4] = {"item": "old_seeds", "count": 3}
	_slots(game)[5] = {"item": "logs", "count": -7}

	_refusal_of(game)


func test_reading_a_save_with_missing_content_gives_no_game_and_moves_it_aside() -> void:
	var game := _current_game()
	_slots(game)[4] = {"item": "old_seeds", "count": 3}
	_write_save(SaveFile.VERSION, game)

	assert_null(SaveFile.read(SAVE_PATH))

	assert_push_error_count(1)
	assert_eq(SaveFile.backups_of(SAVE_PATH).size(), 1)


func _house_with_interior_object(type: String) -> Dictionary:
	return {
		"type": "kate",
		"style": "",
		"origin": [40, 40],
		"interior":
		{
			"size": [4, 4],
			"exit_tile": [1, 3],
			"tiles": [[1, 1, "FLOOR"]],
			"objects": [{"type": type, "pos": [1, 1], "state": {}}],
		},
	}
