extends GutTest
## The scripts of the targets are checked at startup: one added as a file is found and used, and a
## duplicate kind or a script that is no target makes the activity rules invalid (ActivityTargets).


## The real file with the kinds of the fixture folder added to the real ones, and, when `beer` is
## given, as an activity for everybody.
func _rules_with_fixtures(beer := {}) -> ActivityRules:
	var folder_problems: Array[String] = []
	var kinds := KindFolder.in_folder(
		"res://tests/activity_targets", ActivityTarget, folder_problems
	)
	kinds.merge(ActivityTargets.default_kinds())
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	if not beer.is_empty():
		values["have_a_beer"] = beer
		values["sets"]["base"].append("have_a_beer")
	return ActivityRules.new(values, kinds, folder_problems)


func test_a_target_file_that_is_found_is_used_by_an_activity() -> void:
	var beer := {"verb": "have a beer", "target": "inn", "doing": "stand", "inside": true}
	var rules := _rules_with_fixtures(beer)
	assert_eq(rules.target("inn").kind(), "inn")
	var problems := "\n".join(rules.problems())
	assert_false(problems.contains("have_a_beer"), problems)


func test_a_duplicate_kind_and_a_script_that_is_no_target_make_the_rules_invalid() -> void:
	var rules := _rules_with_fixtures()
	var problems := "\n".join(rules.problems())
	assert_false(rules.is_valid())
	assert_string_contains(problems, "inn_target.gd and ")
	assert_string_contains(problems, "second_inn_target.gd are both the kind inn")
	assert_string_contains(problems, "stray.gd is no script that extends ActivityTarget")


func test_the_targets_of_the_game_have_no_problems() -> void:
	assert_eq(ActivityTargets.default_problems(), [] as Array[String])


func test_startup_refuses_a_broken_target_file() -> void:
	var shipped := ActivityRules.default_rules()
	ActivityRules._default = _rules_with_fixtures()
	var is_refused: bool = not RulesCheck.checks()[&"activities"].call()
	ActivityRules._default = shipped
	assert_true(is_refused)
