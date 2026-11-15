extends GutTest
## The edge of a road (#84): a free tile beside a way is drawn with a rim along the side next to the
## way, which goes when a way is laid on that tile and comes back when it is taken up.

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const MIDDLE := Vector2i(10, 10)
const NONE := Vector2i(-1, -1)

var _world: World
var _view: WorldView


func before_each() -> void:
	_world = World.new(1)
	_world.add_chunk(Chunk.new(Vector2i.ZERO))
	_view = WorldView.new()
	add_child_autofree(_view)
	_view.show_world(ChunkResidency.new(_world))


func _lay(type: StringName, tile: Vector2i) -> void:
	_world.add_object(WorldObject.new(type, tile))


## What is drawn on a tile as the road edge: the mask of the picture, or -1 for none.
func _edge_at(tile: Vector2i) -> int:
	var cell := _view._way_edges.layer.get_cell_atlas_coords(tile)
	if cell == NONE:
		return -1
	assert_eq(cell.y, WorldObjectWays.EDGE_ROW)
	return cell.x


func test_a_free_tile_beside_a_way_has_an_edge_on_that_side() -> void:
	_lay(WorldObjectTypes.PLANK_WALK, MIDDLE)
	assert_eq(_edge_at(MIDDLE + Vector2i.LEFT), EAST)
	assert_eq(_edge_at(MIDDLE + Vector2i.RIGHT), WEST)
	assert_eq(_edge_at(MIDDLE + Vector2i.UP), SOUTH)
	assert_eq(_edge_at(MIDDLE + Vector2i.DOWN), NORTH)


func test_a_way_has_no_edge_and_a_tile_beside_its_corner_has_none() -> void:
	_lay(WorldObjectTypes.STONE_PATH, MIDDLE)
	assert_eq(_edge_at(MIDDLE), -1)
	assert_eq(_edge_at(MIDDLE + Vector2i(1, 1)), -1)
	assert_eq(_edge_at(MIDDLE + Vector2i(2, 0)), -1)


func test_a_tile_between_two_ways_has_an_edge_on_both_sides() -> void:
	_lay(WorldObjectTypes.PLANK_WALK, MIDDLE)
	_lay(WorldObjectTypes.STONE_PATH, MIDDLE + Vector2i(2, 0))
	assert_eq(_edge_at(MIDDLE + Vector2i.RIGHT), EAST | WEST)


func test_laying_a_way_on_the_tile_takes_its_edge_away_and_moves_the_others() -> void:
	_lay(WorldObjectTypes.PLANK_WALK, MIDDLE)
	assert_eq(_edge_at(MIDDLE + Vector2i.RIGHT), WEST)
	_lay(WorldObjectTypes.PLANK_WALK, MIDDLE + Vector2i.RIGHT)
	assert_eq(_edge_at(MIDDLE + Vector2i.RIGHT), -1, "the road is wider and has no edge inside")
	assert_eq(_edge_at(MIDDLE + Vector2i(2, 0)), WEST, "its edge is beside the new way")
	assert_eq(_edge_at(MIDDLE + Vector2i(1, -1)), SOUTH)
	assert_eq(_edge_at(MIDDLE + Vector2i(0, -1)), SOUTH)


func test_taking_a_way_up_brings_the_edge_of_the_tile_back() -> void:
	_lay(WorldObjectTypes.PLANK_WALK, MIDDLE)
	_lay(WorldObjectTypes.PLANK_WALK, MIDDLE + Vector2i.RIGHT)
	_world.remove_object(MIDDLE + Vector2i.RIGHT)
	assert_eq(_edge_at(MIDDLE + Vector2i.RIGHT), WEST)
	assert_eq(_edge_at(MIDDLE + Vector2i(2, 0)), -1)
	_world.remove_object(MIDDLE)
	assert_eq(_edge_at(MIDDLE + Vector2i.RIGHT), -1)
	assert_eq(_edge_at(MIDDLE), -1)


func test_other_objects_do_not_make_an_edge() -> void:
	_lay(WorldObjectTypes.KNICK, MIDDLE)
	_lay(WorldObjectTypes.JETTY, MIDDLE + Vector2i(0, 3))
	assert_eq(_edge_at(MIDDLE + Vector2i.RIGHT), -1)
	assert_eq(_edge_at(MIDDLE + Vector2i(0, 2)), -1)


func test_no_edge_is_drawn_on_water_or_tilled_soil() -> void:
	_lay(WorldObjectTypes.PLANK_WALK, MIDDLE)
	_world.set_terrain(MIDDLE + Vector2i.LEFT, Tile.Terrain.SOIL)
	_world.set_terrain(MIDDLE + Vector2i.RIGHT, Tile.Terrain.WATER)
	assert_eq(_edge_at(MIDDLE + Vector2i.LEFT), -1)
	assert_eq(_edge_at(MIDDLE + Vector2i.RIGHT), -1)
	_world.set_terrain(MIDDLE + Vector2i.LEFT, Tile.Terrain.GRASS)
	assert_eq(_edge_at(MIDDLE + Vector2i.LEFT), EAST, "grass again")


func test_the_edge_of_a_chunk_goes_with_it() -> void:
	_lay(WorldObjectTypes.PLANK_WALK, MIDDLE)
	var chunk := _world.chunk_at(Vector2i.ZERO)
	_world.remove_chunk(Vector2i.ZERO)
	_view._on_chunk_unloaded(chunk)
	assert_eq(_edge_at(MIDDLE + Vector2i.LEFT), -1)


func test_a_chunk_that_loads_beside_a_way_draws_the_edge_on_its_border() -> void:
	var east := Chunk.new(Vector2i(1, 0))
	east.add_object(WorldObject.new(WorldObjectTypes.STONE_PATH, Vector2i(Chunk.CHUNK_SIZE, 5)))
	_world.remove_chunk(Vector2i.ZERO)
	_world.add_chunk(east)
	_view._draw_chunk(east)
	assert_eq(_edge_at(Vector2i(Chunk.CHUNK_SIZE - 1, 5)), -1, "its chunk is not loaded")
	var west := Chunk.new(Vector2i.ZERO)
	_world.add_chunk(west)
	_view._draw_chunk(west)
	assert_eq(_edge_at(Vector2i(Chunk.CHUNK_SIZE - 1, 5)), EAST)


func test_the_edge_follows_the_season_of_the_tile() -> void:
	_lay(WorldObjectTypes.PLANK_WALK, MIDDLE)
	var tile := MIDDLE + Vector2i.LEFT
	var look: int = _view._way_edges.layer.get_cell_source_id(tile)
	assert_eq(look, _view._look_at(tile))
