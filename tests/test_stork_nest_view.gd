extends WildlifeCase
## The stork nests on screen: a nest near the view shows who is in it by the date, its pair are
## storks that fly off and come back, the young leave one by one, and the random roof storks keep
## off the roofs with a nest.

const LATE_SPRING := 30
const WINTER := 105
const SUMMER_DAY_WITH_YOUNG_ON_THE_RIM := 56

var _house: Building


func before_each() -> void:
	super()
	_house = _house_with_a_nest()
	_camera.rig.position = _wildlife._front_middle(_house)
	_state.weather_override = &"clear"


## Places houses about the player until one has a nest.
func _house_with_a_nest() -> Building:
	var around := _state.player.tile()
	for y in range(-14, 15, 4):
		for x in range(-14, 15, 4):
			var house := _state.world.place_building(BuildingTypes.KATE, around + Vector2i(x, y))
			if house != null and _wildlife.nests.has_nest(house):
				return house
	fail_test("no house with a nest")
	return null


func _at(day: int, hour := 12) -> void:
	_state.clock.day = day
	_state.clock.set_time(hour, 0)


func _nest_view() -> StorkNestView:
	return _wildlife._nest_views[_house]


func _parents() -> Array[Animal]:
	return _animals_of(Stork).filter(func(stork: Stork) -> bool: return stork.is_nest_parent)


func _visible_young() -> int:
	return _nest_view()._chicks.filter(func(chick) -> bool: return chick.sprite.visible).size()


func test_a_nest_near_the_view_is_shown_all_year_and_once() -> void:
	_at(WINTER)
	_wildlife._follow_nests()
	_wildlife._follow_nests()
	assert_eq(_wildlife._nest_views.size(), 1)
	assert_eq(_nest_view().get_parent(), _wildlife.world_view.entities)
	assert_eq(_parents().size(), 0, "empty in winter")
	assert_eq(_visible_young(), 0)


func test_the_pair_and_the_young_are_there_in_late_spring() -> void:
	_at(LATE_SPRING)
	_wildlife._follow_nests()
	var occupants := _wildlife.occupants_of(_house)
	assert_eq(occupants.stage, StorkNests.Stage.YOUNG)
	assert_eq(_parents().size(), occupants.parents_home)
	assert_gt(_parents().size(), 0)
	assert_eq(_visible_young(), occupants.young)
	for parent: Stork in _parents():
		assert_eq(parent._state, Stork.PERCH, "standing on the nest when it first comes near")
		assert_eq(parent.roof, _house)


func test_the_parents_stand_on_the_rim_higher_than_a_stork_on_the_bare_roof() -> void:
	_at(LATE_SPRING, 0)
	_wildlife._follow_nests()
	var parent: Stork = _parents()[0]
	var bare_lift := _wildlife.roof_lift(_house, parent._roof_column)
	assert_almost_eq(parent._lift, bare_lift + StorkNestView.RIM_HEIGHT, 0.01)


func test_the_young_look_larger_through_the_summer() -> void:
	_at(LATE_SPRING)
	_wildlife._follow_nests()
	var early: int = _nest_view()._chicks[0].sprite.frame
	_at(SUMMER_DAY_WITH_YOUNG_ON_THE_RIM - 14)
	_wildlife._follow_nests()
	assert_ne(_nest_view()._chicks[0].sprite.frame, early, "another picture")


func test_a_parent_leaves_the_nest_when_it_is_away_and_one_flies_back_in() -> void:
	_at(LATE_SPRING, 0)
	_wildlife._follow_nests()
	var minute := _minute_with_a_parent_away()
	_state.clock.set_time(minute / 60, minute % 60)
	_wildlife._follow_nests()
	var flying := _parents().filter(func(stork: Stork) -> bool: return stork._state == Stork.FLY)
	assert_eq(flying.size(), 1, "one flies off to the meadows")
	_at(LATE_SPRING, 0)
	_wildlife._follow_nests()
	var arriving := _parents().filter(
		func(stork: Stork) -> bool: return stork._state == Stork.ARRIVE
	)
	assert_eq(arriving.size(), 1, "and comes back at night")


## A minute of the day when one of the pair of the house's nest is away on late spring.
func _minute_with_a_parent_away() -> int:
	for minute in range(8 * 60, 20 * 60, 30):
		if _wildlife.nests.occupants(_house, LATE_SPRING, minute).parents_home < 2:
			return minute
	fail_test("never away")
	return 12 * 60


func test_the_young_leave_one_by_one() -> void:
	_at(SUMMER_DAY_WITH_YOUNG_ON_THE_RIM - 12)
	var before := _day_with_young_leaving()
	_at(before.x, 12)
	_wildlife._follow_nests()
	var young: int = _nest_view()._young
	_at(before.y, 12)
	_wildlife._follow_nests()
	assert_eq(_nest_view()._young, young - 1)
	assert_eq(_visible_young(), young - 1)
	var leaving := _animals_of(Stork).filter(
		func(stork: Stork) -> bool: return stork._state == Stork.FLY and stork.is_nest_parent
	)
	assert_gte(leaving.size(), 1, "it flies off")


## Two days of the year, (x, y), the second the first that has one young fewer on the nest.
func _day_with_young_leaving() -> Vector2i:
	for day in range(40, 60):
		var now := _wildlife.nests.occupants(_house, day, 12 * 60)
		var next := _wildlife.nests.occupants(_house, day + 1, 12 * 60)
		if (
			now.stage == StorkNests.Stage.FLEDGING
			and next.young == now.young - 1
			and next.young > 0
		):
			return Vector2i(day, day + 1)
	fail_test("no young leaving")
	return Vector2i.ZERO


func test_the_nest_is_empty_in_autumn_and_its_pair_has_gone() -> void:
	_at(LATE_SPRING)
	_wildlife._follow_nests()
	_at(75)
	_wildlife._follow_nests()
	for parent: Stork in _parents():
		assert_eq(parent._state, Stork.FLY)
	assert_eq(_visible_young(), 0)


func test_a_skip_of_time_puts_the_pair_on_the_nest_at_once() -> void:
	_at(WINTER)
	_wildlife._follow_nests()
	_at(LATE_SPRING, 0)
	_wildlife.settle()
	var occupants := _wildlife.occupants_of(_house)
	assert_eq(_parents().size(), occupants.parents_home)
	for parent: Stork in _parents():
		assert_eq(parent._state, Stork.PERCH)
	assert_eq(_visible_young(), occupants.young)


func test_random_roof_storks_keep_off_a_roof_with_a_nest() -> void:
	_at(LATE_SPRING)
	for building in _state.world.buildings():
		if building != _house:
			_state.world.remove_building(building)
	assert_false(_wildlife._send_stork_to_roof(false))
	assert_eq(_wildlife.spawn_in_view(WildlifeRules.ROOF_STORK, 1), 1, "made by hand: any roof")


func test_the_pair_of_a_nest_are_not_counted_or_sent_away_as_roof_storks() -> void:
	_at(LATE_SPRING, 0)
	_wildlife._follow_nests()
	var pair := _parents().size()
	assert_eq(_wildlife._count_of(WildlifeRules.ROOF_STORK), 0)
	_wildlife._send_away(WildlifeRules.ROOF_STORK, 2)
	assert_eq(
		_parents().filter(func(stork: Stork) -> bool: return stork._state == Stork.PERCH).size(),
		pair
	)


func test_the_nest_goes_with_its_house() -> void:
	_at(LATE_SPRING)
	_wildlife._follow_nests()
	_state.world.remove_building(_house)
	_wildlife._follow_nests()
	assert_eq(_wildlife._nest_views.size(), 0)
	for parent: Stork in _parents():
		_run(parent, 10.0)
		assert_eq(parent._state, Stork.FLY, "the pair leaves the roof that is gone")
