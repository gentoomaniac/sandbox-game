extends GutTest
## The quests of the villagers (QuestRules, data/quests/): the folder is clean, the limits are read,
## each kind of fault is reported by file, and a kind added as a file is found (QuestKinds).

const FIBRE := "fibre_for_beans"

var _rules := QuestRules.default_rules()


## The real quest FIBRE with `changes` made to it, and a second quest `other`, as rules.
func _rules_with(changes: Dictionary) -> QuestRules:
	var quest: Dictionary = _rules.quest(FIBRE).duplicate(true)
	quest.merge(changes, true)
	var limits := {
		"villagers":
		{
			"max_open": _rules.max_open(),
			"per_day": _rules.per_day(),
			"repeat_after_days": _rules.repeat_after_days(),
			"default_days": 8,
		},
		"log": {"quest_log_size": _rules.quest_log_size()},
	}
	return QuestRules.new({FIBRE: quest, "other": _rules.quest(FIBRE)}, limits)


func _assert_one_problem(changes: Dictionary, part_of_it: String) -> void:
	var found := _rules_with(changes).problems()
	assert_eq(found.size(), 1, str(found))
	if found.size() == 1:
		assert_string_contains(found[0], FIBRE + ".cfg: ")
		assert_string_contains(found[0], part_of_it)


func test_the_data_folder_is_clean() -> void:
	assert_eq(_rules.problems(), [] as Array[String])
	assert_true(_rules.is_valid())


func test_every_file_but_the_limits_is_a_quest_named_by_its_file() -> void:
	assert_eq(_rules.ids().size(), 4)
	assert_has(_rules.ids(), FIBRE)
	assert_false(_rules.has("_limits"))
	assert_eq(_rules.quest(FIBRE)["objective"], {"type": "bring", "item": "fibre", "count": 5})


func test_the_limits_are_those_of_the_file() -> void:
	assert_eq(_rules.max_open(), 10)
	assert_eq(_rules.per_day(), 1)
	assert_eq(_rules.repeat_after_days(), 20)
	assert_eq(_rules.quest_log_size(), 10)


func test_a_quest_has_the_default_days_and_any_giver_unless_it_says_otherwise() -> void:
	assert_eq(_rules.days_of("stool_for_the_loom"), 12)
	var rules := _rules_with({})
	rules.quest(FIBRE).erase("days")
	rules.quest(FIBRE).erase("giver")
	assert_eq(rules.days_of(FIBRE), 8)
	assert_eq(rules.giver_of(FIBRE), QuestRules.ANY_GIVER)
	assert_true(_rules.is_starter(FIBRE))
	assert_false(_rules.is_starter("stool_for_the_loom"))


func test_a_starter_asks_for_what_is_there_from_the_start() -> void:
	for id in _rules.ids():
		if _rules.is_starter(id):
			var requires: Array = _rules.quest(id).get("requires", [])
			for entry: Dictionary in requires:
				assert_has(QuestRules.STARTER_CONDITIONS, entry["type"], id)


func test_a_missing_key_is_reported() -> void:
	var rules := _rules_with({})
	rules.quest(FIBRE).erase("dialogue")
	assert_string_contains(rules.problems()[0], "no dialogue")


func test_an_unknown_giver_is_reported() -> void:
	_assert_one_problem({"giver": "nobody"}, "giver")


func test_days_out_of_range_are_reported() -> void:
	_assert_one_problem({"days": 0}, "days")
	_assert_one_problem({"days": QuestRules.MAX_DAYS + 1}, "days")


func test_a_notice_too_long_or_naming_an_unknown_word_is_reported() -> void:
	_assert_one_problem({"notice": "x".repeat(QuestRules.MAX_NOTICE_LENGTH + 1)}, "notice")
	_assert_one_problem({"notice": "See {baker}."}, "{baker}")


func test_empty_or_too_long_dialogue_is_reported() -> void:
	_assert_one_problem({"dialogue": []}, "dialogue")
	_assert_one_problem({"turn_in": ["a", "b", "c", "d", "e", "f", "g"]}, "turn_in")
	_assert_one_problem({"dialogue": ["fine", 3]}, "dialogue")


func test_the_short_line_may_name_the_count_and_what_is_held_and_nothing_else() -> void:
	assert_eq(_rules_with({"short": "{have} of {count}"}).problems(), [] as Array[String])
	_assert_one_problem({"short": "{giver}"}, "{giver}")


func test_an_unknown_or_incomplete_objective_is_reported() -> void:
	_assert_one_problem({"objective": {"type": "dance"}}, "objective type")
	_assert_one_problem({"objective": {"type": "bring", "item": "fibre", "count": 0}}, "count")
	_assert_one_problem(
		{"objective": {"type": "bring", "item": "gold", "count": 1}}, "item is no item"
	)
	_assert_one_problem({"objective": "fibre"}, "objective")


func test_each_kind_of_prerequisite_is_checked() -> void:
	var good := [
		{"type": "opinion", "at_least": 0},
		{"type": "opinion", "at_least": 10, "villager": "antje"},
		{"type": "skill", "skill": "woodworking", "at_least": 5},
		{"type": "season", "seasons": ["spring"]},
		{"type": "day", "at_least": 3, "at_most": 9},
		{"type": "quest_done", "quest": "other"},
	]
	assert_eq(_rules_with({"starter": false, "requires": good}).problems(), [] as Array[String])
	var bad := [
		[{"type": "opinion", "at_least": "much"}, "at_least"],
		[{"type": "opinion", "at_least": 0, "villager": "nobody"}, "villager"],
		[{"type": "skill", "skill": "juggling", "at_least": 1}, "skill is no skill"],
		[{"type": "season", "seasons": ["monsoon"]}, "seasons"],
		[{"type": "day"}, "neither"],
		[{"type": "quest_done", "quest": "ghost"}, "quest is no quest"],
		[{"type": "weather"}, "type is none of"],
	]
	for case: Array in bad:
		_assert_one_problem({"starter": false, "requires": [case[0]]}, case[1])


func test_a_starter_may_not_need_more_than_the_day_and_the_season() -> void:
	_assert_one_problem(
		{"requires": [{"type": "skill", "skill": "woodworking", "at_least": 2}]},
		"a starter may only"
	)


func test_a_reward_must_hold_something_that_exists() -> void:
	_assert_one_problem({"reward": {}}, "nothing in it")
	_assert_one_problem({"reward": {"items": {"gold": 1}}}, "reward item gold")
	_assert_one_problem({"reward": {"items": {"wax": 0}}}, "reward item wax")
	_assert_one_problem({"reward": {"opinion_steps": 4}}, "opinion_steps")
	assert_eq(_rules_with({"reward": {"opinion_steps": 3}}).problems(), [] as Array[String])


func test_a_limit_that_is_missing_is_reported() -> void:
	var rules := QuestRules.new({}, {"villagers": {"max_open": 10}})
	var found := rules.problems()
	assert_string_contains("\n".join(found), "[villagers] per_day")
	assert_string_contains("\n".join(found), "[log] quest_log_size")


func test_a_file_with_the_wrong_sections_is_reported() -> void:
	var rules := QuestRules.new({}, {}, ["odd.cfg: has not just a [quest] section"])
	assert_string_contains(rules.problems()[0], "odd.cfg")


func test_a_kind_added_as_a_file_is_found_and_a_bad_one_is_reported() -> void:
	var problems: Array[String] = []
	var kinds := QuestKinds.in_folder("res://tests/quest_kinds", QuestObjective, problems)
	assert_eq(kinds.keys(), ["shout"])
	assert_eq(problems.size(), 3, str(problems))
	var text := "\n".join(problems)
	assert_string_contains(text, "shout_twice_objective.gd: shout is also the kind")
	assert_string_contains(text, "stray.gd is no script that extends QuestObjective")
	assert_string_contains(text, "unnamed_objective.gd has no kind")


func test_the_kinds_of_the_game_are_found_by_name() -> void:
	var problems: Array[String] = []
	var objectives := QuestKinds.in_folder(QuestKinds.OBJECTIVES_DIR, QuestObjective, problems)
	var conditions := QuestKinds.in_folder(QuestKinds.CONDITIONS_DIR, QuestCondition, problems)
	assert_eq(problems, [] as Array[String])
	assert_eq(objectives.keys(), ["bring"])
	var names := conditions.keys()
	names.sort()
	assert_eq(names, ["day", "opinion", "quest_done", "season", "skill"])
