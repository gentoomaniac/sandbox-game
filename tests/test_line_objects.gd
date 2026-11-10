extends GutTest
## Line objects (Knicks and the other field boundaries): which neighbours they join, and that the
## view draws each tile with the picture of its connections.

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8

var _world: World


func before_each() -> void:
	_world = World.new(1)
	# A plain grass chunk, so nothing generated stands in the way.
	_world.add_chunk(Chunk.new(Vector2i.ZERO))


func _knick(pos: Vector2i) -> WorldObject:
	var knick := WorldObject.new(WorldObjectTypes.KNICK, pos)
	_world.add_object(knick)
	return knick


func test_a_knick_alone_joins_nothing() -> void:
	assert_eq(_world.connections(_knick(Vector2i(5, 5))), 0)


func test_a_knick_joins_the_knicks_on_its_sides_but_not_on_its_corners() -> void:
	var middle := _knick(Vector2i(5, 5))
	_knick(Vector2i(5, 4))
	_knick(Vector2i(6, 5))
	_knick(Vector2i(4, 6))
	assert_eq(_world.connections(middle), NORTH | EAST)


func test_a_knick_does_not_join_other_objects() -> void:
	var knick := _knick(Vector2i(5, 5))
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, Vector2i(5, 6)))
	assert_eq(_world.connections(knick), 0)


func test_the_field_boundaries_join_each_other() -> void:
	var knick := _knick(Vector2i(5, 5))
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE_WALL, Vector2i(6, 5)))
	_world.add_object(WorldObject.new(WorldObjectTypes.WATTLE_FENCE, Vector2i(5, 6)))
	assert_eq(_world.connections(knick), EAST | SOUTH)


func test_a_dyke_joins_only_dykes() -> void:
	var dyke := WorldObject.new(WorldObjectTypes.DYKE, Vector2i(5, 5))
	_world.add_object(dyke)
	_world.add_object(WorldObject.new(WorldObjectTypes.DYKE, Vector2i(5, 4)))
	_knick(Vector2i(6, 5))
	assert_eq(_world.connections(dyke), NORTH)


func test_a_dyke_is_walked_on_but_not_built_on_or_tilled() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.DYKE, Vector2i(5, 5)))
	assert_true(_world.is_walkable(Vector2i(5, 5)))
	assert_false(_world.is_buildable(Vector2i(5, 5)))
	assert_false(_world.is_free_on(Vector2i(5, 5), Tile.Terrain.GRASS))


func test_a_side_in_an_unloaded_chunk_counts_its_edits() -> void:
	var knick := _knick(Vector2i(0, 5))
	_knick(Vector2i(1, 5))
	_world.remove_chunk(Vector2i.ZERO)
	var neighbour := Chunk.new(Vector2i(-1, 0))
	_world.add_chunk(neighbour)
	var west := WorldObject.new(WorldObjectTypes.KNICK, Vector2i(-1, 5))
	_world.add_object(west)
	# The knicks at x 0 and 1 are edits of the unloaded chunk.
	assert_eq(_world.connections(west), EAST)
	assert_eq(_world.connections(knick), EAST | WEST)


func test_the_view_draws_the_picture_of_the_connections_and_redraws_the_neighbours() -> void:
	var view := WorldView.new()
	add_child_autofree(view)
	view.show_world(ChunkResidency.new(_world))
	var west := _knick(Vector2i(5, 5))
	assert_eq(
		view._objects.get_cell_atlas_coords(west.pos), ObjectTileset.atlas_cell(west, false, 0)
	)
	var east := _knick(Vector2i(6, 5))
	assert_eq(
		view._objects.get_cell_atlas_coords(west.pos), ObjectTileset.atlas_cell(west, false, EAST)
	)
	assert_eq(
		view._objects.get_cell_atlas_coords(east.pos), ObjectTileset.atlas_cell(east, false, WEST)
	)
	_world.remove_object(east.pos)
	assert_eq(
		view._objects.get_cell_atlas_coords(west.pos), ObjectTileset.atlas_cell(west, false, 0)
	)


func test_a_line_object_has_the_picture_of_its_variant_for_its_connections() -> void:
	var row: int = WorldObjectTypes.TYPES[WorldObjectTypes.KNICK]["atlas_row"]
	var columns := {}
	for x in 20:
		var cell := ObjectTileset.atlas_cell(
			WorldObject.new(WorldObjectTypes.KNICK, Vector2i(x, 0)), false, EAST
		)
		assert_eq(cell.y, row)
		assert_eq(cell.x % WorldObjectTypes.CONNECTION_LOOKS, EAST)
		columns[cell.x] = true
	assert_eq(columns.size(), WorldObjectTypes.TYPES[WorldObjectTypes.KNICK]["variants"])
