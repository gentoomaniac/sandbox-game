extends GutTest
## The skills file and its validation, and how a skill grows by practice and is saved.

const DATA_DIR := "user://test_skills"
const DATA_FILE := DATA_DIR + "/skills.cfg"
const RULES := {
	"cap": {"skill": 100.0},
	"gain": {"at_level": 2.0, "trivial_above": 40.0},
	"woodworking": {"name": "Woodworking", "description": "Wood."},
	"cooking": {"name": "Cooking", "description": "Food."},
}


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func _skills() -> Skills:
	return Skills.new(SkillRules.new(RULES))


# --- The data ---


func test_the_skills_file_is_valid_and_has_the_three_first_crafts() -> void:
	var rules := SkillRules.from_file(SkillRules.DEFAULT_PATH)
	assert_true(rules.is_valid(), str(rules.problems()))
	assert_eq(rules.skill_ids(), [&"woodworking", &"cooking", &"masonry"] as Array[StringName])
	assert_eq(rules.skill_name(&"masonry"), "Masonry")
	assert_eq(rules.skill_cap(), 100.0)


func test_every_missing_or_wrong_key_is_reported() -> void:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string('[gain]\nat_level=0\n\n[cooking]\nname="Cooking"\n')
	file.close()
	var rules := SkillRules.from_file(DATA_FILE)
	assert_eq(
		rules.problems(),
		(
			[
				"[cap] no skill",
				"[gain] at_level must be a number above 0",
				"[gain] no trivial_above",
				"[cooking] no description",
			]
			as Array[String]
		)
	)
	assert_push_error_count(4)


func test_a_file_with_no_skills_is_invalid() -> void:
	var rules := SkillRules.new({"cap": RULES["cap"], "gain": RULES["gain"]})
	assert_eq(rules.problems(), ["no skills"] as Array[String])


func test_a_missing_file_is_reported() -> void:
	var rules := SkillRules.from_file(DATA_DIR + "/none.cfg")
	assert_false(rules.is_valid())
	assert_push_error_count(rules.problems().size() + 1)


# --- Growing ---


func test_a_new_player_has_no_points_in_any_skill() -> void:
	assert_eq(PlayerState.new().skills.points(&"woodworking"), 0.0)


func test_a_recipe_at_the_skills_level_or_above_it_teaches_the_full_gain() -> void:
	var skills := _skills()
	assert_eq(skills.practise(&"woodworking", 0.0), 2.0)
	assert_eq(skills.points(&"woodworking"), 2.0)
	assert_eq(skills.gain_at(&"woodworking", 25.0), 2.0)


func test_the_gain_falls_evenly_and_a_trivial_recipe_teaches_nothing() -> void:
	var skills := _skills()
	skills.set_points(&"woodworking", 30.0)
	assert_eq(skills.gain_at(&"woodworking", 10.0), 1.0, "20 of 40 points above the level")
	assert_eq(skills.gain_at(&"woodworking", 0.0), 0.5)
	skills.set_points(&"woodworking", 40.0)
	assert_eq(skills.practise(&"woodworking", 0.0), 0.0)
	assert_eq(skills.points(&"woodworking"), 40.0)


func test_gains_are_whole_tenths() -> void:
	var skills := _skills()
	skills.set_points(&"woodworking", 5.0)
	assert_eq(skills.practise(&"woodworking", 0.0), 1.8, "1.75 rounds to 1.8")
	assert_eq(skills.points(&"woodworking"), 6.8)


func test_a_skill_saved_above_its_cap_learns_nothing_and_keeps_its_points() -> void:
	var skills := Skills.from_dict({"points": {"cooking": 120.0}, "fading": []})
	assert_eq(skills.gain_at(&"cooking", 90.0), 0.0)
	assert_eq(skills.practise(&"cooking", 90.0), 0.0)
	assert_eq(skills.points(&"cooking"), 120.0)


func test_a_skill_stops_at_its_cap() -> void:
	var skills := _skills()
	skills.set_points(&"cooking", 99.5)
	assert_eq(skills.practise(&"cooking", 90.0), 0.5)
	assert_eq(skills.points(&"cooking"), 100.0)
	assert_eq(skills.practise(&"cooking", 90.0), 0.0)
	skills.set_points(&"cooking", 150.0)
	assert_eq(skills.points(&"cooking"), 100.0)


func test_practising_says_the_skills_changed() -> void:
	var skills := _skills()
	watch_signals(skills)
	skills.practise(&"cooking", 0.0)
	assert_signal_emit_count(skills, "changed", 1)


# --- Saving ---


func test_the_skills_survive_a_save_round_trip() -> void:
	var state := GameState.new_game(7)
	state.player.skills.set_points(&"masonry", 12.3)
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(restored.player.skills.points(&"masonry"), 12.3)
	assert_eq(restored.player.skills.points(&"cooking"), 0.0)


# --- The console ---


func test_the_skill_command_sets_a_skills_points_within_its_cap() -> void:
	var state := GameState.new_game(7)
	var console := Console.new(state)
	assert_eq(console.run("skill masonry 42.5"), ["Masonry is 42.5"] as Array[String])
	assert_eq(state.player.skills.points(&"masonry"), 42.5)
	console.run("skill masonry 500")
	assert_eq(state.player.skills.points(&"masonry"), 100.0)


func test_the_skill_command_names_an_unknown_skill_and_wants_points() -> void:
	var console := Console.new(GameState.new_game(7))
	assert_eq(console.run("skill smithing 5"), ["Unknown skill: smithing"] as Array[String])
	assert_eq(console.run("skill masonry"), ["Usage: skill <skill> <points>"] as Array[String])
