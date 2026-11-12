extends ResourceCase
## The console's `spawn` command for farm animals (wild ones: test_wildlife_art.gd).

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


func test_spawn_puts_farm_animals_near_the_player() -> void:
	assert_eq(_console.run("spawn cow 3"), ["Spawned 3 of 3 cow"] as Array[String])
	var cows := _state.livestock.all()
	assert_eq(cows.size(), 3)
	for cow in cows:
		assert_eq(cow.species, LivestockRules.COW)
		assert_lte(cow.position.distance_to(_state.player.position), Livestock.SPAWN_DISTANCE.y)


func test_a_rabbit_is_a_tame_one_and_a_wild_rabbit_is_wildlife() -> void:
	var asked := []
	_console.wildlife_spawner = func(kind: StringName, count: int) -> int:
		asked.append([kind, count])
		return count
	_console.run("spawn rabbit")
	_console.run("spawn wild_rabbit 2")
	assert_eq(_state.livestock.all().size(), 1)
	assert_eq(_state.livestock.all()[0].species, LivestockRules.RABBIT)
	assert_eq(asked, [[WildlifeRules.RABBIT, 2]])


func test_no_farm_animals_are_spawned_in_a_house() -> void:
	var house := _place_house()
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_eq(_console.run("spawn sheep"), ["No animals here"] as Array[String])
	assert_eq(_state.livestock.all().size(), 0)


func test_spawn_offers_the_farm_animals_and_the_wild_rabbit() -> void:
	assert_eq(_console.complete("spawn co"), "spawn cow ")
	assert_eq(_console.complete("spawn ch"), "spawn chicken ")
	assert_eq(_console.complete("spawn wi"), "spawn wild_rabbit ")
	assert_eq(_console.complete("help sp"), "help spawn ")


func test_spawn_without_a_name_lists_what_can_be_spawned() -> void:
	var lines := _console.run("spawn")
	var text := "\n".join(lines)
	for kind in _console.candidates(&"animal"):
		assert_string_contains(text, kind)
	assert_string_contains(text, "wild_rabbit")
	assert_eq(_state.livestock.all().size(), 0)


func test_an_unknown_animal_is_named_and_the_list_follows() -> void:
	var lines := _console.run("spawn unicorn")
	assert_eq(lines[0], "Unknown animal: unicorn")
	assert_string_contains("\n".join(lines), "squirrel")


func test_help_spawn_lists_what_can_be_spawned() -> void:
	var lines := _console.run("help spawn")
	assert_string_contains(lines[0], "spawn <kind> [count]")
	assert_string_contains("\n".join(lines), "cow")


func test_a_long_list_wraps_into_lines_that_fit_the_log() -> void:
	for line in _console.run("spawn"):
		assert_lte(line.length(), Console.LIST_LINE_LENGTH)


func test_help_lists_the_names_of_every_command_that_takes_names() -> void:
	assert_string_contains("\n".join(_console.run("help weather")), "thunder")
	assert_string_contains("\n".join(_console.run("help snow")), "auto")
	assert_eq(_console.run("help god").size(), 1)
	assert_eq(
		_console.run("help nonsense"), ["Unknown command: nonsense (try help)"] as Array[String]
	)


func test_spawn_rooster_puts_roosters_only() -> void:
	assert_eq(_console.run("spawn rooster 2"), ["Spawned 2 of 2 rooster"] as Array[String])

	var animals := _state.livestock.all()
	assert_eq(animals.size(), 2)
	for animal in animals:
		assert_true(animal.is_rooster())


func test_spawn_chicken_brings_a_rooster_along_and_killall_rooster_removes_only_it() -> void:
	_console.run("spawn chicken 3")
	assert_eq(_state.livestock.all().size(), 4)

	assert_eq(_console.run("killall rooster"), ["Removed 1 rooster"] as Array[String])

	assert_eq(_state.livestock.all().size(), 3)
	assert_eq(_console.run("killall rooster"), ["No rooster to remove"] as Array[String])


func test_spawn_offers_the_rooster() -> void:
	assert_eq(_console.complete("spawn roos"), "spawn rooster ")
