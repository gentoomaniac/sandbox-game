extends ResourceCase
## The console's noclip: the player walks through water, trees and walls, but never off the
## map's tiles (out of the room, or onto ground that isn't loaded).


func before_each() -> void:
	super.before_each()
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	for x in range(1, 4):
		_world.set_terrain(_tile + Vector2i(x, 0), Tile.Terrain.WATER)


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
	assert_not_null(_world.tile_at(_state.player.tile()), "never off the loaded tiles")
	var feet := _state.player.position
	_walk_right(10.0)
	assert_eq(_state.player.position, feet, "the edge of the loaded ground stops them")


func test_turned_off_in_the_water_the_player_is_put_on_the_nearest_ground() -> void:
	var console := Console.new(_state)
	console.run("noclip")
	_state.player.position = Vector2(_tile + Vector2i(2, 0)) + Vector2(0.5, 0.5)
	console.run("noclip")
	assert_true(PlayerState.can_stand_at(_world, _state.player.position))
	assert_lt(_state.player.position.distance_to(Vector2(_tile) + Vector2(2.5, 0.5)), 2.0)
