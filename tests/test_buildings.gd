extends GutTest
## Placing buildings on the world: what blocks a placement, the footprint and the door.

const HOUSE := BuildingTypes.KATE
const ORIGIN := Vector2i(2, 2)

var _world: World


func before_each() -> void:
	_world = World.new(1)
	_world.add_chunk(Chunk.new(Vector2i.ZERO))


func _set_terrain(world_pos: Vector2i, terrain: Tile.Terrain) -> void:
	_world.chunk_at(Vector2i.ZERO).set_terrain(Chunk.local_pos(world_pos), terrain)


func test_placement_on_free_buildable_land() -> void:
	assert_true(_world.placement_blockers(HOUSE, ORIGIN).is_empty())
	var building := _world.place_building(HOUSE, ORIGIN)
	assert_not_null(building)
	assert_eq(_world.buildings(), [building])


func test_rejected_on_unbuildable_terrain() -> void:
	for terrain in [Tile.Terrain.WATER, Tile.Terrain.WETLAND, Tile.Terrain.FLOODPLAIN]:
		# The last footprint tile, so every tile is checked.
		var bad_tile := ORIGIN + Vector2i(3, 2)
		_set_terrain(bad_tile, terrain)
		assert_null(_world.place_building(HOUSE, ORIGIN), "terrain %s" % terrain)
		assert_eq(_world.placement_blockers(HOUSE, ORIGIN), {bad_tile: World.Blocked.TERRAIN})
		_set_terrain(bad_tile, Tile.Terrain.GRASS)
	assert_true(_world.buildings().is_empty())


func test_rejected_on_object() -> void:
	var tree_pos := ORIGIN + Vector2i(1, 1)
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, tree_pos))
	assert_null(_world.place_building(HOUSE, ORIGIN))
	assert_eq(_world.placement_blockers(HOUSE, ORIGIN), {tree_pos: World.Blocked.OCCUPIED})


func test_rejected_on_overlap_with_another_building() -> void:
	_world.place_building(HOUSE, ORIGIN)
	var overlapping := ORIGIN + Vector2i(4, 2)
	assert_null(_world.place_building(HOUSE, overlapping))
	assert_eq(
		_world.placement_blockers(HOUSE, overlapping),
		{overlapping: World.Blocked.OCCUPIED},
		"only the corner overlaps"
	)
	assert_eq(_world.buildings().size(), 1)
	# Touching is fine.
	assert_not_null(_world.place_building(HOUSE, ORIGIN + Vector2i(5, 0)))


func test_rejected_when_a_chunk_is_not_loaded() -> void:
	var size := Chunk.CHUNK_SIZE
	# The right part of the footprint is in the chunk (1, 0), which is not loaded.
	var crossing := Vector2i(size - 2, 2)
	assert_null(_world.place_building(HOUSE, crossing))
	_world.add_chunk(Chunk.new(Vector2i(1, 0)))
	assert_not_null(_world.place_building(HOUSE, crossing), "fine once loaded")


func test_footprint_is_occupied_and_only_the_door_is_walkable() -> void:
	var building := _world.place_building(HOUSE, ORIGIN)
	for pos in building.tiles():
		assert_eq(_world.building_at(pos), building)
		assert_false(_world.is_buildable(pos), "buildable %s" % pos)
		assert_false(_world.is_free_on(pos, Tile.Terrain.SOIL), "plantable %s" % pos)
		assert_eq(_world.is_walkable(pos), pos == building.door_tile(), "walkable %s" % pos)
	assert_true(building.tiles().has(building.door_tile()))
	assert_true(_world.is_walkable(ORIGIN + Vector2i(2, 3)), "the tile in front of the door")
	assert_null(_world.building_at(ORIGIN + Vector2i(5, 0)))


func test_the_bell_frame_has_no_inside_and_no_tile_of_it_can_be_walked_on() -> void:
	var building := _world.place_building(BuildingTypes.BELL_FRAME, ORIGIN)
	assert_false(building.has_inside())
	assert_true(_world.place_building(HOUSE, ORIGIN + Vector2i(3, 0)).has_inside())
	for pos in building.tiles():
		assert_false(_world.is_walkable(pos), "walkable %s" % pos)


func test_placement_emits_the_signal() -> void:
	watch_signals(_world)
	assert_null(_world.place_building(HOUSE, Vector2i(-1000, 0)))
	assert_signal_not_emitted(_world, "building_placed")
	var building := _world.place_building(HOUSE, ORIGIN)
	assert_signal_emitted_with_parameters(_world, "building_placed", [building])


func test_building_outlives_its_chunks() -> void:
	var size := Chunk.CHUNK_SIZE
	var crossing := Vector2i(size - 2, 2)
	_world.add_chunk(Chunk.new(Vector2i(1, 0)))
	var building := _world.place_building(HOUSE, crossing)
	_world.remove_chunk(Vector2i.ZERO)
	_world.remove_chunk(Vector2i(1, 0))
	assert_eq(_world.buildings(), [building])
	assert_eq(_world.building_at(crossing), building)
	_world.add_chunk(Chunk.new(Vector2i.ZERO))
	assert_false(_world.is_buildable(crossing), "still occupied after reloading")


func test_rejected_when_the_tile_in_front_of_the_door_is_blocked() -> void:
	var door_offset: Vector2i = BuildingTypes.TYPES[HOUSE]["door_offset"]
	var front := ORIGIN + door_offset + Vector2i.DOWN
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, front))
	assert_eq(_world.placement_blockers(HOUSE, ORIGIN), {front: World.Blocked.OCCUPIED})
	assert_null(_world.place_building(HOUSE, ORIGIN))
	_world.remove_object(front)
	_set_terrain(front, Tile.Terrain.WATER)
	assert_eq(_world.placement_blockers(HOUSE, ORIGIN), {front: World.Blocked.TERRAIN})


func test_window_lights_are_on_the_lit_windows_of_the_picture() -> void:
	for building_id in BuildingTypes.ids():
		for style in BuildingTypes.styles(building_id):
			var building_type := BuildingTypes.of(building_id, style)
			var lit_path := ProjectSettings.globalize_path(building_type["sprite_lit"])
			var unlit_path := ProjectSettings.globalize_path(building_type["sprite"])
			var lit := Image.load_from_file(lit_path)
			var unlit := Image.load_from_file(unlit_path)
			for centre: Vector2i in building_type["window_lights"]:
				var where := "%s %s lit window at %s" % [building_id, style, centre]
				assert_ne(lit.get_pixelv(centre), unlit.get_pixelv(centre), where)
