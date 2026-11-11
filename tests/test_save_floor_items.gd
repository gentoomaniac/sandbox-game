extends IndoorCase
## The piles on the floor of a house are saved with its interior (version 29); a save of version
## 28, where nothing lay on a floor, loads with every floor bare.

const SAVE_PATH := "user://test_save_floor_items/world.json"


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func test_the_piles_on_a_floor_are_kept() -> void:
	var interior := _enter_house()
	interior.ground_items.add(GroundItem.new(ItemTypes.LOGS, 3, Vector2(2.25, 4.5)))
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	var piles := (restored.current_map as Interior).ground_items.all()
	assert_eq(piles.size(), 1)
	assert_eq(piles[0].item, ItemTypes.LOGS)
	assert_eq(piles[0].count, 3)
	assert_eq(piles[0].position, Vector2(2.25, 4.5))
	assert_true(restored.world.ground_items.all().is_empty(), "none of them in the world")


func test_a_version_28_save_loads_with_bare_floors() -> void:
	_enter_house()
	var game: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	for building: Dictionary in game["world"]["buildings"]:
		building["interior"].erase("ground_items")
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 28, "game": game}))
	file.close()

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	assert_true((restored.current_map as Interior).ground_items.all().is_empty())
