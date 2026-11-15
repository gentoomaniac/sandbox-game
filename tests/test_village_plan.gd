extends GutTest
## The village plan: its data file parses and its layout holds (design/world/wehlsbuell.md).

const DATA_DIR := "user://test_village_plan"
const DATA_FILE := DATA_DIR + "/village_plan.cfg"


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func _write(text: String) -> VillagePlan:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return VillagePlan.from_file(DATA_FILE)


func _default_text() -> String:
	return FileAccess.get_file_as_string(VillagePlan.DEFAULT_PATH)


func test_the_data_file_parses_and_its_layout_holds() -> void:
	var plan := VillagePlan.from_file(VillagePlan.DEFAULT_PATH)
	assert_eq(plan.problems(), [] as Array[String])
	assert_eq(plan.village_name, "Wehlsbüll")
	assert_eq(plan.buildings.size(), 19)


func test_every_building_has_its_free_tile_in_front() -> void:
	var plan := VillagePlan.default_plan()
	for building in plan.buildings:
		var front := plan.door_front(building)
		assert_false(plan.building_tiles(building).has(front), building["id"])


func test_the_square_and_the_mill_spot_hold_no_building() -> void:
	var plan := VillagePlan.default_plan()
	var building_tiles: Array[Vector2i] = []
	for building in plan.buildings:
		building_tiles.append_array(plan.building_tiles(building))
	for tile in building_tiles:
		assert_false(plan.square.has_point(tile), "%s is on the square" % tile)
		assert_false(plan.mill_spot.has_point(tile), "%s is on the mill's spot" % tile)


func test_a_missing_file_is_reported() -> void:
	var plan := VillagePlan.from_file(DATA_DIR + "/nothing.cfg")
	assert_false(plan.is_valid())
	assert_push_error_count(plan.problems().size() + 1)


func test_a_key_that_is_missing_or_of_the_wrong_type_is_named() -> void:
	var text := _default_text().replace("inland_from_u=9\n", "").replace(
		"marsh_end_u=36", 'marsh_end_u="far"'
	)
	var plan := _write(text)
	assert_eq(
		plan.problems(),
		["[village] no inland_from_u", "[village] marsh_end_u is not a int"] as Array[String]
	)
	assert_push_error_count(2)


func test_a_building_type_that_does_not_exist_is_named() -> void:
	var plan := _write(_default_text().replace('type="church"', 'type="cathedral"'))
	assert_eq(
		plan.problems(), ["[building.church] cathedral is not a building type"] as Array[String]
	)
	assert_push_error_count(1)


func test_two_buildings_on_one_tile_are_reported() -> void:
	var plan := _write(
		_default_text().replace("origin=Vector2i(35, -3)", "origin=Vector2i(32, -3)")
	)
	assert_true(plan.problems().any(func(problem: String) -> bool: return "overlaps" in problem))
	assert_push_error_count(plan.problems().size())


func test_a_wall_that_shuts_a_door_in_is_reported() -> void:
	# The churchyard's gap closed: the church and the bell frame are shut in.
	var text := _default_text().replace("gaps=[Vector2i(29, 6), Vector2i(30, 6)]", "gaps=[]")
	var plan := _write(text)
	assert_true(plan.problems().has("nobody can walk from church to the sielweg"))
	assert_push_error_count(plan.problems().size())


func test_a_field_without_a_way_to_a_lane_is_reported() -> void:
	var text := _default_text().replace("gaps=[Vector2i(50, -24), Vector2i(51, -24)]", "gaps=[]")
	var plan := _write(text)
	assert_true(plan.problems().has("the field farm_2_north is shut in"))
	assert_push_error_count(plan.problems().size())


func test_a_square_with_a_wall_across_it_is_reported() -> void:
	var text := _default_text().replace(
		"[lane.mill]",
		'[fence.across]\nkind="fence"\nrect=Rect2i(44, 8, 3, 3)\ngaps=[]\n\n[lane.mill]'
	)
	var plan := _write(text)
	assert_true(plan.problems().any(func(problem: String) -> bool: return "not free" in problem))
	assert_push_error_count(plan.problems().size())


func test_the_market_stall_stands_on_the_square_but_a_well_does_not() -> void:
	var default_plan := VillagePlan.default_plan()
	assert_true(default_plan.square.has_point(Vector2i(45, 7)), "the stall is on the square")
	assert_eq(default_plan.problems(), [] as Array[String])
	var text := _default_text().replace(
		'[objects.square_well]\ntype="draw_well"\ntiles=[Vector2i(42, 9)]',
		'[objects.square_well]\ntype="draw_well"\ntiles=[Vector2i(47, 9)]'
	)
	var plan := _write(text)
	assert_true(plan.problems().any(func(problem: String) -> bool: return "not free" in problem))
	assert_push_error_count(plan.problems().size())


func test_a_warft_is_an_oval_of_the_tiles_whose_middle_it_holds() -> void:
	var plan := VillagePlan.default_plan()
	var landing: Dictionary = plan.warften[0]
	var tiles := plan.warft_tiles(landing)
	assert_true(tiles.has(Vector2i(-7, 12)))
	assert_false(tiles.has(Vector2i(-13, 12)))
	assert_false(tiles.has(Vector2i(-12, 8)))


func test_a_lane_over_the_sielzug_is_a_culvert_and_leaves_the_tile_land() -> void:
	var plan := VillagePlan.default_plan()
	assert_false(plan.siel_tiles().has(Vector2i(9, 14)))
	assert_true(plan.siel_tiles().has(Vector2i(10, 14)))
