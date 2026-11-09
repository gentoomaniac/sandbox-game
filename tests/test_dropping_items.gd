extends ResourceCase
## Dropping a stack of the inventory on the ground: where it lies, that the player does not pick
## it up again at once, and that walking away and back does.

const FRAME := 1.0 / 60.0
## Long enough for the pile to settle after its hop.
const SETTLE_FRAMES := 120


func _walk_frames(frames: int) -> void:
	for _i in frames:
		_state.collect_ground_items(FRAME)


func _slot_with(item: StringName, count: int) -> int:
	var slot := 3
	_state.player.inventory.slots[slot] = {"item": item, "count": count}
	return slot


func test_a_dropped_stack_lies_on_the_ground_in_front_of_the_player() -> void:
	var slot := _slot_with(ItemTypes.STONE, 6)
	assert_true(_state.drop_from_inventory(slot))
	assert_true(_state.player.inventory.slots[slot].is_empty())
	assert_eq(_world.ground_items.count_of(ItemTypes.STONE), 6)
	for pile in _world.ground_items.all():
		assert_lte(pile.position.distance_to(Vector2(_state.player.facing_tile())), 2.5)


func test_a_dropped_stack_is_not_pulled_back_while_the_player_stands_there() -> void:
	var slot := _slot_with(ItemTypes.STONE, 6)
	_state.drop_from_inventory(slot)
	_walk_frames(SETTLE_FRAMES)
	assert_eq(_world.ground_items.count_of(ItemTypes.STONE), 6)
	assert_true(_state.player.inventory.slots[slot].is_empty())


func test_walking_away_and_back_picks_the_dropped_stack_up_again() -> void:
	var slot := _slot_with(ItemTypes.STONE, 1)
	_state.drop_from_inventory(slot)
	var pile: GroundItem = _world.ground_items.all()[0]
	_state.player.position = pile.position + Vector2(0, -6)
	_walk_frames(SETTLE_FRAMES)
	_state.player.position = pile.position
	_walk_frames(SETTLE_FRAMES)
	assert_eq(_world.ground_items.count_of(ItemTypes.STONE), 0)
	assert_eq(_state.player.inventory.count_of(ItemTypes.STONE), 1)


func test_an_empty_slot_drops_nothing() -> void:
	_state.player.inventory.slots[5] = {}
	assert_false(_state.drop_from_inventory(5))
	assert_true(_world.ground_items.all().is_empty())


func test_nothing_is_dropped_inside_a_house() -> void:
	var house: Building = null
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := _state.player.tile() + Vector2i(x, y)
			if house == null and _world.placement_blockers(BuildingTypes.KATE, origin).is_empty():
				house = _world.place_building(BuildingTypes.KATE, origin)
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_true(_state.is_inside())
	var slot := _slot_with(ItemTypes.STONE, 6)
	assert_false(_state.drop_from_inventory(slot))
	assert_eq(_state.player.inventory.slots[slot]["count"], 6)


func test_dropping_from_a_slot_that_does_not_exist_does_nothing() -> void:
	assert_false(_state.drop_from_inventory(-1))
	assert_false(_state.drop_from_inventory(Inventory.SLOT_COUNT))


func test_a_listener_of_the_inventory_sees_the_dropped_pile_already_on_the_ground() -> void:
	var slot := _slot_with(ItemTypes.STONE, 6)
	var seen := []
	var look := func() -> void:
		seen.append(
			[
				_state.player.inventory.count_of(ItemTypes.STONE),
				_world.ground_items.count_of(ItemTypes.STONE)
			]
		)
	_state.player.inventory.changed.connect(look)
	_state.drop_from_inventory(slot)
	_state.player.inventory.changed.disconnect(look)
	assert_eq(seen, [[0, 6]])


func test_a_listener_of_the_inventory_sees_the_picked_up_pile_already_gone() -> void:
	var slot := _slot_with(ItemTypes.STONE, 4)
	_state.drop_from_inventory(slot)
	var pile: GroundItem = _world.ground_items.all()[0]
	_state.player.position = pile.position + Vector2(0, -6)
	_walk_frames(SETTLE_FRAMES)
	_state.player.position = pile.position
	var seen := []
	var look := func() -> void:
		seen.append(
			[
				_state.player.inventory.count_of(ItemTypes.STONE),
				_world.ground_items.count_of(ItemTypes.STONE)
			]
		)
	_state.player.inventory.changed.connect(look)
	_walk_frames(SETTLE_FRAMES)
	_state.player.inventory.changed.disconnect(look)
	assert_false(seen.is_empty())
	for counts: Array in seen:
		assert_eq(counts[0] + counts[1], 4, "an item is in the inventory or on the ground, once")
