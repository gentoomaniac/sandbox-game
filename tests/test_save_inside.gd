extends SaveValidationCase
## Where a villager is when they are inside a building is saved (version 48); a save from before it
## (version 47) has nobody inside.

var _state: GameState
var _house: Building


func before_each() -> void:
	_state = GameFactory.new_game(7)
	var origin := _state.player.tile() + Vector2i(8, 8)
	for y in range(-1, 8):
		for x in range(-1, 8):
			_state.world.remove_object(origin + Vector2i(x, y))
			_state.world.set_terrain(origin + Vector2i(x, y), Tile.Terrain.GRASS)
	_house = _state.world.place_building(BuildingTypes.KATE, origin)
	assert_not_null(_house)


func _villager_inside() -> Npc:
	var antje := Npc.create_villager("antje", _house.yard(), _state.npcs.villagers)
	antje.house = _house
	_state.npcs.add(antje)
	_state.npcs.indoors.go_in(antje, _house, true)
	return antje


func _saved_villager() -> Dictionary:
	var npc := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())
	return JSON.parse_string(JSON.stringify(npc.to_dict()))


func test_a_villager_inside_is_still_inside_after_a_save_and_a_load() -> void:
	var antje := _villager_inside()
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var loaded_state := SaveFile.read(SAVE_PATH)
	var loaded := loaded_state.npcs.all()[0]

	assert_same(loaded.inside, loaded_state.world.building_at(_house.origin))
	assert_eq(loaded.inside_position, antje.inside_position)
	assert_eq(loaded.position, _house.yard())
	assert_null(loaded.entering)


func test_a_villager_in_the_open_is_kept_so() -> void:
	_state.npcs.add(Npc.create_villager("antje", Vector2(3.5, 4.5), _state.npcs.villagers))
	assert_true(SaveFile.write(_state, SAVE_PATH))

	assert_null(SaveFile.read(SAVE_PATH).npcs.all()[0].inside)


func test_a_loaded_villager_whose_day_has_them_in_the_house_stays_in_it() -> void:
	var antje := _villager_inside()
	_state.clock.minute_of_day = 22 * 60
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq(loaded.current_step.activity, "sleep")
	assert_not_null(loaded.inside)
	assert_eq(loaded.inside_position, antje.inside_position)


func test_a_version_47_save_has_nobody_inside() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	saved.erase("inside")
	game["npcs"] = [saved]
	_write_save(47, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()

	assert_eq(loaded.size(), 1)
	assert_null(loaded[0].inside)


func test_a_save_without_inside_is_refused() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	saved.erase("inside")
	game["npcs"] = [saved]

	assert_true(_refusal_of(game).problems.has("npcs 0: no inside"))


func test_a_villager_inside_a_building_that_is_not_there_is_refused() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	saved["inside"] = {"building": [900, 900], "position": [2.5, 3.5]}
	game["npcs"] = [saved]

	var problems: Array = _refusal_of(game).problems

	assert_eq(problems, ["npcs 0 inside: building: no building at (900, 900)"], str(problems))
