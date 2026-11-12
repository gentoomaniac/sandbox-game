extends WildlifeCase
## Wild animals never stand on a building tile, the door included, whether they stand, spawn,
## settle or move. Near a building or a villager they keep their distance, the mice excepted.

const MIDSUMMER := 45
const TILE := float(TerrainTileset.TILE_SIZE)
## Kinds that fly or stand on roofs by design: they are not on the ground of a building tile.
const OFF_THE_GROUND: Array[StringName] = [
	WildlifeRules.ROOF_STORK,
	WildlifeRules.BEE,
	WildlifeRules.BUTTERFLY,
	WildlifeRules.FIREFLY,
	WildlifeRules.FLOCK,
	WildlifeRules.FLYING_GEESE,
	WildlifeRules.TERN,
]


func before_each() -> void:
	super.before_each()
	_state.clock.day = MIDSUMMER
	_state.weather_override = &"clear"


## Houses on a row of lots around the view centre, wherever they can be placed.
func _houses_around_the_view() -> Array[Building]:
	var houses: Array[Building] = []
	var centre := Vector2i((VIEW_CENTRE / TILE).floor())
	for y in range(-10, 11, 5):
		for x in range(-14, 15, 7):
			var house := _state.world.place_building(BuildingTypes.KATE, centre + Vector2i(x, y))
			if house != null:
				houses.append(house)
	return houses


## A point of open ground with room to flee left for a few tiles, away from the buildings.
func _open_point() -> Vector2:
	for y in range(-5, 6):
		for x in range(-10, 11):
			var point := VIEW_CENTRE + Vector2(x, y) * TILE
			if range(0, 6).all(
				func(left: int) -> bool:
					return _wildlife.can_stand(point - Vector2(left * TILE, 0.0))
			):
				return point
	fail_test("no open ground near the view")
	return VIEW_CENTRE


func _villager_beside(point: Vector2, distance_tiles: float) -> void:
	_wildlife.world_view.player_feet = Vector2.ONE * -4000.0
	_wildlife.is_player_ignored = false
	var feet := point + Vector2(distance_tiles * TILE, 0.0)
	_state.npcs.add(Npc.create_villager("antje", feet / TILE, _state.npcs.villagers))
	_wildlife._follow_villagers()


func test_no_animal_can_stand_on_a_building_tile_the_door_included() -> void:
	var houses := _houses_around_the_view()
	assert_gt(houses.size(), 0, "houses placed")
	for house in houses:
		for tile in house.tiles():
			var point := TerrainTileset.tile_centre(tile)
			for kind in WildlifeRules.KINDS:
				assert_false(_wildlife.can_stand(point, kind), "%s on %s" % [kind, tile])
		var door := TerrainTileset.tile_centre(house.door_tile())
		assert_false(_wildlife.can_stand(door, WildlifeRules.MOUSE), "a mouse in the door")


func test_no_animal_spawns_or_settles_on_a_building_tile() -> void:
	var houses := _houses_around_the_view()
	assert_gt(houses.size(), 0, "houses placed")
	var checked := 0
	for hour in [4, 8, 12, 17, 21, 23]:
		_state.clock.set_time(hour, 0)
		_wildlife.settle()
		for animal in _wildlife._animals:
			if animal.kind in OFF_THE_GROUND or animal is Stork and animal.is_nest_parent:
				continue
			checked += 1
			var tile := Vector2i((animal.position / TILE).floor())
			assert_null(_state.world.building_at(tile), "%s on a building" % animal.kind)
	assert_gt(checked, 0, "animals settled")


func test_animals_stay_off_buildings_while_they_move() -> void:
	_houses_around_the_view()
	_state.clock.set_time(12, 0)
	_wildlife.settle()
	for animal in _wildlife._animals.duplicate():
		if animal.kind in OFF_THE_GROUND or animal is Stork and animal.is_nest_parent:
			continue
		_run(animal, 30.0)
		var tile := Vector2i((animal.position / TILE).floor())
		assert_null(_state.world.building_at(tile), "%s on a building" % animal.kind)


func test_animals_do_not_settle_near_a_building_but_mice_do() -> void:
	var house := _state.world.place_building(BuildingTypes.KATE, Vector2i(3, 8))
	var beside_the_door := TerrainTileset.tile_centre(house.door_tile() + Vector2i(0, 1))
	assert_true(_wildlife._is_near_people(WildlifeRules.DEER, beside_the_door))
	assert_true(_wildlife._is_near_people(WildlifeRules.RABBIT, beside_the_door))
	assert_false(_wildlife._is_near_people(WildlifeRules.MOUSE, beside_the_door))
	var far_away := beside_the_door + Vector2(0.0, 20.0 * TILE)
	assert_false(_wildlife._is_near_people(WildlifeRules.DEER, far_away))


func test_animals_do_not_settle_near_a_villager_but_mice_do() -> void:
	var point := _open_point()
	_villager_beside(point, 1.0)
	assert_true(_wildlife._is_near_people(WildlifeRules.RABBIT, point))
	assert_false(_wildlife._is_near_people(WildlifeRules.MOUSE, point))


func test_the_building_and_villager_keys_of_the_data_file() -> void:
	var rules := WildlifeRules.default_rules()
	assert_true(rules.ignores_villagers(WildlifeRules.MOUSE))
	assert_eq(rules.building_tiles(WildlifeRules.MOUSE), 0)
	for kind in [WildlifeRules.RABBIT, WildlifeRules.DEER, WildlifeRules.SQUIRREL]:
		assert_gt(rules.building_tiles(kind), 0, "%s keeps off buildings" % kind)
		assert_false(rules.ignores_villagers(kind), "%s keeps off villagers" % kind)
	for kind in WildlifeRules.KINDS:
		assert_gte(rules.building_tiles(kind), 0, "%s distance" % kind)


func test_the_building_and_villager_keys_must_be_well_formed() -> void:
	var building_problem := "[rabbit] building_tiles is not a whole number from 0"
	for wrong: Variant in [-1, 2.5, "far"]:
		var rules := WildlifeRules.new({"rabbit": {"building_tiles": wrong}})
		assert_true(rules.problems().has(building_problem), "building_tiles = %s" % [wrong])
	assert_false(
		WildlifeRules.new({"rabbit": {"building_tiles": 3}}).problems().has(building_problem)
	)
	var villager_problem := "[mouse] ignores_villagers is not true or false"
	assert_true(
		WildlifeRules.new({"mouse": {"ignores_villagers": "yes"}}).problems().has(villager_problem)
	)
	assert_false(
		WildlifeRules.new({"mouse": {"ignores_villagers": true}}).problems().has(villager_problem)
	)
