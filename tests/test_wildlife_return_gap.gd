extends WildlifeCase
## A kind with a `return_gap_minutes` (the storks) stays away for that long after one has left, on
## the ticks and on a skip of time, so a stork that flies off is not replaced at once.

const MIDSUMMER := 45
const KIND := WildlifeRules.ROOF_STORK
const TRIES := 3000
const ROOM := 1000

var _gap: int


func before_each() -> void:
	super()
	# Room for every kind, so that the others do not crowd the stork out of the view.
	var values := WildlifeRules.default_rules()._values.duplicate(true)
	values["general"]["max_total"] = ROOM
	_wildlife.rules = WildlifeRules.new(values)
	var house := _state.world.place_building(BuildingTypes.KATE, Vector2i(3, 8))
	_camera.rig.position = _wildlife._front_middle(house)
	_state.clock.day = MIDSUMMER
	_state.clock.set_time(12, 0)
	_state.weather_override = &"clear"
	_wildlife.is_player_ignored = false
	_gap = _wildlife.rules.return_gap_minutes(KIND)


## Lets the only roof stork leave: it flies off and is freed.
func _let_the_stork_leave() -> void:
	assert_true(_wildlife._send_stork_to_roof(false, true))
	_animals_of(Stork)[0].is_done = true
	_wildlife._remove_gone_animals()


func _tick_many_times() -> void:
	for _i in TRIES:
		_wildlife._match_counts()


func test_the_storks_have_a_gap_and_the_common_kinds_none() -> void:
	assert_gt(_gap, 0)
	assert_eq(_wildlife.rules.return_gap_minutes(WildlifeRules.BIRD), 0)


func test_no_stork_comes_back_during_the_gap_but_one_does_after_it() -> void:
	_let_the_stork_leave()
	_tick_many_times()
	assert_eq(_wildlife._count_of(KIND), 0, "nothing in the gap")
	_state.clock.advance(_gap)
	_tick_many_times()
	assert_gt(_wildlife._count_of(KIND), 0, "one after it")


func test_a_skip_of_time_into_the_gap_settles_no_stork_and_a_skip_past_it_does() -> void:
	_let_the_stork_leave()
	_state.clock.advance(_gap / 2)
	_wildlife.settle()
	assert_eq(_wildlife._count_of(KIND), 0, "still in the gap")
	_state.clock.advance(_gap)
	_wildlife.settle()
	assert_gt(_wildlife._count_of(KIND), 0, "the gap is over")


func test_settling_is_no_stork_leaving() -> void:
	assert_true(_wildlife._send_stork_to_roof(false, true))
	_wildlife.settle()
	assert_false(_wildlife._is_quiet(KIND))


func test_a_stork_made_by_hand_leaving_starts_no_gap() -> void:
	_wildlife.spawn_in_view(KIND, 1)
	_animals_of(Stork)[0].is_done = true
	_wildlife._remove_gone_animals()
	assert_false(_wildlife._is_quiet(KIND))


func test_the_gap_must_be_a_whole_number_from_0() -> void:
	var problem := "[stork] return_gap_minutes is not a whole number from 0"
	for wrong: Variant in [-1, 2.5, "long"]:
		var rules := WildlifeRules.new({"stork": {"return_gap_minutes": wrong}})
		assert_true(rules.problems().has(problem), "return_gap_minutes = %s" % [wrong])
	assert_false(WildlifeRules.new({"stork": {"return_gap_minutes": 60}}).problems().has(problem))
