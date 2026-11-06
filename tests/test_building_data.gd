extends GutTest
## The buildings file, and what is built from it: types, footprints, doors and pictures.

const DATA_DIR := "user://test_buildings"
const DATA_FILE := DATA_DIR + "/buildings.cfg"
const FOOTPRINTS := {
	BuildingTypes.SHACK: Vector2i(3, 2),
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


func test_the_buildings_file_is_valid_and_has_the_five_buildings_in_order() -> void:
	var rules := BuildingRules.from_file(BuildingRules.DEFAULT_PATH)
	assert_true(rules.is_valid(), str(rules.problems()))
	assert_eq(
		rules.building_ids(),
		[
			BuildingTypes.SHACK,
			BuildingTypes.KATE,
			BuildingTypes.LONGHOUSE,
			BuildingTypes.HALL_HOUSE,
			BuildingTypes.BARN,
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
	_write(text.replace("door_offset=Vector2i(1, 1)", "door_offset=Vector2i(1, 0)"))
	var rules := BuildingRules.from_file(DATA_FILE)
	assert_eq(rules.problems(), ["[shack] door_offset must be a tile of the bottom row"])
	assert_push_error_count(1)


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


func test_every_building_has_pictures_as_wide_as_its_footprint() -> void:
	for id: StringName in FOOTPRINTS:
		var building_type: Dictionary = BuildingTypes.TYPES[id]
		for key in ["sprite", "sprite_lit"]:
			for look in SeasonalArt.HOUSE_LOOKS:
				var path := SeasonalArt.house_path(building_type[key], look)
				var texture: Texture2D = load(path)
				assert_not_null(texture, path)
				assert_eq(texture.get_width(), FOOTPRINTS[id].x * 16, path)
				assert_gt(texture.get_height(), FOOTPRINTS[id].y * 16, path)


func test_every_interior_map_exists_and_every_window_light_is_on_its_picture() -> void:
	for id: StringName in FOOTPRINTS:
		var building_type: Dictionary = BuildingTypes.TYPES[id]
		assert_true(FileAccess.file_exists(building_type["interior_map"]), str(id))
		var size: Vector2i = load(building_type["sprite"]).get_size()
		for centre: Vector2i in building_type["window_lights"]:
			assert_true(Rect2i(Vector2i.ZERO, size).has_point(centre), "%s %s" % [id, centre])


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
	assert_eq(ItemTypes.TYPES[ItemTypes.HAMMER]["tool"], ItemTypes.HAMMER)
	assert_eq(ItemTypes.TYPES[ItemTypes.HAMMER]["level"], 1)
	assert_true(ResourceLoader.exists(ItemTypes.icon_path(ItemTypes.HAMMER)))
	assert_true(ResourceLoader.exists(ItemTypes.ground_icon_path(ItemTypes.HAMMER)))
	assert_true(ResourceLoader.exists(ItemTypes.ground_icon_path(ItemTypes.REEDS)))
	assert_eq(Console.new(GameState.new_game(1)).run("give hammer").size(), 1)
