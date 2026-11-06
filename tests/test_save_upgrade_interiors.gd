extends SaveUpgradeCase
## Version 12 rooms have brick and clay floors and plate racks: a version 11 save's rooms take
## them from their building's map (see SaveFile).


## A version 11 save with a longhouse whose room has the floor of version 11, FLOOR everywhere.
func _version_11_game_with_a_longhouse() -> Dictionary:
	var game := _current_game()
	var interior := InteriorLoader.load_interior(
		BuildingTypes.TYPES[BuildingTypes.LONGHOUSE]["interior_map"]
	)
	var saved_interior := interior.to_dict()
	for tile: Array in saved_interior["tiles"]:
		if tile[2] == "CLAY_FLOOR":
			tile[2] = "FLOOR"
	game["world"]["buildings"].append(
		{"type": "longhouse", "origin": [200, 200], "interior": saved_interior}
	)
	return game


func test_a_version_11_longhouse_gets_brick_in_the_living_end_and_clay_in_the_byre() -> void:
	_write_save(11, _version_11_game_with_a_longhouse())

	var restored := SaveFile.read(SAVE_PATH)

	var inside := restored.world.building_at(Vector2i(200, 200)).interior
	assert_eq(inside.tile_at(Vector2i(3, 4)).terrain, Tile.Terrain.FLOOR, "the living end")
	assert_eq(inside.tile_at(Vector2i(10, 4)).terrain, Tile.Terrain.CLAY_FLOOR, "the byre")
	assert_eq(inside.tile_at(Vector2i(0, 4)).terrain, Tile.Terrain.WALL)
	assert_eq(inside.tile_at(inside.exit_tile).terrain, Tile.Terrain.FLOOR, "the doormat")


func test_a_version_11_kate_gets_its_plate_rack_and_keeps_its_own_furniture() -> void:
	var game := _current_game()
	var interior := InteriorLoader.load_interior(
		BuildingTypes.TYPES[BuildingTypes.KATE]["interior_map"]
	)
	interior.remove_object(Vector2i(7, 0))
	interior.remove_object(Vector2i(2, 2))
	interior.add_object(WorldObject.new(WorldObjectTypes.CHEST, Vector2i(3, 3)))
	game["world"]["buildings"].append(
		{"type": "kate", "origin": [200, 200], "interior": interior.to_dict()}
	)
	_write_save(11, game)

	var restored := SaveFile.read(SAVE_PATH)

	var inside := restored.world.building_at(Vector2i(200, 200)).interior
	assert_eq(inside.object_at(Vector2i(7, 0)).type, WorldObjectTypes.PLATE_RACK, "on the wall")
	assert_null(inside.object_at(Vector2i(2, 2)), "nothing new stands on the floor")
	assert_eq(inside.object_at(Vector2i(3, 3)).type, WorldObjectTypes.CHEST)
	assert_eq(inside.objects().size(), interior.objects().size() + 1)
	var windows := inside.objects().filter(
		func(object: WorldObject) -> bool: return object.type == WorldObjectTypes.WINDOW
	)
	assert_eq(windows.size(), 2, "the windows it had, not twice")
