extends GutTest
## The ground piles kept by chunk: what is near a point is found across chunk borders, and the
## index follows piles that move or are collected and is built again on load.

const SEED := 7
const FRAME := 1.0 / 60.0
const SIZE := Chunk.CHUNK_SIZE

var _piles: GroundItems


func before_each() -> void:
	_piles = GroundItems.new()


func _pile_at(position: Vector2) -> GroundItem:
	var ground_item := GroundItem.new(ItemTypes.LOGS, 1, position)
	_piles.add(ground_item)
	return ground_item


func test_near_finds_the_piles_in_reach_across_a_chunk_border() -> void:
	var border := Vector2(SIZE, SIZE)
	var before := _pile_at(border - Vector2(0.5, 0.5))
	var after := _pile_at(border + Vector2(0.5, 0.5))
	_pile_at(border + Vector2(3, 0))
	var found := _piles.near(border, 1.0)
	assert_eq(found.size(), 2)
	assert_has(found, before)
	assert_has(found, after)


func test_near_finds_nothing_in_negative_chunks_it_has_no_pile_in() -> void:
	var pile := _pile_at(Vector2(-0.5, -0.5))
	assert_eq(_piles.near(Vector2(0.2, 0.2), 1.0), [pile] as Array[GroundItem])
	assert_eq(_piles.near(Vector2(-SIZE, -SIZE), 1.0).size(), 0)


func test_a_moved_pile_is_found_where_it_is_now() -> void:
	var pile := _pile_at(Vector2(SIZE - 0.2, 0.5))
	_piles.move(pile, Vector2(SIZE + 0.2, 0.5))
	assert_eq(_piles.in_chunks_around(Vector2i(0, 0), 0).size(), 0)
	assert_eq(_piles.in_chunks_around(Vector2i(1, 0), 0), [pile] as Array[GroundItem])
	assert_eq(_piles.near(pile.position, 0.1), [pile] as Array[GroundItem])


func test_a_removed_pile_is_not_found_any_more() -> void:
	var pile := _pile_at(Vector2(100.5, 100.5))
	_piles.remove(pile)
	assert_eq(_piles.near(pile.position, 1.0).size(), 0)
	assert_eq(_piles.in_chunks_around(Vector2i(3, 3), 1).size(), 0)
	assert_eq(_piles.all().size(), 0)


func test_in_chunks_around_covers_the_square_of_chunks() -> void:
	var inside := _pile_at(Vector2(SIZE * 2 + 1, 5))
	_pile_at(Vector2(SIZE * 3 + 1, 5))
	assert_eq(_piles.in_chunks_around(Vector2i(1, 0), 1), [inside] as Array[GroundItem])


func test_the_index_is_built_again_on_load() -> void:
	_pile_at(Vector2(SIZE + 4.5, 2.5))
	_pile_at(Vector2(-3.5, 2.5))
	var restored := GroundItems.new()
	restored.load_array(_piles.to_array())
	assert_eq(restored.near(Vector2(SIZE + 4.5, 2.5), 0.5).size(), 1)
	assert_eq(restored.in_chunks_around(Vector2i(0, 0), 1).size(), 2)
	assert_eq(restored.in_chunks_around(Vector2i(5, 5), 1).size(), 0)


func test_a_pile_pulled_over_a_chunk_border_is_collected_and_unfiled() -> void:
	var state := GameState.new_game(SEED)
	state.player.position = Vector2(SIZE + 0.5, 0.5)
	var pile := GroundItem.new(ItemTypes.LOGS, 1, Vector2(SIZE - 0.6, 0.5))
	state.world.ground_items.add(pile)
	for _frame in 60:
		state.collect_ground_items(FRAME)
	assert_eq(state.player.inventory.count_of(ItemTypes.LOGS), 1)
	assert_eq(state.world.ground_items.in_chunks_around(Vector2i(0, 0), 1).size(), 0)


func test_a_pile_in_a_far_chunk_is_neither_settled_nor_touched() -> void:
	var state := GameState.new_game(SEED)
	var far := GroundItem.new(ItemTypes.LOGS, 1, state.player.position + Vector2(300, 0))
	far.settle_seconds = 1.0
	state.world.ground_items.add(far)
	for _frame in 10:
		state.collect_ground_items(FRAME)
	assert_eq(far.settle_seconds, 1.0)


func test_near_gives_the_piles_in_the_order_they_were_laid_across_chunks_and_moves() -> void:
	var border := Vector2(SIZE, SIZE)
	var first := _pile_at(border + Vector2(0.3, 0.3))
	var second := _pile_at(border - Vector2(0.3, 0.3))
	var third := _pile_at(border + Vector2(0.3, -0.3))
	assert_eq(_piles.near(border, 1.0), [first, second, third] as Array[GroundItem])
	_piles.move(first, border - Vector2(0.1, 0.1))
	assert_eq(_piles.near(border, 1.0), [first, second, third] as Array[GroundItem])


func test_the_index_is_not_in_the_save() -> void:
	var pile := _pile_at(Vector2(SIZE + 0.5, 0.5))
	_pile_at(Vector2(-5.5, 0.5))
	var saved := _piles.to_array()
	_piles.move(pile, Vector2(2 * SIZE + 0.5, 0.5))
	var moved := _piles.to_array()
	assert_eq(saved.size(), 2)
	assert_eq(saved[0].keys(), ["item", "count", "position"])
	assert_eq(moved[0]["position"], SaveCodec.float_vector_to_json(Vector2(2 * SIZE + 0.5, 0.5)))
	assert_eq(moved[1], saved[1], "other piles are saved as they were, in the same order")


func test_a_partly_picked_up_pile_stays_filed() -> void:
	var state := GameState.new_game(SEED)
	var inventory := state.player.inventory
	for slot in inventory.slots.size():
		inventory.slots[slot] = {"item": ItemTypes.TURNIP, "count": 99}
	inventory.slots[0] = {"item": ItemTypes.LOGS, "count": 98}
	var pile := GroundItem.new(ItemTypes.LOGS, 5, state.player.position + Vector2(0.1, 0))
	state.world.ground_items.add(pile)
	for _frame in 30:
		state.collect_ground_items(FRAME)
	assert_eq(pile.count, 4)
	assert_eq(state.world.ground_items.near(pile.position, 0.5), [pile] as Array[GroundItem])
	assert_eq(state.world.ground_items.all(), [pile] as Array[GroundItem])


func test_nothing_is_collected_inside_a_house_and_the_piles_stay_filed() -> void:
	var state := GameState.new()
	state.world = World.new(1)
	state.world.add_chunk(Chunk.new(Vector2i.ZERO))
	state.player.home_map = state.world
	var house := state.world.place_building(BuildingTypes.KATE, Vector2i(2, 2))
	var pile := GroundItem.new(ItemTypes.LOGS, 1, Vector2(house.door_tile()) + Vector2(0.5, 0.9))
	state.world.ground_items.add(pile)
	state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	state.pass_door()
	assert_true(state.is_inside())
	for _frame in 30:
		state.collect_ground_items(FRAME)
	assert_eq(state.player.inventory.count_of(ItemTypes.LOGS), 0)
	assert_eq(state.world.ground_items.near(pile.position, 0.5), [pile] as Array[GroundItem])
