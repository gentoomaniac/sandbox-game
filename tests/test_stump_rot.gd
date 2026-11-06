extends ResourceCase
## Stumps rot away and may leave a sapling of their tree, and a sapling grows into the tree of
## its species.

const ROT_DAYS := 14
const SAPLING_GROWTH_DAYS := 4
## The trees that grow from a seed.
const TREES: Array[StringName] = [
	WorldObjectTypes.OAK, WorldObjectTypes.SPRUCE, WorldObjectTypes.PINE, WorldObjectTypes.BEECH
]


func _stump_of(tree: StringName) -> WorldObject:
	var stump := _place(WorldObjectTypes.STUMP)
	if tree != &"":
		stump.state["tree"] = str(tree)
	return stump


## How many of the days 1 to `days` a stump on the tile would leave a sapling on.
func _saplings_over(stump: WorldObject, days: int) -> int:
	var saplings := 0
	for day in range(1, days + 1):
		if stump.rotted(day) != null:
			saplings += 1
	return saplings


# --- Rotting ---


func test_a_stump_is_still_there_the_day_before_it_has_rotted_and_gone_the_day_it_has() -> void:
	_stump_of(WorldObjectTypes.OAK)
	_sleep_days(ROT_DAYS - 1)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.STUMP)
	_sleep_days(1)
	var left := _world.object_at(_tile)
	assert_true(left == null or left.type == WorldObjectTypes.SAPLING)


func test_a_stump_never_becomes_a_tree_directly() -> void:
	_stump_of(WorldObjectTypes.OAK)
	for _day in ROT_DAYS * 2:
		_sleep_days(1)
		var left := _world.object_at(_tile)
		assert_true(left == null or left.type in [WorldObjectTypes.STUMP, WorldObjectTypes.SAPLING])


func test_the_sapling_roll_is_deterministic_and_about_thirty_percent() -> void:
	var stump := _stump_of(WorldObjectTypes.OAK)
	var first := _saplings_over(stump, 200)
	assert_eq(_saplings_over(stump, 200), first)
	assert_between(first, 40, 80)


func test_the_sapling_is_of_the_species_of_the_stump() -> void:
	for tree: StringName in TREES:
		var stump := WorldObject.new(WorldObjectTypes.STUMP, _tile)
		stump.state["tree"] = str(tree)
		var sapling: WorldObject = null
		var day := 1
		while sapling == null:
			sapling = stump.rotted(day)
			day += 1
		assert_eq(sapling.type, WorldObjectTypes.SAPLING)
		assert_eq(sapling.state["tree"], str(tree))
		assert_eq(sapling.pos, _tile)


func test_the_stump_of_a_dead_tree_rots_away_and_leaves_nothing() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.DEAD_TREE, _tile + Vector2i.RIGHT))
	var stump := _stump_of(&"")
	assert_eq(_saplings_over(stump, 200), 0)
	_sleep_days(ROT_DAYS)
	assert_null(_world.object_at(_tile))


func test_a_felled_dead_tree_leaves_a_dead_stump_that_never_becomes_a_sapling() -> void:
	_state.player.position = Vector2(_tile + Vector2i.LEFT) + Vector2(0.5, 0.5)
	_state.player.facing = Vector2i.RIGHT
	_place(WorldObjectTypes.DEAD_TREE)
	_hit(ItemTypes.AXE, WorldObjectTypes.TYPES[WorldObjectTypes.DEAD_TREE]["hp"])
	var stump := _world.object_at(_tile)
	assert_eq(stump.type, WorldObjectTypes.DEAD_STUMP)
	assert_eq(stump.state, {}, "nothing in it that implies regrowth")
	assert_eq(_saplings_over(stump, 500), 0)
	_sleep_days(ROT_DAYS)
	assert_null(_world.object_at(_tile))


func test_a_dead_stump_with_a_tree_in_its_state_still_leaves_no_sapling() -> void:
	var stump := WorldObject.new(WorldObjectTypes.DEAD_STUMP, _tile)
	stump.state["tree"] = str(WorldObjectTypes.OAK)
	assert_eq(_saplings_over(stump, 500), 0)


func test_a_dead_stump_is_like_a_stump_in_hits_drops_and_rot() -> void:
	var stump: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.STUMP]
	var dead_stump: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.DEAD_STUMP]
	for key: String in ["hp", "tool", "drops", "rots_after_days", "harvest_level"]:
		assert_eq(dead_stump[key], stump[key], key)
	assert_eq(dead_stump["hp"], 2)
	assert_eq(dead_stump["tool"], &"axe")
	assert_eq(dead_stump["drops"], {&"logs": 1})
	assert_eq(dead_stump["rots_after_days"], ROT_DAYS)
	assert_false(dead_stump.has("rots_into_sapling_chance"))
	assert_ne(dead_stump["atlas_row"], stump["atlas_row"])


func test_chopping_a_dead_stump_gives_a_log() -> void:
	_place(WorldObjectTypes.DEAD_STUMP)
	_hit(ItemTypes.AXE, 2)
	assert_null(_world.object_at(_tile))
	assert_eq(_dropped(ItemTypes.LOGS), 1)


func test_a_stump_rots_away_in_an_unloaded_chunk_without_rolling_again() -> void:
	var stump := _stump_of(&"")
	var coords := Chunk.world_to_chunk(_tile)
	_world.remove_chunk(coords)
	_sleep_days(ROT_DAYS + 20)
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	assert_null(_world.object_at(_tile))
	assert_eq(stump.type, WorldObjectTypes.STUMP)


func test_rotting_goes_on_in_unloaded_chunks_and_through_a_save() -> void:
	_stump_of(WorldObjectTypes.OAK)
	_sleep_days(ROT_DAYS - 2)
	var coords := Chunk.world_to_chunk(_tile)
	_world.remove_chunk(coords)
	var restored := _through_save()
	assert_eq(restored.world.object_at(_tile).type, WorldObjectTypes.STUMP)
	assert_eq(restored.world.object_at(_tile).days_grown(), ROT_DAYS - 2)
	restored.clock.advance(2 * GameClock.MINUTES_PER_DAY)
	var left := restored.world.object_at(_tile)
	assert_true(left == null or left.type == WorldObjectTypes.SAPLING)


# --- Saplings ---


func test_a_sapling_becomes_the_tree_of_its_species() -> void:
	for tree: StringName in TREES:
		_world.remove_object(_tile)
		_place(WorldObjectTypes.SAPLING, str(tree))
		_sleep_days(SAPLING_GROWTH_DAYS - 1)
		assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SAPLING)
		_sleep_days(1)
		assert_eq(_world.object_at(_tile).type, tree)
		assert_eq(_world.object_at(_tile).state, {})


func test_a_sapling_waits_a_day_while_the_player_stands_on_it() -> void:
	_place(WorldObjectTypes.SAPLING, "spruce")
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	_sleep_days(SAPLING_GROWTH_DAYS)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SAPLING)
	_state.player.position += Vector2(0, 2)
	_sleep_days(1)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SPRUCE)
