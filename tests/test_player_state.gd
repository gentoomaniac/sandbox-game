extends GutTest
## Walking: the body must stay on walkable tiles and slide along walls.

var _world: World
var _player: PlayerState


func before_each() -> void:
	_world = World.new(1)
	_world.add_chunk(Chunk.new(Vector2i.ZERO))
	_player = PlayerState.new()
	_player.position = Vector2(5.5, 5.5)


func test_walks_in_the_given_direction() -> void:
	_player.move(_world, Vector2.RIGHT, 0.05)
	assert_almost_eq(
		_player.position, Vector2(5.5 + PlayerState.SPEED * 0.05, 5.5), Vector2(0.001, 0.001)
	)


func test_diagonal_is_no_faster_than_straight() -> void:
	_player.move(_world, Vector2(1, 1), 0.05)
	assert_almost_eq(
		(_player.position - Vector2(5.5, 5.5)).length(), PlayerState.SPEED * 0.05, 0.001
	)


func test_cannot_enter_water() -> void:
	_world.chunk_at(Vector2i.ZERO).set_terrain(Vector2i(7, 5), Tile.Terrain.WATER)
	for _i in 40:
		_player.move(_world, Vector2.RIGHT, 0.05)
	assert_lt(_player.position.x, 7.0 - PlayerState.BODY_HALF_WIDTH + 0.001)


func test_cannot_enter_a_blocking_object() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, Vector2i(5, 7)))
	for _i in 40:
		_player.move(_world, Vector2.DOWN, 0.05)
	# The feet stop at the stone's top edge.
	assert_lt(_player.position.y, 7.0 + 0.001)


func test_walks_over_a_sleeping_bag() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.SLEEPING_BAG, Vector2i(6, 5)))
	_player.move(_world, Vector2.RIGHT, 0.05)
	assert_true(PlayerState.can_stand_at(_world, Vector2(6.5, 5.5)))


func test_slides_along_a_wall() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, Vector2i(7, 5)))
	_player.position = Vector2(6.65, 5.5)
	_player.move(_world, Vector2(1, 1), 0.05)
	assert_gt(_player.position.y, 5.5)


func test_cannot_leave_the_loaded_chunks() -> void:
	assert_false(PlayerState.can_stand_at(_world, Vector2(-0.1, 5.5)))


func test_a_body_ending_on_a_tile_edge_does_not_touch_the_next_tile() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, Vector2i(5, 7)))
	assert_true(PlayerState.can_stand_at(_world, Vector2(5.5, 7.0)))


func test_a_long_frame_moves_as_far_as_the_same_time_in_short_steps() -> void:
	var stepped := PlayerState.new()
	stepped.position = _player.position
	for _i in 4:
		stepped.move(_world, Vector2.RIGHT, PlayerState.MAX_STEP_SECONDS)
	_player.move(_world, Vector2.RIGHT, PlayerState.MAX_STEP_SECONDS * 4)
	assert_almost_eq(_player.position, stepped.position, Vector2(0.0001, 0.0001))


func test_facing_follows_the_last_move_direction() -> void:
	_player.move(_world, Vector2.RIGHT, 0.05)
	assert_eq(_player.facing, Vector2i.RIGHT)
	_player.move(_world, Vector2(-0.3, -1.0), 0.05)
	assert_eq(_player.facing, Vector2i.UP)
	_player.move(_world, Vector2.ZERO, 0.05)
	assert_eq(_player.facing, Vector2i.UP)
	assert_eq(_player.facing_tile(), _player.tile() + Vector2i.UP)
