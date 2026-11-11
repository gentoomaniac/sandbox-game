extends ResourceCase
## Leaves that drop and blow from the trees around the player (view only): how many may be in the
## air, which way the wind carries them, and that the world view lets trees near the player shed
## in autumn wind and not in calm.

const KINDS := HitEffect.Kind
const LOOKS := SeasonBlend.Look
const AUTUMN := 75
const CANOPY := Vector2(100.0, 100.0)
const EAST_GALE := Vector2(14.0, 0.0)

var _leaves: FallingLeaves


## Rules in which every offered tree sheds, and a leaf is carried off or not as asked.
func _sure_rules(carried_chance: float) -> LeafFallRules:
	var values := DataFile.read_sections(LeafFallRules.DEFAULT_PATH)
	values["shedding"]["shed_chance"] = 10.0
	values["carried"]["chance"] = carried_chance
	return LeafFallRules.new(values)


func _shed_autumn_leaf(wind: Vector2) -> void:
	_leaves.shed(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, CANOPY, wind, 0.0)


func _show_world_in_view() -> WorldView:
	var view := WorldView.new()
	add_child_autofree(view)
	var residency := ChunkResidency.new(_world)
	view.show_world(residency)
	residency.load_chunk(Chunk.world_to_chunk(_tile))
	view.finish_drawing()
	return view


## A view that looks at the tile of the tree and no other, so that it is picked every time.
func _view_watching_the_tree(wind: Vector2) -> WorldView:
	_place(WorldObjectTypes.OAK)
	_state.clock.day = AUTUMN
	var view := _show_world_in_view()
	var values := DataFile.read_sections(LeafFallRules.DEFAULT_PATH)
	values["shedding"]["tries_per_second"] = 100.0
	values["shedding"]["radius_tiles"] = Vector2.ZERO
	view._falling_leaves.rules = LeafFallRules.new(values)
	view.player_feet = TerrainTileset.tile_centre(_tile)
	view.ambient_motion.wind = wind
	return view


func before_each() -> void:
	super.before_each()
	_leaves = autofree(FallingLeaves.new())


func test_no_more_leaves_than_the_cap_are_in_the_air() -> void:
	_leaves.rules = _sure_rules(0.5)
	var cap := int(_leaves.rules.value("shedding", "max_leaves"))
	for _i in cap * 3:
		_shed_autumn_leaf(EAST_GALE)
	assert_eq(_leaves.leaf_count(), cap)


func test_a_tree_sheds_again_once_leaves_have_landed() -> void:
	_leaves.rules = _sure_rules(0.5)
	var cap := int(_leaves.rules.value("shedding", "max_leaves"))
	for _i in cap:
		_shed_autumn_leaf(EAST_GALE)
	_leaves._leaves.advance(10.0)
	assert_eq(_leaves.leaf_count(), 0)
	_shed_autumn_leaf(EAST_GALE)
	assert_eq(_leaves.leaf_count(), 1)


func test_no_leaf_falls_in_calm() -> void:
	_leaves.rules = _sure_rules(1.0)
	for _i in 50:
		_shed_autumn_leaf(Vector2.ZERO)
	assert_eq(_leaves.leaf_count(), 0)


func test_a_bare_tree_sheds_none_in_a_gale() -> void:
	_leaves.rules = _sure_rules(1.0)
	for _i in 50:
		_leaves.shed(KINDS.NONE, LOOKS.BARE, AUTUMN, CANOPY, EAST_GALE, 0.0)
	assert_eq(_leaves.leaf_count(), 0)


func test_leaves_carried_by_the_wind_drift_downwind_either_way() -> void:
	_leaves.rules = _sure_rules(1.0)
	for wind in [EAST_GALE, -EAST_GALE, Vector2(0.0, 12.0)]:
		for _i in 5:
			_shed_autumn_leaf(wind)
		for leaf: HitParticles.Particle in _leaves._leaves._particles:
			assert_eq(signf(leaf.velocity.x), signf(wind.x), "drift along x in wind %s" % wind)
			assert_gt(leaf.velocity.y, 0.0, "still falls")
			assert_gt(
				leaf.velocity.dot(wind.normalized()), 0.0, "blown the way the wind goes %s" % wind
			)
		_leaves._leaves.advance(10.0)


func test_a_carried_leaf_ends_much_further_downwind_than_a_dropped_one() -> void:
	_leaves.rules = _sure_rules(1.0)
	_shed_autumn_leaf(EAST_GALE)
	var carried: HitParticles.Particle = _leaves._leaves._particles[0]
	carried.age = carried.life
	var carried_travel := carried.position_now().x - carried.start.x
	_leaves._leaves.advance(10.0)
	_leaves.rules = _sure_rules(0.0)
	_shed_autumn_leaf(EAST_GALE)
	var dropped: HitParticles.Particle = _leaves._leaves._particles[0]
	dropped.age = dropped.life
	var dropped_travel := dropped.position_now().x - dropped.start.x
	assert_gt(carried_travel, 100.0, "carried a few tiles")
	assert_lt(absf(dropped_travel), 25.0, "dropped beside the tree")


func test_picks_follow_the_time_and_stay_around_the_player() -> void:
	var rate: float = _leaves.rules.value("shedding", "tries_per_second")
	var reach: Vector2 = _leaves.rules.vector("shedding", "radius_tiles")
	var centre := Vector2i(50, -20)
	var tiles := _leaves.tiles_to_look_at(2.0, centre)
	assert_eq(tiles.size(), int(rate * 2.0))
	for tile in tiles:
		var offset := (tile - centre).abs()
		assert_true(offset.x <= reach.x and offset.y <= reach.y, "tile %s" % tile)


func test_the_picks_owed_carry_over_from_frame_to_frame() -> void:
	var rate: float = _leaves.rules.value("shedding", "tries_per_second")
	var frames := 100
	var total := 0
	for _i in frames:
		total += _leaves.tiles_to_look_at(1.0 / rate / 4.0, Vector2i.ZERO).size()
	assert_eq(total, frames / 4)


func test_leaves_in_the_air_are_gone_when_the_world_is_shown_again_after_indoors() -> void:
	add_child(_leaves)
	_leaves.rules = _sure_rules(1.0)
	_shed_autumn_leaf(EAST_GALE)
	_leaves.hide()
	assert_eq(_leaves.leaf_count(), 1, "still there while hidden")
	_leaves.show()
	assert_eq(_leaves.leaf_count(), 0)


func test_the_world_view_lets_a_tree_by_the_player_shed_in_autumn_wind() -> void:
	var view := _view_watching_the_tree(EAST_GALE)
	view._shed_leaves(1.0)
	assert_gt(view._falling_leaves.leaf_count(), 0)


func test_the_world_view_sheds_nothing_in_calm() -> void:
	var view := _view_watching_the_tree(Vector2.ZERO)
	view._shed_leaves(1.0)
	assert_eq(view._falling_leaves.leaf_count(), 0)


func test_the_world_view_sheds_nothing_from_a_tree_out_of_the_picked_tiles() -> void:
	var view := _view_watching_the_tree(EAST_GALE)
	view.player_feet = TerrainTileset.tile_centre(_tile + Vector2i(30, 0))
	view._shed_leaves(1.0)
	assert_eq(view._falling_leaves.leaf_count(), 0)
