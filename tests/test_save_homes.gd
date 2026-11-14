extends SaveValidationCase
## The house and the workplace of a villager are saved as references to buildings of the world
## (version 39); a save from before them (version 38) gives every villager none.

var _state: GameState
var _house: Building
var _shed: Building


func before_each() -> void:
	_state = GameState.new_game(7)
	_house = _place(BuildingTypes.KATE)
	_shed = _place(BuildingTypes.SHACK)
	assert_not_null(_house)
	assert_not_null(_shed)


## Places a building on the first free land near the player.
func _place(building_type: StringName) -> Building:
	var around := _state.player.tile()
	for y in range(-12, 13):
		for x in range(-12, 13):
			var building := _state.world.place_building(building_type, around + Vector2i(x, y))
			if building != null:
				return building
	return null


func _saved_villager() -> Dictionary:
	var npc := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())
	return JSON.parse_string(JSON.stringify(npc.to_dict()))


func test_the_house_and_a_building_as_workplace_are_kept() -> void:
	var antje := Npc.create_villager("antje", Vector2(3.5, 4.5), _state.npcs.villagers)
	_state.npcs.add(antje)
	_state.homes.move_in(antje, _house)
	antje.workplace = Workplace.of_building(_shed)
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	var loaded := restored.npcs.all()[0]
	assert_eq(loaded.house, restored.world.building_at(_house.origin))
	assert_eq(loaded.workplace.building, restored.world.building_at(_shed.origin))
	assert_eq(loaded.anchor, _house.yard())


func test_a_spot_as_workplace_is_kept() -> void:
	var momme := Npc.create_villager("momme", Vector2.ZERO, _state.npcs.villagers)
	momme.workplace = Workplace.of_spot("the landing at the sluice", Vector2i(-4, 9))
	_state.npcs.add(momme)
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_null(loaded.house)
	assert_null(loaded.workplace.building)
	assert_eq(loaded.workplace.label(), "the landing at the sluice")
	assert_eq(loaded.workplace.spot_tile, Vector2i(-4, 9))


func test_a_villager_without_a_house_or_workplace_is_kept_so() -> void:
	_state.npcs.add(Npc.create(42, Vector2.ZERO, _state.npcs.rules))
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_null(loaded.house)
	assert_null(loaded.workplace)


func test_a_version_38_save_gives_every_villager_no_house_and_no_workplace() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	saved.erase("house")
	saved.erase("workplace")
	game["npcs"] = [saved]
	_write_save(38, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()

	assert_eq(loaded.size(), 1)
	assert_null(loaded[0].house)
	assert_null(loaded[0].workplace)


func test_a_house_where_no_building_stands_is_refused() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	saved["house"] = [900, 900]
	game["npcs"] = [saved]

	var problems: Array = _refusal_of(game).problems

	assert_eq(problems, ["npcs 0: house: no building at (900, 900)"], str(problems))


func test_a_workplace_in_a_building_that_is_not_there_is_refused() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	saved["workplace"] = {"building": [900, 900]}
	game["npcs"] = [saved]

	var problems: Array = _refusal_of(game).problems

	assert_eq(problems, ["npcs 0 workplace: building: no building at (900, 900)"], str(problems))


func test_a_spot_without_a_name_is_refused() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	saved["workplace"] = {"spot_tile": [1, 2]}
	game["npcs"] = [saved]

	assert_true(_refusal_of(game).problems.has("npcs 0 workplace: no spot_name"))


func test_a_save_without_the_house_is_refused() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	saved.erase("house")
	game["npcs"] = [saved]

	assert_true(_refusal_of(game).problems.has("npcs 0: no house"))
