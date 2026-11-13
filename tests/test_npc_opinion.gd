extends GutTest
## What a villager thinks of the player (Npc `opinion`, in points): moved by the points of a
## change up to a cap a day, kept between its bounds, told to the language model in words, and
## shown and set by the console's `opinion`.

var _rules := GossipRules.default_rules()
var _antje: Npc
var _state: GameState
var _console: Console


func before_each() -> void:
	_state = GameState.new_game(7)
	_console = Console.new(_state)
	_antje = Npc.create_villager("antje", Vector2.ZERO, _state.npcs.villagers)
	_state.npcs.add(_antje)


func _prompt_tells(opinion: int) -> String:
	_antje.opinion = opinion
	var moment := NpcMoment.of(_state, _antje, 8.0)
	var messages := NpcPrompt.reply_messages(
		_antje, [], "Moin", moment, NpcTalkRules.default_rules(), false
	)
	return messages[-1]["content"]


func test_a_villager_starts_with_no_opinion() -> void:
	assert_eq(_antje.opinion, 0)


func test_points_move_the_opinion() -> void:
	_antje.change_opinion(10, 3, _rules)
	_antje.change_opinion(-4, 3, _rules)
	assert_eq(_antje.opinion, 6)


func test_a_day_moves_the_opinion_by_the_cap_at_most_each_way() -> void:
	var cap := _rules.opinion_daily_cap()
	_antje.change_opinion(cap, 3, _rules)
	_antje.change_opinion(10, 3, _rules)
	assert_eq(_antje.opinion, cap, "nothing more upwards today")
	_antje.change_opinion(-10, 3, _rules)
	assert_eq(_antje.opinion, cap - 10, "a step back is taken")
	_antje.change_opinion(-100, 3, _rules)
	assert_eq(_antje.opinion, -cap, "and down to the cap the other way, no further")


func test_a_new_day_has_its_own_cap() -> void:
	var cap := _rules.opinion_daily_cap()
	_antje.change_opinion(cap, 3, _rules)
	_antje.change_opinion(cap, 4, _rules)
	assert_eq(_antje.opinion, 2 * cap)


func test_the_opinion_stays_between_its_bounds() -> void:
	_antje.opinion = _rules.opinion_max() - 5
	_antje.change_opinion(_rules.opinion_daily_cap(), 3, _rules)
	assert_eq(_antje.opinion, _rules.opinion_max())
	_antje.opinion = _rules.opinion_min() + 5
	_antje.change_opinion(-_rules.opinion_daily_cap(), 4, _rules)
	assert_eq(_antje.opinion, _rules.opinion_min())


func test_the_opinion_has_a_word() -> void:
	assert_eq(_rules.opinion_word(0), &"neutral")
	assert_eq(_rules.opinion_word(_rules.opinion_warm_from()), &"warm")
	assert_eq(_rules.opinion_word(_rules.opinion_warm_from() - 1), &"neutral")
	assert_eq(_rules.opinion_word(_rules.opinion_cold_below()), &"neutral")
	assert_eq(_rules.opinion_word(_rules.opinion_cold_below() - 1), &"cold")


func test_the_prompt_tells_the_opinion_in_words_not_numbers() -> void:
	assert_string_contains(_prompt_tells(0), "no strong feelings")
	assert_string_contains(_prompt_tells(77), "thinks well of this neighbour")
	assert_false(_prompt_tells(77).contains("77"))
	assert_string_contains(_prompt_tells(-50), "thinks ill of this neighbour")


func test_the_console_shows_the_opinion() -> void:
	_antje.opinion = 30
	assert_eq(_console.run("opinion antje"), ["Antje Boysen: warm (30 points)"])


func test_the_console_sets_the_opinion_within_its_bounds() -> void:
	assert_eq(_console.run("opinion antje -30"), ["Antje Boysen: cold (-30 points)"])
	assert_eq(_antje.opinion, -30)
	_console.run("opinion antje 99999")
	assert_eq(_antje.opinion, _rules.opinion_max())


func test_the_console_asks_for_a_villager_and_whole_points() -> void:
	assert_eq(_console.run("opinion"), ["Usage: opinion <villager> [points]"])
	assert_eq(_console.run("opinion antje lots"), ["Usage: opinion <villager> [points]"])
	assert_string_contains(_console.run("opinion nobody")[0], "nobody")
