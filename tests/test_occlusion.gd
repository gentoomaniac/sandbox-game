extends GutTest
## Which objects and buildings hide the player. Tiles are 16 px; the player is 16x32 above
## its feet, at the middle of the tile (3, 3): (56, 56).

const FEET := Vector2(56, 56)

var _world: World


func before_each() -> void:
	_world = World.new(1)
	_world.add_chunk(Chunk.new(Vector2i.ZERO))


func _add_oak(tile: Vector2i) -> WorldObject:
	var oak := WorldObject.new(WorldObjectTypes.OAK, tile)
	_world.add_object(oak)
	return oak


func test_tree_in_front_and_overlapping_occludes() -> void:
	var oak := _add_oak(Vector2i(3, 4))
	assert_eq(Occlusion.occluding_objects(FEET, _world), [oak])


func test_tree_diagonally_in_front_occludes_but_not_two_columns_over() -> void:
	var oak := _add_oak(Vector2i(4, 4))
	_add_oak(Vector2i(5, 4))
	assert_eq(Occlusion.occluding_objects(FEET, _world), [oak])


func test_tree_behind_does_not_occlude() -> void:
	_add_oak(Vector2i(3, 2))
	_add_oak(Vector2i(2, 1))
	assert_true(Occlusion.occluding_objects(FEET, _world).is_empty())


func test_tree_on_the_players_row_is_behind_only_when_the_player_is_lower() -> void:
	var oak := _add_oak(Vector2i(4, 3))
	assert_eq(Occlusion.occluding_objects(FEET - Vector2(0, 4), _world), [oak])
	assert_true(Occlusion.occluding_objects(FEET + Vector2(0, 4), _world).is_empty())


func test_tree_in_front_but_not_overlapping_does_not_occlude() -> void:
	_add_oak(Vector2i(5, 4))
	_add_oak(Vector2i(3, 8))
	assert_true(Occlusion.occluding_objects(FEET, _world).is_empty())


func test_low_object_does_not_occlude() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, Vector2i(3, 4)))
	assert_true(Occlusion.occluding_objects(FEET, _world).is_empty())


func test_building_roof_in_front_occludes_player_behind_it() -> void:
	var house := _world.place_building(BuildingTypes.KATE, Vector2i(2, 5))
	# Feet above the footprint's top edge (y 80), within the roof.
	var behind_roof := Vector2(72, 70)
	assert_eq(Occlusion.occluding_buildings(behind_roof, _world.buildings()), [house])


func test_building_far_above_the_player_does_not_occlude() -> void:
	_world.place_building(BuildingTypes.KATE, Vector2i(2, 8))
	# The house is 96 px high, so its top edge is at y 80; the player's head reaches only y 24.
	assert_true(Occlusion.occluding_buildings(FEET, _world.buildings()).is_empty())


func test_player_beside_or_in_front_of_building_is_not_occluded() -> void:
	var house := _world.place_building(BuildingTypes.KATE, Vector2i(2, 2))
	# Left of the 5-tile-wide footprint, and south of it (sorted after the house).
	assert_true(Occlusion.occluding_buildings(Vector2(16, 60), [house]).is_empty())
	assert_true(Occlusion.occluding_buildings(Vector2(72, 100), [house]).is_empty())
