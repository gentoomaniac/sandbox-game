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
