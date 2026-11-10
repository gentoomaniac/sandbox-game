extends GutTest
## The stork nests: which buildings have one, and the year in each, by the date and the seed.

const SEED := 1
const NOON := 12 * 60
const MIDNIGHT := 0
const SPRING := 15
const LATE_SPRING := 30
const SUMMER := 45
const AUTUMN := 75
const WINTER := 105
const NESTS_TO_TRY := 60

var _rules := StorkNestRules.default_rules()
var _sun := Sun.new()
var _nests := StorkNests.new(_rules, _sun, SEED)


## `count` houses side by side that have a nest, in the order of their places.
func _houses_with_a_nest(nests: StorkNests, count: int) -> Array[Building]:
	var found: Array[Building] = []
	var x := 0
	while found.size() < count:
		var house := Building.new(BuildingTypes.KATE, Vector2i(x, 0))
		if nests.has_nest(house):
			found.append(house)
		x += 4
	return found


func _stage(house: Building, day: int, minute := NOON) -> StorkNests.Stage:
	return _nests.occupants(house, day, minute).stage


func test_the_data_file_has_every_value_of_the_nests() -> void:
	assert_eq(_rules.problems(), [])


func test_some_houses_have_a_nest_and_others_not() -> void:
	var with_nest := 0
	for x in 200:
		if _nests.has_nest(Building.new(BuildingTypes.KATE, Vector2i(x * 4, 3))):
			with_nest += 1
	var chance: float = _rules.value("nest_chance")
	assert_almost_eq(with_nest / 200.0, chance, 0.1)


func test_only_the_buildings_of_the_data_file_have_a_nest() -> void:
	for x in 100:
		assert_false(_nests.has_nest(Building.new(BuildingTypes.CHURCH, Vector2i(x * 4, 3))))
		assert_false(_nests.has_nest(Building.new(BuildingTypes.BELL_FRAME, Vector2i(x * 4, 3))))


func test_the_nests_come_from_the_seed_and_the_place() -> void:
	var same := StorkNests.new(_rules, _sun, SEED)
	var other := StorkNests.new(_rules, _sun, SEED + 1)
	var differing := 0
	for x in 100:
		var house := Building.new(BuildingTypes.KATE, Vector2i(x * 4, 3))
		assert_eq(same.has_nest(house), _nests.has_nest(house))
		assert_eq(same.column(house), _nests.column(house))
		if other.has_nest(house) != _nests.has_nest(house):
			differing += 1
	assert_gt(differing, 0, "another seed has other nests")


func test_a_nest_sits_on_the_middle_third_of_the_ridge() -> void:
	var width: int = (
		BuildingTypes.TYPES[BuildingTypes.KATE]["footprint"].x * WildlifeRules.TILE_SIZE
	)
	for house in _houses_with_a_nest(_nests, NESTS_TO_TRY):
		assert_between(_nests.column(house), width / 3, width * 2 / 3)


func test_a_nest_is_empty_in_winter_and_autumn() -> void:
	for house in _houses_with_a_nest(_nests, NESTS_TO_TRY):
		for day in [61, AUTUMN, 90, WINTER, 120]:
			assert_eq(_stage(house, day), StorkNests.Stage.EMPTY, "day %d" % day)
		assert_eq(_stage(house, 1), StorkNests.Stage.EMPTY, "before the pair")


func test_the_pair_is_there_in_spring_and_the_young_hatch_in_late_spring() -> void:
	for house in _houses_with_a_nest(_nests, NESTS_TO_TRY):
		assert_eq(_stage(house, 9), StorkNests.Stage.PAIR, "arrived in early spring")
		assert_eq(_stage(house, 16), StorkNests.Stage.PAIR, "not before the young hatch")
		assert_eq(_stage(house, 27), StorkNests.Stage.YOUNG, "hatched in late spring")
		var young := _nests.occupants(house, LATE_SPRING, NOON)
		assert_between(young.young, _rules.value("min_young"), _rules.value("max_young"))


func test_the_young_grow_through_the_summer() -> void:
	for house in _houses_with_a_nest(_nests, NESTS_TO_TRY):
		var early := _nests.occupants(house, LATE_SPRING, NOON).growth
		var later := _nests.occupants(house, 40, NOON).growth
		assert_gte(early, 0.0)
		assert_gt(later, early)
		assert_lte(later, 1.0)


func test_the_year_of_a_nest_runs_in_order_and_the_young_leave_one_by_one() -> void:
	var order := [
		StorkNests.Stage.EMPTY,
		StorkNests.Stage.PAIR,
		StorkNests.Stage.YOUNG,
		StorkNests.Stage.FLEDGING,
		StorkNests.Stage.EMPTY,
	]
	for house in _houses_with_a_nest(_nests, NESTS_TO_TRY):
		var step := 0
		var young_before := -1
		for day in range(1, GameClock.DAYS_PER_YEAR + 1):
			var occupants := _nests.occupants(house, day, NOON)
			while order[step] != occupants.stage:
				step += 1
				assert_lt(step, order.size(), "the stages come in order")
			if occupants.stage == StorkNests.Stage.FLEDGING:
				if young_before >= 0:
					assert_between(occupants.young - young_before, -1, 0, "one at a time")
				young_before = occupants.young
				assert_eq(occupants.growth, 1.0)
		assert_eq(step, order.size() - 1, "it ends empty")


func test_the_last_young_goes_with_the_pair_by_the_end_of_summer() -> void:
	for house in _houses_with_a_nest(_nests, NESTS_TO_TRY):
		var last := _nests.occupants(house, 60, NOON + 6 * 60)
		assert_eq(last.stage, StorkNests.Stage.EMPTY)


func test_the_nests_are_not_in_step() -> void:
	var arrivals := {}
	var departures := {}
	for house in _houses_with_a_nest(_nests, NESTS_TO_TRY):
		for day in range(1, 61):
			if _stage(house, day) != StorkNests.Stage.EMPTY and not arrivals.has(house):
				arrivals[house] = day
			if arrivals.has(house) and _stage(house, day) == StorkNests.Stage.EMPTY:
				departures[house] = day
				break
	assert_gt(arrivals.values().size(), 1)
	assert_gt(departures.values().size(), 1)
	assert_gt(Array(arrivals.values()).max(), Array(arrivals.values()).min(), "arrivals differ")
	assert_gt(
		Array(departures.values()).max(), Array(departures.values()).min(), "departures differ"
	)


func test_a_nest_has_other_days_in_another_year() -> void:
	var differing := 0
	for house in _houses_with_a_nest(_nests, NESTS_TO_TRY):
		var first := _nests.occupants(house, LATE_SPRING, NOON)
		var second := _nests.occupants(house, LATE_SPRING + GameClock.DAYS_PER_YEAR, NOON)
		if first.growth != second.growth or first.young != second.young:
			differing += 1
	assert_gt(differing, 0)


func test_both_parents_are_home_at_night_and_one_stays_by_the_newly_hatched() -> void:
	for house in _houses_with_a_nest(_nests, 20):
		for day in [SPRING, LATE_SPRING, SUMMER]:
			if _stage(house, day) == StorkNests.Stage.EMPTY:
				continue
			assert_eq(_nests.occupants(house, day, MIDNIGHT).parents_home, 2)
		var hatched := _first_day_of(house, StorkNests.Stage.YOUNG)
		for minute in range(0, GameClock.MINUTES_PER_DAY, 30):
			assert_gte(_nests.occupants(house, hatched + 1, minute).parents_home, 1)


func test_the_parents_go_to_the_meadows_by_day() -> void:
	var away := 0
	var home := 0
	for house in _houses_with_a_nest(_nests, 20):
		for minute in range(8 * 60, 18 * 60, 60):
			var parents_home := _nests.occupants(house, 38, minute).parents_home
			home += parents_home
			away += 2 - parents_home
	assert_gt(away, 0, "some are away")
	assert_gt(home, 0, "some are home")


func test_no_one_is_on_an_empty_nest() -> void:
	var occupants := _nests.occupants(_houses_with_a_nest(_nests, 1)[0], WINTER, NOON)
	assert_eq(occupants.parents_home, 0)
	assert_eq(occupants.young, 0)


func test_a_loaded_game_has_the_nests_it_had() -> void:
	var state := GameState.new_game(SEED)
	var around := state.player.tile()
	for x in range(-12, 13, 4):
		for y in range(-12, 13, 4):
			state.world.place_building(BuildingTypes.KATE, around + Vector2i(x, y))
	assert_gt(state.world.buildings().size(), 2, "some houses to look at")
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	var nests := StorkNests.new(_rules, loaded.sun, loaded.world.world_seed)
	var before := StorkNests.new(_rules, state.sun, state.world.world_seed)
	for house in state.world.buildings():
		var same_house := loaded.world.building_at(house.origin)
		assert_eq(nests.has_nest(same_house), before.has_nest(house))
		assert_eq(nests.column(same_house), before.column(house))
		var then := before.occupants(house, LATE_SPRING, NOON)
		var now := nests.occupants(same_house, LATE_SPRING, NOON)
		assert_eq([now.stage, now.young, now.growth], [then.stage, then.young, then.growth])


## The first day of the year the nest is in a stage.
func _first_day_of(house: Building, stage: StorkNests.Stage) -> int:
	for day in range(1, GameClock.DAYS_PER_YEAR + 1):
		if _stage(house, day) == stage:
			return day
	return -1
