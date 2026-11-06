extends ResourceCase
## The console's noclip: the player walks through water, trees and walls, but never off the
## map's tiles (out of the room, or onto ground that isn't loaded); turned off where they don't
## fit, they are put on the nearest free ground, never on a building.


func before_each() -> void:
	super.before_each()
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	for x in range(1, 4):
		_world.set_terrain(_tile + Vector2i(x, 0), Tile.Terrain.WATER)
		for y in [-1, 1]:
			_world.set_terrain(_tile + Vector2i(x, y), Tile.Terrain.GRASS)
			_world.remove_object(_tile + Vector2i(x, y))


func _walk_right(seconds: float) -> void:
	_state.walk(Vector2.RIGHT, seconds)


func test_the_toggle_is_named_on_the_hud() -> void:
	var console := Console.new(_state)
	assert_eq(console.run("noclip"), ["No clip on"] as Array[String])
	assert_eq(_state.cheats.active_names(), ["No clip"] as Array[String])
	assert_eq(console.run("noclip"), ["No clip off"] as Array[String])
	assert_eq(_state.cheats.active_names(), [] as Array[String])


func test_without_it_the_water_stops_the_player() -> void:
	_walk_right(2.0)
	assert_lt(_state.player.position.x, float(_tile.x + 1))


func test_with_it_the_player_walks_through_the_water() -> void:
	_state.cheats.is_noclip = true
	_walk_right(2.0)
	assert_gt(_state.player.position.x, float(_tile.x + 4))


func test_with_it_the_player_stays_on_loaded_ground() -> void:
	_state.cheats.is_noclip = true
	for _i in 60:
		_walk_right(10.0)
	var feet := _state.player.position
	_walk_right(10.0)
	assert_eq(_state.player.position, feet, "the edge of the loaded ground stops them")
	assert_not_null(_world.tile_at(_state.player.tile()))


func test_a_noclip_walk_wears_no_path() -> void:
	var tile := _tile + Vector2i(2, -1)
	var stage := _world.wear_stage(tile)
	_state.cheats.is_noclip = true
	_state.player.position = Vector2(_tile) + Vector2(0.5, -0.5)
	for _i in 20:
		_walk_right(1.0)
		_state.walk(Vector2.LEFT, 1.0)
	assert_eq(_world.wear_stage(tile), stage)


func test_turned_off_in_the_water_the_player_is_put_on_the_nearest_ground() -> void:
	var console := Console.new(_state)
	console.run("noclip")
	_state.player.position = Vector2(_tile + Vector2i(2, 0)) + Vector2(0.5, 0.5)
	assert_eq(console.run("noclip"), ["No clip off"] as Array[String])
	assert_eq(_state.player.position, Vector2(_tile + Vector2i(2, -1)) + Vector2(0.5, 0.5))


func test_with_no_free_ground_within_reach_the_player_stays() -> void:
	for y in range(-2, 3):
		for x in range(-2, 3):
			_world.set_terrain(_tile + Vector2i(x, y), Tile.Terrain.WATER)
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	assert_false(_state.put_player_on_free_ground(1))
	assert_eq(_state.player.position, Vector2(_tile) + Vector2(0.5, 0.5))


func test_turned_off_in_a_bed_the_player_stays_lying_in_it() -> void:
	var bed := _world.object_at(_state.player.home_bed)
	_state.player.bed_lying_in = bed
	_state.player.position = Vector2(_tile + Vector2i(2, 0)) + Vector2(0.5, 0.5)
	var console := Console.new(_state)
	console.run("noclip")
	console.run("noclip")
	assert_eq(_state.player.bed_lying_in, bed)
	assert_eq(_state.player.position, Vector2(_tile + Vector2i(2, 0)) + Vector2(0.5, 0.5))


func test_turned_off_in_a_house_the_player_is_put_outside_it_not_through_its_door() -> void:
	var house := _placed_shack()
	_state.player.position = Vector2(house.door_tile() + Vector2i.UP) + Vector2(0.5, 0.5)
	var console := Console.new(_state)
	console.run("noclip")
	console.run("noclip")
	var body := PlayerState.body_tiles(_state.player.position)
	for y in range(body.position.y, body.end.y):
		for x in range(body.position.x, body.end.x):
			assert_null(_world.building_at(Vector2i(x, y)), "not on the house or its door")
	assert_true(PlayerState.can_stand_at(_world, _state.player.position))


func _placed_shack() -> Building:
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := _tile + Vector2i(x, y) + Vector2i(0, 4)
			if _world.placement_blockers(BuildingTypes.SHACK, origin).is_empty():
				return _world.place_building(BuildingTypes.SHACK, origin)
	fail_test("no room for a shack")
	return null
