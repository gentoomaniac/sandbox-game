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
	for look in [SeasonBlend.Look.BUDS, SeasonBlend.Look.YOUNG_LEAVES]:
		for summer_path: String in [
			TerrainTileset.TERRAIN_ATLAS_PATH, TerrainTileset.DECORATION_ATLAS_PATH
		]:
			assert_false(ResourceLoader.exists(SeasonalArt.path(summer_path, look)))
		assert_true(ResourceLoader.exists(SeasonalArt.path(ObjectTileset.ATLAS_PATH, look)))


func test_a_house_has_a_picture_per_house_look_and_a_snow_on_its_roof() -> void:
	var lit: String = BuildingTypes.TYPES[BuildingTypes.KATE]["sprite_lit"]
	assert_eq(SeasonalArt.house_path(lit, SeasonBlend.Look.SUMMER), lit)
	assert_eq(
		SeasonalArt.house_path(lit, SeasonBlend.Look.BARE),
		"res://assets/buildings/kate_lit_bare.png"
	)
	for path: String in [BuildingTypes.TYPES[BuildingTypes.KATE]["sprite"], lit]:
		for look in SeasonalArt.HOUSE_LOOKS:
			assert_true(ResourceLoader.exists(SeasonalArt.house_path(path, look)), str(look))
	for type: StringName in BuildingTypes.TYPES:
		var unlit: String = BuildingTypes.TYPES[type]["sprite"]
		for is_classic in [false, true]:
			var snow := ArtSet.path_in(SeasonalArt.roof_snow_path(unlit), is_classic)
			assert_true(ResourceLoader.exists(snow), snow)
			var picture: Texture2D = load(ArtSet.path_in(unlit, is_classic))
			assert_eq(load(snow).get_size(), picture.get_size(), snow)


func test_the_object_tile_set_has_a_source_per_look() -> void:
	var objects := ObjectTileset.new()
	for look in ObjectTileset.LOOKS:
		assert_eq(
			objects.tile_set.get_source(look).texture.resource_path,
			SeasonalArt.path(ObjectTileset.ATLAS_PATH, look)
		)
