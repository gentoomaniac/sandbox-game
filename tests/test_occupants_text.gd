extends GutTest
## What the hover box over a building says (Households `occupants_text`): its name, who lives
## there and how many places are taken, and who works there.

var _state: GameState


func before_each() -> void:
	_state = GameState.new()


func _villager(villager_id: String) -> Npc:
	var npc := Npc.create_villager(villager_id, Vector2(5, 5), _state.npcs.villagers)
	_state.npcs.add(npc)
	return npc


func test_an_empty_house_says_nobody_lives_there_and_how_many_places_are_free() -> void:
	var house := Building.new(BuildingTypes.HALL_HOUSE, Vector2i(2, 2))

	assert_eq(
		_state.homes.occupants_text(house), "Hall house\nNobody lives here\n0 of 5 places taken"
	)


func test_a_house_names_its_household() -> void:
	var house := Building.new(BuildingTypes.HALL_HOUSE, Vector2i(2, 2))
	_state.homes.move_in(_villager("antje"), house)
	_state.homes.move_in(_villager("hinrich"), house)

	assert_eq(
		_state.homes.occupants_text(house),
		"Hall house\nLives here: Antje Boysen, Hinrich Boysen\n2 of 5 places taken"
	)


func test_a_building_nobody_lives_in_says_who_works_there() -> void:
	var barn := Building.new(BuildingTypes.BARN, Vector2i(2, 2))
	_villager("antje").workplace = Workplace.of_building(barn)

	assert_eq(_state.homes.occupants_text(barn), "Barn\nWorks here: Antje Boysen")


func test_a_building_with_neither_residents_nor_workers_is_only_named() -> void:
	var barn := Building.new(BuildingTypes.BARN, Vector2i(2, 2))

	assert_eq(_state.homes.occupants_text(barn), "Barn")


func test_a_house_can_also_be_a_workplace() -> void:
	var house := Building.new(BuildingTypes.HALL_HOUSE, Vector2i(2, 2))
	var antje := _villager("antje")
	_state.homes.move_in(antje, house)
	antje.workplace = Workplace.of_building(house)

	assert_eq(
		_state.homes.occupants_text(house),
		"Hall house\nLives here: Antje Boysen\n1 of 5 places taken\nWorks here: Antje Boysen"
	)
