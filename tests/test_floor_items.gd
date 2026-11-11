extends IndoorCase
## Items on the floor of a house: dropped there, lying where the floor is free, collected by
## walking over them, and still there when the player leaves and comes back.

const FRAME := 1.0 / 60.0
## Long enough for a pile to settle after its hop.
const SETTLE_FRAMES := 120


func _walk_frames(frames: int) -> void:
	for _i in frames:
		_state.collect_ground_items(FRAME)


func _slot_with(item: StringName, count: int) -> int:
	var slot := 3
	_state.player.inventory.slots[slot] = {"item": item, "count": count}
	return slot


func _positions_of(interior: Interior) -> Array:
	return interior.ground_items.all().map(func(pile: GroundItem) -> Vector2: return pile.position)


func test_a_dropped_stack_lies_on_the_floor_of_the_house_and_not_in_the_world() -> void:
	var interior := _enter_house()
	var slot := _slot_with(ItemTypes.STONE, 6)

	assert_true(_state.drop_from_inventory(slot))

	assert_true(_state.player.inventory.slots[slot].is_empty())
	assert_eq(interior.ground_items.count_of(ItemTypes.STONE), 6)
	assert_eq(_world.ground_items.count_of(ItemTypes.STONE), 0)


func test_the_piles_lie_on_free_floor_inside_the_room() -> void:
	var interior := _enter_house()
	# Next to the walls and the doormat, facing each way: the piles may only go to the floor.
	for position in [interior.entry_tile(), Vector2i(1, interior.size.y - 2)]:
		_state.player.position = Vector2(position) + Vector2(0.5, 0.5)
		for facing in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			_state.player.facing = facing
			_state.drop_from_inventory(_slot_with(ItemTypes.STONE, 40))
	assert_gt(interior.ground_items.all().size(), 4)
	for pile in interior.ground_items.all():
		var tile := Vector2i(pile.position.floor())
		assert_true(interior.can_hold_pile(tile), "pile on %s is on free floor" % tile)
		assert_true(interior.tile_at(tile).is_floor(), "pile on %s is not on a wall" % tile)
		assert_null(interior.object_at(tile), "pile on %s is not on furniture" % tile)
		assert_ne(tile, interior.exit_tile, "pile is not on the doormat")


func test_a_dropped_stack_is_picked_up_again_by_walking_away_and_back() -> void:
	var interior := _enter_house()
	_state.drop_from_inventory(_slot_with(ItemTypes.STONE, 1))
	var pile: GroundItem = interior.ground_items.all()[0]
	_state.player.position = pile.position
	_walk_frames(SETTLE_FRAMES)
	assert_eq(interior.ground_items.count_of(ItemTypes.STONE), 1, "not pulled back at once")

	_state.player.position = pile.position + Vector2(0, -1.5)
	_walk_frames(SETTLE_FRAMES)
	_state.player.position = pile.position
	_walk_frames(SETTLE_FRAMES)

	assert_eq(interior.ground_items.count_of(ItemTypes.STONE), 0)
	assert_eq(_state.player.inventory.count_of(ItemTypes.STONE), 1)


func test_a_pile_on_the_floor_is_pulled_to_the_player_and_collected() -> void:
	var interior := _enter_house()
	interior.ground_items.add(
		GroundItem.new(ItemTypes.LOGS, 2, _state.player.position + Vector2(0.8, 0))
	)

	_walk_frames(SETTLE_FRAMES)

	assert_eq(interior.ground_items.count_of(ItemTypes.LOGS), 0)
	assert_eq(_state.player.inventory.count_of(ItemTypes.LOGS), 2)


func test_piles_stay_on_the_floor_when_the_player_leaves_and_comes_back() -> void:
	var house := _place_house()
	var interior := _walk_in(house)
	_state.drop_from_inventory(_slot_with(ItemTypes.STONE, 6))
	var laid := _positions_of(interior)

	_leave_house(interior)
	_walk_frames(SETTLE_FRAMES)
	assert_eq(_positions_of(interior), laid, "still there while the player is out")
	_walk_in(house)
	_walk_frames(SETTLE_FRAMES)

	assert_eq(_positions_of(interior), laid, "and when they are back")


func test_what_lies_in_the_world_is_not_collected_from_inside() -> void:
	_world.ground_items.add(GroundItem.new(ItemTypes.LOGS, 1, _state.player.position))
	_enter_house()
	_walk_frames(SETTLE_FRAMES)
	assert_eq(_world.ground_items.count_of(ItemTypes.LOGS), 1)
	assert_eq(_state.player.inventory.count_of(ItemTypes.LOGS), 0)


func test_a_drop_with_no_free_floor_near_goes_to_the_nearest_free_floor_of_the_room() -> void:
	var interior := _enter_house()
	var source := Vector2i(0, 0)
	for y in range(-2, 3):
		for x in range(-2, 3):
			var tile := source + Vector2i(x, y)
			if interior.can_hold_pile(tile):
				interior.add_object(WorldObject.new(WorldObjectTypes.CHEST, tile))
	assert_false(interior.can_hold_pile(Vector2i(1, 2)), "the floor near the corner is taken")

	var piles := interior.drop_items(source, {ItemTypes.STONE: 1})

	assert_eq(piles.size(), 1)
	var tile := Vector2i(piles[0].position.floor())
	assert_true(interior.can_hold_pile(tile), "pile on %s is on free floor" % tile)
