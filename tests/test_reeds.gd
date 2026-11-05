extends ResourceCase
## The reeds on the banks: where they stand, the scythe cutting them, and their regrowth by the
## weather of the days after.

const WINTER := 105
const AUTUMN := 85
## The area, in tiles around the origin, that is searched for reeds.
const SEARCH_RADIUS := 160

var _reeds: WorldObject


func before_each() -> void:
	super.before_each()
	_set_midsummer()
	_reeds = _place(WorldObjectTypes.REEDS)


func _cut() -> GameState.Use:
	_state.player.facing = Vector2i.DOWN
	_state.player.position = Vector2(_tile) + Vector2(0.5, -0.5)
	return _hit(ItemTypes.SCYTHE, 1)


func _day(mean_temperature: float, sunlight_hours: float) -> WeatherDay:
	var day := WeatherDay.new()
	day.mean_temperature = mean_temperature
	day.min_temperature = mean_temperature - 4.0
	day.sunlight_hours = sunlight_hours
	return day


# --- Where they stand ---


func test_reeds_stand_on_banks_near_water_and_at_wetland_edges_only() -> void:
	var generator := WorldGenerator.new(SEED)
	var found := 0
	var on_bank := 0
	for y in range(-SEARCH_RADIUS, SEARCH_RADIUS, 2):
		for x in range(-SEARCH_RADIUS, SEARCH_RADIUS, 2):
			var pos := Vector2i(x, y)
			var terrain := generator.terrain_at(pos)
			if generator.object_type_at(pos, terrain) != WorldObjectTypes.REEDS:
				continue
			found += 1
			if terrain == Tile.Terrain.FLOODPLAIN:
				on_bank += 1
				assert_true(generator._is_water_within(pos, WorldGenerator.REEDS_REACH), str(pos))
			else:
				assert_eq(terrain, Tile.Terrain.WETLAND, str(pos))
				assert_true(generator._is_wetland_edge(pos), str(pos))
	assert_gt(found, 20, "stands along the river and wetland")
	assert_gt(on_bank, 10, "the river's bank has reeds")


func test_no_reeds_stand_on_grass_or_in_the_water() -> void:
	var generator := WorldGenerator.new(SEED)
	for y in range(-SEARCH_RADIUS, SEARCH_RADIUS):
		for x in range(-SEARCH_RADIUS, SEARCH_RADIUS, 3):
			var pos := Vector2i(x, y)
			var terrain := generator.terrain_at(pos)
			if terrain == Tile.Terrain.GRASS or terrain == Tile.Terrain.WATER:
				assert_ne(generator.object_type_at(pos, terrain), WorldObjectTypes.REEDS)


func test_reeds_neither_block_walking_nor_give_way_to_the_hoe() -> void:
	assert_false(_reeds.blocks_walking())
	assert_eq(_hit(ItemTypes.HOE, 1), GameState.Use.NOTHING)
	assert_same(_world.object_at(_tile), _reeds)


# --- Cutting ---


func test_the_scythe_cuts_reeds_into_reeds_on_the_ground_and_leaves_stubble() -> void:
	assert_eq(_cut(), GameState.Use.MOW)
	assert_eq(_dropped(ItemTypes.REEDS), 2)
	assert_true(_reeds.is_picked(), "cut")
	assert_same(_world.object_at(_tile), _reeds, "the stubble stays")
	var cell := ObjectTileset.atlas_cell(_reeds)
	assert_gte(cell.x, WorldObjectTypes.TYPES[WorldObjectTypes.REEDS]["variants"], "stubble look")


func test_cut_reeds_are_not_cut_again() -> void:
	_cut()
	assert_eq(_state.use_facing_tile(), GameState.Use.NOTHING)
	assert_eq(_dropped(ItemTypes.REEDS), 2)


func test_a_hand_does_not_pick_reeds() -> void:
	assert_eq(_hit(ItemTypes.NONE, 1), GameState.Use.NOTHING)


func test_reeds_stand_all_year_and_can_be_cut_in_winter() -> void:
	_state.clock.day = WINTER
	assert_false(_world.is_dormant(_reeds))
	assert_eq(_cut(), GameState.Use.MOW)


func test_reeds_have_a_look_in_every_season_and_cut() -> void:
	var object_type: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.REEDS]
	assert_eq(ObjectTileset.looks_count(object_type), 2 * object_type["variants"])
	for look in SeasonBlend.Look.values():
		var image: Image = load(SeasonalArt.path(ObjectTileset.ATLAS_PATH, look)).get_image()
		for variant in ObjectTileset.looks_count(object_type):
			var region := Rect2i(
				(
					Vector2i(variant, object_type["atlas_row"])
					* Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
				),
				Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
			)
			assert_false(image.get_region(region).is_invisible(), "%d, %d" % [look, variant])


func test_the_reeds_item_has_a_weight_and_pictures() -> void:
	assert_gt(ItemTypes.TYPES[ItemTypes.REEDS]["weight"], 0.0)
	for directory in ["items", "ground_items"]:
		assert_true(ResourceLoader.exists("res://assets/%s/reeds.png" % directory))


# --- Regrowth ---


func test_a_cut_stand_regrows_on_warm_sunny_days_and_not_on_cold_or_dark_ones() -> void:
	_cut()
	var needed: float = _reeds.type_data()["regrow_growth"]
	for _i in int(needed) - 1:
		assert_false(ReedLife.live_through_day(_reeds, _day(20.0, 8.0)))
	assert_true(_reeds.is_picked(), "still cut")
	for _i in 50:
		assert_false(ReedLife.live_through_day(_reeds, _day(2.0, 8.0)), "cold")
		assert_false(ReedLife.live_through_day(_reeds, _day(20.0, 0.5)), "dark")
	assert_true(ReedLife.live_through_day(_reeds, _day(20.0, 8.0)), "the last warm day")
	assert_false(_reeds.is_picked(), "stands again")


func test_a_poor_day_gives_less_growth_than_a_perfect_one() -> void:
	_cut()
	ReedLife.live_through_day(_reeds, _day(10.0, 3.0))
	assert_between(float(_reeds.state[ReedLife.REGROWTH]), 0.1, 0.9)


func test_a_stand_cut_in_the_growing_season_is_back_after_some_days() -> void:
	_cut()
	_sleep_days(12)
	assert_false(_world.object_at(_tile).is_picked())
	assert_eq(_cut(), GameState.Use.MOW, "cut again")


func test_a_stand_cut_in_winter_stays_cut_through_the_winter() -> void:
	_state.clock.day = WINTER
	_cut()
	_sleep_days(12)
	assert_true(_world.object_at(_tile).is_picked())


func test_reeds_need_no_soil_moisture() -> void:
	assert_false(_reeds.type_data().has("moisture_best"))
	assert_eq(CropLife.weather_score(_reeds.type_data(), _day(20.0, 8.0)), 1.0)


func test_a_crop_scores_the_lower_of_its_weather_and_its_moisture() -> void:
	var turnip := WorldObject.new(WorldObjectTypes.TURNIP, Vector2i.ZERO)
	var day := _day(turnip.type_data()["temperature_best"], 8.0)
	assert_eq(CropLife.score(turnip, day, 1.0), 1.0)
	assert_lt(CropLife.score(turnip, day, 0.1), 0.5)


# --- Saving ---


func test_a_cut_stand_stays_cut_and_keeps_its_growth_through_the_save() -> void:
	_state.clock.day = AUTUMN
	_cut()
	ReedLife.live_through_day(_reeds, _day(10.0, 3.0))
	var growth := float(_reeds.state[ReedLife.REGROWTH])
	_world.change_object(_reeds)
	var restored := _through_save()
	var loaded := restored.world.object_at(_tile)
	assert_true(loaded.is_picked())
	assert_almost_eq(float(loaded.state[ReedLife.REGROWTH]), growth, 0.0001)
