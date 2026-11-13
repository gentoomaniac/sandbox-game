extends LivestockCase
## The rooster crows (task 204): a run of crows at dawn once a day, now and then by day, never
## while it sleeps.

var _rooster: FarmAnimal
var _crows := 0


func before_each() -> void:
	super()
	_state.cheats.are_needs_off = true
	_rooster = FarmAnimal.new(LivestockRules.CHICKEN, &"rooster", _pen_middle())
	_livestock.add(_rooster)
	_livestock.stand_still(_rooster)
	_crows = 0
	_livestock.crowed.connect(func(_who: FarmAnimal) -> void: _crows += 1)


## The rules of the data file with the day's chance of a crow set.
func _with_day_chance(chance: float) -> void:
	var values := DataFile.read_sections(LivestockRules.DEFAULT_PATH)
	values["rooster"]["day_crow_chance"] = chance
	_livestock.rules = LivestockRules.new(values)


## A game minute some time after sunrise, when every animal is up.
func _morning() -> int:
	return int(_state.sun.sunrise(DAY)) + 40


func test_it_crows_a_run_of_crows_at_dawn() -> void:
	_with_day_chance(0.0)

	_run(60.0, _morning())

	assert_between(_crows, 2, 4, "dawn_crows")


func test_the_dawn_run_comes_once_a_day() -> void:
	_with_day_chance(0.0)
	_run(60.0, _morning())
	var first_run := _crows

	_run(60.0, _morning() + 5)

	assert_eq(_crows, first_run)


func test_it_crows_at_dawn_again_the_next_day() -> void:
	_with_day_chance(0.0)
	_run(60.0, _morning())
	var first_run := _crows
	_state.clock.day = DAY + 1
	_livestock.account_clock(_state.clock)
	for _step_count in int(60.0 / STEP_SECONDS):
		_state.clock.minute_of_day = int(_state.sun.sunrise(DAY + 1)) + 40
		_livestock.update(STEP_SECONDS, _world, _state.player.position, _state.clock)

	assert_gt(_crows, first_run)


func test_by_day_it_crows_now_and_then_when_the_dice_say_so() -> void:
	_with_day_chance(0.0)
	_run(60.0, NOON)
	assert_eq(_crows, 0, "no chance, no crow")

	_with_day_chance(1000.0)
	_run(60.0, NOON)
	assert_gt(_crows, 0)


func test_it_never_crows_at_night_while_it_sleeps() -> void:
	_with_day_chance(1000.0)

	_run(60.0, 2 * 60)
	_run(60.0, 23 * 60)

	assert_eq(_crows, 0)


func test_it_does_not_crow_in_the_coop() -> void:
	_with_day_chance(1000.0)
	_world.place_building(BuildingTypes.CHICKEN_COOP, _middle + Vector2i(0, -1))

	_run(30.0, 23 * 60)
	assert_true(_rooster.is_housed)
	_run(5.0, 2 * 60)

	assert_eq(_crows, 0)


func test_a_hen_never_crows() -> void:
	_with_day_chance(1000.0)
	_livestock.remove_species(LivestockRules.CHICKEN)
	var hen := FarmAnimal.new(LivestockRules.CHICKEN, &"brown", _pen_middle())
	_livestock.add(hen)

	_run(30.0, _morning())

	assert_eq(_crows, 0)


func test_a_run_in_progress_ends_when_it_falls_asleep() -> void:
	_with_day_chance(0.0)
	_rooster.crows_left = 3

	_run(1.0, 2 * 60)

	assert_eq(_rooster.crows_left, 0)


func test_a_skip_of_time_makes_no_burst_of_crows() -> void:
	_with_day_chance(1000.0)
	_state.clock.minute_of_day = _morning()

	_livestock.catch_up(_world, _state.clock, _state.player.position, SEED, 8 * 60)

	assert_eq(_crows, 0)
	assert_eq(_rooster.crows_left, 0)


func test_the_dawn_run_follows_the_sunrise_of_the_season() -> void:
	_with_day_chance(0.0)
	var summer := DAY
	var winter := 105
	assert_lt(_state.sun.sunrise(summer), _state.sun.sunrise(winter), "winter dawns later")
	for day in [summer, winter]:
		_rooster.last_dawn_crow_day = 0
		var before := _crows
		_run_on(day, int(_state.sun.sunrise(day)) + 120)
		assert_eq(_crows, before, "no dawn run two hours after sunrise, day %d" % day)
		_run_on(day, int(_state.sun.sunrise(day)) + 40)
		assert_gt(_crows, before, "a dawn run soon after sunrise, day %d" % day)


## Lets 60 seconds pass at a minute of a day.
func _run_on(day: int, minute: int) -> void:
	for _step_count in int(60.0 / STEP_SECONDS):
		_state.clock.day = day
		_state.clock.minute_of_day = minute
		_livestock.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
