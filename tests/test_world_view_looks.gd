extends GutTest
## WorldView's looks: the season overlays, snow and frost drawn in patches against each tile's
## threshold, the objects' and houses' looks, and how a refresh is spread and limited to what
## changed.

const SEED := 1
const LEFT := Vector2i(-2, -1)
const RIGHT := Vector2i(-1, -1)
const BELOW := Vector2i(-1, 0)
const SUMMER := 45
const AUTUMN := 66
const WINTER := 105

var _view: WorldView


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_view.show_world(World.new(SEED))


func _find_object(coords: Vector2i, type: StringName) -> WorldObject:
	for object in _view.world.chunk_at(coords).objects():
		if object.type == type:
			return object
	fail_test("no %s in chunk %s" % [type, coords])
	return null


func _show(day: int, snow: float, frost := 0.0) -> void:
	_view.world.clock.day = day
	_view.refresh_looks(day, snow, frost)
	_view.finish_refresh()


func _share_of_tiles_with_weather(coords: Vector2i, look: SeasonBlend.Look) -> float:
	var looks: PackedByteArray = _view._chunk_looks[coords].weather_looks
	var count := 0
	for weather_look in looks:
		count += 1 if weather_look == look else 0
	return float(count) / looks.size()


func test_snow_comes_in_patches_that_grow_with_the_cover() -> void:
	_view._load_chunk(RIGHT)
	_show(WINTER, 0.0)
	assert_eq(_view._overlays[SeasonBlend.Look.SNOW].get_used_cells().size(), 0)
	var last_cells := 0
	for cover in [0.2, 0.5, 0.9]:
		_show(WINTER, cover)
		assert_almost_eq(_share_of_tiles_with_weather(RIGHT, SeasonBlend.Look.SNOW), cover, 0.06)
		var cells: int = _view._overlays[SeasonBlend.Look.SNOW].get_used_cells().size()
		assert_gt(cells, last_cells)
		last_cells = cells


func test_frost_is_drawn_where_it_has_not_snowed() -> void:
	_view._load_chunk(RIGHT)
	_show(WINTER, 0.0, 0.6)
	assert_gt(_view._overlays[SeasonBlend.Look.FROST].get_used_cells().size(), 0)
	assert_eq(_view._overlays[SeasonBlend.Look.SNOW].get_used_cells().size(), 0)
	_show(WINTER, 0.6, 0.6)
	var frosty := _share_of_tiles_with_weather(RIGHT, SeasonBlend.Look.FROST)
	assert_almost_eq(frosty, 0.0, 0.01, "snow wins over frost where both are above the threshold")


func test_the_season_overlays_follow_the_blend() -> void:
	_view._load_chunk(RIGHT)
	_show(SUMMER, 0.0)
	for look: SeasonBlend.Look in TerrainTileset.OVERLAY_LOOKS:
		assert_eq(_view._overlays[look].get_used_cells().size(), 0, "no overlay in summer")
	_show(WINTER, 0.0)
	assert_gt(_view._overlays[SeasonBlend.Look.BARE].get_used_cells().size(), 0)
	_show(SUMMER, 0.0)
	assert_eq(_view._overlays[SeasonBlend.Look.BARE].get_used_cells().size(), 0)


func test_a_refresh_only_touches_the_cells_of_tiles_that_flipped() -> void:
	_view._load_chunk(RIGHT)
	_show(WINTER, 0.5)
	var before: PackedByteArray = _view._chunk_looks[RIGHT].weather_looks.duplicate()
	_view.refresh_looks(WINTER, 0.52, 0.0)
	_view._refresh_chunk(RIGHT)
	var after: PackedByteArray = _view._chunk_looks[RIGHT].weather_looks
	var flipped := 0
	for index in before.size():
		flipped += 1 if before[index] != after[index] else 0
	assert_gt(flipped, 0)
	assert_lt(flipped, 100)
	assert_lte(_view._cells_to_redraw.size(), flipped * 4, "the 4 cells around each flipped tile")
	_view.finish_refresh()
	_view.refresh_looks(WINTER, 0.52, 0.0)
	assert_false(_view._is_refreshing(), "nothing to do while the state is the same")


func test_a_chunk_that_loads_later_is_drawn_for_the_current_looks() -> void:
	_show(WINTER, 0.7)
	_view._load_chunk(RIGHT)
	assert_almost_eq(_share_of_tiles_with_weather(RIGHT, SeasonBlend.Look.SNOW), 0.7, 0.06)
	assert_gt(_view._overlays[SeasonBlend.Look.SNOW].get_used_cells().size(), 0)
	assert_false(_view._is_refreshing())


func test_unloading_a_chunk_clears_its_overlays_and_looks() -> void:
	_view._load_chunk(RIGHT)
	_show(WINTER, 0.7)
	_view._unload_chunk(RIGHT)
	assert_false(_view._chunk_looks.has(RIGHT))
	assert_eq(_view._overlays[SeasonBlend.Look.SNOW].get_used_cells().size(), 0)


func test_a_refresh_is_spread_over_frames() -> void:
	for coords in [LEFT, RIGHT, BELOW]:
		_view._load_chunk(coords)
	_view.refresh_looks(WINTER, 0.5, 0.0)
	assert_true(_view._is_refreshing())
	assert_eq(_view._refresh_queue.size(), 3)
	_view.finish_refresh()
	assert_false(_view._is_refreshing())


func test_an_oak_is_in_leaf_bare_snowy_or_frosty_by_the_look() -> void:
	_show(SUMMER, 0.0)
	_view._load_chunk(RIGHT)
	var oak := _find_object(RIGHT, WorldObjectTypes.OAK)
	assert_eq(_view._objects.get_cell_source_id(oak.pos), SeasonBlend.Look.SUMMER)
	_show(WINTER, 0.0)
	assert_eq(_view._objects.get_cell_source_id(oak.pos), SeasonBlend.Look.BARE)
	_show(WINTER, 1.0)
	assert_eq(_view._objects.get_cell_source_id(oak.pos), SeasonBlend.Look.SNOW)
	_show(WINTER, 0.0, 1.0)
	assert_eq(_view._objects.get_cell_source_id(oak.pos), SeasonBlend.Look.FROST)


func test_trees_turn_one_by_one_across_autumn() -> void:
	_view._load_chunk(RIGHT)
	_show(SUMMER, 0.0)
	var summer_looks := _foliage_looks(RIGHT)
	assert_eq(summer_looks.size(), 1, "all alike in summer")
	_show(AUTUMN, 0.0)
	assert_gt(_foliage_looks(RIGHT).size(), 1, "a mix in autumn")


func _foliage_looks(coords: Vector2i) -> Dictionary:
	var looks := {}
	for object in _view.world.chunk_at(coords).objects():
		if object.type == WorldObjectTypes.OAK:
			looks[_view._objects.get_cell_source_id(object.pos)] = true
	return looks


func test_a_see_through_stand_in_has_the_look_of_its_cell() -> void:
	_view._load_chunk(RIGHT)
	_show(WINTER, 1.0)
	var oak := _find_object(RIGHT, WorldObjectTypes.OAK)
	_view._swap_cell_for_sprite(oak)
	var texture: AtlasTexture = _view._object_sprites[oak.pos].texture
	assert_eq(
		texture.atlas.resource_path,
		SeasonalArt.path(ObjectTileset.ATLAS_PATH, SeasonBlend.Look.SNOW)
	)


func test_a_house_has_snow_on_its_roof_while_its_tile_is_snowy() -> void:
	_view.world.add_chunk(Chunk.new(Vector2i.ZERO))
	var building := _view.world.place_building(BuildingTypes.SMALL_HOUSE, Vector2i(2, 2))
	_show(WINTER, 0.0)
	var sprite := _view._building_sprites[building]
	assert_false(sprite.texture.resource_path.contains("_snow"))
	_show(WINTER, 1.0)
	assert_true(sprite.texture.resource_path.contains("_snow"))
	_show(WINTER, 0.0)
	assert_false(sprite.texture.resource_path.contains("_snow"))


func test_decorations_take_the_look_of_their_tile() -> void:
	_view._load_chunk(RIGHT)
	_show(SUMMER, 0.0)
	var source_ids := {}
	for pos in _view._decorations.get_used_cells():
		source_ids[_view._decorations.get_cell_source_id(pos)] = true
	assert_eq(source_ids.keys(), [TerrainTileset.decoration_source_id(SeasonBlend.Look.SUMMER)])
	_show(SUMMER, 1.0)
	for pos in _view._decorations.get_used_cells():
		var is_water := _view._layer_at(pos) == TerrainTileset.Layer.WATER
		var expected := SeasonBlend.Look.SUMMER if is_water else SeasonBlend.Look.SNOW
		assert_eq(
			_view._decorations.get_cell_source_id(pos),
			TerrainTileset.decoration_source_id(expected),
			"decoration at %s" % pos
		)
