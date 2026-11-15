extends GutTest
## The ten levels of friendship (data/friendship.cfg): which points are which level, and what
## makes the data file bad.

var _rules := FriendshipRules.default_rules()


func _rules_with_level(level: int, entry: Variant) -> FriendshipRules:
	var values := DataFile.read_sections(FriendshipRules.DEFAULT_PATH)
	values["levels"]["level_%d" % level] = entry
	return FriendshipRules.new(values)


func test_the_data_file_has_no_problems() -> void:
	assert_eq(_rules.problems(), [])


func test_every_point_has_one_level_and_the_levels_only_go_up() -> void:
	var gossip := GossipRules.default_rules()
	var level := 1
	for points in range(gossip.opinion_min(), gossip.opinion_max() + 1):
		var found := _rules.level_of(points)
		assert_between(found, level, level + 1, "%d points" % points)
		if found != level:
			assert_eq(points, _rules.first_point_of(found), "a level starts where it says")
		level = found
	assert_eq(level, FriendshipRules.LEVEL_COUNT)


func test_the_first_level_starts_at_the_lowest_opinion() -> void:
	assert_eq(_rules.first_point_of(1), GossipRules.default_rules().opinion_min())


func test_a_new_acquaintance_is_a_stranger_between_the_old_cold_and_warm() -> void:
	assert_eq(_rules.level_of(0), 3)
	assert_eq(_rules.level_of(-21), 2)
	assert_eq(_rules.level_of(-20), 3)
	assert_eq(_rules.level_of(19), 3)
	assert_eq(_rules.level_of(20), 4)


func test_the_levels_have_the_names_of_the_plan() -> void:
	assert_eq(_rules.level_name(1), "Shunned")
	assert_eq(_rules.level_name(3), "Stranger")
	assert_eq(_rules.level_name(10), "Heart's friend")


func test_two_levels_are_cold_one_neutral_and_the_rest_warm() -> void:
	assert_eq(_rules.mood_of(-100), &"cold")
	assert_eq(_rules.mood_of(-21), &"cold")
	assert_eq(_rules.mood_of(0), &"neutral")
	assert_eq(_rules.mood_of(20), &"warm")
	assert_eq(_rules.mood_of(1000), &"warm")


func test_a_missing_level_is_a_problem() -> void:
	var values := DataFile.read_sections(FriendshipRules.DEFAULT_PATH)
	values["levels"].erase("level_5")
	assert_eq(FriendshipRules.new(values).problems().size(), 1)


func test_a_level_that_is_no_entry_is_a_problem() -> void:
	assert_eq(_rules_with_level(4, ["Acquaintance", "twenty", "warm"]).problems().size(), 1)


func test_a_level_not_above_the_one_before_is_a_problem() -> void:
	assert_eq(_rules_with_level(4, ["Acquaintance", -20, "warm"]).problems().size(), 1)


func test_an_unknown_mood_is_a_problem() -> void:
	assert_eq(_rules_with_level(4, ["Acquaintance", 20, "hot"]).problems().size(), 1)


func test_an_eleventh_level_is_a_problem() -> void:
	var values := DataFile.read_sections(FriendshipRules.DEFAULT_PATH)
	values["levels"]["level_11"] = ["Lover", 1000, "warm"]
	assert_eq(FriendshipRules.new(values).problems().size(), 1)


func test_the_cap_of_the_actions_is_60_points_a_day() -> void:
	assert_eq(_rules.action_daily_cap(), 60)


func test_a_cap_that_is_no_number_is_a_problem() -> void:
	var values := DataFile.read_sections(FriendshipRules.DEFAULT_PATH)
	values["caps"]["action_daily_cap_points"] = "sixty"
	assert_eq(FriendshipRules.new(values).problems().size(), 1)


func test_every_benefit_opens_at_the_level_of_the_plan() -> void:
	var plan := {
		&"talk": 2,
		&"trade": 3,
		&"quests": 3,
		&"greets_by_name": 4,
		&"small_news": 4,
		&"barter": 5,
		&"tells_wants": 5,
		&"better_prices": 6,
		&"lends_tool": 6,
		&"teaches": 7,
		&"tells_secrets": 8,
		&"invites_inside": 8,
		&"best_wares": 9,
		&"may_court": 10,
	}
	assert_eq(plan.keys(), FriendshipRules.BENEFITS)
	for benefit: StringName in plan:
		assert_eq(_rules.benefit_level(benefit), plan[benefit], benefit)
		assert_true(_rules.allows(benefit, plan[benefit]), "at its level: %s" % benefit)
		assert_false(_rules.allows(benefit, plan[benefit] - 1), "one below: %s" % benefit)


func test_a_sheet_moves_a_benefit_to_its_own_level() -> void:
	var earlier := {"lends_tool": 4}

	assert_true(_rules.allows(&"lends_tool", 4, earlier))
	assert_false(_rules.allows(&"lends_tool", 3, earlier))
	assert_false(_rules.allows(&"teaches", 4, earlier), "the others stay")
	assert_false(_rules.allows(&"teaches", 7, {"teaches": 9}), "held back")


func test_a_benefit_missing_or_below_level_2_or_above_10_is_a_problem() -> void:
	var values := DataFile.read_sections(FriendshipRules.DEFAULT_PATH)
	values["benefits"].erase("barter")
	values["benefits"]["talk"] = 1
	values["benefits"]["may_court"] = 11

	assert_eq(FriendshipRules.new(values).problems().size(), 3)


func test_a_sheets_benefit_levels_are_checked() -> void:
	var sheets := DataFile.read_sections(VillagerRules.DEFAULT_PATH)
	assert_eq(VillagerRules.new(sheets).benefit_levels("antje"), {})
	sheets["antje"]["benefit_level"] = {"lends_tool": 5}
	assert_eq(VillagerRules.new(sheets).problems(), [])
	assert_eq(VillagerRules.new(sheets).benefit_levels("antje"), {"lends_tool": 5})
	for bad in [{"lends_tool": 1}, {"lends_tool": 11}, {"flying": 5}, {"lends_tool": "5"}, 5]:
		sheets["antje"]["benefit_level"] = bad
		assert_eq(VillagerRules.new(sheets).problems().size(), 1, str(bad))
