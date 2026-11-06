extends EnergyCase
## The console's commands (the cheats' effects are in test_cheats.gd).

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


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


# --- give ---


func test_give_defaults_to_one() -> void:
	var before := _count(ItemTypes.STONE)
	assert_eq(_console.run("give stone"), ["Gave 1 Stone"] as Array[String])
	assert_eq(_count(ItemTypes.STONE), before + 1)


func test_give_with_a_count() -> void:
	var before := _count(ItemTypes.LOGS)
	_console.run("/give LOGS 5")
	assert_eq(_count(ItemTypes.LOGS), before + 5)


func test_give_tells_what_did_not_fit() -> void:
	_fill_inventory()
	var output := _console.run("give logs 5")
	assert_true(output.has("Inventory full: 5 not added"))
	assert_eq(_count(ItemTypes.LOGS), 0)


func test_give_names_an_unknown_item_and_guesses() -> void:
	assert_eq(
		_console.run("give lgs"), ["Unknown item: lgs", "Did you mean: logs"] as Array[String]
	)
	assert_eq(_console.run("give qqqqqq"), ["Unknown item: qqqqqq"] as Array[String])


func test_give_with_wrong_arguments_shows_the_usage() -> void:
	for line in ["give", "give logs 0", "give logs -2", "give logs x", "give logs 1 2"]:
		assert_eq(_console.run(line), ["Usage: give <item> [count]"] as Array[String], line)


func test_give_puts_crop_seeds_and_produce_in_the_inventory() -> void:
	_console.run("give carrot_seeds 5")
	_console.run("give strawberries 2")
	assert_eq(_state.player.inventory.count_of(&"carrot_seeds"), 5)
	assert_eq(_state.player.inventory.count_of(&"strawberries"), 2)


func test_crop_shows_the_crop_in_front_or_the_nearest_one() -> void:
	assert_eq(_console.run("crop"), ["No crop near you"] as Array[String])
	var tile := _tile_where(true)
	_world.set_terrain(tile + Vector2i(2, 0), Tile.Terrain.SOIL)
	var crop := WorldObject.new(&"peas", tile + Vector2i(2, 0))
	crop.state["growth"] = 4.0
	_world.add_object(crop)
	_world.set_moisture(crop.pos, 0.55)
	_state.player.position = Vector2(tile) + Vector2(0.5, 0.5)
	var lines := _console.run("crop")
	assert_true(lines[0].begins_with("Peas: stage 2"), lines[0])
	assert_true("growth 4.0" in lines[0])
	assert_eq(lines.size(), 4)
	assert_eq(lines[3], "Soil moisture 0.55")


func test_weather_shows_the_aggregate_of_the_day() -> void:
	var lines := _console.run("weather")
	assert_true(lines.any(func(line: String) -> bool: return line.begins_with("Today: ")))
