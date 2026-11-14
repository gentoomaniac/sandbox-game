extends GutTest
## The hammer's menu on a building: what it offers the villagers near (Households `offers`) and
## how the dialog gives a house or a workplace (HouseMenu).

var _state: GameState
var _house: Building
var _dialog: ChoiceDialog
var _menu: HouseMenu


func before_each() -> void:
	_state = GameState.new()
	_house = Building.new(BuildingTypes.HALL_HOUSE, Vector2i(2, 2))
	_dialog = ChoiceDialog.new()
	add_child_autofree(_dialog)
	_menu = HouseMenu.new(_dialog, _state.homes)


func after_each() -> void:
	get_tree().paused = false


## A villager of data/villagers.cfg `distance` tiles east of the house.
func _villager(villager_id: String, distance := 3.0) -> Npc:
	var feet := _house.centre() + Vector2(distance, 0.0)
	var npc := Npc.create_villager(villager_id, feet, _state.npcs.villagers)
	_state.npcs.add(npc)
	return npc


func _texts(offers: Array[Dictionary]) -> Array[String]:
	var texts: Array[String] = []
	for offer in offers:
		texts.append(offer["text"])
	return texts


## Opens the menu on the house and returns when it has answered and the dialog has finished
## closing (it must not be freed while it still emits).
func _open_the_menu() -> void:
	await _menu.open(_house)
	await get_tree().process_frame


## Presses the button at `index` of the dialog as soon as it opens.
func _press_when_opened(index: int) -> void:
	_dialog.opened.connect(
		func() -> void: _dialog._buttons.get_child(index).pressed.emit.call_deferred(),
		CONNECT_ONE_SHOT
	)


func test_the_villagers_near_are_offered_the_house_and_then_the_workplace() -> void:
	var antje := _villager("antje", 2.0)
	_villager("momme", 4.0)
	_villager("ocke", 100.0)
	_state.homes.move_in(antje, Building.new(BuildingTypes.KATE, Vector2i(20, 2)))

	assert_eq(
		_texts(_state.homes.offers(_house)),
		(
			[
				"Move Antje Boysen in",
				"Give to Momme Ketels",
				"Antje Boysen works here",
				"Momme Ketels works here",
			]
			as Array[String]
		)
	)


func test_a_villager_the_house_would_refuse_is_not_offered_it() -> void:
	_state.homes.move_in(_villager("antje"), _house)
	_villager("momme", 4.0)

	assert_eq(
		_texts(_state.homes.offers(_house)),
		["Antje Boysen works here", "Momme Ketels works here"] as Array[String]
	)


func test_a_villager_who_works_there_already_is_not_offered_it_again() -> void:
	var antje := _villager("antje")
	antje.workplace = Workplace.of_building(_house)

	assert_eq(_texts(_state.homes.offers(_house)), ["Give to Antje Boysen"] as Array[String])


func test_choosing_an_offer_gives_the_house_or_the_workplace() -> void:
	var antje := _villager("antje")
	var offers := _state.homes.offers(_house)

	_state.homes.accept(offers[0], _house)
	_state.homes.accept(offers[1], _house)

	assert_eq(antje.house, _house)
	assert_eq(antje.workplace.building, _house)


func test_the_dialog_gives_the_house_to_the_villager_whose_button_is_pressed() -> void:
	var antje := _villager("antje")
	_press_when_opened(0)

	await _open_the_menu()

	assert_string_contains(_dialog._title.text, "Hall house")
	assert_eq(antje.house, _house)
	assert_null(antje.workplace)


func test_the_dialog_gives_the_workplace_with_the_second_button() -> void:
	var antje := _villager("antje")
	_press_when_opened(1)

	await _open_the_menu()

	assert_null(antje.house)
	assert_eq(antje.workplace.building, _house)


func test_close_changes_nothing_and_the_dialog_says_who_lives_there() -> void:
	_state.homes.move_in(_villager("hinrich"), _house)
	var antje := _villager("antje", 4.0)
	_dialog.opened.connect(
		func() -> void:
			assert_string_contains(_dialog._text.text, "Lives here: Hinrich Boysen.")
			var close := _dialog._buttons.get_child(_dialog._buttons.get_child_count() - 1)
			close.pressed.emit.call_deferred(),
		CONNECT_ONE_SHOT
	)

	await _open_the_menu()

	assert_null(antje.house)
	assert_null(antje.workplace)


func test_with_nobody_near_it_says_so() -> void:
	_dialog.opened.connect(
		func() -> void: _dialog._buttons.get_child(0).pressed.emit.call_deferred(), CONNECT_ONE_SHOT
	)

	await _open_the_menu()

	assert_eq(_dialog._text.text, "Nobody lives here. Nobody near can be given it.")
