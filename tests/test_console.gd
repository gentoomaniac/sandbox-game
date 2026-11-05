extends EnergyCase
## The console's commands (the cheats' effects are in test_cheats.gd).

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


func _tile_where(is_walkable: bool) -> Vector2i:
	var origin := _state.player.tile()
	for y in range(-SEARCH, SEARCH):
		for x in range(-SEARCH, SEARCH):
			var tile := origin + Vector2i(x, y)
			if _world.is_walkable(tile) == is_walkable and _world.tile_at(tile) != null:
				return tile
	fail_test("no such tile near the camp")
	return origin


# --- Parsing ---


func test_an_empty_line_does_nothing() -> void:
	assert_eq(_console.run("   "), [] as Array[String])


func test_a_leading_slash_and_extra_spaces_are_fine() -> void:
	assert_eq(_console.run("  /GOD  "), ["God mode on"] as Array[String])
	assert_true(_state.cheats.is_god)


func test_an_unknown_command_is_named() -> void:
	assert_eq(_console.run("fly"), ["Unknown command: fly (try help)"] as Array[String])


func test_help_lists_every_command() -> void:
	var text := "\n".join(_console.run("help"))
	for command: String in Console.COMMANDS:
		assert_string_contains(text, command)


# --- tp ---


func _place_house() -> Building:
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := _state.player.tile() + Vector2i(x, y)
			if _world.placement_blockers(BuildingTypes.SMALL_HOUSE, origin).is_empty():
				return _world.place_building(BuildingTypes.SMALL_HOUSE, origin)
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


func test_tp_refuses_inside_a_house() -> void:
	var house := _place_house()
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_eq(_console.run("tp 0 0"), ["Can't teleport inside a house"] as Array[String])


func test_tp_to_an_unloaded_chunk_checks_it_and_leaves_it_unloaded() -> void:
	var far := Vector2i(Chunk.CHUNK_SIZE * 6, 0)
	var coords := Chunk.world_to_chunk(far)
	assert_false(_world.is_chunk_loaded(coords))
	var generated := WorldGenerator.new(_world.world_seed).generate_chunk(coords)
	var walkable := generated.tile_at(Chunk.local_pos(far)).is_walkable()
	var output := _console.run("tp %d %d" % [far.x, far.y])
	assert_eq(output[0].begins_with("Teleported"), walkable and _world.object_at(far) == null)
	assert_false(_world.is_chunk_loaded(coords))


# --- give ---


func test_give_defaults_to_one() -> void:
	var before := _count(ItemTypes.STONE)
	assert_eq(_console.run("give stone"), ["Gave 1 Stone"] as Array[String])
	assert_eq(_count(ItemTypes.STONE), before + 1)


func test_give_with_a_count() -> void:
	var before := _count(ItemTypes.WOOD)
	_console.run("/give WOOD 5")
	assert_eq(_count(ItemTypes.WOOD), before + 5)


func test_give_tells_what_did_not_fit() -> void:
	_fill_inventory()
	var output := _console.run("give wood 5")
	assert_true(output.has("Inventory full: 5 not added"))
	assert_eq(_count(ItemTypes.WOOD), 0)


func test_give_names_an_unknown_item_and_guesses() -> void:
	assert_eq(
		_console.run("give wod"), ["Unknown item: wod", "Did you mean: wood"] as Array[String]
	)
	assert_eq(_console.run("give qqqqqq"), ["Unknown item: qqqqqq"] as Array[String])


func test_give_with_wrong_arguments_shows_the_usage() -> void:
	for line in ["give", "give wood 0", "give wood -2", "give wood x", "give wood 1 2"]:
		assert_eq(_console.run(line), ["Usage: give <item> [count]"] as Array[String], line)


# --- Completion ---


func test_complete_a_command_name() -> void:
	assert_eq(_console.complete("gi"), "give ")
	assert_eq(_console.complete("/no"), "/no")
	assert_eq(_console.complete("/nod"), "/nodrain ")


func test_complete_goes_as_far_as_the_candidates_agree() -> void:
	assert_eq(_console.complete("n"), "no")


func test_complete_an_item_after_give() -> void:
	assert_eq(_console.complete("give tur"), "give turnip")
	assert_eq(_console.complete("give sto"), "give stone ")
	assert_eq(_console.complete("/give pick"), "/give pickaxe ")


func test_complete_leaves_other_words_alone() -> void:
	assert_eq(_console.complete("give wood 5"), "give wood 5")
	assert_eq(_console.complete("tp 1"), "tp 1")
	assert_eq(_console.complete("give zzz"), "give zzz")
