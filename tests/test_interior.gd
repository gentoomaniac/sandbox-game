extends GutTest

const MAP_PATH := "res://maps/interiors/small_house.tmx"

var _state: GameState
var _house: Building


func before_each() -> void:
	_state = GameState.new()
	_state.world = World.new(1)
	_state.world.add_chunk(Chunk.new(Vector2i.ZERO))
	_state.current_map = _state.world
	_state.player.home_map = _state.world
	_house = _state.world.place_building(BuildingTypes.SMALL_HOUSE, Vector2i(2, 2))


func _stand_on(tile: Vector2i) -> void:
	_state.player.position = Vector2(tile) + Vector2(0.5, 0.5)


func _enter_house() -> Interior:
	_stand_on(_house.door_tile())
	_state.pass_door()
	return _state.current_map as Interior


func test_the_map_becomes_terrain_objects_and_an_exit() -> void:
	var interior := InteriorLoader.load_interior(MAP_PATH)
	assert_eq(interior.size, Vector2i(8, 6))
	assert_eq(interior.tile_at(Vector2i(0, 0)).terrain, Tile.Terrain.WALL)
	assert_eq(interior.tile_at(Vector2i(3, 3)).terrain, Tile.Terrain.FLOOR)
	assert_eq(interior.exit_tile, Vector2i(3, 5))
	assert_eq(interior.tile_at(interior.exit_tile).terrain, Tile.Terrain.FLOOR)
	assert_eq(interior.entry_tile(), Vector2i(3, 4))
	assert_null(interior.tile_at(Vector2i(8, 0)))
	assert_eq(interior.object_at(Vector2i(1, 1)).type, WorldObjectTypes.SMALL_BED)
	assert_eq(interior.object_at(Vector2i(5, 2)).type, WorldObjectTypes.TABLE)
	assert_eq(interior.objects().size(), 2)


func test_walls_and_furniture_block_walking_and_floor_does_not() -> void:
	var interior := InteriorLoader.load_interior(MAP_PATH)
	assert_false(interior.is_walkable(Vector2i(0, 3)), "wall")
	assert_false(interior.is_walkable(Vector2i(1, 1)), "bed")
	assert_false(interior.is_walkable(Vector2i(-1, 3)), "outside the map")
	assert_true(interior.is_walkable(Vector2i(3, 3)), "floor")
	assert_true(interior.is_walkable(interior.exit_tile), "exit")


func test_interior_terrain_cannot_be_built_on() -> void:
	for terrain in [Tile.Terrain.FLOOR, Tile.Terrain.WALL]:
		var tile := Tile.new()
		tile.terrain = terrain
		assert_false(tile.is_buildable())
		assert_false(tile.is_plantable())


func test_the_player_stops_at_the_interior_wall() -> void:
	var interior := _enter_house()
	for i in 20:
		_state.player.move(interior, Vector2.LEFT, 0.1)
	assert_eq(_state.player.tile(), Vector2i(1, 4))
	assert_true(_state.player.position.x >= 1.0 + PlayerState.BODY_HALF_WIDTH)


func test_the_door_is_only_a_door_on_its_tile() -> void:
	_stand_on(_house.door_tile() + Vector2i.DOWN)
	assert_false(_state.door_underfoot())
	_stand_on(_house.door_tile())
	assert_true(_state.door_underfoot())


func test_walking_through_the_door_enters_at_the_entry_tile() -> void:
	var interior := _enter_house()
	assert_true(_state.is_inside())
	assert_eq(_state.player.tile(), interior.entry_tile())
	assert_false(_state.door_underfoot())


func test_the_exit_leads_to_the_tile_south_of_the_door() -> void:
	var interior := _enter_house()
	_stand_on(interior.exit_tile)
	assert_true(_state.door_underfoot())
	_state.pass_door()
	assert_false(_state.is_inside())
	assert_eq(_state.current_map, _state.world)
	assert_eq(_state.player.tile(), _house.door_tile() + Vector2i.DOWN)
	assert_false(_state.door_underfoot())


func test_each_building_keeps_its_own_interior() -> void:
	var second := _state.world.place_building(
		BuildingTypes.SMALL_HOUSE, _house.origin + Vector2i(8, 0)
	)
	var first_interior := _enter_house()
	first_interior.add_object(WorldObject.new(WorldObjectTypes.TABLE, Vector2i(3, 1)))
	_stand_on(first_interior.exit_tile)
	_state.pass_door()
	_stand_on(second.door_tile())
	_state.pass_door()
	var second_interior := _state.current_map as Interior
	assert_ne(second_interior, first_interior)
	assert_null(second_interior.object_at(Vector2i(3, 1)))
	_stand_on(second_interior.exit_tile)
	_state.pass_door()
	assert_eq(_enter_house(), first_interior)
	assert_not_null(first_interior.object_at(Vector2i(3, 1)))


func test_the_bed_is_in_reach_from_beside_it_and_sleeping_sets_home_there() -> void:
	var interior := _enter_house()
	assert_null(_state.bed_in_reach())
	_stand_on(Vector2i(2, 2))
	var bed := _state.bed_in_reach()
	assert_eq(bed, interior.object_at(Vector2i(1, 1)))
	_state.clock.set_time(22, 0)
	_state.sleep_in(bed)
	assert_eq(_state.clock.minute_of_day, 4 * GameClock.MINUTES_PER_HOUR)
	assert_eq(_state.player.home_map, interior)
	assert_eq(_state.player.home_bed, Vector2i(1, 1))


func test_new_game_home_is_in_the_world() -> void:
	var state := GameState.new_game(7)
	assert_eq(state.player.home_map, state.world)


func test_use_does_nothing_inside() -> void:
	_enter_house()
	for tile in [Vector2i(3, 3), Vector2i(3, 2), Vector2i(0, 0)]:
		assert_eq(_state.use_at(tile), GameState.Use.NOTHING)
