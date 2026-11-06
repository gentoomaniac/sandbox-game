extends GutTest
## The Tiled interior of each building (see data/buildings.cfg), and that its furniture leaves
## every free tile reachable.

var _energy_rules := EnergyRules.default_rules()


func _load(type: StringName) -> Interior:
	return InteriorLoader.load_interior(BuildingTypes.TYPES[type]["interior_map"])


func _bed_of(interior: Interior) -> WorldObject:
	var beds := interior.objects().filter(func(object: WorldObject) -> bool: return object.is_bed())
	return null if beds.is_empty() else beds[0]


## The tiles a player can walk to from the entry tile.
func _reachable_from_entry(interior: Interior) -> Dictionary:
	var seen := {interior.entry_tile(): true}
	var queue: Array[Vector2i] = [interior.entry_tile()]
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not seen.has(tile + step) and interior.is_walkable(tile + step):
				seen[tile + step] = true
				queue.append(tile + step)
	return seen


func test_every_building_has_its_own_interior_map() -> void:
	var paths := []
	for type: StringName in BuildingTypes.TYPES:
		var path: String = BuildingTypes.TYPES[type]["interior_map"]
		assert_true(path.ends_with("/%s.tmx" % type), "%s: %s" % [type, path])
		assert_false(paths.has(path))
		paths.append(path)


func test_each_interior_has_walls_around_and_its_door_in_the_front_wall() -> void:
	var sizes := {
		BuildingTypes.SHACK: Vector2i(6, 6),
		BuildingTypes.KATE: Vector2i(9, 8),
		BuildingTypes.LONGHOUSE: Vector2i(15, 8),
		BuildingTypes.HALL_HOUSE: Vector2i(15, 13),
		BuildingTypes.BARN: Vector2i(13, 8),
	}
	for type: StringName in sizes:
		var interior := _load(type)
		var size: Vector2i = sizes[type]
		assert_eq(interior.size, size, str(type))
		assert_eq(interior.exit_tile.y, size.y - 1, "%s: the door is in the front wall" % type)
		assert_eq(interior.tile_at(interior.exit_tile).terrain, Tile.Terrain.FLOOR)
		assert_eq(interior.entry_tile(), interior.exit_tile + Vector2i.UP)
		for x in size.x:
			assert_eq(interior.tile_at(Vector2i(x, 0)).terrain, Tile.Terrain.WALL)
			assert_eq(interior.tile_at(Vector2i(x, 1)).terrain, Tile.Terrain.WALL)
			if x != interior.exit_tile.x:
				assert_eq(interior.tile_at(Vector2i(x, size.y - 1)).terrain, Tile.Terrain.WALL)
		for y in size.y:
			assert_eq(interior.tile_at(Vector2i(0, y)).terrain, Tile.Terrain.WALL)
			assert_eq(interior.tile_at(Vector2i(size.x - 1, y)).terrain, Tile.Terrain.WALL)


func test_the_beds_are_in_the_buildings_that_can_be_slept_in_and_reachable() -> void:
	var bed_types := {
		BuildingTypes.SHACK: WorldObjectTypes.SLEEPING_MAT,
		BuildingTypes.KATE: WorldObjectTypes.SMALL_BED,
		BuildingTypes.LONGHOUSE: WorldObjectTypes.BOX_BED,
		BuildingTypes.HALL_HOUSE: WorldObjectTypes.BOX_BED,
	}
	for type: StringName in bed_types:
		var interior := _load(type)
		var bed := _bed_of(interior)
		assert_not_null(bed, str(type))
		assert_eq(bed.type, bed_types[type])
		assert_gt(_energy_rules.sleep_fill(bed.type), 0.0, "%s has a sleep fill" % type)
		var reachable := _reachable_from_entry(interior)
		var beside := false
		var around := Rect2i(bed.pos - Vector2i.ONE, bed.type_data()["footprint"] + Vector2i(2, 2))
		for tile: Vector2i in reachable:
			beside = beside or around.has_point(tile)
		assert_true(beside, "%s: a free tile beside the bed is reachable" % type)


func test_the_barn_has_no_bed_and_no_hearth() -> void:
	var barn := _load(BuildingTypes.BARN)
	assert_null(_bed_of(barn))
	for object in barn.objects():
		assert_ne(object.type, WorldObjectTypes.HEARTH)


func test_the_longhouse_has_a_living_end_and_a_stall_end() -> void:
	var longhouse := _load(BuildingTypes.LONGHOUSE)
	var types := longhouse.objects().map(
		func(object: WorldObject) -> StringName: return object.type
	)
	for type in [WorldObjectTypes.HEARTH, WorldObjectTypes.TABLE, WorldObjectTypes.BENCH]:
		assert_true(types.has(type), str(type))
	for type in [WorldObjectTypes.STALL_PARTITION, WorldObjectTypes.HAY_PILE]:
		assert_true(types.has(type), str(type))


func test_the_living_rooms_have_brick_floors_and_the_work_rooms_clay() -> void:
	var floors := {
		BuildingTypes.KATE: [Vector2i(3, 4), Tile.Terrain.FLOOR],
		BuildingTypes.SHACK: [Vector2i(2, 3), Tile.Terrain.CLAY_FLOOR],
		BuildingTypes.BARN: [Vector2i(5, 4), Tile.Terrain.CLAY_FLOOR],
	}
	for type: StringName in floors:
		var tile: Vector2i = floors[type][0]
		assert_eq(_load(type).tile_at(tile).terrain, floors[type][1], str(type))
	var longhouse := _load(BuildingTypes.LONGHOUSE)
	assert_eq(longhouse.tile_at(Vector2i(3, 4)).terrain, Tile.Terrain.FLOOR, "the living end")
	assert_eq(longhouse.tile_at(Vector2i(10, 4)).terrain, Tile.Terrain.CLAY_FLOOR, "the byre")
	var hall_house := _load(BuildingTypes.HALL_HOUSE)
	assert_eq(hall_house.tile_at(Vector2i(7, 3)).terrain, Tile.Terrain.FLOOR, "the Flett")
	assert_eq(hall_house.tile_at(Vector2i(7, 8)).terrain, Tile.Terrain.CLAY_FLOOR, "the Diele")


func test_the_hall_house_has_the_hearth_at_the_end_of_the_diele_and_stalls_on_both_sides() -> void:
	var hall_house := _load(BuildingTypes.HALL_HOUSE)
	var hearth: WorldObject = null
	var box_beds := 0
	var stalls_left := 0
	var stalls_right := 0
	for object in hall_house.objects():
		match object.type:
			WorldObjectTypes.HEARTH:
				hearth = object
			WorldObjectTypes.BOX_BED:
				box_beds += 1
			WorldObjectTypes.STALL_PARTITION:
				if object.pos.x < hall_house.exit_tile.x:
					stalls_left += 1
				else:
					stalls_right += 1
	assert_not_null(hearth)
	assert_eq(hearth.pos.y, InteriorView.BACK_WALL_ROWS, "on the back wall, across the Diele")
	assert_almost_eq(hearth.pos.x + 1.0, hall_house.exit_tile.x + 0.5, 0.5, "behind the door")
	assert_eq(box_beds, 2)
	assert_gt(stalls_left, 0)
	assert_gt(stalls_right, 0)


func test_every_free_floor_tile_of_every_interior_is_reachable() -> void:
	for type: StringName in BuildingTypes.TYPES:
		var interior := _load(type)
		var reachable := _reachable_from_entry(interior)
		var floor_tiles := 0
		for y in range(2, interior.size.y - 1):
			for x in range(1, interior.size.x - 1):
				var tile := Vector2i(x, y)
				if interior.is_walkable(tile):
					floor_tiles += 1
					assert_true(reachable.has(tile), "%s: %s is cut off" % [type, tile])
		assert_gt(floor_tiles, 0)
