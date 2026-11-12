extends GutTest
## The cover texture of the ground shaders: a texel per tile in a ring, drawn from GroundCover for
## the chunks near the focus, drawn again around a change, and the weather it hands on.

var _world: World
var _map: CoverMap


func before_each() -> void:
	_world = World.new(1)
	_map = CoverMap.new()
	_map.show_world(_world)


func after_each() -> void:
	CoverMap.reset()


func _load(coords: Vector2i) -> void:
	_world.add_chunk(Chunk.new(coords))


func test_a_drawn_chunk_has_the_channels_of_its_tiles() -> void:
	_world.add_chunk(Chunk.new(Vector2i(-1, -1)))
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, Vector2i(-10, -10)))
	_map.draw_chunk(Vector2i(-1, -1))
	for tile: Vector2i in [
		Vector2i(-10, -10), Vector2i(-9, -10), Vector2i(-32, -32), Vector2i(-1, -1)
	]:
		assert_eq(
			_map.channels_at(tile), _map.ground_cover.channels_at(tile).as_color(), "%s" % tile
		)
	var under_the_oak := _map.channels_at(Vector2i(-10, -10))
	assert_gt(under_the_oak.r, _map.channels_at(Vector2i(-25, -25)).r, "more leaves under a tree")


func test_the_world_wraps_around_the_ring() -> void:
	_world.add_chunk(Chunk.new(Vector2i(-1, 0)))
	_world.set_terrain(Vector2i(-1, 0), Tile.Terrain.WATER)
	_map.draw_chunk(Vector2i(-1, 0))
	# The tile at x -1 is the last texel of the ring's row, not a texel before the first.
	assert_eq(
		_map.channels_at(Vector2i(CoverMap.RING_TILES - 1, 0)), _map.channels_at(Vector2i(-1, 0))
	)
	assert_eq(_map.channels_at(Vector2i(-1, 0)).a, 1.0, "water is all shelter from frost")


func test_a_chunk_far_from_the_focus_is_not_drawn() -> void:
	var far := Vector2i(CoverMap.DRAW_RANGE_CHUNKS + 1, 0)
	_load(far)
	_map.draw_chunk(far)
	var tile := Chunk.to_world(far, Vector2i(3, 3))
	assert_eq(_map.channels_at(tile), Color(0, 0, 0, 0))


func test_a_change_redraws_the_tiles_around_it() -> void:
	_load(Vector2i.ZERO)
	_map.draw_chunk(Vector2i.ZERO)
	var beside := Vector2i(11, 10)
	var before := _map.channels_at(beside)
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, Vector2i(10, 10)))
	assert_eq(_map.channels_at(beside), before, "not yet")
	_map.redraw_around(Vector2i(10, 10))
	assert_ne(_map.channels_at(beside), before)
	assert_eq(_map.channels_at(beside), _map.ground_cover.channels_at(beside).as_color())


func test_a_changed_tile_is_drawn_again() -> void:
	_load(Vector2i.ZERO)
	_map.draw_chunk(Vector2i.ZERO)
	_world.set_terrain(Vector2i(7, 7), Tile.Terrain.WATER)
	_map.redraw_tile(Vector2i(7, 7))
	assert_eq(_map.channels_at(Vector2i(7, 7)).a, 1.0)


func test_the_border_of_a_chunk_is_drawn_again_when_its_neighbour_loads() -> void:
	_load(Vector2i.ZERO)
	_map.draw_chunk(Vector2i.ZERO)
	_load(Vector2i(1, 0))
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, Vector2i(33, 10)))
	_map.draw_chunk(Vector2i(1, 0))
	for y in range(5, 15):
		for x in range(Chunk.CHUNK_SIZE - _map.ground_cover.reach(), Chunk.CHUNK_SIZE):
			var tile := Vector2i(x, y)
			assert_eq(
				_map.channels_at(tile), _map.ground_cover.channels_at(tile).as_color(), "%s" % tile
			)
	var shaded := _map.channels_at(Vector2i(Chunk.CHUNK_SIZE - 1, 10))
	assert_gt(shaded.r, _map.channels_at(Vector2i(10, 10)).r, "the oak next door drops leaves here")


func test_a_chunk_that_comes_into_range_is_drawn_later() -> void:
	var coords := Vector2i(CoverMap.DRAW_RANGE_CHUNKS + 1, 0)
	_load(coords)
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, Chunk.to_world(coords, Vector2i(5, 5))))
	assert_false(_map.draw_missing(), "too far")
	_map.set_focus(Vector2i(1, 0))
	assert_true(_map.draw_missing(), "in range now")
	assert_ne(_map.channels_at(Chunk.to_world(coords, Vector2i(5, 5))), Color(0, 0, 0, 0))
	assert_false(_map.draw_missing(), "all drawn")
	_map.forget_chunk(coords)
	assert_true(_map.draw_missing(), "drawn again once forgotten")


func test_a_chunk_that_falls_out_of_range_cannot_change_the_ring_and_is_drawn_when_back() -> void:
	_load(Vector2i.ZERO)
	_map.draw_chunk(Vector2i.ZERO)
	var tile := Vector2i(7, 7)
	var drawn := _map.channels_at(tile)
	# 16 chunks away the ring has wrapped round onto the chunk that is in view.
	var far := Vector2i(16, 0)
	_map.set_focus(far)
	_world.set_terrain(tile, Tile.Terrain.WATER)
	_map.redraw_tile(tile)
	_map.redraw_around(tile)
	assert_eq(_map.channels_at(tile), drawn, "the ring is not touched")
	_map.set_focus(Vector2i.ZERO)
	assert_true(_map.draw_missing(), "drawn afresh when it comes back")
	assert_eq(_map.channels_at(tile).a, 1.0, "with the change")


func test_the_shader_constants_that_must_equal_the_games_do() -> void:
	var source := FileAccess.get_file_as_string("res://game/scenes/ground_cover.gdshaderinc")
	var constants := {}
	var pattern := RegEx.create_from_string("const float (\\w+) = ([0-9.]+);")
	for found in pattern.search_all(source):
		constants[found.get_string(1)] = float(found.get_string(2))
	assert_eq(constants["COVER_MAP_TILES"], float(CoverMap.RING_TILES))
	assert_eq(constants["COVER_TILE"], float(TerrainTileset.TILE_SIZE))
	assert_eq(constants["COVER_TEXTURE_SIZE"], 512.0)


func test_uploading_keeps_the_ring_size() -> void:
	_load(Vector2i.ZERO)
	_map.draw_chunk(Vector2i.ZERO)
	_map.upload()
	assert_eq(_map.texture.get_size(), Vector2(CoverMap.RING_TILES, CoverMap.RING_TILES))


func test_the_weather_is_for_the_game_as_it_is_for_the_shaders() -> void:
	_load(Vector2i.ZERO)
	var tile := Vector2i(20, 20)
	_map.set_weather(0.0, 0.0, 0.0, 0.0)
	assert_eq(_map.ground_cover.snow_at(tile), 0.0)
	_map.set_weather(0.0, 1.0, 0.0, 0.0)
	assert_gt(_map.ground_cover.snow_at(tile), 0.5)


func test_the_art_sets_have_their_cover_textures() -> void:
	for is_classic in [false, true]:
		for path in [CoverMap.NOISE_PATH, CoverMap.LEAVES_PATH]:
			var picture: Texture2D = load(ArtSet.path_in(path, is_classic))
			assert_not_null(picture, path)
			assert_eq(picture.get_size(), Vector2(512, 512), path)


func test_the_snow_and_frost_atlases_of_the_objects_have_the_layout_of_the_object_atlas() -> void:
	for is_classic in [false, true]:
		var objects: Texture2D = load(ArtSet.path_in(ObjectTileset.ATLAS_PATH, is_classic))
		for path in [CoverMap.OBJECTS_SNOW_PATH, CoverMap.OBJECTS_FROST_PATH]:
			var atlas: Texture2D = load(ArtSet.path_in(path, is_classic))
			assert_eq(atlas.get_size(), objects.get_size(), path)
