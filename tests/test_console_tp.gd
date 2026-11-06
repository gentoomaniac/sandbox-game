extends EnergyCase
## The console's `tp` command.

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


func _place_house() -> Building:
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := _state.player.tile() + Vector2i(x, y)
			if _world.placement_blockers(BuildingTypes.KATE, origin).is_empty():
				return _world.place_building(BuildingTypes.KATE, origin)
	fail_test("no room for a house near the camp")
	return null


func test_tp_moves_the_player_to_the_tile_centre() -> void:
	var tile := _tile_where(true)
	assert_eq(_console.run("tp %d %d" % [tile.x, tile.y]).size(), 1)
	assert_eq(_state.player.position, Vector2(tile) + Vector2(0.5, 0.5))


func test_tp_with_wrong_arguments_shows_the_usage() -> void:
	var before := _state.player.position
	for line in ["tp", "tp 1", "tp 1 2 3", "tp a b", "tp 1.5 2"]:
		assert_eq(_console.run(line), ["Usage: tp <x> <y>"] as Array[String], line)
	assert_eq(_state.player.position, before)


func test_tp_refuses_a_tile_that_cannot_be_walked_on() -> void:
	var tile := _tile_where(false)
	var before := _state.player.position
	assert_eq(
		_console.run("tp %d %d" % [tile.x, tile.y]),
		["Can't walk on tile %d, %d" % [tile.x, tile.y]] as Array[String]
	)
	assert_eq(_state.player.position, before)


func test_tp_refuses_a_tile_outside_the_world() -> void:
	var before := _state.player.position
	assert_string_contains(_console.run("tp 99999999 0")[0], "outside the world")
	assert_eq(_state.player.position, before)


func test_tp_refuses_a_tile_covered_by_a_building_door_included() -> void:
	var house := _place_house()
	var before := _state.player.position
	for tile in [house.door_tile(), house.origin]:
		assert_string_contains(
			_console.run("tp %d %d" % [tile.x, tile.y])[0], "covered by a building"
		)
	assert_eq(_state.player.position, before)


func _walk_into(house: Building) -> void:
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()


func test_tp_from_inside_a_house_steps_out_onto_the_tile() -> void:
	_walk_into(_place_house())
	var tile := _tile_where(true)
	assert_true(_state.is_inside())
	assert_eq(_console.run("tp %d %d" % [tile.x, tile.y]).size(), 1)
	assert_false(_state.is_inside())
	assert_eq(_state.current_map, _world)
	assert_eq(_state.player.position, Vector2(tile) + Vector2(0.5, 0.5))


func test_tp_from_inside_a_house_refuses_a_tile_that_cannot_be_walked_on() -> void:
	_walk_into(_place_house())
	var tile := _tile_where(false)
	var before := _state.player.position
	assert_eq(
		_console.run("tp %d %d" % [tile.x, tile.y]),
		["Can't walk on tile %d, %d" % [tile.x, tile.y]] as Array[String]
	)
	assert_true(_state.is_inside(), "a refused tp stays where it is")
	assert_eq(_state.player.position, before)


func test_tp_gets_a_player_in_bed_up() -> void:
	_state.sleep_in(_bed())
	var tile := _tile_where(true)
	_console.run("tp %d %d" % [tile.x, tile.y])
	assert_null(_state.player.bed_lying_in)


func test_tp_to_an_unloaded_chunk_checks_it_and_leaves_it_unloaded() -> void:
	var far := Vector2i(Chunk.CHUNK_SIZE * 6, 0)
	var coords := Chunk.world_to_chunk(far)
	assert_false(_world.is_chunk_loaded(coords))
	var generated := WorldGenerator.new(_world.world_seed).generate_chunk(coords)
	var walkable := generated.tile_at(Chunk.local_pos(far)).is_walkable()
	var output := _console.run("tp %d %d" % [far.x, far.y])
	assert_eq(output[0].begins_with("Teleported"), walkable and _world.object_at(far) == null)
	assert_false(_world.is_chunk_loaded(coords))
