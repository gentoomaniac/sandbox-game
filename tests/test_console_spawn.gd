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
