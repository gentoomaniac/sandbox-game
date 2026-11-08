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
	assert_lt(
		AmbientMotion.fire_lean_for(Vector2(5.0, 0.0)),
		AmbientMotion.fire_lean_for(Vector2(12.0, 0.0))
	)
	assert_eq(AmbientMotion.fire_lean_for(Vector2(-100.0, 0.0)), -AmbientMotion.MAX_FIRE_LEAN)


func test_a_flame_stretches_more_the_stronger_the_wind() -> void:
	assert_eq(AmbientMotion.fire_stretch_for(Vector2.ZERO), 0.0)
	assert_eq(
		AmbientMotion.fire_stretch_for(Vector2(0.0, 12.0)), 0.0, "wind straight down the screen"
	)
	var breeze := AmbientMotion.fire_stretch_for(Vector2(-5.0, 0.0))
	assert_gt(breeze, 0.0, "either way")
	assert_lt(breeze, AmbientMotion.fire_stretch_for(Vector2(12.0, 0.0)))
	assert_eq(
		AmbientMotion.fire_stretch_for(Vector2(STORM * 2.0, 0.0)), AmbientMotion.MAX_FIRE_STRETCH
	)


func test_a_flame_plays_its_frames_at_a_steady_rate() -> void:
	var origin := Vector2i(160, -48)
	var step := 1.0 / AmbientMotion.FIRE_FRAMES_PER_SECOND
	var first := AmbientMotion.fire_frame(0.0, origin)
	assert_eq(AmbientMotion.fire_frame(step * 0.9, origin), first, "within a frame's time")
	var shown := {}
	for frame in AmbientMotion.FIRE_FRAMES:
		var now := AmbientMotion.fire_frame(step * (frame + 0.5), origin)
		assert_eq(now, (first + frame) % AmbientMotion.FIRE_FRAMES, "frame %d" % frame)
		shown[now] = true
	assert_eq(shown.size(), AmbientMotion.FIRE_FRAMES, "every frame once a loop")
	assert_eq(AmbientMotion.fire_frame(step * (AmbientMotion.FIRE_FRAMES + 0.5), origin), first)


func test_each_fire_burns_in_a_phase_of_its_own() -> void:
	var origin := Vector2i(160, -48)
	assert_eq(AmbientMotion.fire_frame(2.0, origin), AmbientMotion.fire_frame(2.0, origin))
	var frames := {}
	for x in 8:
		frames[AmbientMotion.fire_frame(2.0, origin + Vector2i(x * 16, 0))] = true
	assert_gt(frames.size(), 2, "fires side by side show different frames at once")


func test_the_hearth_burns_but_does_not_lean() -> void:
	var motion := AmbientMotion.new()
	var hearth := AmbientMotion.fire_material(WorldObjectTypes.HEARTH)
	motion.update(1.0, Vector2(STORM, 0.0), 0.0)
	assert_eq(hearth.get_shader_parameter("frames"), AmbientMotion.FIRE_FRAMES)
	assert_eq(hearth.get_shader_parameter("lean"), null, "the shader's default, 0")
	assert_eq(hearth.get_shader_parameter("stretch"), null, "the shader's default, 0")


## A flame's strip holds what is behind it, what is in front of it and its frames, all of the
## same box; drawn over each other with the first frame they are the fire's picture (in every
## look), so the shader can swap the flame without moving the logs and stones.
func test_the_flame_strips_match_the_pictures() -> void:
	var fireplace_row: int = WorldObjectTypes.TYPES[WorldObjectTypes.FIREPLACE]["atlas_row"]
	var pictures := {
		WorldObjectTypes.HEARTH:
		[load(WorldObjectTypes.TYPES[WorldObjectTypes.HEARTH]["interior_sprite"]).get_image()],
	}
	pictures[WorldObjectTypes.FIREPLACE] = []
	for look: SeasonBlend.Look in SeasonBlend.Look.values():
		var atlas: Image = load(SeasonalArt.path(ObjectTileset.ATLAS_PATH, look)).get_image()
		var cell_size := Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
		pictures[WorldObjectTypes.FIREPLACE].append(
			atlas.get_region(Rect2i(Vector2i(0, fireplace_row) * cell_size, cell_size))
		)
	for type: StringName in AmbientMotion.FIRE_PROFILES:
		var profile: Dictionary = AmbientMotion.FIRE_PROFILES[type]
		var strip: Image = load(profile["flames"]).get_image()
		var cells := AmbientMotion.FIRE_FRAMES + 2
		assert_eq(strip.get_width() % cells, 0, "%s: a whole number of cells" % type)
		var box := Vector2i(strip.get_width() / cells, strip.get_height())
		var box_position := Vector2i(profile["box_position"])
		# The pictures show a still flame of the 16 px art, the strip one drawn at 32 px; what
		# stands in front of the flame is the same in both.
		for picture: Image in pictures[type]:
			assert_eq(picture.get_size(), Vector2i(profile["cell_size"]), type)
			var differing := 0
			for y in box.y:
				for x in box.x:
					var front := _strip_pixel(strip, box, 1, x, y)
					var drawn := picture.get_pixel(box_position.x + x, box_position.y + y)
					if front.a > 0.0 and drawn != front:
						differing += 1
			assert_eq(differing, 0, "%s: pixels in front of the flame unlike the picture" % type)
		assert_ne(
			strip.get_region(Rect2i(Vector2i(2 * box.x, 0), box)).get_data(),
			strip.get_region(Rect2i(Vector2i(3 * box.x, 0), box)).get_data(),
			"%s: the flame changes from frame to frame" % type
		)


func _strip_pixel(strip: Image, box: Vector2i, cell: int, x: int, y: int) -> Color:
	return strip.get_pixel(cell * box.x + x, y)


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
	assert_almost_eq(
		fireplace.get_shader_parameter("stretch"), AmbientMotion.fire_stretch_for(wind), 0.001
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


func test_lily_pads_drift_flowers_and_clover_sway_and_pebbles_stay() -> void:
	var motion := AmbientMotion.new()
	var grass := TerrainTileset.Layer.GRASS
	assert_eq(motion.decoration_material(Vector2i(2, TerrainTileset.Layer.WATER)), motion.lily_pads)
	assert_eq(motion.decoration_material(Vector2i(0, grass)), motion.decoration_sway, "clover")
	assert_null(motion.decoration_material(Vector2i(1, grass)), "pebbles")
	assert_null(motion.decoration_material(Vector2i(0, TerrainTileset.Layer.SOIL)))
	var heather := TerrainTileset.flower_cell(&"heather", TerrainTileset.FlowerVariant.DRIFT)
	assert_eq(motion.decoration_material(heather), motion.flower_sway, "a meadow flower")


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


func test_the_water_of_the_tide_ripples_like_the_river() -> void:
	var motion := AmbientMotion.new()
	motion.update(1.0, Vector2(10.0, 0.0), 0.0)
	for parameter in ["chop", "drift"]:
		assert_eq(
			motion.mud.get_shader_parameter(parameter),
			motion.water.get_shader_parameter(parameter),
			parameter
		)
	motion.show_tide(0.3)
	assert_eq(motion.mud.get_shader_parameter("tide"), 0.3)
