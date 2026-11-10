extends GutTest
## WorldView's chunk borders: cells on a border between two chunks must end up drawn from
## both chunks' terrain, whichever chunk loads first. Drives WorldView's private loading
## and reads its layers directly, since streaming itself is covered by ChunkStreaming.

const SEED := 1
## Chunks by the river whose shared borders cross terrain edges, so a fallback that
## copies the loaded side differs from the real terrain.
const LEFT := Vector2i(-2, -1)
const RIGHT := Vector2i(-1, -1)
const BELOW := Vector2i(-1, 0)
const SUMMER := 45
const WINTER := 105

var _generator := WorldGenerator.new(SEED)
var _view: WorldView


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_view.show_world(World.new(SEED))


func test_right_neighbour_loaded_second_blends_its_border() -> void:
	_view._load_chunk(LEFT)
	_view.finish_drawing()
	_view._load_chunk(RIGHT)
	_view.finish_drawing()
	_assert_drawn_from_terrain(_left_column(RIGHT))


func test_left_neighbour_loaded_second_fixes_up_the_fallback() -> void:
	_view._load_chunk(RIGHT)
	_view.finish_drawing()
	var border := _left_column(RIGHT)
	_assert_drawn_with_fallback(border)
	_view._load_chunk(LEFT)
	_view.finish_drawing()
	_assert_drawn_from_terrain(border)


func test_bottom_neighbour_loaded_first_is_fixed_up_too() -> void:
	_view._load_chunk(BELOW)
	_view.finish_drawing()
	# Leaves out the corner cell: it also touches the diagonal chunk, which stays unloaded.
	var top_row: Array[Vector2i] = []
	for x in range(1, Chunk.CHUNK_SIZE):
		top_row.append(Chunk.to_world(BELOW, Vector2i(x, 0)))
	_assert_drawn_with_fallback(top_row)
	_view._load_chunk(RIGHT)
	_view.finish_drawing()
	_assert_drawn_from_terrain(top_row)


func test_unloading_erases_the_chunks_cells() -> void:
	_view._load_chunk(RIGHT)
	_view.finish_drawing()
	_view._unload_chunk(RIGHT)
	for cell in _left_column(RIGHT):
		assert_eq(_drawn(cell), _empty())


## The cells owned by `coords` that also touch its left neighbour.
func _left_column(coords: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in Chunk.CHUNK_SIZE:
		cells.append(Chunk.to_world(coords, Vector2i(0, y)))
	return cells


func _assert_drawn_from_terrain(cells: Array[Vector2i]) -> void:
	var blended := 0
	for cell in cells:
		var expected := _expected(cell)
		assert_eq(_drawn(cell), expected, "cell %s" % cell)
		if expected.count(Vector2i(-1, -1)) < TerrainTileset.LAYER_COUNT - 1:
			blended += 1
	assert_gt(blended, 0, "the border crosses at least one terrain edge")


## Every cell is drawn, but with the neighbour missing at least one is not what the real
## terrain gives yet.
func _assert_drawn_with_fallback(cells: Array[Vector2i]) -> void:
	var guessed := 0
	for cell in cells:
		assert_ne(_drawn(cell), _empty(), "fallback drawn at %s" % cell)
		if _drawn(cell) != _expected(cell):
			guessed += 1
	assert_gt(guessed, 0, "the fallback differs from the real terrain somewhere")


## The atlas cell of each layer at `cell`, as drawn.
func _drawn(cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for tile_map in _view._layers:
		cells.append(tile_map.get_cell_atlas_coords(cell))
	return cells


func _empty() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.resize(TerrainTileset.LAYER_COUNT)
	cells.fill(Vector2i(-1, -1))
	return cells


## What each layer should show at `cell`, worked out from the generator's terrain.
func _expected(cell: Vector2i) -> Array[Vector2i]:
	var corners := PackedInt32Array()
	for offset in WorldView.CORNER_OFFSETS:
		var tile := cell + offset
		corners.append(_view._layer_of_tile(_generator.terrain_at(tile), tile))
	var cells := _empty()
	var drawn := TerrainTileset.drawn_layers(corners)
	for layer in TerrainTileset.LAYER_COUNT:
		if drawn & (1 << layer):
			var mask := TerrainTileset.mask_for(corners, layer)
			cells[layer] = _view._tileset.atlas_cell(layer, mask, cell)
	return cells


func test_objects_are_drawn_on_load_and_erased_on_unload() -> void:
	_view._load_chunk(RIGHT)
	_view.finish_drawing()
	var object := _view.world.chunk_at(RIGHT).objects()[0]
	assert_ne(_view._objects.get_cell_source_id(object.pos), -1)
	assert_eq(
		_view.decorations._decorations.get_cell_source_id(object.pos), -1, "no decoration under it"
	)
	_view._unload_chunk(RIGHT)
	assert_eq(_view._objects.get_cell_source_id(object.pos), -1)


func test_objects_are_redrawn_when_added_and_removed() -> void:
	_view._load_chunk(RIGHT)
	_view.finish_drawing()
	var free_pos := Vector2i.ZERO
	for local in Chunk.CHUNK_SIZE:
		var pos := Chunk.to_world(RIGHT, Vector2i(local, 0))
		if _view.world.object_at(pos) == null:
			free_pos = pos
	assert_eq(_view._objects.get_cell_source_id(free_pos), -1)
	_view.world.add_object(WorldObject.new(WorldObjectTypes.OAK, free_pos))
	assert_ne(_view._objects.get_cell_source_id(free_pos), -1)
	assert_eq(_view.decorations._decorations.get_cell_source_id(free_pos), -1)
	_view.world.remove_object(free_pos)
	assert_eq(_view._objects.get_cell_source_id(free_pos), -1)


func test_building_windows_are_lit_and_shine_only_in_the_dark() -> void:
	_view.world.add_chunk(Chunk.new(Vector2i.ZERO))
	var building := _view.world.place_building(BuildingTypes.KATE, Vector2i(2, 2))
	_view.set_light_strength(0.0)
	var lights: Array = _view._buildings._window_lights[building]
	var day_texture: Texture2D = _view._buildings._sprites[building].texture
	assert_eq(lights.size(), BuildingTypes.TYPES[BuildingTypes.KATE]["window_lights"].size())
	_view.set_light_strength(1.0)
	assert_ne(_view._buildings._sprites[building].texture, day_texture, "lit window picture")
	assert_true(lights[0].visible)
	_view.set_light_strength(0.0)
	assert_eq(_view._buildings._sprites[building].texture, day_texture)
	assert_false(lights[0].visible)


func test_buildings_follow_the_art_set() -> void:
	_view.world.add_chunk(Chunk.new(Vector2i.ZERO))
	var building := _view.world.place_building(BuildingTypes.KATE, Vector2i(2, 2))
	var sprite: Sprite2D = _view._buildings._sprites[building]
	ArtSet.show(true, get_tree())
	assert_string_starts_with(sprite.texture.resource_path, "res://assets/classic/buildings/kate")
	ArtSet.show(false, get_tree())
	assert_string_starts_with(sprite.texture.resource_path, "res://assets/buildings/kate")


# --- Vegetation follows the year ---


func test_decorations_thin_out_by_winter_and_return_on_the_refresh_of_a_new_day() -> void:
	_view._load_chunk(RIGHT)
	_view.finish_drawing()
	_set_day(SUMMER)
	var in_summer := _view.decorations._decorations.get_used_cells().size()
	_set_day(WINTER)
	var in_winter := _view.decorations._decorations.get_used_cells().size()
	assert_lt(in_winter, in_summer)
	assert_gt(in_winter, 0, "pebbles and a few stalks stay")
	_set_day(SUMMER)
	assert_eq(_view.decorations._decorations.get_used_cells().size(), in_summer)


func test_a_chunk_loaded_in_winter_is_drawn_for_winter() -> void:
	_set_day(SUMMER)
	_view._load_chunk(RIGHT)
	_view.finish_drawing()
	var in_summer := _view.decorations._decorations.get_used_cells().size()
	_view._unload_chunk(RIGHT)
	assert_true(_view.decorations._spots.is_empty(), "unloading forgets the spots")
	_set_day(WINTER)
	_view._load_chunk(RIGHT)
	_view.finish_drawing()
	assert_lt(_view.decorations._decorations.get_used_cells().size(), in_summer)


func test_a_fern_is_drawn_in_summer_and_gone_in_winter() -> void:
	_set_day(SUMMER)
	_view._load_chunk(RIGHT)
	_view.finish_drawing()
	var fern := _find_object(RIGHT, WorldObjectTypes.FERN_BUSH)
	assert_ne(_view._objects.get_cell_source_id(fern.pos), -1)
	_set_day(WINTER)
	assert_eq(_view._objects.get_cell_source_id(fern.pos), -1)
	_set_day(SUMMER + GameClock.DAYS_PER_YEAR)
	assert_ne(_view._objects.get_cell_source_id(fern.pos), -1)


func test_a_berry_bush_is_drawn_without_berries_out_of_season() -> void:
	_set_day(SUMMER)
	_view._load_chunk(RIGHT)
	_view.finish_drawing()
	var bush := _find_object(RIGHT, WorldObjectTypes.BERRY_BUSH)
	var ripe := _view._objects.get_cell_atlas_coords(bush.pos)
	_set_day(WINTER)
	assert_eq(_view._objects.get_cell_atlas_coords(bush.pos), ObjectTileset.atlas_cell(bush, true))
	assert_ne(_view._objects.get_cell_atlas_coords(bush.pos), ripe)


## What the game scene does when the clock passes midnight.
func _set_day(day: int) -> void:
	_view.world.clock.day = day
	_view.refresh_looks(day, 0.0, 0.0)
	_view.finish_refresh()


func _find_object(coords: Vector2i, type: StringName) -> WorldObject:
	for object in _view.world.chunk_at(coords).objects():
		if object.type == type:
			return object
	fail_test("no %s in chunk %s" % [type, coords])
	return null
