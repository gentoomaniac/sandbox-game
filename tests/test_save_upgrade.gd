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
	assert_eq(restored.world.ground_items.all().size(), 0)


func test_a_current_save_keeps_its_ground_items() -> void:
	var state := GameState.new_game(7)
	state.world.ground_items.add(GroundItem.new(ItemTypes.LOGS, 2, Vector2(1.5, 2.25)))
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.world.ground_items.count_of(ItemTypes.LOGS), 2)
	assert_eq(restored.world.ground_items.all()[0].position, Vector2(1.5, 2.25))


func test_a_version_3_save_loads_with_its_saplings_as_acorns() -> void:
	var state := GameState.new_game(7)
	state.player.inventory.add(ItemTypes.ACORN, 3)
	state.world.ground_items.add(GroundItem.new(ItemTypes.ACORN, 2, Vector2(1.5, 2.25)))
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	for stack: Variant in game["player"]["inventory"]["slots"]:
		if stack != null and stack["item"] == "acorn":
			stack["item"] = "sapling"
	game["world"]["ground_items"][0]["item"] = "sapling"
	_write_save(3, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.inventory.count_of(ItemTypes.ACORN), 3)
	assert_eq(restored.world.ground_items.count_of(ItemTypes.ACORN), 2)


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
	assert_eq(restored.world.ground_items.count_of(&"flax"), 2)
	var objects := {}
	for edit: Dictionary in restored.world.to_dict()["object_edits"]:
		if edit["object"] != null:
			objects[edit["object"]["type"]] = edit["object"]
	assert_true(objects.has("flax"), "the planted tomatoes are flax")
	assert_eq(objects["chest"]["storage"][0], {"item": "flax", "count": 3})


func test_a_version_6_save_turns_the_tomatoes_inside_a_building_into_flax() -> void:
	var state := GameState.new_game(7)
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	var crop := WorldObject.new(&"flax", Vector2i(1, 1)).to_dict()
	crop["type"] = "tomatoes"
	crop["state"]["growth"] = 5.0
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i(2, 1)).to_dict()
	chest["storage"][0] = {"item": "tomatoes_seeds", "count": 6}
	var interior := {"size": [4, 4], "exit_tile": [1, 3], "tiles": [], "objects": [crop, chest]}
	game["world"]["buildings"].append({"type": "kate", "origin": [200, 200], "interior": interior})
	_write_save(6, game)

	var restored := SaveFile.read(SAVE_PATH)

	var inside := restored.world.building_at(Vector2i(200, 200)).interior
	assert_eq(inside.object_at(Vector2i(1, 1)).type, &"flax")
	assert_eq(inside.object_at(Vector2i(1, 1)).state["growth"], 5.0, "keeps its growth")
	assert_eq(
		inside.object_at(Vector2i(2, 1)).storage.slots[0], {"item": &"flax_seeds", "count": 6}
	)


## A current save as parsed JSON, to take fields from.
func _current_game() -> Dictionary:
	return JSON.parse_string(JSON.stringify(GameState.new_game(7).to_dict()))


func test_a_version_7_save_without_soil_moisture_or_spent_clay_loads_with_neither() -> void:
	var game := _current_game()
	game["world"].erase("soil_moisture")
	game["world"].erase("spent_clay_spots")
	_write_save(7, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.world.to_dict()["soil_moisture"], [])
	assert_eq(restored.world.to_dict()["spent_clay_spots"], [])


func test_a_version_7_save_keeps_the_soil_moisture_and_clay_it_has() -> void:
	var state := GameState.new_game(7)
	state.world.set_moisture(Vector2i(5, 5), 0.9)
	state.world.spend_clay_spot(Vector2i(6, 6))
	_write_save(7, JSON.parse_string(JSON.stringify(state.to_dict())))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.world.moisture_at(Vector2i(5, 5)), 0.9)
	assert_eq(restored.world.to_dict()["spent_clay_spots"].size(), 1)


func test_a_version_7_save_without_equipment_wears_the_starting_outfit() -> void:
	var game := _current_game()
	game["player"].erase("equipment")
	_write_save(7, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.equipment.to_dict(), Equipment.with_starting_outfit().to_dict())


func test_a_version_7_save_without_energy_health_or_debuff_has_them_full() -> void:
	var game := _current_game()
	for field in ["energy", "health", "is_debuffed"]:
		game["player"].erase(field)
	_write_save(7, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.energy, PlayerState.MAX_ENERGY)
	assert_eq(restored.player.health, PlayerState.MAX_HEALTH)
	assert_false(restored.player.is_debuffed)


func test_a_version_7_save_gives_a_chest_without_a_store_an_empty_one() -> void:
	var game := _current_game()
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i(101, 100)).to_dict()
	chest.erase("storage")
	game["world"]["object_edits"].append({"pos": [101, 100], "object": chest})
	_write_save(7, game)

	var restored := SaveFile.read(SAVE_PATH)

	restored.world.add_chunk(Chunk.new(Vector2i(3, 3)))
	var storage := restored.world.object_at(Vector2i(101, 100)).storage
	assert_eq(storage.slots.size(), WorldObjectTypes.TYPES[WorldObjectTypes.CHEST]["storage_slots"])
	assert_eq(storage.count_of(ItemTypes.LOGS), 0)


func test_a_version_7_crop_that_counted_days_has_that_many_stages_of_growth() -> void:
	var game := _current_game()
	var crop := WorldObject.new(WorldObjectTypes.TURNIP, Vector2i(100, 100)).to_dict()
	crop["state"] = {"days_grown": 2}
	game["world"]["object_edits"].append({"pos": [100, 100], "object": crop})
	_write_save(7, game)

	var restored := SaveFile.read(SAVE_PATH)

	restored.world.add_chunk(Chunk.new(Vector2i(3, 3)))
	var restored_crop := restored.world.object_at(Vector2i(100, 100))
	var per_stage: float = WorldObjectTypes.TYPES[restored_crop.type]["growth_per_stage"]
	assert_eq(CropLife.growth(restored_crop), 2 * per_stage)
	assert_false(restored_crop.state.has("days_grown"))


## A version 8 save: dressed in the tunic and trousers, with bare feet.
func _version_8_game() -> Dictionary:
	var game := _current_game()
	game["player"]["equipment"] = {"body": "tunic", "legs": "trousers"}
	return game


func test_a_version_8_save_loads_with_its_tunic_and_trousers_as_waistcoat_and_breeches() -> void:
	var game := _version_8_game()
	game["player"]["inventory"]["slots"][13] = {"item": "trousers", "count": 1}
	game["world"]["ground_items"].append({"item": "tunic", "count": 1, "position": [3.0, 4.0]})
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i(101, 100)).to_dict()
	chest["storage"][0] = {"item": "tunic", "count": 1}
	game["world"]["object_edits"].append({"pos": [101, 100], "object": chest})
	_write_save(8, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.equipment.item_in(Equipment.BODY), ItemTypes.WAISTCOAT)
	assert_eq(restored.player.equipment.item_in(Equipment.LEGS), ItemTypes.BREECHES)
	assert_eq(restored.player.inventory.slots[13], {"item": ItemTypes.BREECHES, "count": 1})
	assert_eq(restored.world.ground_items.count_of(ItemTypes.WAISTCOAT), 1)
	restored.world.add_chunk(Chunk.new(Vector2i(3, 3)))
	var storage := restored.world.object_at(Vector2i(101, 100)).storage
	assert_eq(storage.slots[0], {"item": ItemTypes.WAISTCOAT, "count": 1})


func test_a_version_8_save_turns_the_trousers_in_a_chest_inside_a_building_into_breeches() -> void:
	var game := _version_8_game()
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i(2, 1)).to_dict()
	chest["storage"][0] = {"item": "trousers", "count": 1}
	var interior := {"size": [4, 4], "exit_tile": [1, 3], "tiles": [], "objects": [chest]}
	game["world"]["buildings"].append({"type": "kate", "origin": [200, 200], "interior": interior})
	_write_save(8, game)

	var restored := SaveFile.read(SAVE_PATH)

	var inside := restored.world.building_at(Vector2i(200, 200)).interior
	assert_eq(
		inside.object_at(Vector2i(2, 1)).storage.slots[0], {"item": ItemTypes.BREECHES, "count": 1}
	)


func test_a_version_8_save_puts_clogs_on_the_bare_feet() -> void:
	_write_save(8, _version_8_game())

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.equipment.item_in(Equipment.FEET), ItemTypes.CLOGS)


func test_a_version_9_save_keeps_the_worked_land_off_the_house_and_the_player() -> void:
	var game := _current_game()
	var generator := WorldGenerator.new(int(game["world"]["seed"]))
	var knick := _find_tile(
		func(pos: Vector2i) -> bool:
			return (
				generator.object_type_at(pos, generator.terrain_at(pos)) == WorldObjectTypes.KNICK
			)
	)
	var ditch := _find_tile(generator.is_ditch)
	# A shack whose door is right above the Knick, and the player standing in the ditch.
	var origin := knick - Vector2i(1, 2)
	var shack := {"type": "shack", "origin": SaveCodec.vector_to_json(origin), "interior": null}
	game["world"]["buildings"].append(shack)
	game["player"]["position"] = [ditch.x + 0.5, ditch.y + 0.9]
	_write_save(9, game)

	var restored := SaveFile.read(SAVE_PATH)

	var world := restored.world
	for tile: Vector2i in [knick, ditch]:
		world.add_chunk(generator.generate_chunk(Chunk.world_to_chunk(tile)))
	assert_null(world.object_at(knick), "nothing stands in front of the door")
	assert_true(world.is_walkable(knick))
	assert_eq(world.tile_at(ditch).terrain, Tile.Terrain.GRASS)
	assert_true(PlayerState.can_stand_at(world, restored.player.position))


## A tile within 200 tiles of the centre for which `is_wanted` is true.
func _find_tile(is_wanted: Callable) -> Vector2i:
	for y in range(-200, 200):
		for x in range(-60, 60):
			if is_wanted.call(Vector2i(x, y)):
				return Vector2i(x, y)
	fail_test("no tile found")
	return Vector2i.ZERO


func test_a_current_save_missing_a_field_fails_loudly() -> void:
	var game := _current_game()
	game["player"].erase("energy")
	_write_save(SaveFile.VERSION, game)

	SaveFile.read(SAVE_PATH)

	assert_engine_error("energy")
