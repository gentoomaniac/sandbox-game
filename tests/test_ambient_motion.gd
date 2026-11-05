extends GutTest
## Ambient motion (view only): how the weather becomes the numbers of the motion shaders, and
## which tiles get which material. The motion itself runs in the shaders.

const STORM := AmbientMotion.STORM_WIND


func test_plants_barely_sway_on_a_calm_day_and_most_in_a_storm() -> void:
	assert_eq(AmbientMotion.sway_for(0.0), 0.0)
	# Rounded to whole pixels, only the very tips of the bendiest plants flick in a light air.
	assert_lt(AmbientMotion.sway_for(2.0), 0.6)
	assert_almost_eq(AmbientMotion.sway_for(STORM), AmbientMotion.MAX_SWAY, 0.001)
	assert_almost_eq(AmbientMotion.sway_for(STORM * 2.0), AmbientMotion.MAX_SWAY, 0.001)


func test_the_sway_grows_with_the_wind() -> void:
	var last := -1.0
	for speed in range(0, int(STORM) + 1, 2):
		var sway := AmbientMotion.sway_for(speed)
		assert_gt(sway, last, "at %d m/s" % speed)
		last = sway


func test_plants_lean_downwind_across_the_screen() -> void:
	assert_gt(AmbientMotion.lean_for(Vector2(8.0, 3.0)), 0.0)
	assert_lt(AmbientMotion.lean_for(Vector2(-8.0, 3.0)), 0.0)
	assert_eq(AmbientMotion.lean_for(Vector2(0.0, 12.0)), 0.0, "wind straight down the screen")
	assert_almost_eq(AmbientMotion.lean_for(Vector2(-40.0, 0.0)), -AmbientMotion.MAX_LEAN, 0.001)


func test_gusts_only_come_with_wind() -> void:
	assert_eq(AmbientMotion.gust_for(1.0), 0.0)
	assert_eq(AmbientMotion.gust_for(AmbientMotion.GUSTS_FROM), 0.0)
	assert_between(AmbientMotion.gust_for(10.0), 0.1, 0.9)
	assert_eq(AmbientMotion.gust_for(STORM), 1.0)


func test_water_gets_choppier_with_wind() -> void:
	assert_eq(AmbientMotion.chop_for(0.0), 0.0)
	assert_lt(AmbientMotion.chop_for(2.0), AmbientMotion.chop_for(8.0))
	assert_eq(AmbientMotion.chop_for(AmbientMotion.CHOPPY_WIND * 2.0), 1.0)


func test_a_flame_leans_downwind_but_not_off_its_fire() -> void:
	assert_eq(AmbientMotion.fire_lean_for(Vector2.ZERO), 0.0)
	assert_gt(AmbientMotion.fire_lean_for(Vector2(5.0, 0.0)), 0.0)
	assert_eq(AmbientMotion.fire_lean_for(Vector2(-100.0, 0.0)), -AmbientMotion.MAX_FIRE_LEAN)


func test_rain_splashes_more_the_heavier_it_rains() -> void:
	assert_eq(AmbientMotion.splash_chance_for(0.0), 0.0, "no rain, no splashes")
	assert_lt(AmbientMotion.splash_chance_for(0.2), AmbientMotion.splash_chance_for(0.8))
	assert_eq(AmbientMotion.splash_chance_for(3.0), AmbientMotion.MAX_SPLASH_CHANCE)


func test_the_wind_reaches_every_material_that_moves_with_it() -> void:
	var motion := AmbientMotion.new()
	var crop := motion.crop_material(Vector2i(16, 32))
	var wind := Vector2(-12.0, 4.0)
	motion.update(0.5, wind, 0.6)
	for material in [motion.object_material(WorldObjectTypes.OAK), crop, motion.decoration_sway]:
		assert_almost_eq(
			material.get_shader_parameter("sway"), AmbientMotion.sway_for(wind.length()), 0.001
		)
		assert_almost_eq(material.get_shader_parameter("lean"), AmbientMotion.lean_for(wind), 0.001)
	var fireplace := motion.object_material(WorldObjectTypes.FIREPLACE)
	assert_almost_eq(
		fireplace.get_shader_parameter("lean"), AmbientMotion.fire_lean_for(wind), 0.001
	)
	assert_almost_eq(motion.splash_chance, AmbientMotion.splash_chance_for(0.6), 0.001)


func test_ripples_drift_with_the_wind() -> void:
	var motion := AmbientMotion.new()
	motion.update(1.0, Vector2(10.0, 0.0), 0.0)
	var first: Vector2 = motion.water.get_shader_parameter("drift")
	motion.update(1.0, Vector2(10.0, 0.0), 0.0)
	var second: Vector2 = motion.water.get_shader_parameter("drift")
	assert_gt(second.x - first.x, 5.0, "downwind")


func test_only_plants_and_fires_among_the_objects_move() -> void:
	var motion := AmbientMotion.new()
	for type in [WorldObjectTypes.OAK, WorldObjectTypes.TALL_GRASS, WorldObjectTypes.REEDS]:
		assert_eq(motion.object_material(type).shader, AmbientMotion.OBJECT_SWAY_SHADER, type)
	assert_eq(motion.object_material(WorldObjectTypes.FIREPLACE).shader, AmbientMotion.FIRE_SHADER)
	for type in [WorldObjectTypes.STONE, WorldObjectTypes.BOULDER, WorldObjectTypes.STUMP]:
		assert_null(motion.object_material(type), type)


func test_crops_of_a_size_share_a_material() -> void:
	var motion := AmbientMotion.new()
	assert_eq(motion.crop_material(Vector2i(16, 16)), motion.crop_material(Vector2i(16, 16)))
	assert_ne(motion.crop_material(Vector2i(16, 16)), motion.crop_material(Vector2i(16, 32)))


func test_lily_pads_drift_flowers_sway_and_pebbles_stay() -> void:
	var motion := AmbientMotion.new()
	var grass := TerrainTileset.Layer.GRASS
	assert_eq(motion.decoration_material(Vector2i(2, TerrainTileset.Layer.WATER)), motion.lily_pads)
	assert_eq(motion.decoration_material(Vector2i(0, grass)), motion.decoration_sway, "a flower")
	assert_null(motion.decoration_material(Vector2i(5, grass)), "pebbles")
	assert_null(motion.decoration_material(Vector2i(0, TerrainTileset.Layer.SOIL)))


## The list of swaying decorations follows the order of the atlas rows: a row with more or
## fewer decorations than the list means the art changed and the list must follow.
func test_the_swaying_decorations_match_the_atlas() -> void:
	var tileset := TerrainTileset.new()
	for layer: int in AmbientMotion.SWAYING_DECORATIONS:
		assert_eq(
			AmbientMotion.SWAYING_DECORATIONS[layer].size(),
			tileset._decoration_counts[layer],
			TerrainTileset.Layer.keys()[layer]
		)


func test_the_tile_sets_put_the_materials_on_the_tiles_that_move() -> void:
	var motion := AmbientMotion.new()
	var objects := ObjectTileset.new(CropRules.default_rules(), motion)
	var source: TileSetAtlasSource = objects.tile_set.get_source(SeasonBlend.Look.SUMMER)
	var oak_row: int = WorldObjectTypes.TYPES[WorldObjectTypes.OAK]["atlas_row"]
	var stone_row: int = WorldObjectTypes.TYPES[WorldObjectTypes.STONE]["atlas_row"]
	assert_eq(
		source.get_tile_data(Vector2i(0, oak_row), 0).material,
		motion.object_material(WorldObjectTypes.OAK)
	)
	assert_null(source.get_tile_data(Vector2i(0, stone_row), 0).material)
	assert_false(source.use_texture_padding, "the shaders read the cell from the texture position")
	var terrain := TerrainTileset.new(motion)
	var decorations: TileSetAtlasSource = terrain.tile_set.get_source(
		TerrainTileset.decoration_source_id(SeasonBlend.Look.SNOW)
	)
	assert_eq(
		decorations.get_tile_data(Vector2i(0, TerrainTileset.Layer.WATER), 0).material,
		motion.lily_pads
	)
