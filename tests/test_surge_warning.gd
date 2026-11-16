extends GutTest
## What the storm surge's warning does (#103): a storm in the sky from six hours before, what the
## villagers say of it, and the church bell's hook.

const SEED := 7
const HOUR := GameClock.MINUTES_PER_HOUR

var _state: GameState
var _rules := NpcTalkRules.default_rules()


func before_each() -> void:
	_state = GameState.new_game(SEED)


func test_the_sky_turns_stormy_six_hours_before_the_sea_rises_and_clears_when_it_falls() -> void:
	var now := _state.clock.total_minutes()
	_state.world.surge.expect(2.8, now + 12 * HOUR, 3 * HOUR)

	assert_lt(_state.current_weather().storm, 1.0, "not yet, 10 hours before")
	_state.simulation.advance(5 * HOUR)
	assert_eq(_state.current_weather().storm, 1.0, "in the warning hours")
	assert_gt(_state.current_weather().wind_speed, 10.0)

	_state.world.surge.clear()
	assert_lt(_state.current_weather().storm, 1.0, "no surge, no storm of its own")


func test_a_forced_weather_still_wins() -> void:
	_state.world.surge.start_now(2.8, _state.clock.total_minutes(), 3 * HOUR)
	_state.weather_override = &"clear"
	assert_eq(_state.current_weather().storm, 0.0)


func test_the_bell_rings_every_hour_of_the_warning_and_without_a_break_once_the_sea_runs() -> void:
	var rings: Array[bool] = []
	_state.world.surge.bell_rung.connect(
		func(is_continuous: bool) -> void: rings.append(is_continuous)
	)
	var now := _state.clock.total_minutes()
	_state.world.surge.expect(2.8, now + 8 * HOUR, 3 * HOUR)

	_state.simulation.advance(4 * HOUR)

	assert_gt(rings.size(), 0, "rung in the warning")
	assert_false(rings.has(true), "not continuous before the sea rises")


func test_no_surge_no_bell() -> void:
	var rings: Array[bool] = []
	_state.world.surge.bell_rung.connect(
		func(is_continuous: bool) -> void: rings.append(is_continuous)
	)
	_state.simulation.advance(6 * HOUR)
	assert_eq(rings.size(), 0)


func test_the_villagers_know_of_a_surge_that_is_coming() -> void:
	var antje := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())
	_state.world.surge.expect(2.8, _state.clock.total_minutes() + 4 * HOUR, 3 * HOUR)

	var moment := NpcMoment.of(_state, antje, 5.0)

	assert_false(moment.surge.is_empty())
	assert_false(moment.surge["running"])
	var text: String = (
		NpcPrompt.reply_messages(antje, [], "Hello", moment, _rules, false)[-1]["content"]
	)
	assert_string_contains(text, "A storm surge is expected")
	assert_string_contains(text, "2.8 m")


func test_the_villagers_speak_of_the_flood_while_the_sea_runs() -> void:
	var antje := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())
	_state.world.surge.start_now(2.8, _state.clock.total_minutes(), 3 * HOUR)

	var moment := NpcMoment.of(_state, antje, 5.0)

	assert_true(moment.surge["running"])
	var text: String = (
		NpcPrompt.reply_messages(antje, [], "Hello", moment, _rules, false)[-1]["content"]
	)
	assert_string_contains(text, "The sea is running over the low dykes")


func test_no_surge_adds_nothing_to_the_prompt() -> void:
	var antje := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())
	var moment := NpcMoment.of(_state, antje, 5.0)
	assert_true(moment.surge.is_empty())
	var text: String = (
		NpcPrompt.reply_messages(antje, [], "Hello", moment, _rules, false)[-1]["content"]
	)
	assert_false(text.contains("surge"))


func test_the_lowest_sea_dyke_of_the_loaded_land_is_named() -> void:
	var world := CoastWorld.make()
	var lowest := world.dykes.lowest_sea_dyke_height(world)
	for dyke in CoastWorld.sea_dykes(world):
		assert_gte(world.dykes.height_of(dyke), lowest)
	assert_between(lowest, 1.5, 3.3)
	assert_eq(World.new(7).dykes.lowest_sea_dyke_height(World.new(7)), INF, "no chunk, no dyke")


func test_the_bell_rings_without_a_break_while_the_sea_runs_over_the_dykes() -> void:
	var rings: Array[bool] = []
	_state.world.surge.bell_rung.connect(
		func(is_continuous: bool) -> void: rings.append(is_continuous)
	)
	_state.world.surge.start_now(2.8, _state.clock.total_minutes(), 3 * HOUR)

	_state.simulation.advance(2 * HOUR)

	assert_true(rings.has(true))
