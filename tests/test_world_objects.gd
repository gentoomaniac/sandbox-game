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


func test_every_natural_object_type_is_generated() -> void:
	var generator := WorldGenerator.new(SEED)
	var types := {}
	for y in range(-128, 128):
		for x in range(-128, 128):
			var pos := Vector2i(x, y)
			types[generator.object_type_at(pos, generator.terrain_at(pos))] = true
	for object_type: StringName in WorldObjectTypes.TYPES:
		# The camp is placed by the game, crops by the player, stumps and trunks by felling and furniture
		# comes with interiors.
		var type_data: Dictionary = WorldObjectTypes.TYPES[object_type]
		var is_made_by_play := (
			(
				object_type
				in [
					WorldObjectTypes.FIREPLACE,
					WorldObjectTypes.SLEEPING_BAG,
					WorldObjectTypes.STUMP
				]
			)
			or str(object_type).ends_with("trunk")
		)
		if is_made_by_play or type_data.has("growth_stages") or type_data.has("interior_sprite"):
			continue
		assert_true(types.has(object_type), "Missing object type %s" % object_type)


func test_dead_trees_are_more_common_near_wetland() -> void:
	var generator := WorldGenerator.new(SEED)
	var area := Rect2i(-128, -128, 256, 256)
	var terrains := {}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			terrains[Vector2i(x, y)] = generator.terrain_at(Vector2i(x, y))
	var near := {"tiles": 0, "dead": 0}
	var far := {"tiles": 0, "dead": 0}
	for pos: Vector2i in terrains:
		if terrains[pos] != Tile.Terrain.GRASS:
			continue
		var group := far
		for offset in WorldGenerator.WETLAND_PROBE_DIRECTIONS:
			if terrains.get(pos + offset * WorldGenerator.WETLAND_REACH) == Tile.Terrain.WETLAND:
				group = near
		group["tiles"] += 1
		if generator.object_type_at(pos, Tile.Terrain.GRASS) == WorldObjectTypes.DEAD_TREE:
			group["dead"] += 1
	assert_gt(near["dead"], 0, "dead trees near wetland")
	assert_gt(near["tiles"], 0)
	assert_gt(far["tiles"], 0)
	var near_rate: float = float(near["dead"]) / near["tiles"]
	var far_rate: float = float(far["dead"]) / far["tiles"]
	assert_gt(near_rate, 3.0 * far_rate)


func test_objects_stand_only_on_grass_but_for_the_reeds_on_the_banks() -> void:
	var terrains := {}
	for chunk in _generate(WorldGenerator.new(SEED), CHUNKS):
		for object in chunk.objects():
			var terrain := chunk.terrain_at(Chunk.local_pos(object.pos))
			terrains[terrain] = true
			assert_eq(Chunk.world_to_chunk(object.pos), chunk.coords)
			if terrain != Tile.Terrain.GRASS:
				assert_eq(object.type, WorldObjectTypes.REEDS)
	var expected := [Tile.Terrain.GRASS, Tile.Terrain.FLOODPLAIN, Tile.Terrain.WETLAND]
	for terrain in terrains:
		assert_true(expected.has(terrain), "terrain %d" % terrain)


func test_no_objects_but_reeds_on_water_wetland_or_floodplain() -> void:
	var generator := WorldGenerator.new(SEED)
	var checked := {}
	for y in range(-64, 64):
		for x in range(-64, 64):
			var terrain := generator.terrain_at(Vector2i(x, y))
			if terrain != Tile.Terrain.GRASS:
				checked[terrain] = true
				var object_type := generator.object_type_at(Vector2i(x, y), terrain)
				if terrain == Tile.Terrain.WATER:
					assert_eq(object_type, &"")
				else:
					assert_true(object_type in [&"", WorldObjectTypes.REEDS])
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
	assert_true(_world.is_free_on(pos, Tile.Terrain.SOIL))
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, pos))
	assert_false(_world.is_buildable(pos))
	assert_false(_world.is_free_on(pos, Tile.Terrain.SOIL))


func test_combined_checks_still_follow_the_tile() -> void:
	_load_chunk_at_origin()
	var chunk := _world.chunk_at(Vector2i.ZERO)
	chunk.set_terrain(Vector2i(1, 1), Tile.Terrain.WATER)
	chunk.set_terrain(Vector2i(2, 2), Tile.Terrain.FLOODPLAIN)
	assert_false(_world.is_walkable(Vector2i(1, 1)))
	assert_true(_world.is_walkable(Vector2i(2, 2)))
	assert_false(_world.is_buildable(Vector2i(2, 2)))
	assert_false(_world.is_free_on(Vector2i(5, 5), Tile.Terrain.SOIL), "grass is not plantable")


func test_combined_checks_are_false_where_no_chunk_is_loaded() -> void:
	var pos := Vector2i(100, 100)
	assert_false(_world.is_walkable(pos))
	assert_false(_world.is_buildable(pos))
	assert_false(_world.is_free_on(pos, Tile.Terrain.SOIL))


func test_big_object_covers_its_whole_footprint() -> void:
	_load_chunk_at_origin()
	var origin := Vector2i(3, 4)
	var boulder := WorldObject.new(WorldObjectTypes.BOULDER, origin)
	_world.add_object(boulder)
	assert_same(_world.object_at(origin), boulder)
	assert_same(_world.object_at(origin + Vector2i.RIGHT), boulder)
	assert_null(_world.object_at(origin + Vector2i.LEFT))
	assert_null(_world.object_at(origin + Vector2i.DOWN))
	assert_false(_world.is_walkable(origin + Vector2i.RIGHT))
	assert_false(_world.is_buildable(origin + Vector2i.RIGHT))
	assert_false(_world.is_free_on(origin + Vector2i.RIGHT, Tile.Terrain.GRASS))


func test_big_object_is_found_across_a_chunk_border() -> void:
	_world.add_chunk(Chunk.new(Vector2i.ZERO))
	_world.add_chunk(Chunk.new(Vector2i(1, 0)))
	var origin := Vector2i(Chunk.CHUNK_SIZE - 1, 2)
	var boulder := WorldObject.new(WorldObjectTypes.BOULDER, origin)
	_world.add_object(boulder)
	assert_same(_world.object_at(origin + Vector2i.RIGHT), boulder)


func test_removing_a_big_object_by_any_of_its_tiles_frees_all_of_them() -> void:
	_load_chunk_at_origin()
	var origin := Vector2i(3, 4)
	_world.add_object(WorldObject.new(WorldObjectTypes.SLEEPING_BAG, origin))
	watch_signals(_world)
	var removed := _world.remove_object(origin + Vector2i.DOWN)
	assert_eq(removed.pos, origin)
	assert_null(_world.object_at(origin))
	assert_null(_world.object_at(origin + Vector2i.DOWN))
	assert_signal_emit_count(_world, "objects_changed", 2)


func test_every_footprint_fits_the_largest_footprint() -> void:
	for object_type: Dictionary in WorldObjectTypes.TYPES.values():
		var footprint: Vector2i = object_type["footprint"]
		assert_true(footprint.x <= WorldObjectTypes.MAX_FOOTPRINT.x)
		assert_true(footprint.y <= WorldObjectTypes.MAX_FOOTPRINT.y)


func test_generated_boulders_have_free_grass_for_their_whole_footprint() -> void:
	var generator := WorldGenerator.new(SEED)
	var boulders := 0
	for y in range(-96, 96):
		for x in range(-96, 96):
			var pos := Vector2i(x, y)
			if generator.object_type_at(pos, generator.terrain_at(pos)) != WorldObjectTypes.BOULDER:
				continue
			boulders += 1
			var right := pos + Vector2i.RIGHT
			assert_eq(generator.terrain_at(right), Tile.Terrain.GRASS)
			assert_eq(generator.object_type_at(right, Tile.Terrain.GRASS), &"")
	assert_gt(boulders, 0)
