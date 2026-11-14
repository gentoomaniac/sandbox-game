extends GutTest
## A house with the inside a villager's sheet names (`home_interior` of data/villagers.cfg)
## instead of its type's default: made when they move in, kept when changed, saved, and a map
## that does not fit its building refused when the data loads.

const BOYSEN_MAP := "res://maps/interiors/villagers/boysen.tmx"
const HALL_ORIGIN := Vector2i(2, 2)

var _state: GameState
var _world: World


func before_each() -> void:
	_state = GameState.new()
	_state.world = World.new(7)
	_state.world.add_chunk(Chunk.new(Vector2i.ZERO))
	_state.player.home_map = _state.world
	_world = _state.world


func _hall() -> Building:
	return _world.place_building(BuildingTypes.HALL_HOUSE, HALL_ORIGIN)


func _villager(villager_id: String) -> Npc:
	var npc := Npc.create_villager(villager_id, Vector2(8.5, 8.5), _state.npcs.villagers)
	_state.npcs.add(npc)
	return npc


func _made_up() -> Npc:
	var npc := Npc.create(42, Vector2(8.5, 8.5), _state.npcs.rules)
	_state.npcs.add(npc)
	return npc


func _default_room(type: StringName) -> Interior:
	return InteriorLoader.load_interior(BuildingTypes.TYPES[type]["interior_map"])


## The tiles a player can walk to from the entry tile.
func _reachable_from_entry(room: Interior) -> Dictionary:
	var seen := {room.entry_tile(): true}
	var queue: Array[Vector2i] = [room.entry_tile()]
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not seen.has(tile + step) and room.is_walkable(tile + step):
				seen[tile + step] = true
				queue.append(tile + step)
	return seen


## The sheet of a made-up farmer, with the house and the inside given ("" for none).
func _sheet(home_building: String, home_interior: String) -> Dictionary:
	var sheet := {
		"name": "Anna",
		"sex": "female",
		"age": 30,
		"trade": "a farmer",
		"personality": "Kind.",
		"background": "From the farm.",
		"home": "The farm.",
		"speech": "Slowly.",
		"likes": "Hay.",
		"wants": "Rain.",
		"day": "Works.",
		"habits": "Hums.",
		"avoids": "Talk.",
		"secrets": "None.",
		"samples": ["One.", "Two."],
		"people": {},
		"look": {"body": "fair"},
	}
	if home_building != "":
		sheet[VillagerRules.HOME_BUILDING_KEY] = home_building
	if home_interior != "":
		sheet[VillagerRules.HOME_INTERIOR_KEY] = home_interior
	return sheet


func test_a_house_has_the_default_inside_when_a_villager_without_an_own_one_moves_in() -> void:
	var hall := _hall()
	var hut := _world.place_building(BuildingTypes.FISHER_HUT, Vector2i(12, 2))

	assert_eq(hall.inside().to_dict(), _default_room(BuildingTypes.HALL_HOUSE).to_dict())
	assert_eq(_state.homes.move_in(_made_up(), hall), "")
	assert_eq(_state.homes.move_in(_villager("momme"), hut), "")

	assert_eq(hall.inside().to_dict(), _default_room(BuildingTypes.HALL_HOUSE).to_dict())
	assert_eq(hut.inside().to_dict(), _default_room(BuildingTypes.FISHER_HUT).to_dict())


func test_a_villager_with_an_own_inside_gives_it_to_their_house_and_the_spouse_shares_it() -> void:
	var hall := _hall()
	var own := InteriorLoader.load_interior(BOYSEN_MAP).to_dict()

	_state.homes.move_in(_villager("antje"), hall)
	assert_eq(hall.inside().to_dict(), own)
	_state.homes.move_in(_villager("hinrich"), hall)

	assert_eq(hall.inside().to_dict(), own)
	assert_ne(own, _default_room(BuildingTypes.HALL_HOUSE).to_dict())


func test_a_house_someone_has_been_in_and_changed_keeps_its_inside() -> void:
	var hall := _hall()
	hall.inside().set_terrain(Vector2i(2, 4), Tile.Terrain.CLAY_FLOOR)
	var changed := hall.inside().to_dict()

	_state.homes.move_in(_villager("antje"), hall)

	assert_eq(hall.inside().to_dict(), changed)


func test_the_own_inside_is_still_theirs_after_a_save() -> void:
	var hall := _hall()
	_state.homes.move_in(_villager("antje"), hall)

	var loaded := Building.from_dict(hall.to_dict())

	assert_eq(loaded.inside().to_dict(), InteriorLoader.load_interior(BOYSEN_MAP).to_dict())


func test_a_house_with_an_own_inside_is_taken_down_when_nothing_was_put_in_it() -> void:
	var hall := _hall()
	_state.homes.move_in(_villager("antje"), hall)

	assert_eq(_state.why_not_take_down(hall), "")


func test_the_boysens_inside_has_beds_and_every_floor_tile_is_reachable() -> void:
	var room := InteriorLoader.load_interior(BOYSEN_MAP)
	var reachable := _reachable_from_entry(room)

	for y in range(2, room.size.y - 1):
		for x in range(1, room.size.x - 1):
			if room.is_walkable(Vector2i(x, y)):
				assert_true(reachable.has(Vector2i(x, y)), "%s is cut off" % Vector2i(x, y))
	var beds := room.objects().filter(func(object: WorldObject) -> bool: return object.is_bed())
	assert_gte(beds.size(), 3, "a bed each for Hinrich and Antje, and Boy's mat")
	for bed: WorldObject in beds:
		var around := Rect2i(bed.pos - Vector2i.ONE, bed.type_data()["footprint"] + Vector2i(2, 2))
		assert_true(reachable.keys().any(around.has_point), "a free tile beside %s" % bed.pos)


func test_the_sheets_of_the_file_are_valid_with_their_own_inside() -> void:
	var villagers := VillagerRules.default_rules()

	assert_true(villagers.is_valid(), str(villagers.problems()))
	assert_eq(villagers.villager("antje")[VillagerRules.HOME_INTERIOR_KEY], BOYSEN_MAP)
	assert_eq(villagers.home_interiors(BuildingTypes.HALL_HOUSE), [BOYSEN_MAP] as Array[String])


func test_a_map_that_does_not_fit_its_building_is_refused_when_the_data_loads() -> void:
	var too_small := _sheet("hall_house", "res://maps/interiors/kate.tmx")
	var missing := _sheet("hall_house", "res://maps/interiors/villagers/nowhere.tmx")
	var homeless := _sheet("", BOYSEN_MAP)

	assert_eq(
		VillagerRules.new({"anna": too_small}).problems(),
		(
			[
				(
					"[anna] home_interior: is (9, 8) with its door at (4, 7),"
					+ " a hall_house has (15, 13) and (7, 12)"
				)
			]
			as Array[String]
		)
	)
	assert_eq(
		VillagerRules.new({"anna": missing}).problems(),
		(
			["[anna] home_interior: no such map: res://maps/interiors/villagers/nowhere.tmx"]
			as Array[String]
		)
	)
	assert_eq(
		VillagerRules.new({"anna": homeless}).problems(),
		["[anna] home_interior: needs a text, and a home_building"] as Array[String]
	)


func test_a_couple_names_the_same_inside() -> void:
	var antje := _sheet("hall_house", BOYSEN_MAP)
	antje["people"] = {"hinrich": ["husband", "Steady."]}
	var hinrich := _sheet("hall_house", "")
	hinrich["people"] = {"antje": ["wife", "Warm."]}
	hinrich["sex"] = "male"

	assert_has(
		VillagerRules.new({"antje": antje, "hinrich": hinrich}).problems(),
		"[antje] people: hinrich does not have the same home_interior as their wife"
	)


func test_a_home_bed_in_a_house_that_gets_an_own_inside_stays_the_players_home() -> void:
	var hall := _hall()
	var beds := hall.inside().objects().filter(
		func(object: WorldObject) -> bool: return object.is_bed()
	)
	var bed: WorldObject = beds[0]
	_state.player.home_map = hall.inside()
	_state.player.home_bed = bed.pos

	_state.homes.move_in(_villager("antje"), hall)
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	restored.go_to_home_bed()

	assert_true(restored.is_inside(), "they wake in the house, at the same bed")
	assert_eq(restored.player.home_bed, bed.pos)


func test_a_villager_with_an_own_inside_does_not_move_in_while_the_player_is_inside() -> void:
	var hall := _hall()
	_state.player.position = Vector2(hall.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()

	assert_eq(_state.homes.move_in(_villager("antje"), hall), "Not while you are inside.")
	assert_null(_state.npcs.find("antje").house)


func test_other_villagers_move_in_while_the_player_is_inside() -> void:
	var hall := _hall()
	_state.player.position = Vector2(hall.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	hall.inside().set_terrain(Vector2i(2, 4), Tile.Terrain.CLAY_FLOOR)

	assert_eq(_state.homes.move_in(_villager("antje"), hall), "", "a changed room stays as it is")
	assert_eq(_state.homes.move_in(_villager("hinrich"), hall), "")


func test_the_own_inside_is_only_for_the_house_type_the_sheet_names() -> void:
	var kate := _world.place_building(BuildingTypes.KATE, HALL_ORIGIN)

	_state.homes.move_in(_villager("antje"), kate)

	assert_eq(kate.inside().to_dict(), _default_room(BuildingTypes.KATE).to_dict())
