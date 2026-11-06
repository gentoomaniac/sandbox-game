extends GutTest
## Which art a look shows: the file names, and that every tile set has a source per look.


func test_summer_is_the_plain_file() -> void:
	var path := SeasonalArt.path("res://assets/terrain.png", SeasonBlend.Look.SUMMER)
	assert_eq(path, "res://assets/terrain.png")


func test_other_looks_add_their_name_before_the_extension() -> void:
	assert_eq(
		SeasonalArt.path("res://assets/terrain.png", SeasonBlend.Look.SPRING),
		"res://assets/terrain_spring.png"
	)
	assert_eq(
		SeasonalArt.path("res://assets/objects.png", SeasonBlend.Look.BARE),
		"res://assets/objects_bare.png"
	)


func test_every_look_has_its_files() -> void:
	for look: SeasonBlend.Look in SeasonBlend.Look.values():
		assert_true(ResourceLoader.exists(SeasonalArt.path(ObjectTileset.ATLAS_PATH, look)))
	for look in SeasonBlend.GROUND_LOOKS:
		for summer_path: String in [
			TerrainTileset.TERRAIN_ATLAS_PATH, TerrainTileset.DECORATION_ATLAS_PATH
		]:
			assert_true(ResourceLoader.exists(SeasonalArt.path(summer_path, look)))


func test_the_leaf_out_steps_are_only_object_art() -> void:
	var terrain := TerrainTileset.new()
	for look in [SeasonBlend.Look.BUDS, SeasonBlend.Look.YOUNG_LEAVES]:
		assert_false(terrain.tile_set.has_source(TerrainTileset.terrain_source_id(look)))
		assert_true(ResourceLoader.exists(SeasonalArt.path(ObjectTileset.ATLAS_PATH, look)))


func test_a_house_has_a_picture_per_house_look() -> void:
	var lit: String = BuildingTypes.TYPES[BuildingTypes.KATE]["sprite_lit"]
	assert_eq(SeasonalArt.house_path(lit, SeasonBlend.Look.SUMMER), lit)
	assert_eq(
		SeasonalArt.house_path(lit, SeasonBlend.Look.SNOW),
		"res://assets/buildings/kate_lit_snow.png"
	)
	for path: String in [BuildingTypes.TYPES[BuildingTypes.KATE]["sprite"], lit]:
		for look in SeasonalArt.HOUSE_LOOKS:
			assert_true(ResourceLoader.exists(SeasonalArt.house_path(path, look)), str(look))


func test_the_tile_sets_have_a_source_per_look_with_the_same_tiles() -> void:
	var terrain := TerrainTileset.new()
	var objects := ObjectTileset.new()
	var summer: TileSetAtlasSource = terrain.tile_set.get_source(
		TerrainTileset.terrain_source_id(SeasonBlend.Look.SUMMER)
	)
	for look in SeasonBlend.GROUND_LOOKS:
		var source: TileSetAtlasSource = terrain.tile_set.get_source(
			TerrainTileset.terrain_source_id(look)
		)
		assert_eq(source.get_tiles_count(), summer.get_tiles_count(), "terrain %d" % look)
	for look: SeasonBlend.Look in SeasonBlend.Look.values():
		assert_eq(
			objects.tile_set.get_source(look).texture.resource_path,
			SeasonalArt.path(ObjectTileset.ATLAS_PATH, look)
		)
