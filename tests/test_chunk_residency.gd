extends GutTest
## ChunkResidency: which chunks a world has loaded, with no renderer in sight.

const SEED := 1
const HOME := Vector2i(0, 0)

var _world: World
var _residency: ChunkResidency


func before_each() -> void:
	_world = World.new(SEED)
	_residency = ChunkResidency.new(_world)


func test_an_update_loads_one_chunk_at_the_focus_first() -> void:
	_residency.set_focus(Chunk.to_world(HOME, Vector2i.ZERO))
	_residency.update()
	assert_eq(_world.loaded_chunk_coords(), [HOME] as Array[Vector2i])
	_residency.update()
	assert_eq(_world.loaded_chunk_coords().size(), 2)


func test_an_update_that_may_not_load_loads_nothing() -> void:
	_residency.update(false)
	assert_eq(_world.loaded_chunk_coords().size(), 0)
	assert_false(_residency.is_complete)


func test_the_chunks_around_the_focus_load_until_it_is_complete() -> void:
	_residency.set_focus(Chunk.to_world(HOME, Vector2i.ZERO))
	var side := ChunkResidency.LOAD_RADIUS * 2 + 1
	for i in side * side:
		_residency.update()
	assert_false(_residency.is_complete, "the last chunk was loaded in the last update")
	_residency.update()
	assert_true(_residency.is_complete)
	assert_eq(_world.loaded_chunk_coords().size(), side * side)


func test_a_chunk_beyond_the_unload_radius_is_dropped() -> void:
	var far := Vector2i(ChunkResidency.UNLOAD_RADIUS + 1, 0)
	_residency.load_chunk(far)
	_residency.update(false)
	assert_false(_world.is_chunk_loaded(far))


func test_listeners_hear_of_the_chunks_loaded_and_unloaded() -> void:
	var loaded: Array[Vector2i] = []
	var unloaded: Array[Vector2i] = []
	_residency.chunk_loaded.connect(func(chunk: Chunk) -> void: loaded.append(chunk.coords))
	_residency.chunk_unloaded.connect(func(chunk: Chunk) -> void: unloaded.append(chunk.coords))
	_residency.load_chunk(HOME)
	assert_eq(loaded, [HOME] as Array[Vector2i])
	_residency.unload_chunk(HOME)
	assert_eq(unloaded, [HOME] as Array[Vector2i])
	assert_false(_world.is_chunk_loaded(HOME), "the chunk is gone when the listener hears of it")
