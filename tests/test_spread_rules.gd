extends GutTest
## The numbers of how stories spread (data/gossip.cfg, SpreadRules), and what makes them bad.

var _rules := SpreadRules.default_rules()


func _rules_with(key: String, value: Variant) -> SpreadRules:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	values["meetings"][key] = value
	return SpreadRules.new(values)


func test_the_data_file_has_no_problems() -> void:
	assert_eq(_rules.problems(), [])


func test_villagers_within_three_tiles_meet_a_pair_once_an_hour() -> void:
	assert_eq(_rules.meeting_radius(), 3.0)
	assert_eq(_rules.pair_wait_minutes(), 60)


func test_a_story_waits_two_hours_and_stops_after_three_hops_or_seven_days() -> void:
	assert_eq(_rules.story_wait_minutes(), 120)
	assert_eq(_rules.max_hops(), 3)
	assert_eq(_rules.max_story_days(), 7)


func test_family_tell_more_often_than_neighbours_and_neighbours_more_than_anyone() -> void:
	assert_gt(_rules.tell_chance(SpreadRules.FAMILY), _rules.tell_chance(SpreadRules.NEIGHBOUR))
	assert_gt(_rules.tell_chance(SpreadRules.NEIGHBOUR), _rules.tell_chance(SpreadRules.ANYONE))
	assert_eq(_rules.neighbour_count(), 3)


func test_a_missing_key_is_a_problem() -> void:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	values["meetings"].erase("max_hops")
	assert_eq(SpreadRules.new(values).problems(), ["[meetings] no max_hops"])


func test_a_chance_beyond_one_and_a_wait_of_nothing_are_problems() -> void:
	assert_eq(_rules_with("chance_family", 1.5).problems().size(), 1)
	assert_eq(_rules_with("story_wait_minutes", 0).problems().size(), 1)
	assert_eq(_rules_with("max_hops", 0).problems().size(), 1)
