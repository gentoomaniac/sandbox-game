extends SaveValidationCase
## The plans the language model made for the days of the villagers are saved (version 47); a save
## from before them (version 46) gives every villager the default day.

const DAY := 20

var _state: GameState


func before_each() -> void:
	_state = GameFactory.new_game(7)


func _plan(day: int, is_whole_day: bool) -> DayPlan:
	var entries: Array[DayEntry] = [
		DayEntry.new("breakfast", 6 * 60, 0, "a late start"),
		DayEntry.new("rest", 13 * 60 + 30),
		DayEntry.new("sleep", 21 * 60, 0, "an early night"),
	]
	return DayPlan.new(day, entries, is_whole_day, (day - 1) * GameClock.MINUTES_PER_DAY - 260)


func _saved_villager() -> Dictionary:
	var npc := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())
	return JSON.parse_string(JSON.stringify(npc.to_dict()))


func test_the_plans_of_a_villager_are_kept() -> void:
	var antje := Npc.create_villager("antje", Vector2(3.5, 4.5), _state.npcs.villagers)
	antje.day_plans[DAY] = _plan(DAY, true)
	antje.day_plans[DAY + 1] = _plan(DAY + 1, false)
	_state.npcs.add(antje)
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq(loaded.day_plans.keys(), [DAY, DAY + 1])
	var whole: DayPlan = loaded.day_plans[DAY]
	var rest: DayPlan = loaded.day_plans[DAY + 1]
	assert_true(whole.is_whole_day)
	assert_false(rest.is_whole_day)
	assert_eq(whole.made_at, antje.day_plans[DAY].made_at)
	assert_eq(whole.entries.size(), 3)
	assert_eq(whole.entries[0].activity, "breakfast")
	assert_eq(whole.entries[0].minute, 6 * 60)
	assert_eq(whole.entries[0].why, "a late start")
	assert_eq(whole.entries[1].minute, 13 * 60 + 30)
	assert_eq(whole.entries[1].minutes, 0)


func test_a_villager_with_no_plan_is_kept_so() -> void:
	_state.npcs.add(Npc.create_villager("antje", Vector2.ZERO, _state.npcs.villagers))
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_true(loaded.day_plans.is_empty())


func test_a_version_46_save_gives_every_villager_the_default_day() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	saved.erase("day_plans")
	game["npcs"] = [saved]
	_write_save(46, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()

	assert_eq(loaded.size(), 1)
	assert_true(loaded[0].day_plans.is_empty())


func test_a_save_without_the_plans_is_refused() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	saved.erase("day_plans")
	game["npcs"] = [saved]

	assert_true(_refusal_of(game).problems.has("npcs 0: no day_plans"))


func test_a_plan_without_entries_or_with_a_minute_out_of_the_day_is_refused() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	var plan := _plan(DAY, true).to_dict()
	plan["entries"] = []
	var late := _plan(DAY, true).to_dict()
	late["entries"][0][1] = 1440
	saved["day_plans"] = [plan, late]
	game["npcs"] = [saved]

	var problems: Array = _refusal_of(game).problems

	assert_eq(
		problems,
		[
			"npcs 0 day_plans 0: has no entries",
			"npcs 0 day_plans 1: entry minute 1440 is not in the day"
		],
		str(problems)
	)


func test_a_plan_with_an_activity_the_game_no_longer_has_asks_and_is_dropped() -> void:
	var game := _current_game()
	var saved := _saved_villager()
	var plan := _plan(DAY, true).to_dict()
	plan["entries"][1][0] = "juggling"
	saved["day_plans"] = [plan, _plan(DAY + 1, true).to_dict()]
	game["npcs"] = [saved]

	var result := _question_about(game)

	assert_eq(result.missing, ["activity juggling in npcs 0 day_plans 0"])
	var loaded := result.load_dropping_missing().npcs.all()[0]
	assert_eq(loaded.day_plans.keys(), [DAY + 1], "the other plan stays")
