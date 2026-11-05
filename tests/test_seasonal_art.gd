extends GutTest
## Which art a season shows: the file names, and that the world view swaps its pictures on a
## season change only.


func test_summer_is_the_plain_file() -> void:
	var path := SeasonalArt.path("res://assets/terrain.png", GameClock.Season.SUMMER)
	assert_eq(path, "res://assets/terrain.png")


func test_other_seasons_add_their_name_before_the_extension() -> void:
	assert_eq(
		SeasonalArt.path("res://assets/terrain.png", GameClock.Season.SPRING),
		"res://assets/terrain_spring.png"
	)
	assert_eq(
		SeasonalArt.path("res://assets/buildings/small_house_lit.png", GameClock.Season.WINTER),
		"res://assets/buildings/small_house_lit_winter.png"
	)


func test_every_season_has_its_files() -> void:
	for season: GameClock.Season in GameClock.Season.values():
		for summer_path: String in [
			TerrainTileset.TERRAIN_ATLAS_PATH,
			TerrainTileset.DECORATION_ATLAS_PATH,
			ObjectTileset.ATLAS_PATH,
			BuildingTypes.TYPES[BuildingTypes.SMALL_HOUSE]["sprite"],
			BuildingTypes.TYPES[BuildingTypes.SMALL_HOUSE]["sprite_lit"],
		]:
			assert_true(ResourceLoader.exists(SeasonalArt.path(summer_path, season)))


func test_view_switches_the_tile_pictures_on_a_season_change_only() -> void:
	var view := WorldView.new()
	add_child_autofree(view)
	view.show_world(World.new(1))
	assert_false(view.set_season(GameClock.Season.SUMMER))
	assert_true(view.set_season(GameClock.Season.WINTER))
	assert_false(view.set_season(GameClock.Season.WINTER))
	var terrain: TileSetAtlasSource = view._tileset.tile_set.get_source(
		TerrainTileset.TERRAIN_SOURCE_ID
	)
	assert_eq(terrain.texture.resource_path, "res://assets/terrain_winter.png")
	var objects: TileSetAtlasSource = view._object_tileset.tile_set.get_source(
		ObjectTileset.SOURCE_ID
	)
	assert_eq(objects.texture.resource_path, "res://assets/objects_winter.png")
