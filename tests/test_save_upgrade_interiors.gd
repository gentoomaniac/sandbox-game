extends SaveUpgradeCase
## Version 12 rooms have brick and clay floors: a version 11 save's rooms take them from their
## building's map (see SaveFile).


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
