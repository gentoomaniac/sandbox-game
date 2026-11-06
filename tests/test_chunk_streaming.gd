extends GutTest
## ChunkStreaming: which chunks load around a focus and when they unload again.

const HALF := World.MAX_SIZE_CHUNKS / 2


func _plan(focus: Vector2i, loaded: Array[Vector2i] = []) -> Dictionary:
	return ChunkStreaming.plan(focus, loaded, 2, 4)


func test_loads_square_around_focus() -> void:
	var plan := _plan(Vector2i(3, -2))
	assert_eq(plan["load"].size(), 25)
	assert_true(Vector2i(1, -4) in plan["load"])
	assert_true(Vector2i(5, 0) in plan["load"])
	assert_false(Vector2i(6, 0) in plan["load"])
	assert_eq(plan["unload"].size(), 0)


func test_load_is_nearest_first() -> void:
	var plan := _plan(Vector2i.ZERO)
	assert_eq(plan["load"][0], Vector2i.ZERO)
	var distances: Array = plan["load"].map(func(c: Vector2i) -> int: return c.length_squared())
	var sorted := distances.duplicate()
	sorted.sort()
	assert_eq(distances, sorted)


func test_loaded_chunks_are_not_loaded_again() -> void:
	var plan := _plan(Vector2i.ZERO, [Vector2i(0, 0), Vector2i(1, 1)])
	assert_eq(plan["load"].size(), 23)
	assert_false(Vector2i(0, 0) in plan["load"])


func test_unload_hysteresis() -> void:
	var loaded: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(0, -5)]
	var plan := _plan(Vector2i.ZERO, loaded)
	# Beyond the load radius but within the unload radius: kept.
	assert_false(Vector2i(3, 0) in plan["unload"])
	assert_false(Vector2i(4, 0) in plan["unload"])
	assert_true(Vector2i(5, 0) in plan["unload"])
	assert_true(Vector2i(0, -5) in plan["unload"])


func test_respects_world_bounds() -> void:
	var plan := _plan(Vector2i(-HALF, HALF - 1))
	assert_eq(plan["load"].size(), 9)
	for coords: Vector2i in plan["load"]:
		assert_true(World.is_chunk_in_bounds(coords), "%s" % coords)


func test_negative_focus() -> void:
	var plan := _plan(Vector2i(-10, -10), [Vector2i(-10, -5)])
	assert_eq(plan["load"].size(), 25)
	assert_true(Vector2i(-12, -12) in plan["load"])
	assert_true(Vector2i(-10, -5) in plan["unload"])
