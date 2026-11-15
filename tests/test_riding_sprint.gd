extends ResourceCase
## Sprinting on horseback (#66): the walking and sprinting speeds, the stamina a sprint uses up
## and what gives it back, and the key that sprints. The numbers are data/livestock.cfg's.

const STEP := 0.05

var _horse: FarmAnimal
var _rules: LivestockRules


func before_each() -> void:
	super()
	_rules = _state.livestock.rules
	_horse = FarmAnimal.new(LivestockRules.HORSE, &"bay", _state.player.position)
	_horse.is_saddled = true
	_state.livestock.add(_horse)
	# Nothing in the way, so the speed is the only thing that decides how far the horse goes.
	_state.cheats.is_noclip = true
	_state.mount(_horse)


## Rides for the seconds; `direction` zero stands.
func _ride(seconds: float, direction := Vector2.RIGHT, is_sprinting := false) -> void:
	_state.is_sprint_held = is_sprinting
	for _step in roundi(seconds / STEP):
		_state.walk(direction, STEP, _state.walk_speed_factor())


## How many tiles a second the horse goes over `seconds` more of riding.
func _speed_over(seconds: float, is_sprinting: bool) -> float:
	var from := _state.player.position
	_ride(seconds, Vector2.RIGHT, is_sprinting)
	return from.distance_to(_state.player.position) / seconds


func _get_going() -> void:
	_ride(_rules.general("trot_after_seconds") + STEP)


func test_riding_walks_at_one_and_a_half_times_the_walking_speed_after_getting_going() -> void:
	_get_going()

	assert_almost_eq(_speed_over(1.0, false), 1.5 * PlayerState.SPEED, 0.01)
	assert_eq(_state.walk_speed_factor(), _rules.general("ride_trot_factor"))


func test_sprinting_goes_at_the_sprint_factor_once_the_horse_has_got_going() -> void:
	_ride(STEP, Vector2.RIGHT, true)
	assert_eq(_state.walk_speed_factor(), _rules.general("ride_walk_factor"), "not yet going")
	_get_going()

	assert_almost_eq(
		_speed_over(1.0, true), _rules.general("ride_sprint_factor") * PlayerState.SPEED, 0.01
	)
	assert_true(_state.is_sprinting())
	assert_gt(_rules.general("ride_sprint_factor"), _rules.general("ride_trot_factor"))


func test_a_sprint_uses_stamina_for_the_seconds_a_full_one_lasts() -> void:
	_get_going()
	var seconds := _rules.general("sprint_stamina_seconds")

	_ride(seconds / 2.0, Vector2.RIGHT, true)

	assert_almost_eq(_horse.stamina, 0.5, 0.01)
	_ride(seconds / 2.0 + 0.2, Vector2.RIGHT, true)
	assert_lt(_horse.stamina, 0.01)
	assert_false(_state.is_sprinting(), "none left")
	assert_eq(_state.walk_speed_factor(), _rules.general("ride_trot_factor"))


func test_a_horse_with_none_left_sprints_again_once_a_part_has_come_back() -> void:
	_get_going()
	_horse.stamina = 0.0
	_ride(STEP, Vector2.RIGHT, true)
	var seconds_to_sprint_again := (
		_rules.general("sprint_again_stamina") * _rules.general("stamina_walk_regain_seconds")
	)

	_ride(seconds_to_sprint_again - 1.0, Vector2.RIGHT, true)
	assert_false(_state.is_sprinting(), "holding the key rests the horse, no more")

	_ride(2.0, Vector2.RIGHT, true)
	assert_true(_state.is_sprinting())


func test_stamina_comes_back_faster_standing_than_walking() -> void:
	_get_going()
	_horse.stamina = 0.0
	_ride(5.0)
	var walking_gain := _horse.stamina
	_horse.stamina = 0.0
	_ride(5.0, Vector2.ZERO)

	assert_almost_eq(walking_gain, 5.0 / _rules.general("stamina_walk_regain_seconds"), 0.01)
	assert_almost_eq(_horse.stamina, 5.0 / _rules.general("stamina_stand_regain_seconds"), 0.01)
	assert_gt(_horse.stamina, walking_gain)


func test_a_horse_nobody_rides_gets_its_stamina_back_standing_rate() -> void:
	_state.dismount()
	_horse.stamina = 0.0

	for _step in roundi(5.0 / STEP):
		_state.livestock.update(STEP, _world, _state.player.position, _state.clock)

	assert_almost_eq(_horse.stamina, 5.0 / _rules.general("stamina_stand_regain_seconds"), 0.01)


func test_a_horse_that_was_saved_with_none_is_winded_when_got_on_again() -> void:
	_state.dismount()
	_horse.stamina = 0.0
	_state.mount(_horse)

	_get_going()
	_ride(STEP, Vector2.RIGHT, true)

	assert_false(_state.is_sprinting())


func test_the_sprint_key_is_shift_by_default_and_can_be_rebound() -> void:
	var settings := GameSettings.new("user://test_riding_sprint_settings.cfg")
	assert_eq(settings.bindings(&"sprint").map(GameSettings.binding_text), ["Shift"])

	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	settings.bind(&"sprint", 0, key)
	assert_eq(settings.bindings(&"sprint").map(GameSettings.binding_text), ["F"])

	settings.reset_bindings()
	DirAccess.remove_absolute("user://test_riding_sprint_settings.cfg")
