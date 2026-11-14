extends GutTest
## The console's `home` and `work` show, give and free the house and the workplace of a villager,
## and `spawn npc` settles a villager of the sheets in the house their sheet names.

var _state: GameState
var _console: Console
var _house: Building
var _antje: Npc
var _momme: Npc


func before_each() -> void:
	_state = GameState.new_game(7)
	_console = Console.new(_state)
	_house = _place(BuildingTypes.KATE)
	_antje = _add("antje")
	_momme = _add("momme")
	_stand_at_the_door()


func _place(building_type: StringName) -> Building:
	var around := _state.player.tile()
	for y in range(-12, 13):
		for x in range(-12, 13):
			var building := _state.world.place_building(building_type, around + Vector2i(x, y))
			if building != null:
				return building
	fail_test("no room for a building")
	return null


func _add(villager_id: String) -> Npc:
	var npc := Npc.create_villager(villager_id, Vector2.ZERO, _state.npcs.villagers)
	_state.npcs.add(npc)
	return npc


func _stand_at_the_door() -> void:
	_state.player.position = _house.yard()


func test_a_villager_with_no_home_says_so() -> void:
	assert_eq(_console.run("home antje"), ["Antje Boysen has no home"] as Array[String])


func test_here_gives_the_house_at_whose_door_the_player_stands() -> void:
	var lines := _console.run("home antje here")

	assert_eq(_antje.house, _house)
	assert_eq(lines, ["Antje Boysen lives in the Kate (%s)" % _house.origin] as Array[String])
	assert_eq(_console.run("home antje"), lines)
	assert_eq(_antje.anchor, _house.yard())


func test_here_inside_a_house_gives_that_house() -> void:
	_state.player.position = Vector2(_house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_true(_state.is_inside())

	_console.run("home antje here")

	assert_eq(_antje.house, _house)


func test_here_far_from_any_building_gives_nothing() -> void:
	_state.player.position = _house.yard() + Vector2(30.0, 0.0)

	assert_eq(
		_console.run("home antje here"),
		["No building here: stand at a door, or inside"] as Array[String]
	)
	assert_null(_antje.house)


func test_a_house_that_will_not_take_them_says_why() -> void:
	_console.run("home antje here")

	assert_eq(
		_console.run("home momme here"), ["Only one household lives in a house."] as Array[String]
	)
	assert_null(_momme.house)


func test_none_frees_the_villager() -> void:
	_console.run("home antje here")

	assert_eq(_console.run("home antje none"), ["Antje Boysen has no home now"] as Array[String])
	assert_null(_antje.house)


func test_work_here_at_a_building_gives_it_as_the_workplace() -> void:
	var lines := _console.run("work antje here")

	assert_eq(_antje.workplace.building, _house)
	assert_eq(lines, ["Antje Boysen works at the Kate (%s)" % _house.origin] as Array[String])


func test_work_here_on_open_ground_gives_the_spot_the_sheet_names() -> void:
	var spot := _house.yard() + Vector2(30.0, 0.0)
	_state.player.position = spot

	var lines := _console.run("work momme here")

	assert_eq(_momme.workplace.label(), "the landing at the sluice")
	assert_eq(_momme.workplace.spot_tile, Vector2i(spot.floor()))
	assert_eq(
		lines,
		(
			["Momme Ketels works at the landing at the sluice (%s)" % Vector2i(spot.floor())]
			as Array[String]
		)
	)


func test_a_spot_of_a_villager_whose_sheet_names_none_is_just_a_spot() -> void:
	_state.player.position = _house.yard() + Vector2(30.0, 0.0)

	_console.run("work antje here")

	assert_eq(_antje.workplace.label(), "a spot")


func test_work_none_frees_the_villager() -> void:
	_console.run("work antje here")

	assert_eq(
		_console.run("work antje none"), ["Antje Boysen has no workplace now"] as Array[String]
	)
	assert_null(_antje.workplace)
	assert_eq(_console.run("work antje"), ["Antje Boysen has no workplace"] as Array[String])


func test_a_made_up_villager_can_be_named_by_first_name() -> void:
	var other := Npc.create(42, Vector2.ZERO, _state.npcs.rules)
	_state.npcs.add(other)

	_console.run("home %s here" % other.name.get_slice(" ", 0).to_lower())

	assert_eq(other.house, _house)


func test_a_wrong_line_gives_the_usage_or_the_names() -> void:
	assert_eq(_console.run("home"), ["Usage: home <villager> [here|none]"] as Array[String])
	assert_eq(
		_console.run("work antje there"), ["Usage: work <villager> [here|none]"] as Array[String]
	)
	var lines := _console.run("home nobody")
	assert_eq(lines[0], "Unknown villager: nobody")
	assert_string_contains("\n".join(lines), "antje")


func test_tab_completes_the_villager_and_here_or_none() -> void:
	assert_eq(_console.complete("home an"), "home antje ")
	assert_eq(_console.complete("work antje h"), "work antje here ")
	assert_eq(_console.complete("work antje n"), "work antje none ")


func test_a_villager_spawned_with_a_house_standing_settles_in_it() -> void:
	var hut := _place(BuildingTypes.FISHER_HUT)
	_state.npcs.remove(_momme)

	_console.run("spawn npc momme")

	assert_eq(_state.npcs.find("momme").house, hut)
