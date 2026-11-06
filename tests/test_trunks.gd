extends ResourceCase
## The trunk a felled tree leaves: where it lies (see TrunkPlacement), that it blocks walking and
## is cut up into logs, and that it is saved.

const OAK_HITS := 5


func before_each() -> void:
	super.before_each()
	_make_room()


## Fells an oak on the tile, from the tile `side` of it (the player stands there).
func _fell_oak_from(side: Vector2i) -> void:
	_state.player.position = Vector2(_tile + side) + Vector2(0.5, 0.5)
	_state.player.facing = -side
	_place(WorldObjectTypes.OAK)
	_hit(ItemTypes.AXE, OAK_HITS)


func _type_at(offset: Vector2i) -> StringName:
	var object := _world.object_at(_tile + offset)
	return &"" if object == null else object.type


# --- Where it lies ---


func test_felling_leaves_a_stump_and_a_trunk_of_the_species() -> void:
	for tree: StringName in [
		WorldObjectTypes.OAK, WorldObjectTypes.SPRUCE, WorldObjectTypes.DEAD_TREE
	]:
		_world.remove_object(_tile)
		_world.remove_object(_tile + Vector2i.RIGHT)
		_world.remove_object(_tile + Vector2i.RIGHT * 2)
		_place(tree)
		_hit(ItemTypes.AXE, int(WorldObjectTypes.TYPES[tree]["hp"]))
		var stump: StringName = WorldObjectTypes.TYPES[tree]["leaves"]
		assert_eq(_type_at(Vector2i.ZERO), stump, tree)
		assert_eq(_type_at(Vector2i.RIGHT), WorldObjectTypes.trunk_type(tree, false), tree)


func test_the_trunk_lies_away_from_a_player_on_the_left() -> void:
	_fell_oak_from(Vector2i.LEFT)
	assert_eq(_world.object_at(_tile + Vector2i.RIGHT), _world.object_at(_tile + Vector2i(2, 0)))
	assert_eq(_type_at(Vector2i.RIGHT), &"oak_trunk")
	assert_eq(_type_at(Vector2i.LEFT), &"")


func test_the_trunk_lies_away_from_a_player_on_the_right() -> void:
	_fell_oak_from(Vector2i.RIGHT)
	assert_eq(_world.object_at(_tile + Vector2i.LEFT), _world.object_at(_tile + Vector2i(-2, 0)))
	assert_eq(_type_at(Vector2i.LEFT), &"oak_trunk")
	assert_eq(_type_at(Vector2i.RIGHT), &"")


func test_the_trunk_lies_to_the_right_of_a_player_above_or_below() -> void:
	_fell_oak_from(Vector2i.UP)
	assert_eq(_type_at(Vector2i.RIGHT), &"oak_trunk")
	_world.remove_object(_tile)
	_world.remove_object(_tile + Vector2i.RIGHT)
	_fell_oak_from(Vector2i.DOWN)
	assert_eq(_type_at(Vector2i.RIGHT), &"oak_trunk")


func test_a_trunk_that_has_no_room_to_the_right_lies_to_the_left() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _tile + Vector2i(2, 0)))
	_fell_oak_from(Vector2i.UP)
	assert_eq(_type_at(Vector2i.LEFT), &"oak_trunk")
	assert_eq(_type_at(Vector2i.RIGHT), &"")


func test_with_no_room_for_a_long_trunk_a_short_one_lies_on_a_free_neighbour() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _tile + Vector2i.RIGHT))
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _tile + Vector2i.LEFT))
	_fell_oak_from(Vector2i.UP)
	assert_eq(_type_at(Vector2i.DOWN), &"oak_short_trunk")
	assert_eq(_world.object_at(_tile + Vector2i.DOWN).tiles().size(), 1)


func test_a_trunk_is_not_laid_on_the_player_or_where_nothing_is_free() -> void:
	for side in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN]:
		_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _tile + side))
	_fell_oak_from(Vector2i.UP)
	assert_eq(_type_at(Vector2i.ZERO), WorldObjectTypes.STUMP)
	assert_eq(_type_at(Vector2i.UP), &"", "the player's tile stays free")


# --- What it is ---


func test_a_trunk_blocks_walking_and_wants_the_axe_level_of_its_tree() -> void:
	_fell_oak_from(Vector2i.LEFT)
	assert_false(_world.is_walkable(_tile + Vector2i.RIGHT))
	assert_false(_world.is_walkable(_tile + Vector2i(2, 0)))
	var pine_trunk: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.trunk_type(
		WorldObjectTypes.PINE, false
	)]
	assert_eq(pine_trunk["harvest_level"], 2)
	assert_eq(pine_trunk["tool"], &"axe")


# --- Logs ---


func test_the_trunks_drop_most_of_the_logs_of_their_tree() -> void:
	var expected := {
		WorldObjectTypes.OAK: 3,
		WorldObjectTypes.SPRUCE: 3,
		WorldObjectTypes.PINE: 4,
		WorldObjectTypes.DEAD_TREE: 2,
		WorldObjectTypes.BEECH: 3,
		WorldObjectTypes.BIRCH: 2,
		WorldObjectTypes.ALDER: 2,
	}
	for tree: StringName in expected:
		for is_short in [false, true]:
			var drops: Dictionary = (
				WorldObjectTypes.TYPES[WorldObjectTypes.trunk_type(tree, is_short)]["drops"]
			)
			assert_eq(drops, {&"logs": expected[tree]}, tree)


func test_cutting_up_a_trunk_drops_its_logs_and_removes_it() -> void:
	_fell_oak_from(Vector2i.LEFT)
	_clear_ground()
	_state.player.position = Vector2(_tile + Vector2i(1, -1)) + Vector2(0.5, 0.5)
	_state.player.facing = Vector2i.DOWN
	var trunk_hp: int = WorldObjectTypes.TYPES[&"oak_trunk"]["hp"]
	_hit(ItemTypes.AXE, trunk_hp - 1)
	assert_eq(_type_at(Vector2i.RIGHT), &"oak_trunk", "still lying")
	_hit(ItemTypes.AXE, 1)
	assert_eq(_type_at(Vector2i.RIGHT), &"")
	assert_eq(_type_at(Vector2i(2, 0)), &"", "both tiles are free again")
	assert_eq(_dropped(ItemTypes.LOGS), 3)


func test_the_stump_gives_one_log() -> void:
	_fell_oak_from(Vector2i.LEFT)
	_clear_ground()
	_hit(ItemTypes.AXE, 2)
	assert_eq(_type_at(Vector2i.ZERO), &"")
	assert_eq(_dropped(ItemTypes.LOGS), 1)


# --- Saving ---


func test_a_trunk_and_its_stump_survive_the_save_and_the_chunk() -> void:
	_fell_oak_from(Vector2i.LEFT)
	_reload_chunk()
	assert_eq(_type_at(Vector2i.RIGHT), &"oak_trunk")
	var restored := _through_save()
	assert_eq(restored.world.object_at(_tile).type, WorldObjectTypes.STUMP)
	assert_eq(restored.world.object_at(_tile + Vector2i(2, 0)).type, &"oak_trunk")
	assert_eq(restored.world.object_at(_tile + Vector2i(2, 0)).pos, _tile + Vector2i.RIGHT)
