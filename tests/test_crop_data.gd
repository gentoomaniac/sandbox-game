extends GutTest
## The crops file, and what is built from it: object types, items, sheets and food.

const DATA_DIR := "user://test_crops"
const DATA_FILE := DATA_DIR + "/crops.cfg"
## A crop made only of a config section, with the picture sheet of the turnip.
const FAKE_CROP := """
[dandelion]
name="Dandelion"
seed_name="Dandelion seeds"
description="A weed."
sheet="res://assets/crops/turnip.png"
seed="dandelion_seeds"
produce="dandelion"
seed_weight=0.01
produce_weight=0.1
yield=2
seed_chance=0.5
regrow_stage=0
ripe_wait_factor=1.0
growth_per_stage=2.0
damage_per_bad_day=0.5
heal_per_good_day=0.1
temperature_min=0.0
temperature_best=10.0
temperature_max=20.0
sunlight_min=1.0
sunlight_best=4.0
moisture_min=0.1
moisture_best=0.5
wind_max=10.0
"""
const FARMING := """
[farming]
default_moisture=0.3
poor_harvest_chance=0.1
good_harvest_chance=0.2
rain_wets=0.1
drying_base=0.04
drying_per_degree=0.005
drying_per_sun_hour=0.015
drying_per_wind=0.005
good_day_score=0.6
fallow_weedy_days=5
fallow_grass_days=10
fallow_rests_in_winter=1
"""
const REEDS := """
[reeds]
regrow_growth=4.0
temperature_min=5.0
temperature_best=20.0
temperature_max=32.0
sunlight_min=2.0
sunlight_best=6.0
"""
const CROP_NAMES: Array[StringName] = [
	&"turnip",
	&"potato",
	&"carrot",
	&"cabbage",
	&"onion",
	&"wheat",
	&"rye",
	&"buckwheat",
	&"peas",
	&"beans",
	&"flax",
	&"strawberries",
	&"pumpkin",
]


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func _write(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_the_crops_file_is_valid_and_has_the_thirteen_crops() -> void:
	var rules := CropRules.from_file(CropRules.DEFAULT_PATH)
	assert_true(rules.is_valid(), str(rules.problems()))
	assert_eq(rules.crop_ids(), CROP_NAMES)
	assert_eq(rules.crop(&"potato")["seed_name"], "Seed potatoes")
	assert_eq(rules.crop(&"potato")["yield"], 3)
	assert_eq(rules.farming("good_day_score"), 0.6)


func test_the_reeds_are_no_crop_and_have_their_needs_in_their_own_section() -> void:
	var rules := CropRules.default_rules()
	assert_false(rules.crop_ids().has(&"reeds"), "no seeds, no sheet, no planting")
	for key in CropRules.REQUIRED_REEDS_KEYS:
		assert_true(rules.reeds().has(key), key)
	assert_false(ItemTypes.TYPES.has(&"reeds_seeds"))


func test_every_missing_required_key_is_reported() -> void:
	_write('[farming]\nrain_wets=0.1\n[turnip]\nname="Turnip"\n')
	var rules := CropRules.from_file(DATA_FILE)
	var problems := rules.problems()
	assert_false(rules.is_valid())
	assert_true(problems.has("[farming] no default_moisture"))
	assert_false(problems.has("[farming] no rain_wets"))
	assert_true(problems.has("[turnip] no wind_max"))
	assert_true(problems.has("[turnip] no sheet"))
	assert_true(problems.has("[reeds] no regrow_growth"))
	assert_false(problems.has("[turnip] no name"))
	assert_push_error_count(problems.size())


func test_a_regrow_stage_outside_the_stages_is_reported() -> void:
	_write(FARMING + REEDS + FAKE_CROP.replace("regrow_stage=0", "regrow_stage=4"))
	var rules := CropRules.from_file(DATA_FILE)
	assert_eq(rules.problems().size(), 1)
	assert_true("regrow_stage" in rules.problems()[0])
	assert_push_error_count(1)


func test_a_harvest_that_cannot_be_drawn_is_reported() -> void:
	var wrong := {
		"yield=2": "yield=0",
		"wind_max=10.0": "wind_max=10.0\npoor_harvest_chance=-0.1",
		"ripe_wait_factor=1.0":
		"ripe_wait_factor=1.0\npoor_harvest_chance=0.6\ngood_harvest_chance=0.5",
		"seed_chance=0.5": "seed_chance=1.5",
	}
	var reported := 0
	for right: String in wrong:
		_write(FARMING + REEDS + FAKE_CROP.replace(right, wrong[right]))
		var rules := CropRules.from_file(DATA_FILE)
		assert_false(rules.is_valid(), wrong[right])
		reported += rules.problems().size()
	assert_push_error_count(reported)


func test_a_crop_takes_the_harvest_chances_of_the_farming_section_unless_it_has_its_own() -> void:
	_write(FARMING + REEDS + FAKE_CROP.replace("yield=2", "yield=2\ngood_harvest_chance=0.4"))
	var crop := CropRules.from_file(DATA_FILE).crop(&"dandelion")
	assert_eq(crop["poor_harvest_chance"], 0.1)
	assert_eq(crop["good_harvest_chance"], 0.4)


func test_a_missing_file_is_reported() -> void:
	var rules := CropRules.from_file(DATA_DIR + "/nothing.cfg")
	assert_false(rules.is_valid())
	assert_push_error_count(rules.problems().size() + 1)


func test_every_required_key_has_a_value_for_every_crop() -> void:
	var rules := CropRules.default_rules()
	for crop_id in rules.crop_ids():
		for key in CropRules.REQUIRED_CROP_KEYS:
			assert_true(rules.crop(crop_id).has(key), "%s %s" % [crop_id, key])


func test_every_crop_has_an_object_type_and_items() -> void:
	for crop_id in CROP_NAMES:
		var object_type: Dictionary = WorldObjectTypes.TYPES[crop_id]
		assert_eq(object_type["growth_stages"], 4)
		assert_false(object_type["blocks_walking"])
		var seeds: Dictionary = ItemTypes.TYPES[object_type["seed"]]
		assert_eq(seeds["plants"], crop_id)
		assert_true(ItemTypes.TYPES.has(object_type["produce"]), str(crop_id))
		assert_eq(object_type["seed"], StringName("%s_seeds" % crop_id))


func test_the_turnip_ids_still_work() -> void:
	assert_eq(ItemTypes.TURNIP_SEEDS, &"turnip_seeds")
	assert_eq(ItemTypes.TYPES[ItemTypes.TURNIP_SEEDS]["plants"], WorldObjectTypes.TURNIP)
	assert_eq(ItemTypes.TYPES[ItemTypes.TURNIP]["name"], "Turnip")


func test_every_crop_has_a_sheet_with_four_stages_and_the_dead_one() -> void:
	for crop_id in CROP_NAMES:
		var sheet: Texture2D = load(WorldObjectTypes.TYPES[crop_id]["sheet"])
		assert_not_null(sheet, str(crop_id))
		assert_eq(
			sheet.get_width(), (CropRules.STAGES + 1) * TerrainTileset.TILE_SIZE, str(crop_id)
		)
		assert_eq(sheet.get_height() % TerrainTileset.TILE_SIZE, 0, str(crop_id))


func test_every_seed_and_produce_has_an_icon() -> void:
	for crop_id in CROP_NAMES:
		for item: StringName in [WorldObjectTypes.TYPES[crop_id]["seed"], crop_id]:
			assert_true(ResourceLoader.exists(ItemTypes.icon_path(item)), "icon of %s" % item)


func test_produce_is_food_except_the_grains_and_flax() -> void:
	var rules := EnergyRules.default_rules()
	for crop_id in CROP_NAMES:
		var is_food := crop_id not in [&"wheat", &"rye", &"buckwheat", &"flax"]
		assert_eq(rules.is_food(crop_id), is_food, str(crop_id))
	assert_eq(rules.food_restore(&"pumpkin"), 12.0)
	assert_eq(rules.food_restore(&"onion"), 4.0)


func test_eating_produce_restores_energy() -> void:
	var state := GameState.new_game(7)
	state.player.energy = 50.0
	state.player.inventory.add(&"potato", 2)
	HotbarHold.hold(state.player.inventory, &"potato")
	assert_true(state.eat_held())
	assert_eq(state.player.energy, 60.0)
	assert_eq(state.player.inventory.count_of(&"potato"), 1)


func test_wheat_cannot_be_eaten() -> void:
	var state := GameState.new_game(7)
	state.player.energy = 50.0
	state.player.inventory.add(&"wheat", 1)
	HotbarHold.hold(state.player.inventory, &"wheat")
	assert_false(state.eat_held())
	assert_eq(state.player.inventory.count_of(&"wheat"), 1)


func test_a_crop_added_only_by_config_and_picture_gets_its_own_sheet_source() -> void:
	_write(FARMING + REEDS + FAKE_CROP)
	var rules := CropRules.from_file(DATA_FILE)
	assert_true(rules.is_valid())
	var tileset := ObjectTileset.new(rules)
	var dandelion := WorldObject.new(WorldObjectTypes.TURNIP, Vector2i.ZERO)
	dandelion.type = &"dandelion"
	var source_id := tileset.crop_source_id(dandelion.type)
	assert_false(source_id in SeasonBlend.Look.values(), "after the look sources")
	var source := tileset.tile_set.get_source(source_id) as TileSetAtlasSource
	assert_eq(source.get_tiles_count(), CropRules.STAGES + 1)
	assert_eq(source.texture_region_size, Vector2i.ONE * TerrainTileset.TILE_SIZE)


func test_each_crop_is_drawn_from_its_own_sheet_and_stage() -> void:
	var tileset := ObjectTileset.new()
	var sources := {}
	for crop_id in CROP_NAMES:
		var crop := WorldObject.new(crop_id, Vector2i.ZERO)
		var source_id := tileset.crop_source_id(crop.type)
		assert_false(sources.has(source_id), "one source per crop")
		sources[source_id] = true
		assert_eq(ObjectTileset.atlas_cell(crop), Vector2i(0, 0))
		var source := tileset.tile_set.get_source(source_id) as TileSetAtlasSource
		for stage in CropRules.STAGES:
			crop.state["growth"] = stage * crop.type_data()["growth_per_stage"]
			assert_eq(ObjectTileset.atlas_cell(crop), Vector2i(stage, 0), str(crop_id))
			assert_true(source.has_tile(ObjectTileset.atlas_cell(crop)))
		crop.state["crop_damage"] = 1.0
		assert_eq(ObjectTileset.atlas_cell(crop), Vector2i(CropRules.STAGES, 0), "dead")


func test_tall_crops_have_taller_sheets() -> void:
	for crop_id in [&"wheat", &"peas", &"beans", &"flax"]:
		var sheet: Texture2D = load(WorldObjectTypes.TYPES[crop_id]["sheet"])
		assert_gt(sheet.get_height(), TerrainTileset.TILE_SIZE, str(crop_id))
	var turnip: Texture2D = load(WorldObjectTypes.TYPES[WorldObjectTypes.TURNIP]["sheet"])
	assert_eq(turnip.get_height(), TerrainTileset.TILE_SIZE)
