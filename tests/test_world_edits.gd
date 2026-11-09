extends GutTest
## Edits live outside the chunks, so they survive a chunk being unloaded and generated again.

const SEED := 42
## A chunk by the river with trees on it.
const COORDS := Vector2i(0, -1)

var _world: World
var _generator := WorldGenerator.new(SEED)


func before_each() -> void:
	_world = World.new(SEED)
	_world.add_chunk(_generator.generate_chunk(COORDS))


func _reload() -> void:
	_world.remove_chunk(COORDS)
	_world.add_chunk(_generator.generate_chunk(COORDS))


func _generated_tree() -> WorldObject:
	for object in _world.chunk_at(COORDS).objects():
		if object.type == WorldObjectTypes.OAK:
			return object
	fail_test("no tree in the chunk")
	return null


func _free_tile() -> Vector2i:
	var origin := Chunk.to_world(COORDS, Vector2i.ZERO)
	for i in Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE:
		var pos := origin + Vector2i(i % Chunk.CHUNK_SIZE, i / Chunk.CHUNK_SIZE)
		if _world.is_buildable(pos):
			return pos
	fail_test("no free tile in the chunk")
	return origin


func test_an_added_object_comes_back_after_a_reload_with_its_state() -> void:
	var camp := WorldObject.new(WorldObjectTypes.FIREPLACE, _free_tile())
	camp.state["fuel"] = 3
	_world.add_object(camp)
	_reload()
	assert_same(_world.object_at(camp.pos), camp)
	assert_eq(_world.object_at(camp.pos).state["fuel"], 3)


func test_a_removed_generated_object_stays_gone_after_a_reload() -> void:
	var tree := _generated_tree()
	_world.remove_object(tree.pos)
	_reload()
	assert_null(_world.object_at(tree.pos))


func test_an_object_replacing_a_generated_one_wins_after_a_reload() -> void:
	var tree := _generated_tree()
	_world.remove_object(tree.pos)
	var stone := WorldObject.new(WorldObjectTypes.STONE, tree.pos)
	_world.add_object(stone)
	_reload()
	assert_same(_world.object_at(tree.pos), stone)


func test_replaying_edits_does_not_emit() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.FIREPLACE, _free_tile()))
	watch_signals(_world)
	_reload()
	assert_signal_not_emitted(_world, "objects_changed")


func test_edits_do_not_leak_into_other_chunks() -> void:
	var tree := _generated_tree()
	_world.remove_object(tree.pos)
	var other := Vector2i(-3, -2)
	_world.add_chunk(_generator.generate_chunk(other))
	assert_eq(
		_world.chunk_at(other).objects().size(), _generator.generate_chunk(other).objects().size()
	)


func test_edits_made_in_an_unloaded_chunk_are_replayed_when_it_loads_after_a_save() -> void:
	var near_tree := _generated_tree()
	_world.remove_object(near_tree.pos)
	var tilled := _free_tile()
	_world.set_terrain(tilled, Tile.Terrain.SOIL)
	var restored := World.from_dict(_world.to_dict(), GameClock.new())
	assert_eq(restored.tilled_tiles_in_chunk(COORDS), [tilled] as Array[Vector2i])
	assert_eq(restored.tilled_tiles_in_chunk(Vector2i(-3, -2)).size(), 0)
	restored.add_chunk(_generator.generate_chunk(COORDS))
	assert_null(restored.object_at(near_tree.pos))
	assert_eq(restored.tile_at(tilled).terrain, Tile.Terrain.SOIL)


func test_tilled_tiles_of_a_chunk_leave_out_what_was_grassed_over() -> void:
	var tilled := _free_tile()
	_world.set_terrain(tilled, Tile.Terrain.SOIL)
	_world.set_terrain(tilled + Vector2i.RIGHT, Tile.Terrain.SOIL)
	_world.set_terrain(tilled, Tile.Terrain.GRASS)
	assert_eq(_world.tilled_tiles_in_chunk(COORDS), [tilled + Vector2i.RIGHT] as Array[Vector2i])
	assert_eq(_world.tilled_tiles(), _world.tilled_tiles_in_chunk(COORDS))


func test_edits_in_other_chunks_do_not_change_what_a_chunk_replays() -> void:
	var tree := _generated_tree()
	_world.remove_object(tree.pos)
	var other := Vector2i(-3, -2)
	_world.add_chunk(_generator.generate_chunk(other))
	var elsewhere := Chunk.to_world(other, Vector2i(3, 3))
	_world.set_terrain(elsewhere, Tile.Terrain.SOIL)
	_reload()
	assert_null(_world.object_at(tree.pos))
	assert_eq(_world.tilled_tiles_in_chunk(COORDS).size(), 0)
	assert_eq(_world.tilled_tiles_in_chunk(other), [elsewhere] as Array[Vector2i])


func test_an_object_edited_twice_is_replayed_once_as_the_latest() -> void:
	var tree := _generated_tree()
	_world.remove_object(tree.pos)
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, tree.pos))
	_world.remove_object(tree.pos)
	var stone := WorldObject.new(WorldObjectTypes.STONE, tree.pos)
	_world.add_object(stone)
	_reload()
	assert_same(_world.object_at(tree.pos), stone)
