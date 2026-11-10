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
	_residency.update(_never)
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
	_residency.update(_never)
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


func test_a_held_residency_loads_and_drops_nothing() -> void:
	var far := Vector2i(ChunkResidency.UNLOAD_RADIUS + 1, 0)
	_residency.load_chunk(far)
	_residency.is_held = true
	_residency.update()
	assert_eq(_world.loaded_chunk_coords(), [far] as Array[Vector2i])
	_residency.is_held = false
	_residency.update()
	assert_false(_world.is_chunk_loaded(far))


func test_the_chunks_an_action_needs_load_at_once_without_a_view() -> void:
	var tiles: Array[Vector2i] = [Vector2i(5, 5), Vector2i(Chunk.CHUNK_SIZE + 1, 5)]
	_residency.require(tiles)
	assert_not_null(_world.tile_at(tiles[0]))
	assert_not_null(_world.tile_at(tiles[1]))
	assert_eq(_world.loaded_chunk_coords().size(), 2)
	_residency.require(tiles)
	assert_eq(_world.loaded_chunk_coords().size(), 2, "loaded chunks are not loaded again")


func test_a_tile_out_of_the_world_needs_no_chunk() -> void:
	var out_of_the_world: Array[Vector2i] = [
		Chunk.to_world(Vector2i(World.MAX_SIZE_CHUNKS, 0), Vector2i.ZERO)
	]
	_residency.require(out_of_the_world)
	assert_eq(_world.loaded_chunk_coords().size(), 0)


func test_a_view_that_goes_leaves_the_chunks_loaded_and_the_next_one_draws_them() -> void:
	var first: WorldView = add_child_autofree(WorldView.new())
	first.show_world(_residency)
	_residency.load_chunk(HOME)
	first.finish_drawing()
	first.free()
	_residency.update(_never)
	assert_true(_world.is_chunk_loaded(HOME), "the game still has its chunk")
	var second: WorldView = add_child_autofree(WorldView.new())
	second.show_world(_residency)
	assert_false(second.is_drawing(), "a chunk that is loaded is drawn when the view starts")
	assert_true(second._chunk_looks.has(HOME))


func test_a_chunk_required_while_another_is_drawn_is_drawn_after_it() -> void:
	var view: WorldView = add_child_autofree(WorldView.new())
	view.show_world(_residency)
	_residency.load_chunk(HOME)
	_residency.load_chunk(Vector2i(-1, -1))
	assert_true(view.is_drawing())
	view.finish_drawing()
	assert_false(view.is_drawing())
	assert_eq(view._chunk_looks.size(), 2, "both chunks are drawn")


## A renderer that can't take a chunk.
func _never() -> bool:
	return false
