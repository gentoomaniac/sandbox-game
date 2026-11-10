extends GutTest
## WorldView draws a loaded chunk over several frames (see WorldView `_draw_chunk_step`): the
## result is that of drawing it at once, whatever changes between the steps. Drives WorldView's
## private loading and reads its layers directly.

const SEED := 1
const RIGHT := Vector2i(-1, -1)
const SUMMER := 45
const WINTER := 105

var _generator := WorldGenerator.new(SEED)
var _view: WorldView
var _residency: ChunkResidency


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_residency = ChunkResidency.new(World.new(SEED))
	_view.show_world(_residency)


func test_a_chunk_drawn_step_by_step_looks_like_one_drawn_at_once() -> void:
	var at_once := _view_drawn_at_once(RIGHT, Vector2i(-1, -1))
	_residency.load_chunk(RIGHT)
	var steps := 0
	while _view._drawing != null:
		_view._draw_next_step()
		steps += 1
	assert_gt(steps, 2, "drawn over several steps")
	_assert_same_cells(_view, at_once, RIGHT)


func test_a_tile_that_changes_while_its_chunk_is_drawn_is_drawn_as_it_is_now() -> void:
	var tile := Chunk.to_world(RIGHT, Vector2i(5, 9))
	var at_once := _view_drawn_at_once(RIGHT, tile)
	_residency.load_chunk(RIGHT)
	_view._draw_next_step()
	_view._draw_next_step()
	_view.world.set_terrain(tile, Tile.Terrain.WATER)
	_view.finish_drawing()
	_assert_same_cells(_view, at_once, RIGHT)


func test_unloading_a_chunk_that_is_still_drawn_stops_its_drawing() -> void:
	_residency.load_chunk(RIGHT)
	_view._draw_next_step()
	_residency.unload_chunk(RIGHT)
	assert_null(_view._drawing)
	assert_eq(_drawn(Chunk.to_world(RIGHT, Vector2i(3, 3))), _empty())


func test_a_chunk_is_drawn_for_a_budget_a_frame_and_the_next_loads_when_it_is_drawn() -> void:
	_frame()
	assert_true(_view.is_drawing(), "one frame's budget does not draw the whole chunk")
	assert_eq(_view.world.loaded_chunk_coords().size(), 1)
	_frame()
	assert_eq(_view.world.loaded_chunk_coords().size(), 1, "no second chunk while one is drawn")
	_view.finish_drawing()
	_frame()
	assert_eq(_view.world.loaded_chunk_coords().size(), 2)


func test_a_tree_that_hides_the_player_before_its_chunk_is_drawn_stays_a_sprite() -> void:
	_residency.load_chunk(RIGHT)
	_view._draw_next_step()
	var tree := _first_tall_object(RIGHT)
	_view.player_feet = (Vector2(tree.pos) + Vector2(0.5, 0.1)) * TerrainTileset.TILE_SIZE
	_view._update_see_through(0.0)
	assert_true(_view._object_sprites.has(tree.pos), "the tree is a stand-in sprite")
	_view.finish_drawing()
	assert_eq(_view._objects.get_cell_source_id(tree.pos), -1, "its cell stays empty")


func test_the_stand_in_of_a_tree_shows_the_look_it_has_when_the_chunk_is_drawn() -> void:
	_set_day(SUMMER)
	_residency.load_chunk(RIGHT)
	_view._draw_next_step()
	var tree := _first_tall_object(RIGHT)
	_view.player_feet = (Vector2(tree.pos) + Vector2(0.5, 0.1)) * TerrainTileset.TILE_SIZE
	_view._update_see_through(0.0)
	var sprite: Sprite2D = _view._object_sprites[tree.pos]
	var summer_picture := _atlas_path(sprite.texture)
	_view.world.clock.day = WINTER
	_view.refresh_looks(WINTER, 0.0, 0.0)
	_view.finish_drawing()
	_view.finish_refresh()
	assert_ne(_atlas_path(sprite.texture), summer_picture)
	assert_eq(_atlas_path(sprite.texture), _atlas_path(_view._object_texture(tree)))


func test_an_object_added_while_its_chunk_is_drawn_covers_the_decoration_under_it() -> void:
	var at_once := _view_drawn_at_once(RIGHT, Vector2i(-1, -1))
	var pos := _free_tile_with_decoration(at_once, RIGHT)
	_residency.load_chunk(RIGHT)
	_view._draw_next_step()
	_view.world.add_object(WorldObject.new(WorldObjectTypes.STONE, pos))
	_view.finish_drawing()
	assert_eq(_view.decorations._decorations.get_cell_source_id(pos), -1)
	assert_false(_view.decorations._spots.has(pos))


func test_an_object_removed_while_its_chunk_is_drawn_shows_the_decoration_it_covered() -> void:
	var at_once := _view_drawn_at_once(RIGHT, Vector2i(-1, -1))
	var pos := _free_tile_with_decoration(at_once, RIGHT)
	at_once.world.add_object(WorldObject.new(WorldObjectTypes.STONE, pos))
	_view.world.add_chunk(_generator.generate_chunk(RIGHT))
	_view.world.add_object(WorldObject.new(WorldObjectTypes.STONE, pos))
	_view._drawing = WorldView.ChunkDrawing.new(_view.world.chunk_at(RIGHT))
	_view._draw_next_step()
	_view.world.remove_object(pos)
	_view.finish_drawing()
	assert_true(_view.decorations._spots.has(pos))


## What Main does in a frame: the residency loads a chunk if the view can take it, the view draws.
func _frame() -> void:
	_residency.update(not _view.is_drawing())
	_view._process(0.0)


func _atlas_path(texture: Texture2D) -> String:
	return (texture as AtlasTexture).atlas.resource_path


func _first_tall_object(coords: Vector2i) -> WorldObject:
	for object in _view.world.chunk_at(coords).objects():
		if Occlusion.object_rect(object).size != Vector2.ZERO:
			return object
	return null


## A tile of the chunk with a decoration and no object, in the lower rows, which come late.
func _free_tile_with_decoration(view: WorldView, coords: Vector2i) -> Vector2i:
	for y in range(Chunk.CHUNK_SIZE - 1, 8, -1):
		for x in Chunk.CHUNK_SIZE:
			var pos := Chunk.to_world(coords, Vector2i(x, y))
			if view.decorations._spots.has(pos) and view.world.object_at(pos) == null:
				return pos
	return Vector2i.ZERO


## A view that shows the chunk, made water at `water_tile` first, as drawn when the view starts.
func _view_drawn_at_once(coords: Vector2i, water_tile: Vector2i) -> WorldView:
	var view := WorldView.new()
	add_child_autofree(view)
	var world := World.new(SEED)
	world.add_chunk(_generator.generate_chunk(coords))
	if Chunk.world_to_chunk(water_tile) == coords:
		world.set_terrain(water_tile, Tile.Terrain.WATER)
	view.show_world(ChunkResidency.new(world))
	return view


func _assert_same_cells(view: WorldView, expected: WorldView, coords: Vector2i) -> void:
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var cell := origin + Vector2i(x, y)
			for layer in TerrainTileset.LAYER_COUNT:
				var drawn := view._layers[layer].get_cell_atlas_coords(cell)
				assert_eq(drawn, expected._layers[layer].get_cell_atlas_coords(cell), "%s" % cell)
			assert_eq(
				view._objects.get_cell_atlas_coords(cell),
				expected._objects.get_cell_atlas_coords(cell),
				"object at %s" % cell
			)


func _set_day(day: int) -> void:
	_view.world.clock.day = day
	_view.refresh_looks(day, 0.0, 0.0)
	_view.finish_refresh()


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
