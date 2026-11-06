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


func test_a_version_3_save_loads_with_its_saplings_as_acorns() -> void:
	var state := GameState.new_game(7)
	state.player.inventory.add(ItemTypes.ACORN, 3)
	state.world.add_ground_item(GroundItem.new(ItemTypes.ACORN, 2, Vector2(1.5, 2.25)))
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	for stack: Variant in game["player"]["inventory"]["slots"]:
		if stack != null and stack["item"] == "acorn":
			stack["item"] = "sapling"
	game["world"]["ground_items"][0]["item"] = "sapling"
	_write_save(3, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.inventory.count_of(ItemTypes.ACORN), 3)
	assert_eq(restored.world.ground_count_of(ItemTypes.ACORN), 2)


func test_a_version_4_save_loads_with_its_small_houses_as_kates() -> void:
	var state := GameState.new_game(7)
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := state.player.tile() + Vector2i(x, y)
			if state.world.place_building(BuildingTypes.KATE, origin) != null:
				break
		if not state.world.buildings().is_empty():
			break
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	game["world"]["buildings"][0]["type"] = "small_house"
	_write_save(4, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.world.buildings()[0].type, BuildingTypes.KATE)
	assert_eq(restored.world.buildings()[0].origin, state.world.buildings()[0].origin)


func test_a_version_5_save_loads_with_its_twenty_slots_in_place_and_ten_new_empty_ones() -> void:
	var state := GameState.new_game(7)
	state.player.inventory.slots[19] = {"item": ItemTypes.LOGS, "count": 9}
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	var slots: Array = game["player"]["inventory"]["slots"]
	slots.resize(20)
	_write_save(5, game)

	var inventory := SaveFile.read(SAVE_PATH).player.inventory

	assert_eq(inventory.slots.size(), Inventory.SLOT_COUNT)
	assert_eq(inventory.item_in(0), ItemTypes.HOE)
	assert_eq(inventory.item_in(10), ItemTypes.STRAW_HAT)
	assert_eq(inventory.slots[19], {"item": ItemTypes.LOGS, "count": 9})
	for slot in range(20, Inventory.SLOT_COUNT):
		assert_true(inventory.slots[slot].is_empty())


func test_a_version_6_save_loads_with_its_tomatoes_as_flax() -> void:
	var state := GameState.new_game(7)
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	game["player"]["inventory"]["slots"][13] = {"item": "tomatoes_seeds", "count": 4}
	game["world"]["ground_items"].append({"item": "tomatoes", "count": 2, "position": [3.0, 4.0]})
	var crop := WorldObject.new(&"flax", Vector2i(100, 100)).to_dict()
	crop["type"] = "tomatoes"
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i(101, 100)).to_dict()
	chest["storage"][0] = {"item": "tomatoes", "count": 3}
	game["world"]["object_edits"].append({"pos": [100, 100], "object": crop})
	game["world"]["object_edits"].append({"pos": [101, 100], "object": chest})
	_write_save(6, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.inventory.slots[13], {"item": &"flax_seeds", "count": 4})
	assert_eq(restored.world.ground_count_of(&"flax"), 2)
	var objects := {}
	for edit: Dictionary in restored.world.to_dict()["object_edits"]:
		if edit["object"] != null:
			objects[edit["object"]["type"]] = edit["object"]
	assert_true(objects.has("flax"), "the planted tomatoes are flax")
	assert_eq(objects["chest"]["storage"][0], {"item": "flax", "count": 3})
