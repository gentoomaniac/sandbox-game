extends ResourceCase
## Items on the ground: what harvesting drops, where it lands, collecting by walking over it,
## and saving it.

const OAK_HITS := 5
const FRAME := 1.0 / 60.0

var _player_start: Vector2


func before_each() -> void:
	super.before_each()
	_player_start = _state.player.position


## A pile lying at `offset` from the player, as if it had been dropped there.
func _lay(item: StringName, count: int, offset: Vector2) -> GroundItem:
	var ground_item := GroundItem.new(item, count, _state.player.position + offset)
	_world.add_ground_item(ground_item)
	return ground_item


func _walk_frames(frames: int) -> void:
	for _i in frames:
		_state.collect_ground_items(FRAME)


## No free slot is left, not even the held one.
func _fill_inventory_completely() -> void:
	_fill_inventory()
	_state.player.inventory.slots[_state.player.inventory.selected_slot] = {
		"item": ItemTypes.TURNIP, "count": 99
	}


# --- Dropping ---


func test_felling_drops_the_logs_on_the_ground_not_in_the_inventory() -> void:
	_place(WorldObjectTypes.OAK)
	_hit(ItemTypes.AXE, OAK_HITS)
	assert_eq(_dropped(ItemTypes.LOGS), 4)
	assert_eq(_count(ItemTypes.LOGS), 0)


func test_mining_picking_and_harvesting_drop_on_the_ground() -> void:
	_place(WorldObjectTypes.STONE)
	_hit(ItemTypes.PICKAXE, 3)
	assert_eq(_dropped(ItemTypes.STONE), 2)
	_set_midsummer()
	_place(WorldObjectTypes.BERRY_BUSH)
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), GameState.Use.FORAGE)
	assert_eq(_dropped(ItemTypes.BERRIES), 3)
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	var crop := WorldObject.new(WorldObjectTypes.TURNIP, _tile)
	crop.state["growth"] = 3.0 * crop.type_data()["growth_per_stage"]
	_world.remove_object(_tile)
	_world.add_object(crop)
	assert_eq(_state.use_facing_tile(), GameState.Use.HARVEST)
	assert_eq(_dropped(ItemTypes.TURNIP), 1)
	assert_eq(_dropped(ItemTypes.TURNIP_SEEDS), 1)
	assert_eq(_count(ItemTypes.TURNIP), 0)


func test_a_drop_is_split_over_free_walkable_tiles_around_the_source() -> void:
	_world.drop_items(_tile, {ItemTypes.LOGS: 4})
	var tiles := {}
	for ground_item in _world.ground_items():
		var pile_tile := Vector2i(ground_item.position.floor())
		assert_true(_world.is_walkable(pile_tile))
		assert_lte(maxi(absi(pile_tile.x - _tile.x), absi(pile_tile.y - _tile.y)), 1)
		tiles[pile_tile] = true
	assert_eq(_world.ground_items().size(), 4)
	assert_eq(tiles.size(), 4, "one pile to a tile")
	assert_eq(_dropped(ItemTypes.LOGS), 4)


func test_piles_are_as_even_as_they_can_be() -> void:
	_world.drop_items(_tile, {ItemTypes.STONE: 20})
	assert_eq(_dropped(ItemTypes.STONE), 20)
	for ground_item in _world.ground_items():
		assert_between(ground_item.count, 2, 3)


func test_scattering_is_deterministic() -> void:
	_world.drop_items(_tile, {ItemTypes.LOGS: 4, ItemTypes.STONE: 3})
	var first: Array = _world.to_dict()["ground_items"]
	_clear_ground()
	_world.drop_items(_tile, {ItemTypes.LOGS: 4, ItemTypes.STONE: 3})
	assert_eq(_world.to_dict()["ground_items"], first)


func test_a_drop_avoids_tiles_that_block_walking() -> void:
	var blocked := _tile + Vector2i(1, 0)
	_world.remove_object(blocked)
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, blocked))
	_world.drop_items(_tile, {ItemTypes.LOGS: 8})
	for ground_item in _world.ground_items():
		assert_ne(Vector2i(ground_item.position.floor()), blocked)
	assert_eq(_dropped(ItemTypes.LOGS), 8)


func test_a_source_with_no_walkable_tile_around_drops_on_itself() -> void:
	for y in range(-2, 3):
		for x in range(-2, 3):
			var pos := _tile + Vector2i(x, y)
			_world.remove_object(pos)
			_world.add_object(WorldObject.new(WorldObjectTypes.STONE, pos))
	_world.remove_object(_tile)
	_world.drop_items(_tile, {ItemTypes.LOGS: 3})
	assert_eq(_dropped(ItemTypes.LOGS), 3)
	for ground_item in _world.ground_items():
		assert_eq(Vector2i(ground_item.position.floor()), _tile)


func test_the_drops_of_a_felled_tree_avoid_its_stump() -> void:
	_place(WorldObjectTypes.OAK)
	_hit(ItemTypes.AXE, OAK_HITS)
	for ground_item in _world.ground_items():
		assert_ne(Vector2i(ground_item.position.floor()), _tile)


# --- Collecting ---


func test_walking_over_a_pile_collects_it() -> void:
	_lay(ItemTypes.LOGS, 3, Vector2(0.3, 0))
	_walk_frames(30)
	assert_eq(_count(ItemTypes.LOGS), 3)
	assert_eq(_world.ground_items().size(), 0)


func test_a_pile_is_pulled_only_in_the_last_half_tile() -> void:
	var far := _lay(ItemTypes.LOGS, 1, Vector2(0.8, 0))
	var near := _lay(ItemTypes.STONE, 1, Vector2(0, 0.4))
	_walk_frames(1)
	assert_eq(far.position, _player_start + Vector2(0.8, 0))
	assert_lt(near.position.distance_to(_player_start), 0.4)
	assert_eq(_count(ItemTypes.STONE), 0, "pulled, not there yet")
	_walk_frames(20)
	assert_eq(_count(ItemTypes.STONE), 1)


func test_with_a_full_inventory_the_pile_stays_where_it_is() -> void:
	_fill_inventory_completely()
	var pile := _lay(ItemTypes.LOGS, 3, Vector2(0.2, 0))
	var spot := pile.position
	_walk_frames(30)
	assert_eq(pile.position, spot)
	assert_eq(pile.count, 3)
	assert_eq(_world.ground_items().size(), 1)


func test_a_pile_that_only_partly_fits_leaves_the_rest() -> void:
	_fill_inventory_completely()
	_state.player.inventory.slots[3] = {"item": ItemTypes.LOGS, "count": 97}
	var pile := _lay(ItemTypes.LOGS, 5, Vector2(0.1, 0))
	_walk_frames(30)
	assert_eq(_count(ItemTypes.LOGS), 99)
	assert_eq(pile.count, 3)
	assert_eq(_world.ground_items(), [pile] as Array[GroundItem])


func test_picking_up_emits_ground_item_removed() -> void:
	_lay(ItemTypes.LOGS, 1, Vector2(0.1, 0))
	watch_signals(_world)
	_walk_frames(30)
	assert_signal_emitted(_world, "ground_item_removed")


# --- Saving ---


func test_ground_items_survive_a_save() -> void:
	_world.drop_items(_tile, {ItemTypes.LOGS: 4, ItemTypes.BERRIES: 1})
	var restored := _through_save()
	assert_eq(restored.world.to_dict()["ground_items"], _world.to_dict()["ground_items"])
	assert_eq(restored.world.ground_count_of(ItemTypes.LOGS), 4)
	assert_eq(restored.world.ground_count_of(ItemTypes.BERRIES), 1)
