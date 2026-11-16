extends VillageCase
## The nine villagers live in Wehlsbüll from the start of a new game, each with the home and the
## workplace of design/world/wehlsbuell.md, section 10.

var _state: GameState


func before_all() -> void:
	super.before_all()
	_state = GameFactory.new_game(1, true)


func _building_of(plan_id: String) -> Building:
	for entry in _plan.buildings:
		if entry["id"] == plan_id:
			return _state.world.building_at(_site(1).to_world(entry["origin"]))
	return null


func _villager(id: String) -> Npc:
	return _state.npcs.find(id)


func _spot_tile(name_of_spot: String) -> Vector2i:
	return _site(1).to_world(_plan.workplace_spots[name_of_spot])


func test_every_villager_of_the_file_lives_in_one_building_of_the_plan() -> void:
	var residents: Array[String] = []
	for entry in _plan.buildings:
		residents.append_array(entry["residents"])
	residents.sort()
	var ids := _state.npcs.villagers.ids()
	ids.sort()
	assert_eq(residents, ids)


func test_every_spot_a_sheet_works_at_has_its_tile_in_the_plan() -> void:
	for id in _state.npcs.villagers.ids():
		var sheet := _state.npcs.villagers.villager(id)
		if sheet.has(VillagerRules.WORKPLACE_SPOT_KEY):
			assert_true(_plan.workplace_spots.has(sheet[VillagerRules.WORKPLACE_SPOT_KEY]), id)


func test_the_nine_are_in_the_world_and_the_village_is_populated() -> void:
	assert_eq(_state.npcs.all().size(), 9)
	assert_true(_state.world.village.is_populated)


func test_each_lives_in_the_building_of_the_plan_and_the_boysens_share_one() -> void:
	for entry in _plan.buildings:
		for id: String in entry["residents"]:
			assert_eq(_villager(id).house, _building_of(entry["id"]), id)
	assert_eq(_villager("boy").house, _villager("antje").house)
	assert_eq(_villager("hinrich").house.type, BuildingTypes.HALL_HOUSE)


func test_the_boysens_work_in_the_hall_house_and_the_barn_the_others_at_their_spots_or_nowhere(
) -> void:
	assert_eq(_villager("antje").workplace.building, _villager("antje").house)
	for id in ["hinrich", "boy"]:
		assert_eq(_villager(id).workplace.building, _building_of("boysen_barn"), id)
	var landing := "the landing at the sluice"
	assert_eq(_villager("momme").workplace.spot_name, landing)
	assert_eq(_villager("momme").workplace.spot_tile, _spot_tile(landing))
	for id in ["ocke", "gesche"]:
		assert_eq(_villager(id).workplace.spot_name, "the post mill", id)
		assert_eq(_villager(id).workplace.spot_tile, _spot_tile("the post mill"), id)
	for id in ["inken", "kerrin"]:
		assert_null(_villager(id).workplace, id)


func test_trienke_works_at_the_stall_on_the_square() -> void:
	var trienke := _villager("trienke")
	var spot := "the market stall"
	assert_eq(trienke.workplace.spot_name, spot)
	assert_eq(trienke.workplace.spot_tile, _spot_tile(spot))
	assert_eq(trienke.house, _building_of("cottage_3"))
	var counter := _spot_tile(spot) + Vector2i.DOWN
	var stalls := _state.world.edited_objects().filter(
		func(object: WorldObject) -> bool: return object.type == WorldObjectTypes.MARKET_STALL
	)
	assert_eq(stalls.size(), 1)
	assert_eq(stalls[0].pos, counter, "the counter is in front of the spot")
	assert_true(_state.world.village.square.has_point(counter))


func test_trienke_keeps_the_stall_on_a_weekday_and_is_at_church_on_sunday() -> void:
	var trienke := _villager("trienke")
	var monday := _state.activities.entries_of(trienke, 1)
	var sunday := _state.activities.entries_of(trienke, 7)
	var no_day: Array[DayEntry] = []
	assert_eq(DayEntry.on(monday, no_day, 8 * 60).activity, "keep_shop")
	assert_eq(DayEntry.on(monday, no_day, 15 * 60).activity, "keep_shop")
	assert_eq(DayEntry.on(sunday, no_day, 10 * 60).activity, "go_to_church")
	var places := ActivityPlaces.new(_state.world, _state.npcs)
	assert_eq(
		places.spot_of(trienke, "workplace", 1),
		Vector2(_spot_tile("the market stall")) + Vector2(0.5, 0.5)
	)


func test_they_stand_at_the_door_of_their_house() -> void:
	for npc in _state.npcs.all():
		assert_lte(npc.position.distance_to(npc.house.yard()), Npcs.SPAWN_DISTANCE.y + 1.0, npc.id)


func test_they_move_in_once_and_a_save_holds_them_without_spawning_more() -> void:
	assert_eq(VillagePeople.move_in(_state, _site(1), _plan), "")
	assert_eq(_state.npcs.all().size(), 9)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.npcs.all().size(), 9)
	assert_true(restored.world.village.is_populated)
	assert_eq(restored.npcs.find("ocke").house.origin, _building_of("mill_house").origin)


func test_the_chunks_of_the_doors_are_unloaded_again() -> void:
	for coords in _state.world.loaded_chunk_coords():
		var chunk_rect := Rect2i(coords * Chunk.CHUNK_SIZE, Vector2i.ONE * Chunk.CHUNK_SIZE)
		assert_false(chunk_rect.intersects(_state.world.village.area), "chunk %s" % coords)


func test_the_places_of_the_day_are_the_villages() -> void:
	var places := ActivityPlaces.new(_state.world, _state.npcs)
	var meeting := Vector2(_state.world.village.meeting_spot) + Vector2(0.5, 0.5)
	assert_eq(places.spot_of(_villager("antje"), "meeting", 1), meeting)
	assert_eq(
		places.spot_of(_villager("momme"), "workplace", 1),
		Vector2(_spot_tile("the landing at the sluice")) + Vector2(0.5, 0.5)
	)
	var field := places.spot_of(_villager("hinrich"), "field", 1)
	assert_ne(field, ActivityPlaces.NOWHERE)
	assert_true(_state.world.village.field_spots.has(Vector2i(field.floor())))


func test_their_days_have_the_village_s_places_in_them() -> void:
	var activities_of := func(id: String) -> Array[String]:
		var found: Array[String] = []
		for day in range(1, 8):
			for entry in _state.activities.entries_of(_villager(id), day):
				found.append(entry.activity)
		return found
	assert_has(activities_of.call("hinrich"), "water_field")
	assert_has(activities_of.call("hinrich"), "meet_at_the_krug")
	assert_has(activities_of.call("ocke"), "work")
	assert_has(activities_of.call("momme"), "work")
