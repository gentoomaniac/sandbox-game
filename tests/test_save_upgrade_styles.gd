extends SaveUpgradeCase
## Version 24 saves keep the style of each building: in an older save every building has its own
## look (see SaveFile).


func test_a_version_23_save_loads_with_every_building_in_its_own_look() -> void:
	var game := _current_game()
	game["world"]["buildings"].append(
		{"type": "kate", "origin": SaveCodec.vector_to_json(Vector2i(4, 6)), "interior": null}
	)
	_write_save(23, game)

	var restored := SaveFile.read(SAVE_PATH)

	var kate: Building = restored.world.buildings()[-1]
	assert_eq(kate.type, BuildingTypes.KATE)
	assert_eq(kate.style, &"")
