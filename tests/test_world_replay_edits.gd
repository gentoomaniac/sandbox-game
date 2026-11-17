extends GutTest
## `World.replay_edits` puts the edits on any chunk, loaded or not, and `edited` tells in which
## chunk an edit was made.

const SEED := 42
## A chunk with trees on it.
const COORDS := Vector2i(0, -2)

var _world: World
var _generator := WorldGenerator.new(SEED)
var _edited_chunks: Array[Vector2i] = []


func before_each() -> void:
	_edited_chunks = []
	_world = World.new(SEED)
	_world.add_chunk(_generator.generate_chunk(COORDS))
	_world.edited.connect(_edited_chunks.append)


func _tree() -> WorldObject:
	for object in _world.chunk_at(COORDS).objects():
		if object.type == WorldObjectTypes.OAK:
			return object
	fail_test("no tree in the chunk")
	return null


func test_the_edits_are_replayed_on_a_chunk_that_is_not_loaded() -> void:
	var tree := _tree()
	_world.take_off(tree)
	_world.set_terrain(tree.pos, Tile.Terrain.SOIL)
	var fresh := _generator.generate_chunk(COORDS)
	assert_not_null(fresh.object_at(Chunk.local_pos(tree.pos)))
	_world.replay_edits(fresh)
	assert_null(fresh.object_at(Chunk.local_pos(tree.pos)))
	assert_eq(fresh.terrain_at(Chunk.local_pos(tree.pos)), Tile.Terrain.SOIL)
	assert_eq(_world.loaded_chunk_coords(), [COORDS] as Array[Vector2i], "nothing was loaded")


func test_a_copy_of_a_chunk_changes_on_its_own() -> void:
	var tree := _tree()
	var copy := _world.chunk_at(COORDS).copy()
	copy.remove_object(Chunk.local_pos(tree.pos))
	copy.set_terrain(Chunk.local_pos(tree.pos), Tile.Terrain.WATER)
	assert_same(_world.chunk_at(COORDS).object_at(Chunk.local_pos(tree.pos)), tree)
	assert_ne(_world.chunk_at(COORDS).terrain_at(Chunk.local_pos(tree.pos)), Tile.Terrain.WATER)


func test_an_object_edit_tells_the_chunk_of_its_origin() -> void:
	var tree := _tree()
	_world.take_off(tree)
	assert_eq(_edited_chunks, [COORDS] as Array[Vector2i])


func test_a_terrain_edit_tells_its_chunk() -> void:
	_world.set_terrain(_tree().pos, Tile.Terrain.SOIL)
	assert_true(_edited_chunks.has(COORDS))


func test_an_edit_in_a_chunk_that_is_not_loaded_tells_too() -> void:
	var pos := Chunk.to_world(Vector2i(3, 3), Vector2i(5, 5))
	_world.replace_object(
		WorldObject.new(WorldObjectTypes.STONE, pos), WorldObject.new(WorldObjectTypes.STONE, pos)
	)
	assert_eq(_edited_chunks, [Vector2i(3, 3)] as Array[Vector2i])


func test_loading_a_chunk_is_no_edit() -> void:
	_world.add_chunk(_generator.generate_chunk(Vector2i(1, -2)))
	assert_eq(_edited_chunks, [] as Array[Vector2i])


func test_a_replayed_wide_object_clears_the_generated_object_under_its_other_tile() -> void:
	var tree := _tree()
	var trunk := WorldObject.new(&"oak_trunk", tree.pos + Vector2i.LEFT)
	assert_eq(trunk.tiles(), [trunk.pos, tree.pos] as Array[Vector2i], "covers the tree's tile")
	_world.replace_object(trunk, trunk)
	var fresh := _generator.generate_chunk(COORDS)
	_world.replay_edits(fresh)
	assert_same(fresh.object_at(Chunk.local_pos(trunk.pos)), trunk)
	assert_null(fresh.object_at(Chunk.local_pos(tree.pos)), "the tree is not left overlapping")


func test_a_replayed_snapshot_of_a_wide_object_clears_the_same_way() -> void:
	var tree := _tree()
	var trunk := WorldObject.new(&"oak_trunk", tree.pos + Vector2i.LEFT)
	_world.replace_object(trunk, trunk)
	var fresh := _generator.generate_chunk(COORDS)
	WorldEdits.replay_snapshot(fresh, _world.edits_snapshot(COORDS))
	assert_eq(fresh.object_at(Chunk.local_pos(trunk.pos)).type, trunk.type)
	assert_null(fresh.object_at(Chunk.local_pos(tree.pos)))


func test_a_wide_object_reaching_into_the_next_chunk_leaves_that_chunks_own_tiles_to_it() -> void:
	var edge := Chunk.to_world(COORDS, Vector2i(Chunk.CHUNK_SIZE - 1, 3))
	var trunk := WorldObject.new(&"oak_trunk", edge)
	_world.replace_object(trunk, trunk)
	var fresh := _generator.generate_chunk(COORDS)
	_world.replay_edits(fresh)
	assert_same(fresh.object_at(Chunk.local_pos(edge)), trunk)
