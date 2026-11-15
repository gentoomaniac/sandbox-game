extends GutTest
## The village built into a world (design/world/wehlsbuell.md, section 4): what its ground is like.

const SEEDS := [1, 4]

var _plan := VillagePlan.default_plan()
## {seed: [world, site, generator]}, each built once for all the tests.
var _built := {}


func before_all() -> void:
	for world_seed: int in SEEDS:
		var world := World.new(world_seed)
		var site := VillageSite.find(world_seed)
		assert_eq(VillageBuilder.build_land(world, site, _plan), "")
		_built[world_seed] = [world, site, WorldGenerator.new(world_seed)]


func _world(world_seed: int) -> World:
	return _built[world_seed][0]


func _site(world_seed: int) -> VillageSite:
	return _built[world_seed][1]


func _generator(world_seed: int) -> WorldGenerator:
	return _built[world_seed][2]


## Loads the chunk of a tile into a world, which replays the edits on it.
func _load(world: World, generator: WorldGenerator, tile: Vector2i) -> void:
	var coords := Chunk.world_to_chunk(tile)
	if not world.is_chunk_loaded(coords):
		world.add_chunk(generator.generate_chunk(coords))


func _terrain_at(world_seed: int, plan_tile: Vector2i) -> Tile.Terrain:
	var tile := _site(world_seed).to_world(plan_tile)
	_load(_world(world_seed), _generator(world_seed), tile)
	return _world(world_seed).tile_at(tile).terrain


func _object_at(world_seed: int, plan_tile: Vector2i) -> WorldObject:
	var tile := _site(world_seed).to_world(plan_tile)
	_load(_world(world_seed), _generator(world_seed), tile)
	return _world(world_seed).object_at(tile)


func _land_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for v in range(_plan.area.position.y, _plan.area.end.y):
		for u in range(_plan.area.position.x, _plan.area.end.x):
			tiles.append(Vector2i(u, v))
	return tiles


func _edits_of(world: World) -> Dictionary:
	var edits := World.dict_of(world.snapshot())
	return {"terrain": edits["terrain_edits"], "objects": edits["object_edits"]}


func _is_planned_object(type: StringName) -> bool:
	return _plan.objects.any(func(group: Dictionary) -> bool: return group["type"] == type)


func test_the_same_seed_gives_the_same_edits() -> void:
	var world := World.new(1)
	assert_eq(VillageBuilder.build_land(world, _site(1), _plan), "")
	assert_eq(_edits_of(world), _edits_of(_world(1)))


func test_it_builds_a_village_of_edits_and_leaves_no_chunk_loaded() -> void:
	for world_seed: int in SEEDS:
		var fresh := World.new(world_seed)
		VillageBuilder.build_land(fresh, _site(world_seed), _plan)
		var edits := _edits_of(fresh)
		assert_gt(edits["terrain"].size(), 200)
		assert_gt(edits["objects"].size(), 100)
		assert_eq(fresh.loaded_chunk_coords(), [] as Array[Vector2i])


func test_the_warften_are_dry_ground() -> void:
	for world_seed: int in SEEDS:
		var ponds := _plan.pond_tiles()
		for warft in _plan.warften:
			for tile in _plan.warft_tiles(warft):
				if not ponds.has(tile):
					assert_eq(_terrain_at(world_seed, tile), Tile.Terrain.WARFT, "%s" % tile)


func test_the_square_the_meeting_spot_and_the_mills_spot_are_free_dry_land() -> void:
	for world_seed: int in SEEDS:
		var tiles: Array[Vector2i] = [_plan.meeting_spot, _plan.landing_spot]
		for rect in [_plan.square, _plan.mill_spot]:
			for v in range(rect.position.y, rect.end.y):
				for u in range(rect.position.x, rect.end.x):
					tiles.append(Vector2i(u, v))
		for tile in tiles:
			var terrain := _terrain_at(world_seed, tile)
			assert_true(terrain == Tile.Terrain.GRASS or terrain == Tile.Terrain.WARFT, "%s" % tile)
			assert_null(_object_at(world_seed, tile), "%s" % tile)


func test_the_pond_the_sielzug_and_the_field_ditches_are_the_only_new_water() -> void:
	var expected := {}
	for tile in _plan.pond_tiles() + _plan.siel_tiles():
		expected[tile] = true
	for field in _plan.fields:
		for tile in _plan.ring_tiles(field):
			if tile.x <= _plan.marsh_end_u:
				expected[tile] = true
	for world_seed: int in SEEDS:
		var site := _site(world_seed)
		for tile in _land_tiles():
			var is_new_water := (
				_terrain_at(world_seed, tile) == Tile.Terrain.WATER
				and _generator(world_seed).terrain_at(site.to_world(tile)) != Tile.Terrain.WATER
			)
			if is_new_water:
				# The Sielzug starts at the row's own dyke, which the plan's u 0 is only near.
				var is_siel := tile.y in range(_plan.siel.position.y, _plan.siel.end.y)
				assert_true(expected.has(tile) or is_siel, "seed %d: %s" % [world_seed, tile])


func test_the_dyke_has_a_gap_in_the_rows_of_the_sielzug_only() -> void:
	var siel_rows := range(_plan.siel.position.y, _plan.siel.end.y)
	for world_seed: int in SEEDS:
		var site := _site(world_seed)
		var generator := _generator(world_seed)
		var gap_tiles := 0
		for tile in _land_tiles():
			var world_tile := site.to_world(tile)
			var generated := generator.object_type_at(world_tile, generator.terrain_at(world_tile))
			if generated == WorldObjectTypes.DYKE and _object_at(world_seed, tile) == null:
				gap_tiles += 1
				assert_true(tile.y in siel_rows, "seed %d: dyke gone at %s" % [world_seed, tile])
		assert_gt(gap_tiles, 0)


func test_the_inland_ground_is_clean_and_drained() -> void:
	var village_types: Array[StringName] = [
		WorldObjectTypes.DYKE,
		WorldObjectTypes.KNICK,
		WorldObjectTypes.STONE_WALL,
		WorldObjectTypes.WATTLE_FENCE,
	]
	for world_seed: int in SEEDS:
		for tile in _land_tiles():
			if tile.x < _plan.inland_from_u:
				continue
			assert_ne(_terrain_at(world_seed, tile), Tile.Terrain.WETLAND, "%s" % tile)
			var object := _object_at(world_seed, tile)
			if object != null:
				assert_true(
					village_types.has(object.type) or _is_planned_object(object.type),
					"seed %d: %s at %s" % [world_seed, object.type, tile]
				)


func test_each_field_has_a_ditch_in_the_marsh_a_knick_beyond_and_a_gap() -> void:
	for world_seed: int in SEEDS:
		for field in _plan.fields:
			for tile in _plan.ring_tiles(field):
				if tile.x <= _plan.marsh_end_u:
					assert_eq(_terrain_at(world_seed, tile), Tile.Terrain.WATER, "%s" % tile)
				else:
					var knick := _object_at(world_seed, tile)
					assert_eq(knick.type, WorldObjectTypes.KNICK, "%s" % tile)
			for gap: Vector2i in field["gaps"]:
				assert_ne(_terrain_at(world_seed, gap), Tile.Terrain.WATER, "%s" % gap)
				assert_null(_object_at(world_seed, gap), "%s" % gap)


func test_the_churchyard_has_its_wall_and_its_gate() -> void:
	var churchyard: Dictionary = _plan.fences[0]
	for world_seed: int in SEEDS:
		for tile in _plan.ring_tiles(churchyard):
			assert_eq(_object_at(world_seed, tile).type, WorldObjectTypes.STONE_WALL)
		for gap: Vector2i in churchyard["gaps"]:
			assert_null(_object_at(world_seed, gap))


func test_the_things_of_the_plan_stand_where_it_says() -> void:
	for world_seed: int in SEEDS:
		for group in _plan.objects:
			for tile: Vector2i in group["tiles"]:
				assert_eq(_object_at(world_seed, tile).type, group["type"], "%s" % tile)


func test_every_door_of_the_plan_has_a_walkable_tile_in_front_after_the_land() -> void:
	for world_seed: int in SEEDS:
		for building in _plan.buildings:
			var front := _plan.door_front(building)
			var tile := _site(world_seed).to_world(front)
			_load(_world(world_seed), _generator(world_seed), tile)
			assert_true(_world(world_seed).is_walkable(tile), "%s %s" % [building["id"], front])


func test_land_with_a_building_of_the_player_on_it_is_refused_and_left_alone() -> void:
	var world_seed := 1
	var world := World.new(world_seed)
	var site := _site(world_seed)
	var shack_origin := Vector2i.ZERO
	for tile in _land_tiles():
		var world_tile := site.to_world(tile)
		_load(world, _generator(world_seed), world_tile)
		if (
			tile.x >= _plan.inland_from_u
			and world.placement_blockers(BuildingTypes.SHACK, world_tile).is_empty()
		):
			shack_origin = world_tile
			break
	assert_not_null(world.place_building(BuildingTypes.SHACK, shack_origin))
	var reason := VillageBuilder.build_land(world, site, _plan)
	assert_string_contains(reason, "a building stands on the village's land")
	assert_eq(World.dict_of(world.snapshot())["terrain_edits"], [])


func test_building_twice_is_refused() -> void:
	var reason := VillageBuilder.build_land(_world(1), _site(1), _plan)
	assert_string_contains(reason, "was changed on the village's land")
