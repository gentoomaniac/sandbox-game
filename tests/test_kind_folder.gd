extends GutTest
## The folders of kinds (KindFolder): a kind added as a file is found, a bad one is reported.


func test_a_kind_added_as_a_file_is_found_and_a_bad_one_is_reported() -> void:
	var problems: Array[String] = []
	var kinds := KindFolder.in_folder("res://tests/quest_kinds", QuestObjective, problems)
	assert_eq(kinds.keys(), ["shout"])
	assert_eq(problems.size(), 3, str(problems))
	var text := "\n".join(problems)
	assert_string_contains(text, "shout_objective.gd and ")
	assert_string_contains(text, "shout_twice_objective.gd are both the kind shout")
	assert_string_contains(text, "stray.gd is no script that extends QuestObjective")
	assert_string_contains(text, "unnamed_objective.gd has no kind")


func test_the_kinds_of_the_game_are_found_by_name() -> void:
	var problems: Array[String] = []
	var objectives := KindFolder.in_folder(QuestKinds.OBJECTIVES_DIR, QuestObjective, problems)
	var conditions := KindFolder.in_folder(QuestKinds.CONDITIONS_DIR, QuestCondition, problems)
	assert_eq(problems, [] as Array[String])
	assert_eq(objectives.keys(), ["bring", "build"])
	var names := conditions.keys()
	names.sort()
	assert_eq(names, ["day", "opinion", "quest_done", "season", "skill"])
