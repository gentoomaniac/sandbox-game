extends GutTest
## WorldView's looks of the plants and houses (the ground's are in test_world_view_ground.gd): the
## look of each tree and house by the season and the weather, and how a refresh is spread.

const SEED := 1
const LEFT := Vector2i(-2, -1)
const RIGHT := Vector2i(-1, -1)
const BELOW := Vector2i(-1, 0)
const SUMMER := 45
const AUTUMN := 62
const WINTER := 105

var _view: WorldView
var _residency: ChunkResidency


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_residency = ChunkResidency.new(World.new(SEED))
	_view.show_world(_residency)


func _find_object(coords: Vector2i, type: StringName) -> WorldObject:
	for object in _view.world.chunk_at(coords).objects():
		if object.type == type:
			return object
	fail_test("no %s in chunk %s" % [type, coords])
	return null


func _show(day: int) -> void:
	_view.world.clock.day = day
	_view.refresh_looks(day)
	_view.finish_refresh()


func test_a_refresh_is_spread_over_frames() -> void:
	for coords in [LEFT, RIGHT, BELOW]:
		_residency.load_chunk(coords)
		_view.finish_drawing()
	_view.refresh_looks(WINTER)
	assert_eq(_view._refresh_queue.size(), 3)
	_view.finish_refresh()
	assert_true(_view._refresh_queue.is_empty())


func test_an_oak_is_in_leaf_or_bare_by_the_season() -> void:
	_show(SUMMER)
	_residency.load_chunk(RIGHT)
	_view.finish_drawing()
	var oak := _find_object(RIGHT, WorldObjectTypes.OAK)
	assert_eq(_view._objects.get_cell_source_id(oak.pos), SeasonBlend.Look.SUMMER)
	_show(WINTER)
	assert_eq(_view._objects.get_cell_source_id(oak.pos), SeasonBlend.Look.BARE)


func test_the_objects_have_the_cover_shader_and_the_plants_their_own() -> void:
	assert_eq(_view._objects.material, _view._ground_look.objects)
	var oak_row: int = WorldObjectTypes.TYPES[WorldObjectTypes.OAK]["atlas_row"]
	var stone_row: int = WorldObjectTypes.TYPES[WorldObjectTypes.STONE]["atlas_row"]
	var source: TileSetAtlasSource = _view._object_tileset.tile_set.get_source(
		SeasonBlend.Look.SUMMER
	)
	assert_eq(
		source.get_tile_data(Vector2i(0, oak_row), 0).material,
		_view.ambient_motion.object_material(WorldObjectTypes.OAK)
	)
	assert_null(source.get_tile_data(Vector2i(0, stone_row), 0).material, "the layer's")


func test_trees_turn_one_by_one_across_autumn() -> void:
	_residency.load_chunk(RIGHT)
	_view.finish_drawing()
	_show(SUMMER)
	var summer_looks := _foliage_looks(RIGHT)
	assert_eq(summer_looks.size(), 1, "all alike in summer")
	_show(AUTUMN)
	assert_gt(_foliage_looks(RIGHT).size(), 1, "a mix in autumn")


func _foliage_looks(coords: Vector2i) -> Dictionary:
	var looks := {}
	for object in _view.world.chunk_at(coords).objects():
		if object.type == WorldObjectTypes.OAK:
			looks[_view._objects.get_cell_source_id(object.pos)] = true
	return looks


func test_a_see_through_stand_in_has_the_look_and_the_cover_of_its_cell() -> void:
	_residency.load_chunk(RIGHT)
	_view.finish_drawing()
	_show(WINTER)
	var oak := _find_object(RIGHT, WorldObjectTypes.OAK)
	_view._swap_cell_for_sprite(oak)
	var sprite: SeeThroughSprite = _view._object_sprites[oak.pos]
	var texture: AtlasTexture = sprite.texture
	assert_eq(
		texture.atlas.resource_path,
		SeasonalArt.path(ObjectTileset.ATLAS_PATH, SeasonBlend.Look.BARE)
	)
	assert_true(sprite.material.get_shader_parameter("has_cover"))
	var footprint: Vector2i = oak.type_data()["footprint"]
	var foot := Vector2(
		(oak.pos.x + footprint.x / 2.0) * TerrainTileset.TILE_SIZE,
		(oak.pos.y + footprint.y - 0.5) * TerrainTileset.TILE_SIZE
	)
	assert_eq(sprite.material.get_shader_parameter("cover_anchor"), foot)


func test_a_felled_trees_sprite_has_the_cover_too() -> void:
	_residency.load_chunk(RIGHT)
	_view.finish_drawing()
	var oak := _find_object(RIGHT, WorldObjectTypes.OAK)
	var fall := FallingTree.beside_trunk_of(oak, _view.world, 0.0)
	_view._place_object_sprite(fall, oak)
	assert_true(fall.material.get_shader_parameter("has_cover"))
	fall.free()


func test_a_house_has_the_snow_of_its_roof_and_the_cover_of_its_ground() -> void:
	_view.world.add_chunk(Chunk.new(Vector2i.ZERO))
	var building := _view.world.place_building(BuildingTypes.KATE, Vector2i(2, 2))
	var sprite := _view._buildings._sprites[building]
	assert_true(sprite.material.get_shader_parameter("has_roof_snow"))
	var snow: Texture2D = sprite.material.get_shader_parameter("roof_snow")
	assert_eq(snow.resource_path, "res://assets/buildings/kate_snow_cover.png")
	assert_eq(snow.get_size(), sprite.texture.get_size(), "the size of its pictures")
	assert_eq(
		sprite.material.get_shader_parameter("cover_anchor"),
		building.centre() * TerrainTileset.TILE_SIZE
	)
	_show(WINTER)
	assert_false(sprite.texture.resource_path.contains("_snow"), "the snow is not a look")


func test_a_house_roof_takes_the_season_of_its_tile() -> void:
	_view.world.add_chunk(Chunk.new(Vector2i.ZERO))
	var building := _view.world.place_building(BuildingTypes.SHACK, Vector2i(2, 2))
	var sprite := _view._buildings._sprites[building]
	# In daylight, so the windows are not lit.
	_view.set_light_strength(0.0)
	_show(SUMMER)
	assert_eq(sprite.texture.resource_path, "res://assets/buildings/shack.png")
	_show(WINTER)
	assert_eq(sprite.texture.resource_path, "res://assets/buildings/shack_bare.png")


func test_decorations_are_all_drawn_from_the_summer_atlas() -> void:
	_residency.load_chunk(RIGHT)
	_view.finish_drawing()
	for day in [SUMMER, WINTER]:
		_show(day)
		var source_ids := {}
		for pos in _view.decorations._decorations.get_used_cells():
			source_ids[_view.decorations._decorations.get_cell_source_id(pos)] = true
		assert_eq(source_ids.keys(), [TerrainTileset.DECORATION_SOURCE_ID])


func test_a_crop_is_drawn_from_its_own_sheet_in_every_look() -> void:
	_residency.load_chunk(RIGHT)
	_view.finish_drawing()
	var pos := Vector2i(-20, -20)
	_view.world.set_terrain(pos, Tile.Terrain.SOIL)
	var crop := WorldObject.new(&"carrot", pos)
	crop.state["growth"] = 2.0 * crop.type_data()["growth_per_stage"]
	_view.world.add_object(crop)
	var source_id := _view._objects.get_cell_source_id(pos)
	assert_false(source_id in ObjectTileset.LOOKS, "not from an object atlas look")
	assert_eq(source_id, _view._object_tileset.crop_source_id(&"carrot"))
	assert_eq(_view._objects.get_cell_atlas_coords(pos), Vector2i(2, 0))
	for day in [WINTER, AUTUMN]:
		_show(day)
		assert_eq(_view._objects.get_cell_source_id(pos), source_id)
		assert_eq(_view._object_state(crop), 0, "a look change does not redraw it")
