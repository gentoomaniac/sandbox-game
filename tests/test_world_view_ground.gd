extends GutTest
## The ground of WorldView: its colour through the year and the leaves, frost and snow over it are
## shader parameters and a cover texture, so a day or a minute of weather costs no redrawing.

const SEED := 1
const RIGHT := Vector2i(-1, -1)
const SUMMER := 45
const AUTUMN := 75
const WINTER := 105
const L := SeasonBlend.Look

var _view: WorldView
var _residency: ChunkResidency


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_residency = ChunkResidency.new(World.new(SEED))
	_view.show_world(_residency)
	_residency.load_chunk(RIGHT)
	_view.finish_drawing()


func after_each() -> void:
	CoverMap.reset()


## A tile of the chunk that is open ground: grass with nothing on it and no tree or house near.
func _open_tile(coords := RIGHT) -> Vector2i:
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	for y in range(3, Chunk.CHUNK_SIZE - 3):
		for x in range(3, Chunk.CHUNK_SIZE - 3):
			var tile := origin + Vector2i(x, y)
			var channels := _view._cover_map.ground_cover.channels_at(tile)
			if _view.world.tile_at(tile).terrain == Tile.Terrain.GRASS and channels.snow == 1.0:
				return tile
	fail_test("no open grass in chunk %s" % coords)
	return origin


func test_the_land_layers_have_the_ground_material_and_the_water_and_mud_their_own() -> void:
	var ground := _view._ground_look
	for layer in TerrainTileset.LAYER_COUNT:
		var expected: Material = ground.terrain
		if layer == TerrainTileset.Layer.WATER:
			expected = _view.ambient_motion.water
		elif layer == TerrainTileset.Layer.MUD:
			expected = _view.ambient_motion.mud
		elif layer == TerrainTileset.Layer.SOIL:
			expected = ground.soil
		assert_eq(_view._layers[layer].material, expected, "layer %d" % layer)
	assert_eq(_view._soil_wetness.material, ground.soil_wet)
	assert_eq(_view.decorations._decorations.material, ground.decoration)


func test_every_layer_draws_from_the_summer_atlas_whatever_the_season() -> void:
	for day in [SUMMER, AUTUMN, WINTER]:
		_view.show_ground_cover(day, 0.0, 0.0, 0.0)
		for layer in _view._layers:
			for cell in layer.get_used_cells():
				assert_eq(layer.get_cell_source_id(cell), TerrainTileset.TERRAIN_SOURCE_ID)
				break


func test_the_ground_mixes_from_one_season_into_the_next_by_the_day() -> void:
	var terrain := _view._ground_look.terrain
	_view.show_ground_cover(SUMMER, 0.0, 0.0, 0.0)
	assert_eq(terrain.get_shader_parameter("mix_share"), 1.0)
	_view.show_ground_cover(66, 0.0, 0.0, 0.0)
	var share: float = terrain.get_shader_parameter("mix_share")
	assert_between(share, 0.01, 0.99)
	var summer_atlas := load(
		ArtSet.path(SeasonalArt.path(TerrainTileset.TERRAIN_ATLAS_PATH, L.SUMMER))
	)
	var autumn_atlas := load(
		ArtSet.path(SeasonalArt.path(TerrainTileset.TERRAIN_ATLAS_PATH, L.AUTUMN))
	)
	assert_eq(terrain.get_shader_parameter("from_look"), summer_atlas)
	assert_eq(terrain.get_shader_parameter("to_look"), autumn_atlas)
	assert_eq(
		_view._ground_look.soil.get_shader_parameter("mix_share"), 0.0, "soil keeps its colour"
	)


func test_snow_covers_more_of_the_ground_as_the_cover_grows_and_melts_with_the_thaw() -> void:
	var tile := _open_tile()
	var ground_cover := _view._cover_map.ground_cover
	var shares: Array[float] = []
	for cover in [0.0, 0.3, 0.6, 1.0]:
		_view.show_ground_cover(WINTER, cover, 0.0, 0.0)
		shares.append(ground_cover.snow_at(tile))
	assert_eq(shares, [0.0, 0.3, 0.6, 1.0] as Array[float])
	assert_false(_view.is_snowed_over(tile) and shares[1] >= 0.5)
	_view.show_ground_cover(WINTER, 1.0, 0.0, 0.0)
	assert_true(_view.is_snowed_over(tile))
	_view.show_ground_cover(WINTER, 1.0, 1.0, 0.0)
	assert_lt(ground_cover.snow_at(tile), 1.0, "a thaw takes some off")


func test_footsteps_ask_the_cover_under_the_feet() -> void:
	var tile := _open_tile()
	_view.show_ground_cover(WINTER, 1.0, 0.0, 0.0)
	assert_true(_view.is_snow_drawn_at(Vector2(tile) + Vector2(0.5, 0.5)))
	_view.show_ground_cover(WINTER, 0.0, 0.0, 0.0)
	assert_false(_view.is_snow_drawn_at(Vector2(tile) + Vector2(0.5, 0.5)))


func test_a_chunk_that_loads_later_is_in_the_cover_texture() -> void:
	var coords := Vector2i(-2, -1)
	_residency.load_chunk(coords)
	_view.finish_drawing()
	var tile := _open_tile(coords)
	assert_eq(
		_view._cover_map.channels_at(tile),
		_view._cover_map.ground_cover.channels_at(tile).as_color()
	)
	assert_gt(_view._cover_map.channels_at(tile).r, 0.0)


func test_a_planted_tree_changes_the_cover_around_it_and_felling_it_changes_it_back() -> void:
	var tile := _open_tile()
	var before := _view._cover_map.channels_at(tile)
	var oak := WorldObject.new(WorldObjectTypes.OAK, tile)
	_view.world.add_object(oak)
	assert_gt(_view._cover_map.channels_at(tile).r, before.r, "more leaves under it")
	assert_lt(_view._cover_map.channels_at(tile).g, before.g, "less snow under it")
	_view.world.remove_object(tile)
	assert_eq(_view._cover_map.channels_at(tile), before)


func test_a_house_changes_the_lee_behind_it() -> void:
	_view.world.add_chunk(Chunk.new(Vector2i.ZERO))
	_view._cover_map.draw_chunk(Vector2i.ZERO)
	var building := _view.world.place_building(BuildingTypes.KATE, Vector2i(2, 2))
	var behind := Vector2i(building.origin.x + 5, building.origin.y)
	for tile in building.tiles():
		behind.x = maxi(behind.x, tile.x + 1)
	assert_lt(_view._cover_map.channels_at(behind).g, 1.0, "less snow in the lee")
	_view.world.remove_building(building)
	assert_eq(_view._cover_map.channels_at(behind).g, 1.0)


func test_unloading_a_chunk_forgets_its_layers() -> void:
	assert_true(_view._chunk_layers.has(RIGHT))
	_residency.unload_chunk(RIGHT)
	assert_false(_view._chunk_layers.has(RIGHT))
	assert_eq(_view._layers[TerrainTileset.Layer.GRASS].get_used_cells().size(), 0)


func test_a_chunk_that_comes_into_range_when_the_player_walks_is_drawn() -> void:
	var far := Vector2i(CoverMap.DRAW_RANGE_CHUNKS + 2, 0)
	_residency.load_chunk(far)
	_view.finish_drawing()
	var tile := Chunk.to_world(far, Vector2i(3, 3))
	assert_eq(_view._cover_map.channels_at(tile), Color(0, 0, 0, 0), "out of range")
	_residency.focus_chunk = Vector2i(CoverMap.DRAW_RANGE_CHUNKS, 0)
	for _i in 3:
		_view._sync_cover_focus()
		_view._draw_missing_cover()
	assert_gt(_view._cover_map.channels_at(tile).g, 0.0)


func test_a_world_shown_far_from_the_origin_has_its_cover_from_the_first_draw() -> void:
	var far := Vector2i(20, 20)
	var residency := ChunkResidency.new(World.new(SEED))
	residency.set_focus(Chunk.to_world(far, Vector2i.ZERO))
	var view := WorldView.new()
	add_child_autofree(view)
	view.show_world(residency)
	residency.load_chunk(far)
	view.finish_drawing()
	var tile := Chunk.to_world(far, Vector2i(10, 10))
	assert_eq(
		view._cover_map.channels_at(tile), view._cover_map.ground_cover.channels_at(tile).as_color()
	)
	assert_ne(view._cover_map.channels_at(tile), Color(0, 0, 0, 0), "not skipped as out of range")


func test_a_tree_felled_while_its_chunk_is_half_drawn_still_changes_the_cover() -> void:
	var coords := Vector2i(-2, -1)
	_residency.load_chunk(coords)
	_view._draw_next_step()
	var tree: WorldObject = null
	for object in _view.world.chunk_at(coords).objects():
		if object.type in GroundCover.CROWNED:
			tree = object
			break
	assert_not_null(tree, "a tree in the chunk")
	var before := _view._cover_map.channels_at(tree.pos)
	_view.world.remove_object(tree.pos)
	assert_ne(_view._cover_map.channels_at(tree.pos), before)


func test_snow_clears_the_wet_pixels_of_soil_by_shader_and_costs_no_redrawing() -> void:
	var pos := Vector2i(-20, -20)
	_view.world.set_terrain(pos, Tile.Terrain.SOIL)
	_view.world.set_moisture(pos, 1.0)
	assert_ne(_view._soil_wetness.get_cell_source_id(pos), -1, "wet")
	_view.show_ground_cover(WINTER, 1.0, 0.0, 0.0)
	assert_ne(_view._soil_wetness.get_cell_source_id(pos), -1, "still drawn: the shader clears it")
	assert_eq(_view._soil_wetness.material, _view._ground_look.soil_wet)
