extends ResourceCase
## Harvest animations (view only): the fall of a felled tree and the hops of what a harvest drops.
## The state changes at once; these tests look at what the views do meanwhile.

var _view: WorldView
var _items: GroundItemView
var _entities: Node2D


func before_each() -> void:
	super.before_each()
	_make_room()
	_set_midsummer()
	_hold(ItemTypes.AXE)


func _show_views() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_view.show_world(_world)
	_view._load_chunk(Chunk.world_to_chunk(_tile))
	_entities = Node2D.new()
	add_child_autofree(_entities)
	_items = GroundItemView.new()
	add_child_autofree(_items)
	_items.show_items(_world, _entities)


## Fells an oak on the tile from the side of it (LEFT: the player stands left of it).
func _fell_oak_from(side: Vector2i) -> void:
	var tree := _place(WorldObjectTypes.OAK)
	tree.take_hit(tree.type_data()["hp"] - 1)
	_state.player.position = Vector2(_tile + side) + Vector2(0.5, 0.5)
	_state.use_tile(_tile)


func _trunk() -> WorldObject:
	return _view._falling_trees[0].trunk


# --- The fall ---


func test_a_tree_falls_towards_its_trunk_away_from_the_player() -> void:
	_show_views()
	_fell_oak_from(Vector2i.LEFT)
	assert_eq(_view._falling_trees.size(), 1)
	assert_eq(_view._falling_trees[0].direction, 1)
	assert_gt(_trunk().pos.x, _tile.x, "the trunk lies on the right")


func test_a_tree_felled_from_the_right_falls_left() -> void:
	_show_views()
	_fell_oak_from(Vector2i.RIGHT)
	assert_eq(_view._falling_trees[0].direction, -1)
	assert_lt(_trunk().pos.x, _tile.x, "the trunk lies on the left")


func test_the_state_is_final_at_once() -> void:
	_show_views()
	_fell_oak_from(Vector2i.LEFT)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.STUMP)
	assert_eq(_world.object_at(_tile + Vector2i.RIGHT).type, &"oak_trunk")


func test_the_trunk_is_not_drawn_until_the_fall_ends() -> void:
	_show_views()
	_fell_oak_from(Vector2i.LEFT)
	var trunk_tile := _trunk().pos
	assert_eq(_view._objects.get_cell_source_id(trunk_tile), -1, "hidden")
	_view._update_falling_trees(FallingTree.FALL_SECONDS)
	assert_eq(_view._objects.get_cell_source_id(trunk_tile), -1, "hidden while it settles")
	_view._update_falling_trees(FallingTree.SETTLE_SECONDS)
	assert_ne(_view._objects.get_cell_source_id(trunk_tile), -1, "drawn")
	assert_true(_view._falling_trees.is_empty())


func test_the_tree_accelerates_and_ends_lying_down() -> void:
	var early := FallingTree.angle_at(FallingTree.FALL_SECONDS * 0.25)
	var middle := FallingTree.angle_at(FallingTree.FALL_SECONDS * 0.5)
	var late := FallingTree.angle_at(FallingTree.FALL_SECONDS * 0.75)
	assert_gt(late - middle, middle - early, "faster and faster")
	assert_almost_eq(FallingTree.angle_at(FallingTree.FALL_SECONDS), FallingTree.LYING_ANGLE, 0.001)
	assert_almost_eq(
		FallingTree.angle_at(FallingTree.TOTAL_SECONDS), FallingTree.LYING_ANGLE, 0.001
	)
	var rebound := FallingTree.angle_at(FallingTree.FALL_SECONDS + FallingTree.SETTLE_SECONDS / 2)
	assert_lt(rebound, FallingTree.LYING_ANGLE, "bounces back a little")


func test_landing_bursts_leaves_shakes_the_stump_and_says_so() -> void:
	_show_views()
	var landed: Array[WorldObject] = []
	_view.tree_landed.connect(landed.append)
	_fell_oak_from(Vector2i.LEFT)
	assert_eq(_view._hit_particles.particle_count(), 0, "nothing flies off before it lands")
	_view._update_falling_trees(FallingTree.FALL_SECONDS - 0.01)
	assert_true(landed.is_empty())
	_view._update_falling_trees(0.02)
	assert_eq(landed.size(), 1)
	assert_eq(landed[0].type, WorldObjectTypes.OAK)
	assert_gt(_view._hit_particles.particle_count(), 0)
	assert_false(_view._object_sprites[_tile].is_plain(), "the stump shakes")


func test_unloading_the_chunk_cancels_the_fall() -> void:
	_show_views()
	_fell_oak_from(Vector2i.LEFT)
	var fall: FallingTree = _view._falling_trees[0]
	_view._unload_chunk(Chunk.world_to_chunk(_tile))
	assert_true(_view._falling_trees.is_empty())
	assert_true(_view._hidden_trunks.is_empty())
	assert_true(fall.is_queued_for_deletion())
	_view._update_falling_trees(1.0)


# --- The hops ---


func test_dropped_piles_hop_from_the_middle_of_the_source_tile_to_where_they_lie() -> void:
	_show_views()
	_world.drop_items(_tile, {ItemTypes.STONE: 3})
	var piles := _world.ground_items()
	assert_eq(piles.size(), _items._hops.size())
	var tile_size := TerrainTileset.TILE_SIZE
	for pile in piles:
		var hop: ItemHop = _items._hops[pile]
		assert_eq(hop.ground_position(), (Vector2(_tile) + Vector2(0.5, 0.5)) * tile_size)
		hop.elapsed = hop.delay + ItemHop.SECONDS
		assert_eq(hop.ground_position(), pile.position * tile_size)
		assert_eq(hop.lift(), 0.0)


func test_the_hop_rises_in_an_arc_and_bounces() -> void:
	var hop := ItemHop.new(Vector2i.ZERO, Vector2(40, 0), 0.0)
	var arc_seconds := ItemHop.SECONDS * (1.0 - ItemHop.BOUNCE_SHARE)
	hop.elapsed = arc_seconds / 2.0
	assert_almost_eq(hop.lift(), ItemHop.HEIGHT, 0.001)
	hop.elapsed = arc_seconds
	assert_almost_eq(hop.lift(), 0.0, 0.001)
	hop.elapsed = arc_seconds + ItemHop.SECONDS * ItemHop.BOUNCE_SHARE / 2.0
	assert_almost_eq(hop.lift(), ItemHop.BOUNCE_HEIGHT, 0.001)
	assert_between(ItemHop.SECONDS, 0.35, 0.5)


func test_several_piles_hop_one_after_the_other() -> void:
	_show_views()
	_world.drop_items(_tile, {ItemTypes.STONE: 3, ItemTypes.CLAY: 3})
	var delays: Array[float] = []
	for pile in _world.ground_items():
		delays.append(_items._hops[pile].delay)
	assert_gt(delays.size(), 1)
	for index in delays.size():
		assert_almost_eq(delays[index], index * GroundItemView.STAGGER_SECONDS, 0.0001)
	assert_between(GroundItemView.STAGGER_SECONDS, 0.04, 0.06)


func test_a_waiting_pile_is_not_shown_yet() -> void:
	_show_views()
	_world.drop_items(_tile, {ItemTypes.STONE: 3, ItemTypes.CLAY: 3})
	var piles := _world.ground_items()
	assert_true(_items._sprites[piles[0]].visible)
	assert_false(_items._sprites[piles[-1]].visible)
	_items._process(1.0)
	assert_true(_items._sprites[piles[-1]].visible)
	assert_true(_items._hops.is_empty(), "the hops are over")


func test_items_that_were_on_the_ground_appear_without_a_hop() -> void:
	_world.add_ground_item(GroundItem.new(ItemTypes.STONE, 1, Vector2(_tile) + Vector2(0.5, 0.5)))
	_show_views()
	assert_true(_items._hops.is_empty())
	_world.add_ground_item(GroundItem.new(ItemTypes.STONE, 1, Vector2(_tile) + Vector2(0.5, 0.5)))
	assert_true(_items._hops.is_empty(), "placed, not dropped")


func test_collecting_a_pile_mid_hop_works_and_ends_its_hop() -> void:
	_show_views()
	_world.drop_items(_tile, {ItemTypes.STONE: 1})
	var pile := _world.ground_items()[0]
	# A dropped pile normally waits out its hop; the view must still cope if it goes early.
	pile.settle_seconds = 0.0
	_state.player.position = pile.position
	_state.collect_ground_items(0.1)
	assert_true(_world.ground_items().is_empty(), "the state has collected it")
	assert_true(_items._hops.is_empty())
	assert_true(_items._sprites.is_empty())


func test_a_pile_pulled_mid_hop_stops_hopping() -> void:
	_show_views()
	_world.drop_items(_tile, {ItemTypes.STONE: 1})
	var pile := _world.ground_items()[0]
	pile.position += Vector2(0.1, 0.0)
	_items._process(0.0)
	assert_true(_items._hops.is_empty())
	assert_eq(_items._sprites[pile].position, (pile.position * TerrainTileset.TILE_SIZE).round())


func test_the_seed_of_a_felled_tree_waits_for_the_landing() -> void:
	_show_views()
	_view.tree_felled.connect(_items.hold_hops_from)
	_world.drop_items(_tile, {ItemTypes.ACORN: 1})
	_view.tree_felled.emit(_tile, FallingTree.FALL_SECONDS)
	var hop: ItemHop = _items._hops[_world.ground_items()[0]]
	assert_almost_eq(hop.delay, FallingTree.FALL_SECONDS, 0.0001)
	assert_false(_items._sprites[_world.ground_items()[0]].visible)
