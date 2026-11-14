extends GutTest
## Who works where (Households): a building someone lives in is a workplace only for those who
## live there, and nobody moves into a house where others work (#69).

const SEED := 7
const FIRST_HALL := Vector2i(2, 2)
const SECOND_HALL := Vector2i(12, 2)
const BARN_ORIGIN := Vector2i(12, 12)

var _state: GameState
var _world: World


func before_each() -> void:
	_state = GameState.new()
	_state.world = World.new(SEED)
	_state.world.add_chunk(Chunk.new(Vector2i.ZERO))
	_state.player.home_map = _state.world
	_world = _state.world


func _hall(origin := FIRST_HALL) -> Building:
	return _world.place_building(BuildingTypes.HALL_HOUSE, origin)


## A villager of data/villagers.cfg, in the world, near the tile `at`.
func _villager(villager_id: String, at := Vector2i(8, 8)) -> Npc:
	var npc := Npc.create_villager(
		villager_id, Vector2(at) + Vector2(0.5, 0.5), _state.npcs.villagers
	)
	_state.npcs.add(npc)
	return npc


func test_a_building_someone_lives_in_is_a_workplace_only_for_those_who_live_there() -> void:
	var hall := _hall()
	var antje := _villager("antje")
	var momme := _villager("momme")
	_state.homes.move_in(antje, hall)

	assert_eq(_state.homes.give_work(antje, hall), "")
	assert_eq(antje.workplace.building, hall)
	assert_eq(
		_state.homes.give_work(momme, hall), "Only those who live in the Hall house work there."
	)
	assert_null(momme.workplace)


func test_a_building_nobody_lives_in_is_a_workplace_for_anybody() -> void:
	var barn := _world.place_building(BuildingTypes.BARN, BARN_ORIGIN)
	var momme := _villager("momme")

	assert_eq(_state.homes.give_work(momme, barn), "")
	assert_eq(momme.workplace.building, barn)


func test_nobody_moves_into_a_house_where_others_work() -> void:
	var hall := _hall()
	var antje := _villager("antje")
	var momme := _villager("momme")
	_state.homes.give_work(momme, hall)

	assert_eq(_state.homes.move_in(antje, hall), "Others work there: Momme Ketels.")
	assert_null(antje.house)


func test_one_who_works_in_a_house_may_move_into_it() -> void:
	var hall := _hall()
	var antje := _villager("antje")
	_state.homes.give_work(antje, hall)

	assert_eq(_state.homes.move_in(antje, hall), "")
	assert_eq(antje.workplace.building, hall)


func test_one_who_moves_out_of_a_house_others_still_live_in_stops_working_there() -> void:
	var hall := _hall()
	var antje := _villager("antje")
	var hinrich := _villager("hinrich")
	_state.homes.move_in(antje, hall)
	_state.homes.move_in(hinrich, hall)
	_state.homes.give_work(antje, hall)
	_state.homes.give_work(hinrich, hall)

	_state.homes.move_in(antje, _hall(SECOND_HALL))
	_state.homes.move_out(hinrich)

	assert_null(antje.workplace, "Hinrich still lived there")
	assert_eq(hinrich.workplace.building, hall, "nobody lives there now, so he may work on")


func test_the_hammer_menu_offers_work_in_a_house_only_to_those_who_live_there() -> void:
	var hall := _hall()
	var antje := _villager("antje")
	_villager("momme")
	_state.homes.move_in(antje, hall)

	var work_offers := _state.homes.offers(hall).filter(
		func(offer: Dictionary) -> bool: return not offer["is_home"]
	)

	assert_eq(
		work_offers.map(func(offer: Dictionary) -> String: return offer["text"]),
		["Antje Boysen works here"]
	)


func test_the_last_one_to_leave_a_house_may_go_on_working_there() -> void:
	var hall := _hall()
	var antje := _villager("antje")
	_state.homes.move_in(antje, hall)
	_state.homes.give_work(antje, hall)

	_state.homes.move_out(antje)

	assert_eq(antje.workplace.building, hall, "nobody lives there now")


func test_a_villager_of_the_sheets_works_in_their_own_house_not_a_nearer_one() -> void:
	var home := _hall()
	var nearer := _hall(SECOND_HALL)
	var hinrich := _villager("hinrich", Vector2i(3, 8))
	var antje := _villager("antje", Vector2i(13, 8))
	_state.homes.settle(hinrich, _world)

	_state.homes.settle(antje, _world)

	assert_eq(antje.house, home, "she joins Hinrich")
	assert_eq(antje.workplace.building, home, "her sheet's workplace is a hall house: her own")
	assert_true(_state.homes.workers_of(nearer).is_empty())


func test_a_villager_of_the_sheets_does_not_get_work_in_a_house_others_live_in() -> void:
	var hall := _hall()
	var stranger := Npc.create(42, Vector2(8.5, 8.5), _state.npcs.rules)
	_state.npcs.add(stranger)
	_state.homes.move_in(stranger, hall)
	var antje := _villager("antje")

	_state.homes.settle(antje, _world)

	assert_null(antje.house, "another household lives in the only hall")
	assert_null(antje.workplace, "and she doesn't live there")
