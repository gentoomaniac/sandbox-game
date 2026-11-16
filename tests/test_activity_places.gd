extends GutTest
## Where activities are done for a villager (ActivityPlaces): home, workplace, field, church,
## meeting, friend and wild, with what each does when the villager has no such place.

const NOWHERE := ActivityPlaces.NOWHERE

var _state: GameState
var _places: ActivityPlaces
var _house: Building
var _antje: Npc


func before_each() -> void:
	_state = GameFactory.new_game(7)
	_places = ActivityPlaces.new(_state.world, _state.npcs)
	_house = _place(BuildingTypes.KATE, Vector2i(-6, 0))
	_antje = _add("antje")
	_state.homes.move_in(_antje, _house)


## A building of the type on the first free spot at or near `offset` from the player.
func _place(building_type: StringName, offset: Vector2i) -> Building:
	var around := _state.player.tile() + offset
	for y in range(-12, 13):
		for x in range(-12, 13):
			var building := _state.world.place_building(building_type, around + Vector2i(x, y))
			if building != null:
				return building
	fail_test("no room for a building")
	return null


func _add(villager_id: String) -> Npc:
	var npc := Npc.create_villager(villager_id, _state.player.position, _state.npcs.villagers)
	_state.npcs.add(npc)
	return npc


func _till(tile: Vector2i) -> void:
	_state.world.remove_object(tile)
	_state.world.set_terrain(tile, Tile.Terrain.SOIL)


func _spot(npc: Npc, target: String, day := 1) -> Vector2:
	return _places.spot_of(npc, target, day)


func test_home_is_the_yard_of_the_house() -> void:
	assert_eq(_spot(_antje, "home"), _house.yard())


func test_a_villager_with_no_house_has_no_home() -> void:
	_state.homes.move_out(_antje)
	assert_eq(_spot(_antje, "home"), NOWHERE)
	assert_eq(_spot(_antje, "workplace"), NOWHERE)


func test_the_workplace_is_where_they_work_and_else_home() -> void:
	assert_eq(_spot(_antje, "workplace"), _house.yard(), "none: home")
	var barn := _place(BuildingTypes.BARN, Vector2i(10, 0))
	_state.homes.give_work(_antje, barn)
	assert_eq(_spot(_antje, "workplace"), barn.yard())
	_antje.workplace = Workplace.of_spot("the landing", Vector2i(3, 4))
	assert_eq(_spot(_antje, "workplace"), Vector2(3.5, 4.5))


func test_the_field_is_the_nearest_tilled_tile_to_home() -> void:
	var home := Vector2i(_house.yard().floor())
	_till(home + Vector2i(12, 0))
	_till(home + Vector2i(0, 7))
	assert_eq(_spot(_antje, "field"), Vector2(home + Vector2i(0, 7)) + Vector2(0.5, 0.5))


func test_the_field_is_also_the_nearest_field_the_village_keeps() -> void:
	var home := Vector2i(_house.yard().floor())
	var village := Village.new()
	village.field_spots = [home + Vector2i(20, 0), home + Vector2i(0, 30)]
	_state.world.village = village
	assert_eq(_spot(_antje, "field"), Vector2(home + Vector2i(20, 0)) + Vector2(0.5, 0.5))
	_till(home + Vector2i(0, 7))
	assert_eq(_spot(_antje, "field"), Vector2(home + Vector2i(0, 7)) + Vector2(0.5, 0.5))


func test_a_field_too_far_from_home_is_none() -> void:
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values["rules"]["search_tiles"]["field"] = 5
	var places := ActivityPlaces.new(_state.world, _state.npcs, ActivityRules.new(values))
	_till(Vector2i(_house.yard().floor()) + Vector2i(12, 0))
	assert_eq(places.spot_of(_antje, "field", 1), NOWHERE)


func test_with_no_tilled_tile_the_field_is_the_workplace_if_that_is_a_spot() -> void:
	_antje.workplace = Workplace.of_building(_house)
	assert_eq(_spot(_antje, "field"), NOWHERE, "a building is not a field")
	_antje.workplace = Workplace.of_spot("the Ketels field", Vector2i(3, 4))
	assert_eq(_spot(_antje, "field"), Vector2(3.5, 4.5))


func test_the_church_is_the_yard_of_the_church_nearest_home() -> void:
	assert_eq(_spot(_antje, "church"), NOWHERE)
	var church := _place(BuildingTypes.CHURCH, Vector2i(10, 10))
	assert_eq(_spot(_antje, "church"), church.yard())


func test_without_a_village_the_meeting_is_the_yard_of_the_church() -> void:
	assert_eq(_spot(_antje, "meeting"), NOWHERE)
	var church := _place(BuildingTypes.CHURCH, Vector2i(10, 10))
	assert_eq(_spot(_antje, "meeting"), church.yard())


func test_the_meeting_is_the_villages_meeting_spot_when_it_is_near_enough() -> void:
	var village := Village.new()
	village.meeting_spot = Vector2i(_house.yard().floor()) + Vector2i(30, 0)
	_state.world.village = village
	_place(BuildingTypes.CHURCH, Vector2i(10, 10))
	assert_eq(_spot(_antje, "meeting"), Vector2(village.meeting_spot) + Vector2(0.5, 0.5))

	village.meeting_spot += Vector2i(300, 0)
	assert_eq(_spot(_antje, "meeting"), NOWHERE, "too far, and the church is not asked")


func test_a_church_too_far_is_none() -> void:
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values["rules"]["search_tiles"]["church"] = 5
	var places := ActivityPlaces.new(_state.world, _state.npcs, ActivityRules.new(values))
	_place(BuildingTypes.CHURCH, Vector2i(10, 10))
	assert_eq(places.spot_of(_antje, "church", 1), NOWHERE)


func test_a_friend_is_the_yard_of_the_house_of_one_of_their_people() -> void:
	assert_eq(_spot(_antje, "friend"), NOWHERE, "nobody of hers is in the world")
	var hinrich := _add("hinrich")
	assert_eq(_spot(_antje, "friend"), NOWHERE, "he has no house")
	var house := _place(BuildingTypes.KATE, Vector2i(10, 0))
	_state.homes.move_in(hinrich, house)
	assert_eq(_spot(_antje, "friend"), house.yard())


func test_which_friend_follows_the_day_and_is_the_same_all_day() -> void:
	for id in ["hinrich", "boy", "gesche"]:
		_state.homes.move_in(_add(id), _place(BuildingTypes.KATE, Vector2i(10, 12)))
	var yards := {}
	for day in 30:
		var spot := _spot(_antje, "friend", day + 1)
		assert_eq(_spot(_antje, "friend", day + 1), spot)
		yards[spot] = true
	assert_gt(yards.size(), 1, "another friend another day")


func test_a_wild_spot_is_a_free_meadow_tile_near_home_and_the_same_all_day() -> void:
	var home := _house.yard()
	var spot := _spot(_antje, "wild", 5)
	assert_ne(spot, NOWHERE)
	assert_eq(_spot(_antje, "wild", 5), spot)
	assert_between(spot.distance_to(home), 7.0, 31.0)
	var tile := Vector2i(spot.floor())
	assert_eq(_state.world.tile_at(tile).terrain, Tile.Terrain.GRASS)
	assert_true(_state.world.is_walkable(tile))


func test_another_day_is_another_wild_spot() -> void:
	var spots := {}
	for day in 10:
		spots[_spot(_antje, "wild", day + 1)] = true
	assert_gt(spots.size(), 1)


func test_a_wild_spot_in_chunks_that_are_not_loaded_is_none() -> void:
	_antje.workplace = null
	_antje.house = null
	_antje.position = Vector2(100000.5, 100000.5)
	assert_eq(_spot(_antje, "wild"), NOWHERE)
