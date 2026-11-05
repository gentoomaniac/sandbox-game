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
