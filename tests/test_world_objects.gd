extends GutTest

const SEED := 42
## Chunks around the river: they have grass with trees as well as water, floodplain and
## wetland.
const CHUNKS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, -1), Vector2i(-3, -2)]

var _world: World


func before_each() -> void:
	_world = World.new(SEED)


## Every object of the chunks as "x,y:type" strings, in position order.
func _describe(chunks: Array[Chunk]) -> Array[String]:
	var result: Array[String] = []
	for chunk in chunks:
		for object in chunk.objects():
			result.append("%s:%s" % [object.pos, object.type])
	result.sort()
	return result


func _generate(generator: WorldGenerator, coords: Array[Vector2i]) -> Array[Chunk]:
	var chunks: Array[Chunk] = []
	for chunk_coords in coords:
		chunks.append(generator.generate_chunk(chunk_coords))
	return chunks


func _load_chunk_at_origin() -> void:
	_world.add_chunk(Chunk.new(Vector2i.ZERO))


func test_generation_is_deterministic_and_independent_of_chunk_order() -> void:
	var forward := _describe(_generate(WorldGenerator.new(SEED), CHUNKS))
	var reversed_coords := CHUNKS.duplicate()
	reversed_coords.reverse()
	var backward := _describe(_generate(WorldGenerator.new(SEED), reversed_coords))
	assert_gt(forward.size(), 0, "the chunks have objects")
	assert_eq(forward, backward)


func test_both_object_types_are_generated() -> void:
	var types := {}
	for chunk in _generate(WorldGenerator.new(SEED), CHUNKS):
		for object in chunk.objects():
			types[object.type] = true
	assert_true(types.has(WorldObjectTypes.OAK))
	assert_true(types.has(WorldObjectTypes.STONE))


func test_objects_stand_only_on_grass() -> void:
	var terrains := {}
	for chunk in _generate(WorldGenerator.new(SEED), CHUNKS):
		for object in chunk.objects():
			var terrain := chunk.terrain_at(Chunk.local_pos(object.pos))
			terrains[terrain] = true
			assert_eq(Chunk.world_to_chunk(object.pos), chunk.coords)
	assert_eq(terrains.keys(), [Tile.Terrain.GRASS])


func test_no_objects_on_water_wetland_or_floodplain() -> void:
	var generator := WorldGenerator.new(SEED)
	var checked := {}
	for y in range(-64, 64):
		for x in range(-64, 64):
			var terrain := generator.terrain_at(Vector2i(x, y))
			if terrain != Tile.Terrain.GRASS:
				checked[terrain] = true
				assert_eq(generator.object_type_at(Vector2i(x, y), terrain), &"")
	assert_true(checked.has(Tile.Terrain.WATER))
	assert_true(checked.has(Tile.Terrain.FLOODPLAIN))
	assert_true(checked.has(Tile.Terrain.WETLAND))


func test_add_and_remove_object_changes_the_world_and_emits() -> void:
	_load_chunk_at_origin()
	var pos := Vector2i(3, 4)
	watch_signals(_world)
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, pos))
	assert_eq(_world.object_at(pos).type, WorldObjectTypes.OAK)
	assert_signal_emitted_with_parameters(_world, "objects_changed", [pos])

	var removed := _world.remove_object(pos)
	assert_eq(removed.type, WorldObjectTypes.OAK)
	assert_null(_world.object_at(pos))
	assert_signal_emit_count(_world, "objects_changed", 2)


func test_removing_nothing_does_not_emit() -> void:
	_load_chunk_at_origin()
	watch_signals(_world)
	assert_null(_world.remove_object(Vector2i(3, 4)))
	assert_signal_not_emitted(_world, "objects_changed")


func test_object_state_belongs_to_the_object() -> void:
	_load_chunk_at_origin()
	var tree := WorldObject.new(WorldObjectTypes.OAK, Vector2i(1, 1))
	tree.state["hits_left"] = 5
	_world.add_object(tree)
	assert_eq(_world.object_at(Vector2i(1, 1)).state["hits_left"], 5)


func test_blocking_object_makes_a_tile_unwalkable() -> void:
	_load_chunk_at_origin()
	var pos := Vector2i(3, 4)
	assert_true(_world.is_walkable(pos))
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, pos))
	assert_false(_world.is_walkable(pos))
	_world.remove_object(pos)
	assert_true(_world.is_walkable(pos))


func test_object_makes_a_tile_unbuildable_and_unplantable() -> void:
	_load_chunk_at_origin()
	var pos := Vector2i(3, 4)
	_world.chunk_at(Vector2i.ZERO).set_terrain(pos, Tile.Terrain.SOIL)
	assert_true(_world.is_buildable(pos))
	assert_true(_world.is_plantable(pos))
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, pos))
	assert_false(_world.is_buildable(pos))
	assert_false(_world.is_plantable(pos))


func test_combined_checks_still_follow_the_tile() -> void:
	_load_chunk_at_origin()
	var chunk := _world.chunk_at(Vector2i.ZERO)
	chunk.set_terrain(Vector2i(1, 1), Tile.Terrain.WATER)
	chunk.set_terrain(Vector2i(2, 2), Tile.Terrain.FLOODPLAIN)
	assert_false(_world.is_walkable(Vector2i(1, 1)))
	assert_true(_world.is_walkable(Vector2i(2, 2)))
	assert_false(_world.is_buildable(Vector2i(2, 2)))
	assert_false(_world.is_plantable(Vector2i(5, 5)), "grass is not plantable")


func test_combined_checks_are_false_where_no_chunk_is_loaded() -> void:
	var pos := Vector2i(100, 100)
	assert_false(_world.is_walkable(pos))
	assert_false(_world.is_buildable(pos))
	assert_false(_world.is_plantable(pos))
