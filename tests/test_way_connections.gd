extends GutTest
## The ways (#84) join the ways beside them, of either kind: which neighbours they join, which way
## the boards of the plank walk lie by them, and that the view draws each piece with the picture of
## its connections and again when a way beside it is laid or taken up.

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
## Where the ways of a test lie: the middle of a plain chunk, room for a road of 5 by 5.
const MIDDLE := Vector2i(10, 10)

var _world: World


func before_each() -> void:
	_world = World.new(1)
	_world.add_chunk(Chunk.new(Vector2i.ZERO))


func _lay(type: StringName, offset: Vector2i) -> WorldObject:
	var way := WorldObject.new(type, MIDDLE + offset)
	_world.add_object(way)
	return way


## Lays a plank walk on each offset, taking up what was laid before, and returns the one at
## `MIDDLE`.
func _planks_at(offsets: Array[Vector2i]) -> WorldObject:
	for y in range(-2, 3):
		for x in range(-2, 3):
			_world.remove_object(MIDDLE + Vector2i(x, y))
	for offset in offsets:
		_lay(WorldObjectTypes.PLANK_WALK, offset)
	return _world.object_at(MIDDLE)


func _lie_east_west(offsets: Array[Vector2i]) -> bool:
	return WorldObjectWays.boards_lie_east_west(_world.connections(_planks_at(offsets)))


func test_a_way_joins_the_ways_on_its_sides_of_either_kind() -> void:
	var plank := _lay(WorldObjectTypes.PLANK_WALK, Vector2i.ZERO)
	_lay(WorldObjectTypes.STONE_PATH, Vector2i.RIGHT)
	var stone := _lay(WorldObjectTypes.STONE_PATH, Vector2i.DOWN)
	_lay(WorldObjectTypes.PLANK_WALK, Vector2i(1, 1))
	assert_eq(_world.connections(plank), EAST | SOUTH)
	assert_eq(_world.connections(stone), NORTH | EAST)


func test_a_way_joins_no_other_line_object() -> void:
	var plank := _lay(WorldObjectTypes.PLANK_WALK, Vector2i.ZERO)
	_lay(WorldObjectTypes.KNICK, Vector2i.RIGHT)
	_lay(WorldObjectTypes.JETTY, Vector2i.DOWN)
	assert_eq(_world.connections(plank), 0)


func test_the_boards_of_a_run_lie_across_it() -> void:
	assert_true(_lie_east_west([Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN]), "north to south")


func test_the_boards_of_a_run_from_east_to_west_lie_north_to_south() -> void:
	assert_false(_lie_east_west([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT]), "east to west")


func test_the_boards_at_the_end_of_a_run_lie_as_those_of_the_run() -> void:
	assert_true(_lie_east_west([Vector2i.ZERO, Vector2i.DOWN]), "end of a run north to south")
	assert_false(_lie_east_west([Vector2i.ZERO, Vector2i.RIGHT]), "end of a run east to west")


func test_the_boards_at_a_corner_lie_east_to_west() -> void:
	assert_true(_lie_east_west([Vector2i.ZERO, Vector2i.UP, Vector2i.LEFT]))


func test_the_boards_at_a_t_lie_as_those_of_the_run_it_leaves() -> void:
	assert_true(
		_lie_east_west([Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]), "stem east"
	)
	assert_false(
		_lie_east_west([Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]), "stem south"
	)


func test_the_boards_at_a_crossing_or_alone_lie_east_to_west() -> void:
	assert_true(
		_lie_east_west([Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]),
		"crossing"
	)


func test_the_boards_of_a_tile_alone_lie_east_to_west() -> void:
	assert_true(_lie_east_west([Vector2i.ZERO]))


## The rule for every mask, as tools/art/test_ways.py has it for the art.
func test_the_rule_of_every_connection_mask() -> void:
	var lie_east_west := [
		true,
		true,
		false,
		true,
		true,
		true,
		true,
		true,
		false,
		true,
		false,
		false,
		true,
		true,
		false,
		true,
	]
	for mask in 16:
		assert_eq(WorldObjectWays.boards_lie_east_west(mask), lie_east_west[mask], "mask %d" % mask)


func test_a_piece_has_the_picture_of_its_connections() -> void:
	var plank := _lay(WorldObjectTypes.PLANK_WALK, Vector2i.ZERO)
	_lay(WorldObjectTypes.STONE_PATH, Vector2i.LEFT)
	var connections := _world.connections(plank)
	assert_eq(connections, WEST)
	assert_eq(ObjectTileset.atlas_cell(plank, false, connections).x % 16, WEST)


func test_the_boards_of_a_road_two_tiles_wide_have_the_same_variant_across_it() -> void:
	var variants := {}
	for y in range(-2, 3):
		var west := _lay(WorldObjectTypes.PLANK_WALK, Vector2i(0, y))
		var east := _lay(WorldObjectTypes.PLANK_WALK, Vector2i(1, y))
		var west_cell := ObjectTileset.atlas_cell(west, false, _world.connections(west))
		var east_cell := ObjectTileset.atlas_cell(east, false, _world.connections(east))
		assert_eq(west_cell.x / 16, east_cell.x / 16, "row %d" % y)
		variants[west_cell.x / 16] = true
	assert_gt(variants.size(), 1, "the rows differ")


func test_the_view_draws_a_way_again_when_a_way_is_laid_or_taken_up_beside_it() -> void:
	var view := WorldView.new()
	add_child_autofree(view)
	view.show_world(ChunkResidency.new(_world))
	var stone := _lay(WorldObjectTypes.STONE_PATH, Vector2i.ZERO)
	assert_eq(
		view._object_view.cells.get_cell_atlas_coords(stone.pos),
		ObjectTileset.atlas_cell(stone, false, 0)
	)
	var plank := _lay(WorldObjectTypes.PLANK_WALK, Vector2i.RIGHT)
	assert_eq(
		view._object_view.cells.get_cell_atlas_coords(stone.pos),
		ObjectTileset.atlas_cell(stone, false, EAST)
	)
	assert_eq(
		view._object_view.cells.get_cell_atlas_coords(plank.pos),
		ObjectTileset.atlas_cell(plank, false, WEST)
	)
	_world.remove_object(plank.pos)
	assert_eq(
		view._object_view.cells.get_cell_atlas_coords(stone.pos),
		ObjectTileset.atlas_cell(stone, false, 0)
	)
