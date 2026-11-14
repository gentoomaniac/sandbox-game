extends GutTest
## The homes and workplaces of villagers (Households): a house holds a household up to its
## residents, the yard in front of its door is the anchor, a villager of data/villagers.cfg finds
## the house and workplace their sheet names, and a house taken down frees its villagers.

const SEED := 7
const FIRST_HALL := Vector2i(2, 2)
const SECOND_HALL := Vector2i(12, 2)
const HUT := Vector2i(2, 12)
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


func _made_up() -> Npc:
	var npc := Npc.create(42, Vector2(8.5, 8.5), _state.npcs.rules)
	_state.npcs.add(npc)
	return npc


func test_a_villager_who_moves_in_keeps_near_the_yard_before_the_door() -> void:
	var hall := _hall()
	var antje := _villager("antje")

	assert_eq(_state.homes.move_in(antje, hall), "")

	assert_eq(antje.house, hall)
	assert_eq(antje.anchor, Vector2(hall.door_tile() + Vector2i.DOWN) + Vector2(0.5, 0.5))
	assert_eq(_state.homes.residents_of(hall), [antje] as Array[Npc])


func test_a_couple_and_their_son_share_a_house_and_a_stranger_does_not_join() -> void:
	var hall := _hall()
	for villager_id in ["antje", "hinrich", "boy"]:
		assert_eq(_state.homes.move_in(_villager(villager_id), hall), "", villager_id)

	assert_eq(_state.homes.residents_of(hall).size(), 3)
	assert_eq(
		_state.homes.why_not_live_in(_made_up(), hall), "Only one household lives in a house."
	)
	assert_eq(
		_state.homes.why_not_live_in(_villager("momme"), hall),
		"Only one household lives in a house."
	)


func test_a_house_holds_no_more_than_its_residents() -> void:
	var shack := _world.place_building(BuildingTypes.SHACK, FIRST_HALL)
	assert_eq(_state.homes.move_in(_villager("momme"), shack), "")

	assert_eq(
		_state.homes.why_not_live_in(_villager("inken"), shack), "There is no room: 1 live there."
	)
	assert_null(_state.npcs.find("inken").house)


func test_a_building_that_is_no_house_is_refused() -> void:
	var barn := _world.place_building(BuildingTypes.BARN, BARN_ORIGIN)

	assert_eq(_state.homes.move_in(_made_up(), barn), "Barn is no house.")


func test_a_villager_who_moves_to_another_house_leaves_the_first() -> void:
	var first := _hall()
	var second := _hall(SECOND_HALL)
	var antje := _villager("antje")
	_state.homes.move_in(antje, first)

	assert_eq(_state.homes.move_in(antje, second), "")

	assert_eq(antje.house, second)
	assert_eq(antje.anchor, second.yard())
	assert_true(_state.homes.residents_of(first).is_empty())
	assert_eq(_state.homes.why_not_live_in(antje, second), "Antje Boysen lives there already.")


func test_a_villager_can_be_freed_and_keeps_their_anchor() -> void:
	var hall := _hall()
	var antje := _villager("antje")
	_state.homes.move_in(antje, hall)

	_state.homes.move_out(antje)

	assert_null(antje.house)
	assert_eq(antje.anchor, hall.yard())


func test_taking_a_house_down_frees_those_who_lived_and_worked_in_it() -> void:
	var hall := _hall()
	var antje := _villager("antje")
	var hinrich := _villager("hinrich")
	_state.homes.move_in(antje, hall)
	hinrich.workplace = Workplace.of_building(hall)

	assert_true(_state.take_down_building(hall))

	assert_null(antje.house)
	assert_null(hinrich.workplace)
	assert_eq(antje.anchor, hall.yard(), "they keep near where it stood")


func test_the_villagers_near_a_house_are_listed_nearest_first() -> void:
	var hall := _hall()
	var far := _villager("kerrin", Vector2i(20, 20))
	var near := _villager("momme", Vector2i(9, 8))
	_villager("ocke", Vector2i(100, 100))

	assert_eq(_state.homes.near(hall), [near, far] as Array[Npc])


func test_a_villager_of_the_sheets_settles_in_the_house_their_sheet_names() -> void:
	var hall := _hall()
	var barn := _world.place_building(BuildingTypes.BARN, BARN_ORIGIN)
	var hut := _world.place_building(BuildingTypes.FISHER_HUT, HUT)
	var hinrich := _villager("hinrich")
	var momme := _villager("momme")
	var ocke := _villager("ocke")

	for npc in [hinrich, momme, ocke]:
		_state.homes.settle(npc, _world)

	assert_eq(hinrich.house, hall)
	assert_eq(hinrich.workplace.building, barn)
	assert_eq(momme.house, hut)
	assert_null(momme.workplace, "a spot has no place until it is given")
	assert_null(ocke.house, "the mill house is no building")


func test_a_married_couple_settles_in_the_same_house_though_another_stands_nearer() -> void:
	var first := _hall()
	var second := _hall(SECOND_HALL)
	var antje := _villager("antje", Vector2i(3, 8))
	var hinrich := _villager("hinrich", Vector2i(13, 8))

	_state.homes.settle(antje, _world)
	_state.homes.settle(hinrich, _world)

	assert_eq(antje.house, first)
	assert_eq(hinrich.house, first)
	assert_true(_state.homes.residents_of(second).is_empty())


func test_where_no_house_stands_a_villager_has_none_and_keeps_their_anchor() -> void:
	var antje := _villager("antje")
	var anchor := antje.anchor

	_state.homes.settle(antje, _world)

	assert_null(antje.house)
	assert_null(antje.workplace)
	assert_eq(antje.anchor, anchor)


func test_a_workplace_is_a_building_or_a_spot_with_a_name() -> void:
	var barn := _world.place_building(BuildingTypes.BARN, BARN_ORIGIN)
	var in_barn := Workplace.of_building(barn)
	var at_landing := Workplace.of_spot("the landing at the sluice", Vector2i(5, 6))

	assert_eq(in_barn.label(), "Barn")
	assert_eq(in_barn.spot(), barn.yard())
	assert_eq(at_landing.label(), "the landing at the sluice")
	assert_eq(at_landing.spot(), Vector2(5.5, 6.5))


func test_the_place_of_a_deed_is_the_house_of_the_villager_who_lives_there() -> void:
	_state.clock.minute_of_day = 12 * GameClock.MINUTES_PER_HOUR
	var spot := _state.player.tile()
	var house := Building.new(BuildingTypes.HALL_HOUSE, spot + Vector2i(-3, -6))
	var antje := _villager("antje", spot)
	antje.position = Vector2(spot) + Vector2(0.5, 0.5)
	_state.homes.move_in(antje, house)

	_state.report(ActionOutcome.BREAK, spot, WorldObjectTypes.OAK, {ItemTypes.LOGS: 3})

	assert_eq(_state.deeds.entries[0]["place"], "by Antje's house")


func test_a_villager_who_comes_into_the_world_settles_by_themselves() -> void:
	var hall := _hall()

	var hinrich := _state.npcs.spawn_villager("hinrich", Vector2(8.5, 12.5), _world)

	assert_eq(hinrich.house, hall)
	assert_eq(hinrich.anchor, hall.yard())
