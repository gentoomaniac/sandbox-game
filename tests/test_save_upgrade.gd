extends GutTest
## Saves of older versions load, upgraded to the current one (see SaveFile).

const SAVE_DIR := "user://test_save_upgrade"
const SAVE_PATH := SAVE_DIR + "/world.json"


func after_each() -> void:
	for file_name in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR.path_join(file_name))


func _write_save(version: int, game: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": version, "game": game}))
	file.close()


func test_a_version_2_save_loads_with_wood_as_logs_and_nothing_on_the_ground() -> void:
	var state := GameState.new_game(7)
	state.player.inventory.add(ItemTypes.LOGS, 7)
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	game["world"].erase("ground_items")
	for stack: Variant in game["player"]["inventory"]["slots"]:
		if stack != null and stack["item"] == "logs":
			stack["item"] = "wood"
	_write_save(2, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.inventory.count_of(ItemTypes.LOGS), 7)
	assert_eq(restored.world.ground_items().size(), 0)


func test_a_current_save_keeps_its_ground_items() -> void:
	var state := GameState.new_game(7)
	state.world.add_ground_item(GroundItem.new(ItemTypes.LOGS, 2, Vector2(1.5, 2.25)))
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.world.ground_count_of(ItemTypes.LOGS), 2)
	assert_eq(restored.world.ground_items()[0].position, Vector2(1.5, 2.25))
