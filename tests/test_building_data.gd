extends GutTest
## The buildings file, and what is built from it: types, footprints, doors and pictures.

const DATA_DIR := "user://test_buildings"
const DATA_FILE := DATA_DIR + "/buildings.cfg"
const FOOTPRINTS := {
	BuildingTypes.SHACK: Vector2i(3, 2),
	BuildingTypes.FISHER_HUT: Vector2i(4, 2),
	BuildingTypes.KATE: Vector2i(5, 3),
	BuildingTypes.LONGHOUSE: Vector2i(7, 3),
	BuildingTypes.HALL_HOUSE: Vector2i(7, 5),
	BuildingTypes.BARN: Vector2i(6, 3),
}


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func _write(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_the_buildings_file_is_valid_and_has_the_nine_buildings_in_order() -> void:
	var rules := BuildingRules.from_file(BuildingRules.DEFAULT_PATH)
	assert_true(rules.is_valid(), str(rules.problems()))
	assert_eq(
		rules.building_ids(),
		[
			BuildingTypes.SHACK,
			BuildingTypes.FISHER_HUT,
			BuildingTypes.KATE,
			BuildingTypes.LONGHOUSE,
			BuildingTypes.HALL_HOUSE,
			BuildingTypes.BARN,
			BuildingTypes.CHURCH,
			BuildingTypes.BELL_FRAME,
			BuildingTypes.CHICKEN_COOP,
		]
	)
	assert_eq(BuildingTypes.ids(), rules.building_ids())


func test_every_missing_required_key_is_reported() -> void:
	_write('[shack]\nname="Shack"\nfootprint=Vector2i(3, 2)\ndoor_offset=Vector2i(1, 1)\n')
	var rules := BuildingRules.from_file(DATA_FILE)
	var problems := rules.problems()
	assert_false(rules.is_valid())
	assert_true(problems.has("[shack] no cost_reeds"))
	assert_true(problems.has("[shack] no interior_map"))
	assert_true(problems.has("[shack] no comfort"))
	assert_false(problems.has("[shack] no name"))
	assert_eq(problems.size(), BuildingRules.REQUIRED_KEYS.size() - 3)
	assert_push_error_count(problems.size())


func test_a_door_off_the_bottom_row_is_reported() -> void:
	var text := FileAccess.get_file_as_string(BuildingRules.DEFAULT_PATH)
	var shack_door := 'door_offset=Vector2i(1, 1)\nsprite="res://assets/buildings/shack.png"'
	_write(text.replace(shack_door, shack_door.replace("(1, 1)", "(1, 0)")))
	var rules := BuildingRules.from_file(DATA_FILE)
	assert_eq(rules.problems(), ["[shack] door_offset must be a tile of the bottom row"])
	assert_push_error_count(1)


func test_a_style_is_its_building_with_its_own_keys_over_it() -> void:
	var text := FileAccess.get_file_as_string(BuildingRules.DEFAULT_PATH)
	_write(text + '\n[shack.tarred]\nname="Tarred shack"\ncost_logs=25\n')
	var rules := BuildingRules.from_file(DATA_FILE)
	assert_true(rules.is_valid(), str(rules.problems()))
	assert_false(rules.building_ids().has(&"shack.tarred"))
	assert_eq(rules.style_ids(BuildingTypes.SHACK), [&"", &"tarred"])
	assert_eq(rules.style(BuildingTypes.SHACK, &""), rules.building(BuildingTypes.SHACK))
	var tarred := rules.style(BuildingTypes.SHACK, &"tarred")
	assert_eq(tarred["name"], "Tarred shack")
	assert_eq(tarred["cost_logs"], 25)
	assert_eq(tarred["footprint"], Vector2i(3, 2))
	assert_eq(rules.building(BuildingTypes.SHACK)["cost_logs"], 20)


func test_a_style_without_a_name_one_word_id_or_building_or_that_changes_it_is_reported() -> void:
	var text := FileAccess.get_file_as_string(BuildingRules.DEFAULT_PATH)
	var styles := (
		'\n[shack.tarred]\nfootprint=Vector2i(4, 2)\ninterior_map=""\n'
		+ '\n[cottage.brick]\nname="Brick cottage"\n'
		+ '\n[shack.]\nname="Shack"\n'
		+ '\n[shack.tarred.old]\nname="Old tarred shack"\n'
	)
	_write(text + styles)
	var rules := BuildingRules.from_file(DATA_FILE)
	assert_eq(
		rules.problems(),
		[
			"[shack.tarred] no name",
			"[shack.tarred] footprint is the building's",
			"[shack.tarred] interior_map is the building's",
			"[cottage.brick] is a style of no building",
			"[shack.] style id must be one word",
			"[shack.tarred.old] style id must be one word",
		]
	)
	assert_push_error_count(6)


func test_every_building_has_its_own_look_as_its_first_style() -> void:
	for id in BuildingTypes.ids():
		assert_eq(BuildingTypes.styles(id)[0], &"", str(id))
		assert_eq(BuildingTypes.of(id, &""), BuildingTypes.TYPES[id], str(id))


func test_a_missing_file_is_reported() -> void:
	var rules := BuildingRules.from_file(DATA_DIR + "/nothing.cfg")
	assert_false(rules.is_valid())
	assert_push_error_count(2)


func test_every_building_has_the_footprint_and_a_door_on_its_bottom_row() -> void:
	for id: StringName in FOOTPRINTS:
		var building_type: Dictionary = BuildingTypes.TYPES[id]
		assert_eq(building_type["footprint"], FOOTPRINTS[id], str(id))
		var door: Vector2i = building_type["door_offset"]
		assert_eq(door.y, FOOTPRINTS[id].y - 1, "%s door row" % id)
		var building := Building.new(id, Vector2i(10, 20))
		assert_eq(building.tiles().size(), FOOTPRINTS[id].x * FOOTPRINTS[id].y, str(id))
		assert_true(building.tiles().has(building.door_tile()), str(id))
		assert_eq(building.door_tile(), Vector2i(10, 20) + door)


func test_every_style_has_pictures_as_wide_as_its_footprint() -> void:
	for id: StringName in FOOTPRINTS:
		var size: Vector2i = FOOTPRINTS[id] * TerrainTileset.TILE_SIZE
		for style in BuildingTypes.styles(id):
			var building_type := BuildingTypes.of(id, style)
			for key in ["sprite", "sprite_lit"]:
				for look in SeasonalArt.HOUSE_LOOKS:
					var path := SeasonalArt.house_path(building_type[key], look)
					var texture: Texture2D = load(path)
					assert_not_null(texture, path)
					assert_eq(texture.get_width(), size.x, path)
					assert_gt(texture.get_height(), size.y, path)


func test_every_interior_map_exists_and_every_window_light_is_on_its_picture() -> void:
	for id: StringName in FOOTPRINTS:
		assert_true(FileAccess.file_exists(BuildingTypes.TYPES[id]["interior_map"]), str(id))
		for style in BuildingTypes.styles(id):
			var building_type := BuildingTypes.of(id, style)
			var size: Vector2i = load(building_type["sprite"]).get_size()
			for centre: Vector2i in building_type["window_lights"]:
				var where := "%s %s %s" % [id, style, centre]
				assert_true(Rect2i(Vector2i.ZERO, size).has_point(centre), where)


func test_the_kate_comes_in_brick_and_in_the_geest_look() -> void:
	assert_eq(BuildingTypes.styles(BuildingTypes.KATE), [&"", &"brick", &"geest"])
	var brick := BuildingTypes.of(BuildingTypes.KATE, &"brick")
	assert_eq(brick["name"], "Brick Kate")
	assert_eq(brick["costs"][ItemTypes.CLAY], 30)
	assert_eq(brick["window_lights"], BuildingTypes.TYPES[BuildingTypes.KATE]["window_lights"])
	assert_eq(BuildingTypes.of(BuildingTypes.KATE, &"geest")["name"], "Geest Kate")


func test_costs_are_the_materials_that_are_not_zero() -> void:
	assert_eq(BuildingTypes.TYPES[BuildingTypes.BARN]["costs"][ItemTypes.CLAY], 5)
	assert_false(BuildingTypes.TYPES[BuildingTypes.SHACK]["costs"].has(ItemTypes.CLAY))
	for id in BuildingTypes.ids():
		for item: StringName in BuildingTypes.TYPES[id]["costs"]:
			assert_true(ItemTypes.TYPES.has(item), "%s %s" % [id, item])
			assert_true(ResourceLoader.exists(ItemTypes.icon_path(item)))


func test_the_hall_house_is_the_biggest_and_costs_the_most_of_every_material() -> void:
	var hall_house: Dictionary = BuildingTypes.TYPES[BuildingTypes.HALL_HOUSE]
	var area: int = hall_house["footprint"].x * hall_house["footprint"].y
	for id in BuildingTypes.ids():
		if id == BuildingTypes.HALL_HOUSE:
			continue
		var building_type: Dictionary = BuildingTypes.TYPES[id]
		assert_lt(building_type["footprint"].x * building_type["footprint"].y, area, str(id))
		for key: String in BuildingTypes.COST_ITEMS:
			assert_lt(building_type[key], hall_house[key], "%s %s" % [id, key])


func test_the_hammer_is_a_tool_item_with_icons() -> void:
	assert_eq(ItemTypes.TYPES[ItemTypes.RUSTY_IRON_HAMMER]["tool"], ItemTypes.HAMMER)
	assert_eq(ItemTypes.TYPES[ItemTypes.RUSTY_IRON_HAMMER]["level"], 1)
	assert_true(ResourceLoader.exists(ItemTypes.icon_path(ItemTypes.RUSTY_IRON_HAMMER)))
	assert_true(ResourceLoader.exists(ItemTypes.ground_icon_path(ItemTypes.RUSTY_IRON_HAMMER)))
	assert_true(ResourceLoader.exists(ItemTypes.ground_icon_path(ItemTypes.REEDS)))
	assert_eq(Console.new(GameState.new_game(1)).run("give rusty_iron_hammer").size(), 1)
