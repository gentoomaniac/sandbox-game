extends WildlifeCase
## After a skip of time the ambient wildlife is what the new hour has, at once.

const MIDSUMMER := 45


func before_each() -> void:
	super.before_each()
	_wildlife.is_player_ignored = false
	_state.clock.day = MIDSUMMER
	_state.weather_override = &"clear"


func test_the_animals_of_the_night_are_there_after_a_skip_into_it() -> void:
	_state.clock.set_time(12, 0)
	_wildlife.settle()
	assert_eq(_animals_of(Firefly).size(), 0, "no fireflies by day")
	_state.clock.set_time(23, 0)
	_wildlife.settle()
	assert_gt(_animals_of(Firefly).size(), 0, "fireflies on a summer night")


func test_the_animals_of_the_night_are_gone_after_a_skip_into_the_day() -> void:
	_state.clock.set_time(23, 0)
	_wildlife.settle()
	_state.clock.set_time(12, 0)
	_wildlife.settle()
	assert_eq(_animals_of(Firefly).size(), 0)


func test_animals_made_by_hand_stay() -> void:
	_wildlife.place(WildlifeRules.FIREFLY, VIEW_CENTRE)
	_state.clock.set_time(12, 0)
	_wildlife.settle()
	assert_eq(_animals_of(Firefly).size(), 1)


func test_a_stork_that_settles_stands_on_its_roof_at_once_and_is_not_made_by_hand() -> void:
	var house := _state.world.place_building(BuildingTypes.KATE, Vector2i(3, 8))
	_camera.rig.position = _wildlife._front_middle(house)
	assert_true(_wildlife._send_stork_to_roof(false, true))
	var stork: Stork = _animals_of(Stork)[0]
	assert_eq(stork._state, Stork.PERCH)
	assert_false(stork.is_pinned)


func test_a_flock_that_settles_is_in_the_view_not_beyond_it() -> void:
	_wildlife._spawn_flock(WildlifeRules.FLOCK, false, true)
	var flock: Animal = _animals_of(Flock)[0]
	assert_true(_wildlife.view_rect().has_point(flock.position))
	assert_false(flock.is_pinned)


func test_a_skip_into_bloom_settles_the_animals_that_live_at_flowers() -> void:
	var decorations := _wildlife.world_view.decorations
	decorations.day = 105
	for y in range(-20, 20):
		for x in range(-20, 20):
			decorations.place(Vector2i(x, y), TerrainTileset.Layer.GRASS, false)
	var meadow := Rect2(Vector2(-300, -300), Vector2(600, 600))
	assert_true(decorations.flower_tiles_within(meadow).is_empty(), "none in bloom as drawn")
	_state.clock.day = MIDSUMMER
	_state.clock.set_time(12, 0)
	_wildlife.settle()
	assert_gt(_animals_of(Bee).size() + _animals_of(Butterfly).size(), 0, "the date's flowers")


func test_a_skip_from_snow_into_bloom_settles_the_animals_that_live_at_flowers() -> void:
	var decorations := _wildlife.world_view.decorations
	decorations.day = 105
	for y in range(-20, 20):
		for x in range(-20, 20):
			decorations.place(Vector2i(x, y), TerrainTileset.Layer.GRASS, false)
	_state.clock.day = MIDSUMMER
	_state.clock.set_time(12, 0)
	_wildlife.settle()
	assert_gt(_animals_of(Bee).size() + _animals_of(Butterfly).size(), 0, "no snow lies in summer")
