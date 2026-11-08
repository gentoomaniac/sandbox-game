extends SaveUpgradeCase
## Saves of the last versions load, upgraded to the current one; older ones are refused (see
## SaveFile).


func test_a_save_of_the_oldest_supported_version_loads() -> void:
	_write_save(SaveFile.OLDEST_VERSION, _current_game())

	assert_not_null(SaveFile.read(SAVE_PATH))


func test_a_save_older_than_the_oldest_supported_version_is_refused_and_kept_as_backup() -> void:
	_write_save(SaveFile.OLDEST_VERSION - 1, _current_game())

	assert_null(SaveFile.read(SAVE_PATH))

	assert_push_error_count(1)
	assert_false(FileAccess.file_exists(SAVE_PATH))
	assert_true(FileAccess.file_exists(SAVE_PATH + SaveFile.BACKUP_SUFFIX))


func test_a_current_save_keeps_its_ground_items() -> void:
	var state := GameState.new_game(7)
	state.world.ground_items.add(GroundItem.new(ItemTypes.LOGS, 2, Vector2(1.5, 2.25)))
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.world.ground_items.count_of(ItemTypes.LOGS), 2)
	assert_eq(restored.world.ground_items.all()[0].position, Vector2(1.5, 2.25))


func test_a_current_save_missing_a_field_fails_loudly() -> void:
	var game := _current_game()
	game["player"].erase("energy")
	_write_save(SaveFile.VERSION, game)

	SaveFile.read(SAVE_PATH)

	assert_engine_error("energy")
