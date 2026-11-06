extends GutTest
## Interiors read from a Tiled map: terrain, objects, furniture, exits and walking inside.

const KATE_MAP := "res://maps/interiors/kate.tmx"

var _state: GameState
var _kate: Building


func before_each() -> void:
	_state = GameState.new()
	_state.world = World.new(1)
	_state.world.add_chunk(Chunk.new(Vector2i.ZERO))
	_state.current_map = _state.world
	_state.player.home_map = _state.world
	_kate = _state.world.place_building(BuildingTypes.KATE, Vector2i(2, 2))


func _stand_on(tile: Vector2i) -> void:
	_state.player.position = Vector2(tile) + Vector2(0.5, 0.5)


func _enter_kate() -> Interior:
	_stand_on(_kate.door_tile())
	_state.pass_door()
	return _state.current_map as Interior


func test_the_map_becomes_terrain_objects_and_an_exit() -> void:
	var interior := InteriorLoader.load_interior(KATE_MAP)
	assert_eq(interior.size, Vector2i(9, 8))
	assert_eq(interior.tile_at(Vector2i(0, 0)).terrain, Tile.Terrain.WALL)
	assert_eq(interior.tile_at(Vector2i(4, 1)).terrain, Tile.Terrain.WALL, "back wall face")
	assert_eq(interior.tile_at(Vector2i(3, 4)).terrain, Tile.Terrain.FLOOR)
	assert_eq(interior.exit_tile, Vector2i(4, 7))
	assert_eq(interior.tile_at(interior.exit_tile).terrain, Tile.Terrain.FLOOR)
	assert_eq(interior.entry_tile(), Vector2i(4, 6))
	assert_null(interior.tile_at(Vector2i(9, 0)))
	assert_eq(interior.object_at(Vector2i(1, 2)).type, WorldObjectTypes.SMALL_BED)
	assert_eq(interior.object_at(Vector2i(5, 5)).type, WorldObjectTypes.TABLE)
	assert_eq(interior.object_at(Vector2i(7, 5)).type, WorldObjectTypes.STOOL)
	assert_eq(interior.object_at(Vector2i(4, 2)).type, WorldObjectTypes.HEARTH)
	assert_eq(interior.objects().size(), 8, "bed, table, 2 stools, hearth, chest, 2 windows")


func test_furniture_covers_its_whole_footprint_and_counts_once() -> void:
	var interior := InteriorLoader.load_interior(KATE_MAP)
	var bed := interior.object_at(Vector2i(1, 2))
	assert_eq(bed.pos, Vector2i(1, 2), "the position is the top left tile")
	assert_eq(interior.object_at(Vector2i(1, 3)), bed)
	assert_null(interior.object_at(Vector2i(1, 4)))
	var table := interior.object_at(Vector2i(5, 5))
	assert_eq(interior.object_at(Vector2i(6, 5)), table)
	assert_eq(interior.objects().count(table), 1)
	for hearth_tile in [Vector2i(4, 2), Vector2i(5, 2), Vector2i(4, 3), Vector2i(5, 3)]:
		assert_eq(interior.object_at(hearth_tile).type, WorldObjectTypes.HEARTH)


func test_added_furniture_takes_its_tile() -> void:
	var interior := InteriorLoader.load_interior(KATE_MAP)
	assert_true(interior.object_at(Vector2i(2, 3)) == null, "free next to the bed")
	interior.add_object(WorldObject.new(WorldObjectTypes.STOOL, Vector2i(2, 3)))
	assert_not_null(interior.object_at(Vector2i(2, 3)))


func test_walls_and_furniture_block_walking_and_floor_does_not() -> void:
	var interior := InteriorLoader.load_interior(KATE_MAP)
	assert_false(interior.is_walkable(Vector2i(0, 3)), "wall")
	assert_false(interior.is_walkable(Vector2i(4, 1)), "back wall")
	assert_false(interior.is_walkable(Vector2i(1, 3)), "second tile of the bed")
	assert_false(interior.is_walkable(Vector2i(6, 5)), "second tile of the table")
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
	var interior := _enter_kate()
	for i in 20:
		_state.player.move(interior, Vector2.LEFT, 0.1)
	assert_eq(_state.player.tile(), Vector2i(1, 6))
	assert_true(_state.player.position.x >= 1.0 + PlayerState.BODY_HALF_WIDTH)


func test_the_door_is_only_a_door_on_its_tile() -> void:
	_stand_on(_kate.door_tile() + Vector2i.DOWN)
	assert_false(_state.door_underfoot())
	_stand_on(_kate.door_tile())
	assert_true(_state.door_underfoot())


func test_walking_through_the_door_enters_at_the_entry_tile() -> void:
	var interior := _enter_kate()
	assert_true(_state.is_inside())
	assert_eq(_state.player.tile(), interior.entry_tile())
	assert_false(_state.door_underfoot())


func test_the_exit_leads_to_the_tile_south_of_the_door() -> void:
	var interior := _enter_kate()
	_stand_on(interior.exit_tile)
	assert_true(_state.door_underfoot())
	_state.pass_door()
	assert_false(_state.is_inside())
	assert_eq(_state.current_map, _state.world)
	assert_eq(_state.player.tile(), _kate.door_tile() + Vector2i.DOWN)
	assert_false(_state.door_underfoot())


func test_each_building_keeps_its_own_interior() -> void:
	var second := _state.world.place_building(BuildingTypes.KATE, _kate.origin + Vector2i(8, 0))
	var first_interior := _enter_kate()
	first_interior.add_object(WorldObject.new(WorldObjectTypes.CHEST, Vector2i(3, 5)))
	_stand_on(first_interior.exit_tile)
	_state.pass_door()
	_stand_on(second.door_tile())
	_state.pass_door()
	var second_interior := _state.current_map as Interior
	assert_ne(second_interior, first_interior)
	assert_null(second_interior.object_at(Vector2i(3, 5)))
	_stand_on(second_interior.exit_tile)
	_state.pass_door()
	assert_eq(_enter_kate(), first_interior)
	assert_not_null(first_interior.object_at(Vector2i(3, 5)))


func test_the_bed_is_in_reach_from_beside_it_and_sleeping_sets_home_there() -> void:
	var interior := _enter_kate()
	assert_null(_state.bed_in_reach())
	_stand_on(Vector2i(2, 3))
	var bed := _state.bed_in_reach()
	assert_eq(bed, interior.object_at(Vector2i(1, 2)))
	_state.clock.set_time(22, 0)
	_state.sleep_in(bed)
	assert_eq(_state.clock.time_text(), "06:30")
	assert_eq(_state.player.home_map, interior)
	assert_eq(_state.player.home_bed, Vector2i(1, 2))


func test_new_game_home_is_in_the_world() -> void:
	var state := GameState.new_game(7)
	assert_eq(state.player.home_map, state.world)


func test_use_does_nothing_inside() -> void:
	_enter_kate()
	for tile in [Vector2i(3, 3), Vector2i(3, 2), Vector2i(0, 0)]:
		assert_eq(_state.use_at(tile), GameState.Use.NOTHING)


func test_wall_tiles_get_their_picture_from_their_place() -> void:
	var size := Vector2i(9, 8)
	var wall := Tile.new()
	wall.terrain = Tile.Terrain.WALL
	var floor_tile := Tile.new()
	floor_tile.terrain = Tile.Terrain.FLOOR
	var cases := {
		Vector2i(4, 0): InteriorView.Ground.BACK_TOP,
		Vector2i(4, 1): InteriorView.Ground.BACK_BOTTOM,
		Vector2i(0, 0): InteriorView.Ground.BACK_LEFT_TOP,
		Vector2i(8, 1): InteriorView.Ground.BACK_RIGHT_BOTTOM,
		Vector2i(0, 4): InteriorView.Ground.RIM_LEFT,
		Vector2i(8, 4): InteriorView.Ground.RIM_RIGHT,
		Vector2i(3, 7): InteriorView.Ground.RIM_FRONT,
		Vector2i(0, 7): InteriorView.Ground.FRONT_LEFT,
		Vector2i(8, 7): InteriorView.Ground.FRONT_RIGHT,
	}
	for pos: Vector2i in cases:
		assert_eq(InteriorView.ground_at(wall, pos, size, false), cases[pos], "wall at %s" % pos)
	var shaded := InteriorView.ground_at(floor_tile, Vector2i(3, 2), size, false)
	assert_eq(shaded, InteriorView.Ground.FLOOR_SHADED)
	var lit := InteriorView.ground_at(floor_tile, Vector2i(3, 4), size, false)
	assert_eq(lit, InteriorView.Ground.FLOOR)
	var mat := InteriorView.ground_at(floor_tile, Vector2i(4, 7), size, true)
	assert_eq(mat, InteriorView.Ground.DOORMAT)


func test_the_view_shows_furniture_and_lights_the_hearth() -> void:
	var view := InteriorView.new()
	add_child_autofree(view)
	view.show_interior(InteriorLoader.load_interior(KATE_MAP))
	assert_eq(view.entities.get_child_count(), 8)
	var lights := view.get_children().filter(func(node: Node) -> bool: return node is ObjectLight)
	assert_eq(lights.size(), 1)
