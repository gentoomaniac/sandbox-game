extends GutTest

const PLAYER := Vector2i(10, 10)
const FACING := Vector2i(10, 11)


func _resolve(mouse_tile: Vector2i, is_mouse_active := true) -> Targeting:
	return Targeting.resolve(PLAYER, FACING, mouse_tile, is_mouse_active)


func test_active_mouse_in_reach_targets_the_mouse_tile() -> void:
	var targeting := _resolve(Vector2i(9, 9))
	assert_eq(targeting.tile, Vector2i(9, 9))
	assert_eq(targeting.source, Targeting.Source.MOUSE)
	assert_true(targeting.is_in_reach)


func test_the_players_own_tile_is_in_reach() -> void:
	assert_true(_resolve(PLAYER).is_in_reach)


func test_every_corner_of_the_three_by_three_is_in_reach() -> void:
	for corner in [Vector2i(9, 9), Vector2i(11, 9), Vector2i(9, 11), Vector2i(11, 11)]:
		assert_true(_resolve(corner).is_in_reach, str(corner))


func test_two_tiles_away_is_out_of_reach() -> void:
	var far_tiles := [Vector2i(12, 10), Vector2i(8, 10), Vector2i(10, 12), Vector2i(10, 8)]
	for far in far_tiles + [Vector2i(12, 12)]:
		var targeting := _resolve(far)
		assert_eq(targeting.tile, far)
		assert_eq(targeting.source, Targeting.Source.MOUSE)
		assert_false(targeting.is_in_reach, str(far))


func test_idle_mouse_falls_back_to_the_facing_tile() -> void:
	var targeting := _resolve(Vector2i(20, 20), false)
	assert_eq(targeting.tile, FACING)
	assert_eq(targeting.source, Targeting.Source.FACING)
	assert_true(targeting.is_in_reach)
